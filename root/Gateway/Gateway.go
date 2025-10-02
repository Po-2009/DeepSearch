package Gateway

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pbAnswerReceive "gateway_service/ProtoGenerated/AnswerReceive"
	pbConverter "gateway_service/ProtoGenerated/Converter"
	pbInvertedIndex "gateway_service/ProtoGenerated/InvertedIndex"

	"sync"
)

func pipeAndPrefixOutput(cmd *exec.Cmd, prefix string, wg *sync.WaitGroup) error {
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("error creating stdout pipe for %s: %w", prefix, err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("error creating stderr pipe for %s: %w", prefix, err)
	}

	readPipe := func(pipe io.Reader, pipeName string) {
		defer wg.Done()
		scanner := bufio.NewScanner(pipe)
		for scanner.Scan() {
			fmt.Printf("[%s:%s] %s\n", prefix, pipeName, scanner.Text())
		}
	}

	wg.Add(2)
	go readPipe(stdout, "stdout")
	go readPipe(stderr, "stderr")

	return nil
}

func waitForGrpcServer(host string, port int, maxAttempts int, interval time.Duration) (*grpc.ClientConn, error) {
	const maxMessageSize = 20 * 1024 * 1024

	dialOptions := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultCallOptions(grpc.MaxCallRecvMsgSize(maxMessageSize)),
	}
	var conn *grpc.ClientConn
	var err error
	for i := 0; i < maxAttempts; i++ {
		conn, err = grpc.NewClient(fmt.Sprintf("%s:%d", host, port),
			dialOptions...,
		)
		if err == nil {
			fmt.Printf("gRPC server is ready on %s:%d\n", host, port)
			return conn, nil
		}
		fmt.Printf("Waiting for gRPC server %s:%d (%d/%d)...\n", host, port, i+1, maxAttempts)
		time.Sleep(interval)
	}
	return nil, fmt.Errorf("could not connect to gRPC server %s:%d: %v", host, port, err)
}
func getFreePorts(n int) ([]int, error) {
	ports := make([]int, 0, n)
	listeners := make([]net.Listener, 0, n)
	for i := 0; i < n; i++ {
		l, err := net.Listen("tcp", ":0")
		if err != nil {
			for _, l := range listeners {
				l.Close()
			}
			return nil, err
		}
		listeners = append(listeners, l)
		ports = append(ports, l.Addr().(*net.TCPAddr).Port)
	}

	for _, l := range listeners {
		l.Close()
	}
	//ports[0] = 50053
	//ports[1] = 50052
	//ports[2] = 50051
	return ports, nil
}

type Gateway struct {
	converterClient     pbConverter.ConverterClient
	answerReceiveClient pbAnswerReceive.DictionaryClient
	invertedIndexClient pbInvertedIndex.InvertedIndexClient
}

var (
	serverInstance *Gateway
	once           sync.Once
)

func GetGatewayInstance() *Gateway {
	once.Do(func() {
		ports, err := getFreePorts(3)
		if err != nil {
			panic(err)
		}
		executablePath, err := os.Executable()
		fmt.Println(executablePath)
		if err != nil {
			panic(err)
		}
		executableDir := filepath.Dir(executablePath)

		goBinaryName := "InvertedIndex"
		cppBinaryName := "search_service"
		pythonBinaryName := "converter_service"

		var wg sync.WaitGroup

		goBinaryPath := filepath.Join(executableDir, goBinaryName)
		cppBinaryPath := filepath.Join(executableDir, cppBinaryName)
		pythonBinaryPath := filepath.Join(executableDir, pythonBinaryName)
		pythonCmd := exec.Command(pythonBinaryPath, fmt.Sprintf("--port=%d", ports[2]))
		if err := pipeAndPrefixOutput(pythonCmd, "converter_service", &wg); err != nil {
			fmt.Println("Error setting up output for converter_service:", err)
			return
		}
		if err := pythonCmd.Start(); err != nil {
			fmt.Println("Error starting converter_service:", err)
		} else {
			fmt.Printf("Started converter_service (PID: %d) on port %d\n", pythonCmd.Process.Pid, ports[2])
		}
		conn, err := waitForGrpcServer("localhost", ports[2], 120, 60*time.Second)

		goCmd := exec.Command(goBinaryPath, fmt.Sprintf("--port=%d", ports[0]))
		if err := pipeAndPrefixOutput(goCmd, "InvertedIndex", &wg); err != nil {
			fmt.Println("Error setting up output for InvertedIndex service:", err)
			return
		}
		if err := goCmd.Start(); err != nil {
			fmt.Println("Error starting InvertedIndex service:", err)
		} else {
			fmt.Printf("Started InvertedIndex service (PID: %d) on port %d\n", goCmd.Process.Pid, ports[0])
		}
		conn3, err := waitForGrpcServer("localhost", ports[0], 120, 60*time.Second)

		cppCmd := exec.Command(cppBinaryPath, fmt.Sprintf("--port=%d", ports[1]))
		if err := pipeAndPrefixOutput(cppCmd, "search_service", &wg); err != nil {
			fmt.Println("Error setting up output for search_service:", err)
			return
		}
		if err := cppCmd.Start(); err != nil {
			fmt.Println("Error starting search_service:", err)
		} else {
			fmt.Printf("Started search_service (PID: %d) on port %d\n", cppCmd.Process.Pid, ports[1])
		}
		conn2, err := waitForGrpcServer("localhost", ports[1], 120, 60*time.Second)

		serverInstance = &Gateway{
			converterClient:     pbConverter.NewConverterClient(conn),
			answerReceiveClient: pbAnswerReceive.NewDictionaryClient(conn2),
			invertedIndexClient: pbInvertedIndex.NewInvertedIndexClient(conn3),
		}
	})
	return serverInstance
}

func (gateway *Gateway) GetConverterClient() pbConverter.ConverterClient {
	return gateway.converterClient
}
func (gateway *Gateway) GetAnswerReceiveClient() pbAnswerReceive.DictionaryClient {
	return gateway.answerReceiveClient
}

func (gateway *Gateway) GetInvertedIndexClient() pbInvertedIndex.InvertedIndexClient {
	return gateway.invertedIndexClient
}
