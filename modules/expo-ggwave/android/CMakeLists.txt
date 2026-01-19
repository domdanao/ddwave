cmake_minimum_required(VERSION 3.18.1)

project(expo-ggwave)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions -frtti -DGGWAVE_BUILD_EXAMPLES=OFF")

# Set the path to ggwave C++ sources
set(GGWAVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cpp")

# Include directories
include_directories(
  "${GGWAVE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp"
)

# Collect ggwave source files
file(GLOB GGWAVE_SOURCES
  "${GGWAVE_DIR}/ggwave.cpp"
  "${GGWAVE_DIR}/reed-solomon/*.cpp"
)

# JNI source files
file(GLOB JNI_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/*.cpp"
)

# Create shared library
add_library(
  expo-ggwave
  SHARED
  ${GGWAVE_SOURCES}
  ${JNI_SOURCES}
)

# Link against Android log library
find_library(log-lib log)
target_link_libraries(expo-ggwave ${log-lib})

# Link against Android libraries
target_link_libraries(expo-ggwave android)
