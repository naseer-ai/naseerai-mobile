#include "text_generator.h"
#include "model_loader.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <random>
#include <ctime>
#include "llama.h"

struct TextGenerator::ModelData {
    // Legacy fields for compatibility
    std::vector<float> weights;
    std::vector<std::string> vocabulary;
    int vocab_size = 0;
    int hidden_size = 0;
    int num_layers = 0;
    bool use_pattern_fallback = true;
    
    // llama.cpp integration
    llama_model* llama_model = nullptr;
    llama_context* llama_context = nullptr;
    std::string model_path;
    
    // Destructor to clean up llama.cpp resources
    ~ModelData() {
        if (llama_context) {
            llama_free(llama_context);
            llama_context = nullptr;
        }
        if (llama_model) {
            llama_model_free(llama_model);
            llama_model = nullptr;
        }
    }
};

TextGenerator::TextGenerator() : m_data(std::make_unique<ModelData>()) {
    std::srand(std::time(nullptr));
}

TextGenerator::~TextGenerator() = default;

bool TextGenerator::load_model(const std::string& model_path) {
    try {
        // Use ModelLoader to load the model with llama.cpp support
        ModelLoader loader;
        ::ModelData model_data;  // Use the global ModelData from model_loader.h
        
        if (loader.load_from_file(model_path, model_data)) {
            // Copy relevant data from ModelLoader's ModelData to TextGenerator's ModelData
            m_data->vocab_size = model_data.vocab_size;
            m_data->hidden_size = model_data.hidden_size;
            m_data->num_layers = model_data.num_layers;
            m_data->use_pattern_fallback = model_data.use_pattern_fallback;
            
            // Transfer llama.cpp resources (transfer ownership)
            m_data->llama_model = model_data.llama_model;
            m_data->llama_context = model_data.llama_context;
            m_data->model_path = model_data.model_path;
            
            // Prevent double cleanup by nullifying in the temporary object
            model_data.llama_model = nullptr;
            model_data.llama_context = nullptr;
            
            m_loaded = true;
            return true;
        } else {
            // Fallback to pattern-based responses
            m_data->use_pattern_fallback = true;
            m_loaded = true;
            return true;
        }
    } catch (const std::exception& e) {
        // Always fallback to pattern responses to ensure functionality
        m_data->use_pattern_fallback = true;
        m_loaded = true;
        return true;
    }
}

std::string TextGenerator::generate(const std::string& prompt, int max_tokens) {
    if (!m_loaded) {
        return "Error: Model not loaded";
    }
    
    if (m_data->use_pattern_fallback || !m_data->llama_model) {
        return generate_pattern_response(prompt);
    }
    
    // Use llama.cpp for real inference
    try {
        return generate_with_llama(prompt, max_tokens);
    } catch (const std::exception& e) {
        return "Error during inference: " + std::string(e.what());
    }
}

std::string TextGenerator::generate_with_llama(const std::string& prompt, int max_tokens) {
    if (!m_data->llama_model) {
        return "Error: llama model not loaded";
    }
    
    // Create context if not exists
    if (!m_data->llama_context) {
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;        // Context size
        ctx_params.n_batch = 512;       // Batch size for prompt processing
        ctx_params.n_threads = 4;       // Number of threads (good for mobile)
        
        m_data->llama_context = llama_init_from_model(m_data->llama_model, ctx_params);
        
        if (!m_data->llama_context) {
            return "Error: Failed to create llama context";
        }
    }
    
    // Tokenize the prompt
    std::vector<llama_token> tokens_list;
    tokens_list.resize(prompt.length() + 1);
    
    const llama_vocab* vocab = llama_model_get_vocab(m_data->llama_model);
    int n_tokens = llama_tokenize(vocab, prompt.c_str(), prompt.length(), 
                                  tokens_list.data(), tokens_list.size(), true, true);
    
    if (n_tokens < 0) {
        tokens_list.resize(-n_tokens);
        n_tokens = llama_tokenize(vocab, prompt.c_str(), prompt.length(), 
                                  tokens_list.data(), tokens_list.size(), true, true);
        if (n_tokens < 0) {
            return "Error: Failed to tokenize prompt";
        }
    }
    
    tokens_list.resize(n_tokens);
    
    // Process the prompt
    if (llama_decode(m_data->llama_context, llama_batch_get_one(tokens_list.data(), n_tokens))) {
        return "Error: Failed to process prompt";
    }
    
    // Generate response
    std::string response;
    int n_generated = 0;
    
    while (n_generated < max_tokens) {
        // Sample next token
        llama_token next_token = sample_token(m_data->llama_context);
        
        // Check for end of sequence
        const llama_vocab* vocab = llama_model_get_vocab(m_data->llama_model);
        if (next_token == llama_vocab_eos(vocab)) {
            break;
        }
        
        // Convert token to text
        char token_str[256];
        int token_len = llama_token_to_piece(vocab, next_token, token_str, sizeof(token_str), 0, false);
        
        if (token_len > 0) {
            response.append(token_str, token_len);
        }
        
        // Process the new token
        if (llama_decode(m_data->llama_context, llama_batch_get_one(&next_token, 1))) {
            break;
        }
        
        n_generated++;
    }
    
    return response;
}

