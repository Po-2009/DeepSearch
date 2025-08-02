package main

import (
	pb "gateway_service/ProtoGenerated/FileUpload"
	"google.golang.org/grpc"
	"log"
	"net"
	"os"
	"strings"
)

func parsePort(defaultPort string) string {
	for _, arg := range os.Args[1:] {
		if strings.HasPrefix(arg, "--port=") {
			port := strings.TrimPrefix(arg, "--port=")
			if port != "" {
				return ":" + port
			}
		}
	}
	return ":" + defaultPort
}
func main() {
	port := parsePort("50054")
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	pb.RegisterFileServiceServer(grpcServer, &FileUploadServer{})
	log.Printf("FileUploadServer listening at %v", lis.Addr())

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
	log.Printf("FileUploadServer listening at %v", lis.Addr())
}
