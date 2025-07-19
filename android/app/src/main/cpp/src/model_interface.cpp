#include "../include/model_interface.h"
#include "text_generator.h"
#include "model_loader.h"
#include <string>
#include <memory>
#include <cstring>

static std::unique_ptr<TextGenerator> g_model = nullptr;

extern "C" {

int init_model(const char* model_path) {
    try {
        if (g_model) {
            cleanup_model();
        }
        
        g_model = std::make_unique<TextGenerator>();
        return g_model->load_model(model_path) ? 0 : -1;
    } catch (const std::exception& e) {
        return -1;
    }
}

void cleanup_model() {
    if (g_model) {
        g_model.reset();
    }
}

char* generate_text(const char* prompt, int max_tokens) {
    if (!g_model || !prompt) {
        return nullptr;
    }
    
    try {
        std::string response = g_model->generate(prompt, max_tokens);
        char* result = new char[response.length() + 1];
        std::strcpy(result, response.c_str());
        return result;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

void free_string(char* str) {
    delete[] str;
}

int is_model_loaded() {
    return (g_model && g_model->is_loaded()) ? 1 : 0;
}

const char* get_model_info() {
    static std::string info = "NaseerAI C++ Model v1.0";
    return info.c_str();
}

void set_temperature(float temperature) {
    if (g_model) {
        g_model->set_temperature(temperature);
    }
}

void set_top_k(int top_k) {
    if (g_model) {
        g_model->set_top_k(top_k);
    }
}

void set_top_p(float top_p) {
    if (g_model) {
        g_model->set_top_p(top_p);
    }
}

}