package Gateway

import (
	"fmt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"

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
			// Закрываем уже открытые
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
		fmt.Println(os.Getwd())
		goBinary := filepath.Join("..", "bin", "inverted_index")
		cppBinary := filepath.Join("..", "bin", "search_service")
		pythonScript := filepath.Join("..", "converter_service", "Converter.py")
		var pythonScriptPath string

		if runtime.GOOS == "windows" {
			pythonScriptPath = filepath.Join("..", "converter_service", "venv", "Scripts", "python.exe")
		} else {
			pythonScriptPath = filepath.Join("..", "converter_service", "venv", "bin", "python")
		}

		goCmd := exec.Command(goBinary, fmt.Sprintf("--port=%d", ports[0]))
		if err := goCmd.Start(); err != nil {
			fmt.Println("Error starting inverted_index :", err)
		}

		cppCmd := exec.Command(cppBinary, fmt.Sprintf("--port=%d", ports[1]))
		if err := cppCmd.Start(); err != nil {
			fmt.Println("Error starting search_service :", err)
		}
		pythonCmd := exec.Command(pythonScriptPath, pythonScript, fmt.Sprintf("--port=%d", ports[2]))
		if err := pythonCmd.Start(); err != nil {
			fmt.Println("Error starting converter :", err)
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
