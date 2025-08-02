//#include <Server.h>
//#include <algorithm>
//#include <iostream>
////std::vector<std::vector<FileMatch>> AnswerReceiveServer::search(const std::string &query) noexcept {
////    return std::vector<std::vector<FileMatch>>();
////}
////grpc::Status AnswerReceiveServer::SendDictionary(grpc::ServerContext* context, grpc::ServerReader<AnswerReceive::WordEntry>* reader, AnswerReceive::UploadResponse* response){
////    AnswerReceive::WordEntry wordEntry;
////    while(reader->Read(&wordEntry)){
////        auto& entries = invertedIndex[wordEntry.word()];
////        for (auto& file : wordEntry.files()) {
////            auto it = std::find_if(entries.begin(), entries.end(),
////                                   [&](const FileFrequency& e) { return e.filename == file.filename(); });
////
////            if (it != entries.end()) {
////                it->frequency += file.frequency();
////            } else {
////                entries.push_back({file.filename(),file.frequency()});
////            }
////        }
////    }
////    response->set_message("Successfully imported dictionary!");
////    return grpc::Status::OK;
////}
//grpc::Status AnswerReceiveServer::Search(grpc::ServerContext* context, grpc::ServerReaderWriter<AnswerReceive::QueryResult,AnswerReceive::Query>* stream){
//
//}
//
//AnswerReceiveServer::AnswerReceiveServer() {
//    return;
//}
