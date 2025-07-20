#include "model_loader.h"
#include <fstream>
#include <iostream>
#include <algorithm>
#include "llama.h"

ModelLoader::ModelLoader() = default;
ModelLoader::~ModelLoader() = default;

// ModelData destructor implementation
ModelData::~ModelData() {
    if (llama_context) {
        llama_free(llama_context);
        llama_context = nullptr;
    }
    if (llama_model) {
            llama_model_free(llama_model);
            llama_model = nullptr;
        }
}

bool ModelLoader::load_from_file(const std::string& file_path, ModelData& data) {
    if (!is_supported_format(file_path)) {
        return false;
    }
    
    std::string extension = get_file_extension(file_path);
    
    if (extension == ".gguf") {
        return load_gguf(file_path, data);
    } else if (extension == ".safetensors") {
        return load_safetensors(file_path, data);
    } else if (extension == ".bin" || extension == ".pt" || extension == ".pth") {
        return load_pytorch(file_path, data);
    }
    
    return false;
}

bool ModelLoader::is_supported_format(const std::string& file_path) {
    std::string extension = get_file_extension(file_path);
    return (extension == ".gguf" || 
            extension == ".safetensors" || 
            extension == ".bin" || 
            extension == ".pt" || 
            extension == ".pth");
}

bool ModelLoader::load_gguf(const std::string& file_path, ModelData& data) {
    // Initialize llama.cpp backend
    llama_backend_init();
    
    try {
        // Set up model parameters
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = 0; // Use CPU only for Android compatibility
        model_params.use_mmap = true;  // Memory map the model file
        model_params.use_mlock = false; // Don't lock memory on mobile
        
        // Load the model using llama.cpp
        llama_model* model = llama_model_load_from_file(file_path.c_str(), model_params);
        
        if (!model) {
            llama_backend_free();
            return false;
        }
        
        // Get model metadata
        data.llama_model = model;
        const llama_vocab* vocab = llama_model_get_vocab(model);
        data.vocab_size = llama_vocab_n_tokens(vocab);
        data.hidden_size = llama_model_n_embd(model);
        data.num_layers = llama_model_n_layer(model);
        data.use_pattern_fallback = false;
        
        // Store model file path for context creation
        data.model_path = file_path;
        
        std::cout << "Successfully loaded GGUF model:" << std::endl;
        std::cout << "  Vocab size: " << data.vocab_size << std::endl;
        std::cout << "  Hidden size: " << data.hidden_size << std::endl;
        std::cout << "  Layers: " << data.num_layers << std::endl;
        
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Error loading GGUF model: " << e.what() << std::endl;
        llama_backend_free();
        return false;
    }
}

bool ModelLoader::load_safetensors(const std::string& file_path, ModelData& data) {
    std::ifstream file(file_path, std::ios::binary);
    if (!file.is_open()) {
        return false;
    }
    
    // SafeTensors format parsing would go here
    // This is a JSON-based format with binary tensor data
    try {
        // Read the header length (first 8 bytes)
        uint64_t header_length;
        file.read(reinterpret_cast<char*>(&header_length), 8);
        
        // Read the JSON header
        std::string header(header_length, '\0');
        file.read(&header[0], header_length);
        
        // Parse JSON header to get tensor information
        // For a real implementation, you would parse the JSON
        // and load each tensor according to its metadata
        
        // Placeholder values
        data.vocab_size = 50257;
        data.hidden_size = 2048;
        data.num_layers = 24;
        data.use_pattern_fallback = false;
        
        file.close();
        return true;
    } catch (const std::exception& e) {
        file.close();
        return false;
    }
}

bool ModelLoader::load_pytorch(const std::string& file_path, ModelData& data) {
    std::ifstream file(file_path, std::ios::binary);
    if (!file.is_open()) {
        return false;
    }
    
    // PyTorch binary format parsing would go here
    // This typically involves pickle protocol for the structure
    // and raw tensor data
    try {
        // For a real implementation, you would:
        // 1. Parse the pickle header
        // 2. Read the model structure
        // 3. Load tensor data
        // 4. Convert to our internal format
        
        // Placeholder values
        data.vocab_size = 51200;
        data.hidden_size = 2560;
        data.num_layers = 32;
        data.use_pattern_fallback = false;
        
        file.close();
        return true;
    } catch (const std::exception& e) {
        file.close();
        return false;
    }
}

std::string ModelLoader::get_file_extension(const std::string& file_path) {
    size_t dot_pos = file_path.find_last_of('.');
    if (dot_pos != std::string::npos) {
        std::string ext = file_path.substr(dot_pos);
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
        return ext;
    }
    return "";
}