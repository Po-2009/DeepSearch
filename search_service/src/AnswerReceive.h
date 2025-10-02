#include <grpc++/grpc++.h>
#include "ProtoGenerated/AnswerReceive.grpc.pb.h"
#include <mutex>
#include <thread>
#include "include_files/BS_thread_pool.hpp"
#include "InvertedIndex.h"

class AnswerReceiveServer final : public AnswerReceive::Dictionary::Service {
public:
    AnswerReceiveServer() = default;
    ~AnswerReceiveServer() final = default;

    grpc::Status SendDictionary(grpc::ServerContext* context, grpc::ServerReader<AnswerReceive::WordEntry>* reader, AnswerReceive::UploadResponse* response) final {
        AnswerReceive::WordEntry wordEntry;

        std::lock_guard<std::mutex> lock(data_mutex_);

        if (filesCount == 0) {
            response->set_message("Error! filesCount is not set!");
            return grpc::Status::CANCELLED;
        }

        while (reader->Read(&wordEntry)) {
            for (auto &file: wordEntry.files()) {
                idx.addEntry(wordEntry.word(), {file.filename(), std::vector<int>{file.frequency().begin(), file.frequency().end()}});
            }
        }

        response->set_message("Successfully imported dictionary!");
        std::cout << "Dictionary successfully loaded." << std::endl;
        return grpc::Status::OK;
    }

grpc::Status Search(grpc::ServerContext* context, grpc::ServerReaderWriter<AnswerReceive::QueryResult, AnswerReceive::Query>* stream) final {

    std::vector<std::future<AnswerReceive::QueryResult>> futures;

    AnswerReceive::Query query;
    while (stream->Read(&query)) {
        std::string query_str = query.query();
        futures.emplace_back(
            pool_.submit_task([this, query_str] {
                std::vector<FileMatch> results;
                {
                    std::lock_guard<std::mutex> lock(data_mutex_);
                    results = idx.searchOneQuery(query_str);
                }

                AnswerReceive::QueryResult res;
                res.set_query(query_str);
                for (const auto& match : results) {
                    auto m = res.add_matches();
                    m->set_filename(match.filename);
                    m->set_rank(match.rank);
                }
                return res;
            })
        );
    }


    for (auto& fut : futures) {
        AnswerReceive::QueryResult res = fut.get();
        {
             std::lock_guard<std::mutex> lock(stream_write_mutex_);
            stream->Write(res);
        }
    }

    return grpc::Status::OK;
}

    grpc::Status SendFilesCount(grpc::ServerContext* context, const AnswerReceive::FilesCount* request, AnswerReceive::UploadResponse* response) final {
        std::lock_guard<std::mutex> lock(data_mutex_);
        filesCount = request->filescount();
        idx.clear();

        response->set_message("Success! filesCount set to " + std::to_string(filesCount));
        return grpc::Status::OK;
    }

private:
    BS::thread_pool<> pool_{std::thread::hardware_concurrency()};
    std::mutex stream_write_mutex_;
    InvertedIndex idx;
    int32_t filesCount = 0;
    std::mutex data_mutex_;
};