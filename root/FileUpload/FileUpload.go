package main

import (
	"context"
	"fmt"
	"gateway_service/Gateway"
	pbAnswerReceive "gateway_service/ProtoGenerated/AnswerReceive"
	pbConverter "gateway_service/ProtoGenerated/Converter"
	pbFileUpload "gateway_service/ProtoGenerated/FileUpload"
	pbInvertedIndex "gateway_service/ProtoGenerated/InvertedIndex"
	"io"
	"log"
	"sync"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type FileUploadServer struct {
	pbFileUpload.UnimplementedFileServiceServer
}

func (s *FileUploadServer) UploadFile(streamFileUpload pbFileUpload.FileService_UploadFileServer) error {
	ctx := context.TODO()
	gateway := Gateway.GetGatewayInstance()
	streamInvertedIndex, err := gateway.GetInvertedIndexClient().BuildIndex(ctx)
	if err != nil {
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Err! no InvertedIndex!",
		})
		return err
	}
	streamAnswerReceive, err := gateway.GetAnswerReceiveClient().SendDictionary(ctx)
	if err != nil {
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Eror! no AnswerRecieve!",
		})
		return err
	}
	streamConverter, err := gateway.GetConverterClient().ConvertFile(ctx)
	if err != nil {
		log.Printf("%v", err)
		err := streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
			Message: "Err! no converter!",
		})
		return err
	}
	var wg sync.WaitGroup
	errs := make(chan error, 2)
	wg.Go(
		func() {
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
					log.Printf("Error form flutter: %v", err)
					errs <- err
					return
				}
				log.Printf("%s", file.Filename)
				if err := streamConverter.Send(&pbConverter.FileChunk{Filename: file.Filename, Content: file.Content}); err != nil {
					errs <- err
					return
				}
			}
		},
	)
	wg.Go(
		func() {
			for {
				parsedText, err := streamConverter.Recv()
				if err == io.EOF {
					err := streamInvertedIndex.CloseSend()
					if err != nil {
						errs <- err
					}
					return
				}
				if err != nil {
					errs <- err
					log.Printf("ERROR receiving from stream: %v", err)
					return
				}
				if err := streamInvertedIndex.Send(&pbInvertedIndex.IndexRequest{Filename: parsedText.Filename, Text: parsedText.Text}); err != nil {
					errs <- err
					return
				}
			}
		},
	)

	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			log.Printf("Chan error: %v", err)

			return err
		}
	}
	resp, err := streamInvertedIndex.CloseAndRecv()
	log.Println("Success!")
	if err != nil {
		log.Printf("Closing error: %v", err)
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
	if err := streamAnswerReceive.CloseSend(); err != nil {
		log.Printf("Errorrr: %v", err)

		return status.Errorf(codes.Internal, "failed to close stream to AnswerReceive: %v", err)
	}

	res, err := streamAnswerReceive.CloseAndRecv()
	log.Println(res.Message)
	if err != nil {
		return status.Errorf(codes.Internal, "failed to receive from AnswerReceive: %v", err)
	}
	return streamFileUpload.SendAndClose(&pbFileUpload.UploadResponse{
		Message: "Successfully processed files!",
	})
}
func (s *FileUploadServer) SendQuery(streamFileUpload pbFileUpload.FileService_SendQueryServer) error {
	ctx := streamFileUpload.Context()
	gateway := Gateway.GetGatewayInstance()

	streamAnswerReceive, err := gateway.GetAnswerReceiveClient().Search(ctx)
	if err != nil {
		return err // Не удалось подключиться к внутреннему сервису
	}

	var wg sync.WaitGroup
	errors := make(chan error, 2)

	wg.Add(1)
	wg.Go(func() {
		for {
			query, err := streamFileUpload.Recv()
			if err == io.EOF {
				if err := streamAnswerReceive.CloseSend(); err != nil {
					errors <- fmt.Errorf("failed to close send stream to answer receive: %w", err)
				}
				return
			}
			if err != nil {
				errors <- err
				return
			}

			if err := streamAnswerReceive.Send(&pbAnswerReceive.Query{Query: query.Query}); err != nil {
				errors <- err
				return
			}
		}
	},
	)

	wg.Go(
		func() {
			for {
				queryAnswer, err := streamAnswerReceive.Recv()
				if err == io.EOF {
					// Внутренний сервис закончил отправлять ответы.
					// Это нормальное завершение для этой горутины.
					return // Успешное завершение
				}
				if err != nil {
					errors <- err
					return
				}

				var result pbFileUpload.QueryResult
				result.Query = queryAnswer.Query
				for _, answer := range queryAnswer.Matches {
					log.Printf("%s ----- %s : %f", result.Query, answer.Filename, answer.Rank)
					if answer.Rank != 0.0 {
						result.Matches = append(result.Matches, &pbFileUpload.FileMatch{Filename: answer.Filename, Rank: answer.Rank})
					}
				}

				if err := streamFileUpload.Send(&result); err != nil {
					errors <- err
					return
				}
			}
		},
	)

	go func() {
		wg.Wait()
		close(errors)
	}()

	for err := range errors {
		if err != nil {
			log.Printf("Error during stream proxying: %v", err)
			return err
		}
	}

	log.Println("SendQuery stream completed successfully.")
	return nil
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
