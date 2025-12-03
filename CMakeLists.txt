cmake_minimum_required(VERSION 3.10)

project(PORRRRRR)

# Find AdaptiveCpp
find_package(AdaptiveCpp REQUIRED)

add_executable(PORRRRRR main.cpp)

# Add SYCL support to target
add_sycl_to_target(TARGET PORRRRRR)

