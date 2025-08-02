#include "AnswerReceive.h"
int main(int argc, char* argv[]){
    std::string port;
    for(int i =0;i< argc;i++){
        port = argv[i];
        if(port.find("--port=") ==0){
            port = port.substr(7);
            break;
        }
    }
    if(port.empty()) port = "50052";
    std::string server_address("localhost:" + port);
    AnswerReceiveServer server;
    grpc::ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&server);
    std::unique_ptr<grpc::Server> service(builder.BuildAndStart());
    std::cout << "Server listening on " << server_address << std::endl;
    service->Wait();
    return 0;
}