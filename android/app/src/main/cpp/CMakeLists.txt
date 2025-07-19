cmake_minimum_required(VERSION 3.10)

project(naseer_model)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(PkgConfig REQUIRED)

# Add include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
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

# Compiler flags for optimization
target_compile_options(naseer_model PRIVATE
    -O3
    -march=native
    -ffast-math
    -funroll-loops
)

# Link math library
target_link_libraries(naseer_model m)

# Install targets
install(TARGETS naseer_model
    LIBRARY DESTINATION lib
    PUBLIC_HEADER DESTINATION include
)