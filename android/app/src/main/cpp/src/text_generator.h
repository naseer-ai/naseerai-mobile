#ifndef TEXT_GENERATOR_H
#define TEXT_GENERATOR_H

#include <string>
#include <vector>
#include <memory>

class TextGenerator {
public:
    TextGenerator();
    ~TextGenerator();
    
    bool load_model(const std::string& model_path);
    std::string generate(const std::string& prompt, int max_tokens);
    bool is_loaded() const;
    
    void set_temperature(float temperature);
    void set_top_k(int top_k);
    void set_top_p(float top_p);

private:
    struct ModelData;
    std::unique_ptr<ModelData> m_data;
    
    bool m_loaded = false;
    float m_temperature = 0.7f;
    int m_top_k = 40;
    float m_top_p = 0.95f;
    
    std::string generate_pattern_response(const std::string& prompt);
    std::vector<std::string> tokenize(const std::string& text);
    std::string detokenize(const std::vector<int>& tokens);
};

#endif // TEXT_GENERATOR_H