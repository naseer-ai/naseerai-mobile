#ifndef MODEL_INTERFACE_H
#define MODEL_INTERFACE_H

#ifdef __cplusplus
extern "C" {
#endif

// Model lifecycle functions
int init_model(const char* model_path);
void cleanup_model();

// Text generation functions
char* generate_text(const char* prompt, int max_tokens);
void free_string(char* str);

// Model status functions
int is_model_loaded();
const char* get_model_info();

// Configuration functions
void set_temperature(float temperature);
void set_top_k(int top_k);
void set_top_p(float top_p);

#ifdef __cplusplus
}
#endif

#endif // MODEL_INTERFACE_H