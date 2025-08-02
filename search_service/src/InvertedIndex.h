#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
int getWordCount(const std::string& s) noexcept{
    std::istringstream ss(s);
    std::string w;
    int count = 0;
    while(ss >>w){
        count++;
    }
    return count;
}
struct FileFrequency {
    std::string filename;
    int frequency;
    bool operator==(const FileFrequency& other) const {
        return filename == other.filename;
    }
};

struct FileFrequencyHash {
    std::size_t operator()(const FileFrequency& fileFrequency) const {
        return std::hash<std::string>{}(fileFrequency.filename);
    }
};

struct FileMatch {
    std::string filename;
    float rank;
    bool operator==(const FileMatch& other) const {
        return filename == other.filename && std::abs(rank - other.rank) < 0.001f;
    }
};

class InvertedIndex {
public:
    InvertedIndex() = default;
public:
    inline void addEntry(const std::string& word, const FileFrequency& fileFrequency) noexcept{
        auto word_it = invertedIndex.find(word);
        if(word_it != invertedIndex.end()){
            auto frequency_it = word_it->second.find(fileFrequency);
            if(frequency_it != word_it->second.end()){
                int new_frequency = frequency_it->frequency + fileFrequency.frequency;
                word_it->second.erase(frequency_it);
                word_it->second.insert({fileFrequency.filename,new_frequency});
            }else{
                word_it->second.insert({fileFrequency});
            }
        }else{
            invertedIndex.insert({word, std::unordered_set<FileFrequency,FileFrequencyHash>{fileFrequency}});
        }
    }
    inline std::unordered_set<FileFrequency,FileFrequencyHash> getEntries(const std::string& word) noexcept{
        auto it=  invertedIndex.find(word);
        if(it == invertedIndex.end()){
            return std::unordered_set<FileFrequency,FileFrequencyHash>{};
        }else{
            return it->second;
        }
    }

    [[nodiscard]] inline std::vector<FileMatch> searchOneQuery(const std::string& query) const noexcept{
        std::unordered_map<std::string,std::pair<int,int>> files;
        int max_frequency = 0;
        int word_count = getWordCount(query);
        std::vector<FileMatch> answer;
        std::istringstream gs(query);
        std::string query_word;
        while(gs >>query_word){
            auto it = invertedIndex.find(query_word);
            if(it == invertedIndex.end()){
                return {};
            }
            for(auto& query_word_freg : it->second){
                files[query_word_freg.filename].first++;
                files[query_word_freg.filename].second += query_word_freg.frequency;
                if(word_count == files[query_word_freg.filename].first){
                    max_frequency = std::max(files[query_word_freg.filename].second,max_frequency);
                }
            }
        }
        for(auto& item : files){
            if(item.second.first==word_count){
                answer.emplace_back(item.first, float(item.second.second)/float(max_frequency));
            }
        }
        return answer;
    }

private:
    std::unordered_map<std::string, std::unordered_set<FileFrequency,FileFrequencyHash>> invertedIndex;
};