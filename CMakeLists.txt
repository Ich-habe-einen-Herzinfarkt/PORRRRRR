cmake_minimum_required(VERSION 3.10)

project(PORRRRRR)

# Find AdaptiveCpp
find_package(AdaptiveCpp REQUIRED)

add_executable(PORRRRRR main.cpp)

# Add SYCL support to target
add_sycl_to_target(TARGET PORRRRRR)

# Optional: Benchmarks
option(BUILD_BENCHMARKS "Build benchmarks" OFF)

if(BUILD_BENCHMARKS)
  find_package(benchmark REQUIRED)
  find_package(OpenMP REQUIRED)
  
  add_executable(PORRRRRR_bench bench.cpp)
  add_sycl_to_target(TARGET PORRRRRR_bench)
  target_link_libraries(PORRRRRR_bench PRIVATE benchmark::benchmark)

  if(OpenMP_CXX_FOUND)
    target_link_libraries(PORRRRRR_bench PRIVATE OpenMP::OpenMP_CXX)
  endif()
endif()
