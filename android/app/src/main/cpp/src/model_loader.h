#ifndef MODEL_LOADER_H
#define MODEL_LOADER_H

#include <string>
#include <vector>

struct ModelData {
    std::vector<float> weights;
    std::vector<std::string> vocabulary;
    int vocab_size = 0;
    int hidden_size = 0;
    int num_layers = 0;
    bool use_pattern_fallback = true;
};

class ModelLoader {
public:
    ModelLoader();
    ~ModelLoader();
    
    bool load_from_file(const std::string& file_path, ModelData& data);
    bool is_supported_format(const std::string& file_path);
    
private:
    bool load_gguf(const std::string& file_path, ModelData& data);
    bool load_safetensors(const std::string& file_path, ModelData& data);
    bool load_pytorch(const std::string& file_path, ModelData& data);
    
    std::string get_file_extension(const std::string& file_path);
};

#endif // MODEL_LOADER_H