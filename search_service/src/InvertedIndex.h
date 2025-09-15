#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <iterator>
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
    std::vector<int> frequency;
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
    FileMatch() = default;
    FileMatch(const std::string& file, float r) : filename(file), rank(r) {}
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
                std::vector<int> new_frequency;
                std::set_union(frequency_it->frequency.begin(), frequency_it->frequency.end(), fileFrequency.frequency.begin(), fileFrequency.frequency.end(), std::back_inserter(new_frequency));
//                std::vector<int> new_frequency = frequency_it->frequency + fileFrequency.frequency;
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

    inline std::vector<FileMatch> searchOneQuery(const std::string& query) const noexcept{
        if(query.empty()) return {};
        std::unordered_map<std::string,int> files;
        int max_frequency = 0;
        std::vector<FileMatch> answer;
        std::vector<std::string> words;
        std::istringstream gs(query);
        std::string query_word;
        while(gs >>query_word) {
            words.push_back(query_word);
            auto it = invertedIndex.find(query_word);
            if(it == invertedIndex.end()){
                return {};
            }
        }
        auto it = invertedIndex.find(words[0]);
        if(words.size() == 1){
            for(auto& query_word_freg : it->second){
                files[query_word_freg.filename] += query_word_freg.frequency.size();
                max_frequency = std::max(files[query_word_freg.filename],max_frequency);
            }
        }else {
            for (auto &query_word_freg: it->second) {
                std::string filename = query_word_freg.filename;
                int start_idx = 0;
                int last_word_idx = 0;

                for(auto index : query_word_freg.frequency){
                    bool finish = false;
                    auto next_word_it = invertedIndex.find(words[last_word_idx+1])->second.find({filename,{}});
                    if(next_word_it == invertedIndex.find(words[last_word_idx+1])->second.end()) break;
                    for(int i = start_idx;i < next_word_it->frequency.size();i++){
                        if(index == next_word_it->frequency[i]-last_word_idx-1){
                            start_idx = 0;
                            last_word_idx++;
                            if(last_word_idx+1 == words.size()){
                                files[query_word_freg.filename]++;
                                max_frequency = std::max(files[query_word_freg.filename],max_frequency);
                                last_word_idx = 0;
                                break;
                            }else{
                                i = -1;
                                next_word_it = invertedIndex.find(words[last_word_idx+1])->second.find({filename,{}});
                                if(next_word_it == invertedIndex.find(words[last_word_idx+1])->second.end()) break;
                            }
                        }else if(index < next_word_it->frequency[i]-last_word_idx-1){
                            start_idx = i;
                            break;
                        }else if(i == next_word_it->frequency.size()-1){
                            finish = true;
                            break;
                        }
                    }
                    if(finish) break;
                }
            }
        }
        for(auto& item : files){
            answer.emplace_back(item.first, float(item.second)/float(max_frequency));
        }
        return answer;
    }

private:
    std::unordered_map<std::string, std::unordered_set<FileFrequency,FileFrequencyHash>> invertedIndex;
};