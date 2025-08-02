package main

import (
	pb "gateway_service/ProtoGenerated/InvertedIndex"
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
	port := parsePort("50053")
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()
	pb.RegisterInvertedIndexServer(grpcServer, NewInvertedIndexServer())

	log.Printf("Server listening at %v", lis.Addr())

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
	log.Printf("Server listening at %v", lis.Addr())
}
