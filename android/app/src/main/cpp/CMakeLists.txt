cmake_minimum_required(VERSION 3.10)

project(naseer_model)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Android-specific settings
if(ANDROID)
    set(CMAKE_ANDROID_STL_TYPE c++_shared)
    add_definitions(-DANDROID)
    # Fix pointer size issues for Android
    add_compile_definitions(ANDROID_TARGET_API=21)
    # Use 64-bit pointers on 64-bit Android
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a" OR CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
        add_compile_definitions(_LP64=1)
    endif()
endif()

# Add llama.cpp subdirectory
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "llama: build tests" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "llama: build examples" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "llama: build server" FORCE)
add_subdirectory(llama.cpp)

# Add include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/include
)

# Add source files
set(SOURCES
    src/model_interface.cpp
    src/text_generator.cpp
    src/tokenizer.cpp
    src/model_loader.cpp
)

# Create shared library
add_library(naseer_model SHARED ${SOURCES})

# Set library properties
set_target_properties(naseer_model PROPERTIES
    VERSION 1.0.0
    SOVERSION 1
    PUBLIC_HEADER include/model_interface.h
)

# Compiler flags for optimization (Android-compatible)
target_compile_options(naseer_model PRIVATE
    -O3
    -ffast-math
    -funroll-loops
    -ftree-vectorize
    -fomit-frame-pointer
)

# Android ARM-specific optimizations
if(ANDROID)
    # ARM64 optimizations (aarch64 - no mfpu/mfloat-abi needed)
    if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        target_compile_options(naseer_model PRIVATE
            -march=armv8-a
            -mtune=cortex-a53
            -DARM_NEON
        )
    # ARM32 optimizations  
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
        target_compile_options(naseer_model PRIVATE
            -march=armv7-a
            -mtune=cortex-a9
            -mfpu=neon
            -mfloat-abi=hard
            -DARM_NEON
        )
    # x86_64 optimizations
    elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
        target_compile_options(naseer_model PRIVATE
            -march=x86-64
            -mtune=generic
            -msse4.2
        )
    endif()
    
    # Additional Android-specific performance flags
    target_compile_options(naseer_model PRIVATE
        -DANDROID_OPTIMIZED
        -fPIC
        -ffunction-sections
        -fdata-sections
    )
endif()

# Android-specific compiler flags
if(ANDROID)
    target_compile_options(naseer_model PRIVATE
        -Wno-cast-to-pointer-from-smaller-type
        -Wno-cast-from-pointer-to-smaller-type
        -D__ANDROID_API__=21
    )
    # Target llama.cpp libraries with same flags
    target_compile_options(llama PRIVATE
        -Wno-cast-to-pointer-from-smaller-type
        -Wno-cast-from-pointer-to-smaller-type
    )
    target_compile_options(ggml PRIVATE
        -Wno-cast-to-pointer-from-smaller-type
        -Wno-cast-from-pointer-to-smaller-type
    )
endif()

# Link libraries
target_link_libraries(naseer_model 
    llama 
    ggml
)

# Android-specific linking
if(ANDROID)
    target_link_libraries(naseer_model log)
else()
    target_link_libraries(naseer_model m)
endif()

# Install targets
install(TARGETS naseer_model
    LIBRARY DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)