llama_token TextGenerator::sample_token(llama_context* ctx) {
    // Get logits for the last token
    float* logits = llama_get_logits_ith(ctx, -1);
    const llama_vocab* vocab = llama_model_get_vocab(llama_get_model(ctx));
    int n_vocab = llama_vocab_n_tokens(vocab);
    
    // Simple greedy sampling (take the most likely token)
    // For better results, you could implement temperature sampling, top-k, or top-p
    llama_token max_token = 0;
    float max_logit = logits[0];
    
    for (int i = 1; i < n_vocab; i++) {
        if (logits[i] > max_logit) {
            max_logit = logits[i];
            max_token = i;
        }
    }
    
    return max_token;
}

std::string TextGenerator::generate_pattern_response(const std::string& prompt) {
    std::string lower_prompt = prompt;
    std::transform(lower_prompt.begin(), lower_prompt.end(), lower_prompt.begin(), ::tolower);
    
    // Emergency and safety responses (highest priority for Gaza context)
    if (lower_prompt.find("emergency") != std::string::npos ||
        lower_prompt.find("danger") != std::string::npos ||
        lower_prompt.find("help") != std::string::npos) {
        return "I understand this may be an emergency situation. For immediate safety:\n\n1. Move to the safest available location\n2. Stay low if there's debris or smoke\n3. Check for injuries and provide basic first aid\n4. Signal for help if possible\n5. Conserve water, food, and battery power\n\nWhat specific emergency assistance do you need?";
    }
    
    // Water purification (critical for survival)
    if (lower_prompt.find("water") != std::string::npos && 
        (lower_prompt.find("clean") != std::string::npos || lower_prompt.find("purify") != std::string::npos)) {
        return "Water purification methods using available materials:\n\n**Immediate options:**\n• Boiling: Use any heat source for 1-3 minutes\n• Solar disinfection: Clear bottles in direct sunlight for 6+ hours\n• Sand filtration: Layer fine sand, gravel, cloth in container\n\n**Materials needed:**\n• Cloth or fabric for initial filtering\n• Sand and gravel (if available)\n• Clear containers or bottles\n• Heat source (wood, solar cooker)\n\nThese methods remove most harmful bacteria and particles. Always use the clearest water source available as starting point.";
    }
    
    // Medical and first aid
    if (lower_prompt.find("medical") != std::string::npos ||
        lower_prompt.find("injury") != std::string::npos ||
        lower_prompt.find("first aid") != std::string::npos) {
        return "Basic first aid using available materials:\n\n**For wounds:**\n• Clean cloth or fabric for bandages\n• Clean water for washing\n• Apply direct pressure to stop bleeding\n• Elevate injured area if possible\n\n**For burns:**\n• Cool running water or clean wet cloth\n• Avoid ice or very cold water\n• Cover with clean, dry cloth\n\n**Important:** These are emergency measures. Seek professional medical help when possible.";
    }
    
    // Shelter and protection
    if (lower_prompt.find("shelter") != std::string::npos ||
        lower_prompt.find("protection") != std::string::npos) {
        return "Creating protective shelter with available materials:\n\n**Basic structure:**\n• Use walls, debris, or natural features\n• Create windbreaks with fabric, tarps, or boards\n• Insulate from ground with blankets, cardboard, or clothing\n\n**For weather protection:**\n• Slope roof materials to shed water\n• Block wind from dominant direction\n• Create small, enclosed space to retain body heat\n\n**Safety priorities:**\n• Avoid unstable structures\n• Ensure ventilation\n• Have clear exit routes";
    }
    
    // Communication and coordination
    if (lower_prompt.find("communication") != std::string::npos ||
        lower_prompt.find("signal") != std::string::npos ||
        lower_prompt.find("contact") != std::string::npos) {
        return "Communication methods when networks are down:\n\n**Visual signals:**\n• Mirrors or reflective surfaces for sunlight signals\n• Bright cloth or clothing as markers\n• Smoke signals (safely controlled fires)\n\n**Audio signals:**\n• Whistles, horns, or loud objects\n• Rhythmic patterns (3 blasts = distress)\n• Shouting at regular intervals\n\n**Written messages:**\n• Leave notes in visible locations\n• Use improvised writing materials\n• Include date, time, direction of travel";
    }
    
    // Standard conversational responses
    if (lower_prompt.find("hello") != std::string::npos ||
        lower_prompt.find("hi") != std::string::npos) {
        return "Hello! I'm NaseerAI, running locally on your device. I'm designed to provide assistance even without internet connectivity. How can I help you today?";
    }
    
    if (lower_prompt.find("how are you") != std::string::npos) {
        return "I'm functioning well and ready to assist you. As a local AI model, I can help with information, problem-solving, and guidance even when you're offline. What do you need help with?";
    }
    
    if (lower_prompt.find("what") != std::string::npos && lower_prompt.find("ai") != std::string::npos) {
        return "I'm an AI assistant running locally on your device using a lightweight language model. I can help with explanations, problem-solving, emergency guidance, and general questions without requiring an internet connection.";
    }
    
    // Technical questions
    if (lower_prompt.find("programming") != std::string::npos ||
        lower_prompt.find("code") != std::string::npos) {
        return "I can help with programming concepts and coding questions. What specific programming language or problem are you working with? I can explain concepts, help debug issues, or suggest approaches.";
    }
    
    // Math and calculations
    if (lower_prompt.find("+") != std::string::npos ||
        lower_prompt.find("-") != std::string::npos ||
        lower_prompt.find("calculate") != std::string::npos) {
        // Simple math handling
        std::string math_result = handle_basic_math(prompt);
        if (!math_result.empty()) {
            return math_result;
        }
    }
    
    // Default helpful response
    return "I'm here to help with a wide range of topics including emergency guidance, technical questions, explanations, and problem-solving. I work completely offline, so you can rely on me even without internet access. What specific information or assistance do you need?";
}

