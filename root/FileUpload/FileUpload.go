package main

import (
	"context"
	"gateway_service/Gateway"
	pbAnswerReceive "gateway_service/ProtoGenerated/AnswerReceive"
	pbConverter "gateway_service/ProtoGenerated/Converter"
	pbFileUpload "gateway_service/ProtoGenerated/FileUpload"
	pbInvertedIndex "gateway_service/ProtoGenerated/InvertedIndex"
	"io"
	"log"
	"sync"
)

type FileUploadServer struct {
	pbFileUpload.UnimplementedFileServiceServer
}

func (s *FileUploadServer) UploadFile(streamFileUpload pbFileUpload.FileService_UploadFileServer) error {
	ctx := context.TODO()
	gateway := Gateway.GetGatewayInstance()
	streamConverter, err := gateway.GetConverterClient().ConvertFile(ctx)
	if err != nil {
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Err!",
		})
		return err
	}
	streamInvertedIndex, err := gateway.GetInvertedIndexClient().BuildIndex(ctx)
	if err != nil {
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Err!",
		})
		return err
	}
	streamAnswerReceive, err := gateway.GetAnswerReceiveClient().SendDictionary(ctx)
	if err != nil {
		log.Printf("%v", err)
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Eror!",
		})
		return err
	}
	var wg sync.WaitGroup
	errs := make(chan error, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		for {
			file, err := streamFileUpload.Recv()
			if err == io.EOF {
				err := streamConverter.CloseSend()
				if err != nil {
					errs <- err
				}
				return
			}
			if err != nil {
				errs <- err
				return
			}
			log.Printf("%s", file.Filename)
			if err := streamConverter.Send(&pbConverter.FileChunk{Filename: file.Filename, Content: file.Content}); err != nil {
				errs <- err
				return
			}
		}
	}()
	go func() {
		defer wg.Done()
		for {
			parsedText, err := streamConverter.Recv()
			if err == io.EOF {
				err := streamInvertedIndex.CloseSend()
				if err != nil {
					errs <- err
				}
				return
			}
			if err := streamInvertedIndex.Send(
				&pbInvertedIndex.IndexRequest{Filename: parsedText.Filename, Text: parsedText.Text}); err != nil {
				errs <- err
				return
			}
		}
	}()

	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			return err
		}
	}
	resp, err := streamInvertedIndex.CloseAndRecv()
	if err != nil {
		return err
	}
	for _, entry := range resp.Entries {
		wordEntry := pbAnswerReceive.WordEntry{
			Word:  entry.Word,
			Files: make([]*pbAnswerReceive.FileFrequency, len(entry.Files)),
		}
		for _, file := range entry.Files {
			wordEntry.Files = append(wordEntry.Files, &pbAnswerReceive.FileFrequency{Filename: file.Filename, Frequency: file.Frequency})
		}
		err = streamAnswerReceive.Send(&wordEntry)
		if err != nil {
			log.Printf("Error: %v", err)
			return err
		}
	}
	_, err = streamAnswerReceive.CloseAndRecv()
	if err != nil {
		log.Printf("Error: %v", err)
		return err
	}
	return streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
		Message: "Successfully processed files!",
	})
}
func (s *FileUploadServer) SendQuery(streamFileUpload pbFileUpload.FileService_SendQueryServer) error {
	ctx := context.TODO()
	gateway := Gateway.GetGatewayInstance()
	streamAnswerReceive, err := gateway.GetAnswerReceiveClient().Search(ctx)
	if err != nil {
		return err
	}
	errors := make(chan error, 2)
	go func() {
		for {
			query, err := streamFileUpload.Recv()
			if err == io.EOF {
				break
			}
			if err != nil {
				errors <- err
				break
			}
			err = streamAnswerReceive.Send(&pbAnswerReceive.Query{Query: query.Query})
			if err != nil {
				errors <- err
				break
			}

		}
	}()
	go func() {
		for {
			queryAnswer, err := streamAnswerReceive.Recv()
			if err == io.EOF {
				_ = streamAnswerReceive.CloseSend()
				break
			}
			if err != nil {
				errors <- err
				break
			}
			var result pbFileUpload.QueryResult
			result.Query = queryAnswer.Query
			for _, answer := range queryAnswer.Matches {
				log.Printf("%s ----- %s : %f", result.Query, answer.Filename, answer.Rank)
				if answer.Rank != 0.0 {
					result.Matches = append(result.Matches, &pbFileUpload.FileMatch{Filename: answer.Filename, Rank: answer.Rank})
				}
			}
			err = streamFileUpload.Send(&result)
			if err != nil {
				errors <- err
				break
			}
		}
	}()
	select {
	case err := <-errors:
		log.Printf("%v", err)
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *FileUploadServer) SendFilesCount(ctx context.Context, filesCount *pbFileUpload.FilesCount) (*pbFileUpload.UploadResponse, error) {
	ctxx := context.TODO()
	gateway := Gateway.GetGatewayInstance()
	_, err := gateway.GetAnswerReceiveClient().SendFilesCount(ctxx, &pbAnswerReceive.FilesCount{FilesCount: filesCount.FilesCount})
	if err != nil {
		log.Printf("%v", err)
	}
	return &pbFileUpload.UploadResponse{Message: "Success!"}, err
}
