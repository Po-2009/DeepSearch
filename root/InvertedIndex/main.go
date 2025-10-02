package main

import (
	pb "gateway_service/ProtoGenerated/InvertedIndex"
	"log"
	"net"
	"os"
	"strings"

	"google.golang.org/grpc"
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
	serverOptions := []grpc.ServerOption{
		grpc.MaxSendMsgSize(1024 * 1024 * 20),
	}
	grpcServer := grpc.NewServer(serverOptions...)
	pb.RegisterInvertedIndexServer(grpcServer, NewInvertedIndexServer())

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
