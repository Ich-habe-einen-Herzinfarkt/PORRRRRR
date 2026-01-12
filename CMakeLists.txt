cmake_minimum_required(VERSION 3.31)
project(local_tmp)

set(CMAKE_CXX_STANDARD 17)

find_package(MPI REQUIRED)

add_executable(local_tmp main.cpp)

include_directories(${MPI_INCLUDE_PATH})
target_link_libraries(local_tmp ${MPI_LIBRARIES})
