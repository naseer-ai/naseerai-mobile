#ifndef TOKENIZER_H
#define TOKENIZER_H

#include <string>
#include <vector>
#include <unordered_map>
#include <fstream>

class Tokenizer {
public:
    Tokenizer();
    ~Tokenizer();
    
    bool load_vocabulary(const std::string& vocab_file);
    std::vector<int> encode(const std::string& text);
    std::string decode(const std::vector<int>& tokens);
    
    size_t vocab_size() const { return m_vocabulary.size(); }
    const std::vector<std::string>& get_vocabulary() const { return m_vocabulary; }

private:
    std::vector<std::string> m_vocabulary;
    std::unordered_map<std::string, int> m_token_to_id;
    
    void create_basic_vocabulary();
};

#endif // TOKENIZER_H