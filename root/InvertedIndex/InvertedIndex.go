package main

import (
	"io"
	"log"
	"strings"
	"sync"
	"unicode"

	pb "gateway_service/ProtoGenerated/InvertedIndex"
)

type Entry struct {
	Filename string
	Count    uint32
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
	count    uint32
}

func (s *InvertedIndexServer) BuildIndex(stream pb.InvertedIndex_BuildIndexServer) error {
	log.Println("BuildIndex: New client connection.")

	updateTasksChan := make(chan wordUpdateTask, 1024)
	var parsersWg sync.WaitGroup
	var aggregatorWg sync.WaitGroup

	aggregatorWg.Add(1)
	go func() {
		defer aggregatorWg.Done()
		log.Println("BuildIndex: Aggregator goroutine started.")
		for task := range updateTasksChan {
			s.dictMutex.Lock()

			entries, ok := s.freqDictionary[task.word]
			if !ok {
				entries = []Entry{}
			}
			found := false
			for i := range entries {
				if entries[i].Filename == task.filename {
					entries[i].Count += task.count
					found = true
					break
				}
			}
			if !found {
				entries = append(entries, Entry{Filename: task.filename, Count: task.count})
			}
			s.freqDictionary[task.word] = entries

			s.dictMutex.Unlock()
		}
		log.Println("BuildIndex: Aggregator goroutine finished.")
	}()

	for {
		request, err := stream.Recv()
		if err == io.EOF {
			log.Println("BuildIndex: EOF received from client stream.")
			break
		}
		if err != nil {
			log.Printf("BuildIndex: Error receiving from stream: %v", err)
			close(updateTasksChan)
			parsersWg.Wait()
			aggregatorWg.Wait()
			return err
		}

		log.Printf("BuildIndex: Received request for filename: %s", request.Filename)

		parsersWg.Add(1)
		go func(req *pb.IndexRequest) {
			defer parsersWg.Done()
			localWordCounts := make(map[string]uint32)
			words := strings.FieldsFunc(req.Text, func(r rune) bool {
				return !unicode.IsLetter(r) && !unicode.IsNumber(r)
			})

			for _, wordRaw := range words {
				normalizedWord := normalizeWord(wordRaw)
				if normalizedWord != "" {
					localWordCounts[normalizedWord]++
				}
			}

			for word, count := range localWordCounts {
				updateTasksChan <- wordUpdateTask{
					word:     word,
					filename: req.Filename,
					count:    count,
				}
			}
		}(request)
	}

	log.Println("BuildIndex: All requests read. Waiting for parsers...")
	parsersWg.Wait()
	log.Println("BuildIndex: Parsers completed. Closing updateTasksChan.")
	close(updateTasksChan)

	log.Println("BuildIndex: Waiting for aggregator...")
	aggregatorWg.Wait()
	log.Println("BuildIndex: Aggregator completed. Preparing response.")

	s.dictMutex.Lock()
	responseEntries := make([]*pb.WordEntry, 0, len(s.freqDictionary))
	for word, fileEntries := range s.freqDictionary {
		log.Printf("%s", word)
		pbFileFreqs := make([]*pb.FileFrequency, 0, len(fileEntries))
		for _, fileEntry := range fileEntries {
			log.Printf("%s : %i", fileEntry.Filename, fileEntry.Count)
			pbFileFreqs = append(pbFileFreqs, &pb.FileFrequency{
				Filename:  fileEntry.Filename,
				Frequency: int32(fileEntry.Count),
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
		log.Printf("BuildIndex: Error sending response: %v", err)
		return err
	}
	for entry := range s.freqDictionary {
		delete(s.freqDictionary, entry)
	}
	log.Println("BuildIndex: Response sent to client. Method finished.")
	return nil
}