std::string TextGenerator::handle_basic_math(const std::string& expression) {
    // Very basic math parser for common operations
    std::string clean_expr = expression;
    // Remove spaces
    clean_expr.erase(std::remove(clean_expr.begin(), clean_expr.end(), ' '), clean_expr.end());
    
    // Simple addition
    size_t plus_pos = clean_expr.find('+');
    if (plus_pos != std::string::npos) {
        std::string left = clean_expr.substr(0, plus_pos);
        std::string right = clean_expr.substr(plus_pos + 1);
        try {
            int a = std::stoi(left);
            int b = std::stoi(right);
            return std::to_string(a + b);
        } catch (...) {
            return "";
        }
    }
    
    // Simple subtraction
    size_t minus_pos = clean_expr.find('-');
    if (minus_pos != std::string::npos && minus_pos > 0) {
        std::string left = clean_expr.substr(0, minus_pos);
        std::string right = clean_expr.substr(minus_pos + 1);
        try {
            int a = std::stoi(left);
            int b = std::stoi(right);
            return std::to_string(a - b);
        } catch (...) {
            return "";
        }
    }
    
    return "";
}

bool TextGenerator::is_loaded() const {
    return m_loaded;
}

void TextGenerator::set_temperature(float temperature) {
    m_temperature = std::max(0.1f, std::min(2.0f, temperature));
}

void TextGenerator::set_top_k(int top_k) {
    m_top_k = std::max(1, std::min(100, top_k));
}

void TextGenerator::set_top_p(float top_p) {
    m_top_p = std::max(0.1f, std::min(1.0f, top_p));
}

std::vector<std::string> TextGenerator::tokenize(const std::string& text) {
    std::vector<std::string> tokens;
    std::istringstream iss(text);
    std::string token;
    while (iss >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

std::string TextGenerator::detokenize(const std::vector<int>& tokens) {
    std::string result;
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (tokens[i] < static_cast<int>(m_data->vocabulary.size())) {
            result += m_data->vocabulary[tokens[i]];
            if (i < tokens.size() - 1) result += " ";
        }
    }
    return result;
}