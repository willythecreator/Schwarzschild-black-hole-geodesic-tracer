cmake_minimum_required(VERSION 3.15)
project(SchwarzschildTracer CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MSYS2_PREFIX "C:/msys64/mingw64")

add_executable(tracer
    src/main.cpp
    src/Image.cpp
    src/GeodesicIntegrator.cpp
    src/Camera.cpp
)
target_include_directories(tracer PRIVATE src)
target_compile_options(tracer PRIVATE -O2 -Wall -Wextra)

add_executable(tracer_gpu
    src/main_gpu.cpp
)
target_include_directories(tracer_gpu PRIVATE
    src
    ${MSYS2_PREFIX}/include
)
target_link_directories(tracer_gpu PRIVATE
    ${MSYS2_PREFIX}/lib
)
target_link_libraries(tracer_gpu PRIVATE glfw3 glew32 opengl32)
target_compile_options(tracer_gpu PRIVATE -O2 -Wall -Wextra)