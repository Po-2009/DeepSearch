#include <grpcpp/grpcpp.h>
#include "ProtoGenerated/AnswerReceive.grpc.pb.h"
#include <mutex>
#include <thread>
#include <future>
#include "google/protobuf/wire_format.h"
#include "include_files/BS_thread_pool.hpp"
#include "InvertedIndex.h"

class AnswerReceiveServer final : public AnswerReceive::Dictionary::Service{
public:
    AnswerReceiveServer()  =default;
    ~AnswerReceiveServer() final = default;
    inline grpc::Status SendDictionary(grpc::ServerContext* context, grpc::ServerReader<AnswerReceive::WordEntry>* reader, AnswerReceive::UploadResponse* response) final{
        AnswerReceive::WordEntry wordEntry;
        wordEntry.set_word("");
        if(filesCount != 0) {
            for (int i = 0; i <= filesCount*2; i++) {
                auto file = wordEntry.add_files();
                file->set_filename("");
                file->set_frequency(0);
            }
        }else{
            response->set_message("Error! No filesCount!");
            return grpc::Status::CANCELLED;
        }
        std::cout << "SendDictionary called " << filesCount << std::endl;
        while (reader->Read(&wordEntry)) {
            std::cout << wordEntry.word() << ":" << std::endl;
            for (auto &file: wordEntry.files()) {
                idx.addEntry(wordEntry.word(), {file.filename(),file.frequency()});
            }
            std::cout << "-----------------------------------" << std::endl;
            std::cout << "-----------------------------------" << std::endl;
            std::cout << "-----------------------------------" << std::endl;
        }
        response->set_message("Successfully imported dictionary!");
        std::cout << "End" << std::endl;
        return grpc::Status::OK;
    }

    inline grpc::Status Search(grpc::ServerContext* context, grpc::ServerReaderWriter<AnswerReceive::QueryResult,AnswerReceive::Query>* stream) final{
        BS::thread_pool pool(std::thread::hardware_concurrency());  // создаём пул потоков с числом потоков равным числу ядер

        std::mutex write_mutex;  // чтобы не было гонки при вызове stream->Write()

        AnswerReceive::Query query;
        while (stream->Read(&query)) {
            std::string query_str = query.query();

            pool.submit_task([this,query_str, &stream, &write_mutex] {
                std::cout << query_str << std::endl;
                auto results = idx.searchOneQuery(query_str);

                AnswerReceive::QueryResult res;
                res.set_query(query_str);
                for (const auto& match : results) {
                    auto m = res.add_matches();
                    m->set_filename(match.filename);
                    m->set_rank(match.rank);
                }

                {
                    std::lock_guard<std::mutex> lock(write_mutex);
                    bool a = stream->Write(res);
                    std::cout << res.query() << " " << a << std::endl;
                }
            });
        }
        pool.wait();
        return grpc::Status::OK;
    }
    inline grpc::Status SendFilesCount(grpc::ServerContext* context, const AnswerReceive::FilesCount* request, AnswerReceive::UploadResponse* response) final{
        filesCount = request->filescount();
        response->set_message("Success!");
        std::cout << response->message() << std::endl;
        return grpc::Status::OK;
    }

private:
    InvertedIndex idx;
    std::mutex mtx;
    int32_t filesCount = 0;
};