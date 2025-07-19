#include "tokenizer.h"
#include <sstream>
#include <algorithm>
#include <regex>

Tokenizer::Tokenizer() = default;
Tokenizer::~Tokenizer() = default;

bool Tokenizer::load_vocabulary(const std::string& vocab_file) {
    std::ifstream file(vocab_file);
    if (!file.is_open()) {
        // Create a basic vocabulary for fallback
        create_basic_vocabulary();
        return true;
    }
    
    std::string line;
    m_vocabulary.clear();
    m_token_to_id.clear();
    
    int id = 0;
    while (std::getline(file, line) && id < 50000) {
        if (!line.empty()) {
            m_vocabulary.push_back(line);
            m_token_to_id[line] = id++;
        }
    }
    
    return !m_vocabulary.empty();
}

std::vector<int> Tokenizer::encode(const std::string& text) {
    std::vector<int> tokens;
    
    if (m_vocabulary.empty()) {
        create_basic_vocabulary();
    }
    
    // Simple whitespace tokenization for demo
    std::istringstream iss(text);
    std::string token;
    
    while (iss >> token) {
        // Convert to lowercase for matching
        std::string lower_token = token;
        std::transform(lower_token.begin(), lower_token.end(), lower_token.begin(), ::tolower);
        
        // Remove punctuation for basic matching
        lower_token.erase(std::remove_if(lower_token.begin(), lower_token.end(), 
                         [](char c) { return std::ispunct(c); }), lower_token.end());
        
        auto it = m_token_to_id.find(lower_token);
        if (it != m_token_to_id.end()) {
            tokens.push_back(it->second);
        } else {
            // Unknown token - use <UNK> token ID (1)
            tokens.push_back(1);
        }
    }
    
    return tokens;
}

std::string Tokenizer::decode(const std::vector<int>& tokens) {
    std::string result;
    
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (tokens[i] >= 0 && tokens[i] < static_cast<int>(m_vocabulary.size())) {
            result += m_vocabulary[tokens[i]];
            if (i < tokens.size() - 1) {
                result += " ";
            }
        }
    }
    
    return result;
}

void Tokenizer::create_basic_vocabulary() {
    // Create a basic English vocabulary for fallback
    m_vocabulary.clear();
    m_token_to_id.clear();
    
    // Special tokens
    std::vector<std::string> special_tokens = {
        "<PAD>", "<UNK>", "<BOS>", "<EOS>", "<MASK>"
    };
    
    // Common words
    std::vector<std::string> common_words = {
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
        "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
        "will", "would", "could", "should", "may", "might", "can", "must",
        "what", "where", "when", "why", "how", "who", "which", "that", "this", "these", "those",
        "yes", "no", "not", "never", "always", "sometimes", "often", "usually", "here", "there",
        "good", "bad", "big", "small", "new", "old", "first", "last", "long", "short", "high", "low",
        "water", "food", "help", "emergency", "safety", "medical", "shelter", "communication",
        "hello", "hi", "thank", "please", "sorry", "welcome", "goodbye"
    };
    
    // Add all tokens to vocabulary
    int id = 0;
    for (const auto& token : special_tokens) {
        m_vocabulary.push_back(token);
        m_token_to_id[token] = id++;
    }
    
    for (const auto& word : common_words) {
        m_vocabulary.push_back(word);
        m_token_to_id[word] = id++;
    }
    
    // Add alphabet for character-level fallback
    for (char c = 'a'; c <= 'z'; ++c) {
        std::string char_token(1, c);
        m_vocabulary.push_back(char_token);
        m_token_to_id[char_token] = id++;
    }
    
    // Add digits
    for (char c = '0'; c <= '9'; ++c) {
        std::string digit_token(1, c);
        m_vocabulary.push_back(digit_token);
        m_token_to_id[digit_token] = id++;
    }
}