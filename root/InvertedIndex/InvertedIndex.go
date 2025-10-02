package main

import (
	"io"
	"strings"
	"sync"
	"unicode"

	pb "gateway_service/ProtoGenerated/InvertedIndex"
)

type Entry struct {
	Filename string
	Count    []int32
}

type InvertedIndexServer struct {
	pb.UnimplementedInvertedIndexServer

	freqDictionary map[string][]Entry
	dictMutex      sync.Mutex
}

func NewInvertedIndexServer() *InvertedIndexServer {
	return &InvertedIndexServer{
		freqDictionary: make(map[string][]Entry),
	}
}

func normalizeWord(wordRaw string) string {
	wordLower := strings.ToLower(wordRaw)
	var builder strings.Builder
	for _, r := range wordLower {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			builder.WriteRune(r)
		}
	}
	return builder.String()
}

type wordUpdateTask struct {
	word     string
	filename string
	indexes  []int32
}

func (s *InvertedIndexServer) BuildIndex(stream pb.InvertedIndex_BuildIndexServer) error {

	updateTasksChan := make(chan wordUpdateTask, 1024)
	var parsersWg sync.WaitGroup
	var aggregatorWg sync.WaitGroup

	aggregatorWg.Go(func() {
		for task := range updateTasksChan {
			s.dictMutex.Lock()

			entries, ok := s.freqDictionary[task.word]
			if !ok {
				entries = []Entry{}
			}
			found := false
			for i := range entries {
				if entries[i].Filename == task.filename {
					entries[i].Count = append(entries[i].Count, task.indexes...)
					found = true
					break
				}
			}
			if !found {
				entries = append(entries, Entry{Filename: task.filename, Count: task.indexes})
			}
			s.freqDictionary[task.word] = entries

			s.dictMutex.Unlock()
		}
	},
	)

	for {
		request, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			close(updateTasksChan)
			parsersWg.Wait()
			aggregatorWg.Wait()
			return err
		}

		parsersWg.Add(1)
		go func(req *pb.IndexRequest) {
			defer parsersWg.Done()
			localWordCounts := make(map[string][]int32)
			words := strings.FieldsFunc(req.Text, func(r rune) bool {
				return !unicode.IsLetter(r) && !unicode.IsNumber(r)
			})

			for idx, wordRaw := range words {
				print(idx)
				normalizedWord := normalizeWord(wordRaw)
				if normalizedWord != "" {
					localWordCounts[normalizedWord] = append(localWordCounts[normalizedWord], int32(idx))
				}
			}

			for word, count := range localWordCounts {
				updateTasksChan <- wordUpdateTask{
					word:     word,
					filename: req.Filename,
					indexes:  count,
				}
			}
		}(request)
	}

	parsersWg.Wait()
	close(updateTasksChan)

	aggregatorWg.Wait()

	s.dictMutex.Lock()
	responseEntries := make([]*pb.WordEntry, 0, len(s.freqDictionary))
	for word, fileEntries := range s.freqDictionary {
		pbFileFreqs := make([]*pb.FileFrequency, 0, len(fileEntries))
		for _, fileEntry := range fileEntries {
			pbFileFreqs = append(pbFileFreqs, &pb.FileFrequency{
				Filename:  fileEntry.Filename,
				Frequency: fileEntry.Count,
			})
		}
		responseEntries = append(responseEntries, &pb.WordEntry{
			Word:  word,
			Files: pbFileFreqs,
		})
	}
	s.dictMutex.Unlock()

	response := &pb.IndexResponse{
		Entries: responseEntries,
	}

	if err := stream.SendAndClose(response); err != nil {
		return err
	}
	for entry := range s.freqDictionary {
		delete(s.freqDictionary, entry)
	}
	return nil
}
