package Gateway

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pbAnswerReceive "gateway_service/ProtoGenerated/AnswerReceive"
	pbConverter "gateway_service/ProtoGenerated/Converter"
	pbInvertedIndex "gateway_service/ProtoGenerated/InvertedIndex"

	"log"
	"sync"
)

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
		if err != nil {
			panic(err)
		}
		executableDir := filepath.Dir(executablePath)

		goBinaryName := "InvertedIndex"
		cppBinaryName := "search_service"
		pythonBinaryName := "converter_service"

		//if runtime.GOOS == "windows" {
		//	goBinaryName += ".exe"
		//	cppBinaryName += ".exe"
		//	pythonBinaryName += ".exe"
		//}

		goBinaryPath := filepath.Join(executableDir, goBinaryName)
		cppBinaryPath := filepath.Join(executableDir, cppBinaryName)
		pythonBinaryPath := filepath.Join(executableDir, pythonBinaryName)

		goCmd := exec.Command(goBinaryPath, fmt.Sprintf("--port=%d", ports[0]))
		if err := goCmd.Start(); err != nil {
			fmt.Println("Error starting InvertedIndex service:", err)
		} else {
			fmt.Printf("Started InvertedIndex service (PID: %d) on port %d\n", goCmd.Process.Pid, ports[0])
		}

		cppCmd := exec.Command(cppBinaryPath, fmt.Sprintf("--port=%d", ports[1]))
		if err := cppCmd.Start(); err != nil {
			fmt.Println("Error starting search_service:", err)
		} else {
			fmt.Printf("Started search_service (PID: %d) on port %d\n", cppCmd.Process.Pid, ports[1])
		}

		pythonCmd := exec.Command(pythonBinaryPath, fmt.Sprintf("--port=%d", ports[2]))
		if err := pythonCmd.Start(); err != nil {
			fmt.Println("Error starting converter_service:", err)
		} else {
			fmt.Printf("Started converter_service (PID: %d) on port %d\n", pythonCmd.Process.Pid, ports[2])
		}

		conn, err := grpc.NewClient("localhost:"+strconv.Itoa(ports[2]), grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			log.Fatalf("did not connect: %v", err)
		}
		conn2, err := grpc.NewClient("localhost:"+strconv.Itoa(ports[1]), grpc.WithTransportCredentials(insecure.NewCredentials()))

		if err != nil {
			log.Fatalf("did not connect: %v", err)
		}
		conn3, err := grpc.NewClient("localhost:"+strconv.Itoa(ports[0]), grpc.WithTransportCredentials(insecure.NewCredentials()))

		if err != nil {
			log.Fatalf("did not connect: %v", err)
		}
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
