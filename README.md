# Sobel edge detection

## Building and running

### nix

The simplest way of running this project is using [`nix` package manager](https://nixos.org/) ([nix-installer](https://github.com/DeterminateSystems/nix-installer) is a good way of getting it onto non-nixos Linux and MacOS systems).

#### Building and running the main program


To build the binary to `result/bin/PORRRRRR`
```bash
# default build
nix build
# for AMD specifically
nix build .#rocm
# for Nvidia specifically
nix build .#cuda
```

To run the program, either run the `result/bin/PORRRRRR` binary or use `nix run` (does not require running nix build first):
```bash
# default build 
nix run
# for AMD specifically
nix run .#rocm
# for Nvidia specifically
nix run .#cuda
```

#### Building and running the benchmark

To build the binary to `result/bin/PORRRRRR_bench`
```bash
# default generic build 
nix build .#bench
# for AMD specifically
nix build .#bench-rocm
# for Nvidia specifically
nix build .#bench-cuda
```

To run the program, either run the `result/bin/PORRRRRR_bench` binary or use `nix run` (does not require running nix build first):
```bash
# default generic build
nix run .#bench
# for AMD specifically
nix run .#bench-rocm
# for Nvidia specifically
nix run .#bench-cuda
```

Example results:
```bash
Running /nix/store/yapkp59csv2cldwf91dbhi0k5v915xrb-PORRRRRR-bench-rocm-0.1.0/bin/PORRRRRR_bench
Run on (24 X 4398.6 MHz CPU s)
CPU Caches:
  L1 Data 32 KiB (x12)
  L1 Instruction 32 KiB (x12)
  L2 Unified 1024 KiB (x12)
  L3 Unified 32768 KiB (x2)
Load Average: 1.29, 1.27, 1.04
--------------------------------------------------------------------------------------------------
Benchmark                                        Time             CPU   Iterations UserCounters...
--------------------------------------------------------------------------------------------------
BM_Sobel_CPU_Original/640/480                 5.03 ms         5.01 ms          139 bytes_per_second=468.089Mi/s items_per_second=61.3534M/s
BM_Sobel_CPU_Original/1280/720                15.3 ms         15.3 ms           46 bytes_per_second=460.126Mi/s items_per_second=60.3096M/s
BM_Sobel_CPU_Original/1920/1080               35.6 ms         35.5 ms           20 bytes_per_second=446.092Mi/s items_per_second=58.4701M/s
BM_Sobel_CPU_Original/3840/2160                149 ms          149 ms            4 bytes_per_second=425.352Mi/s items_per_second=55.7517M/s
BM_Sobel_CPU_Original/7680/4320                646 ms          644 ms            1 bytes_per_second=393.235Mi/s items_per_second=51.542M/s
BM_Sobel_CPU_Unrolled/640/480                0.170 ms        0.170 ms         4143 bytes_per_second=13.4894Gi/s items_per_second=1.81052G/s
BM_Sobel_CPU_Unrolled/1280/720               0.507 ms        0.505 ms         1343 bytes_per_second=13.6052Gi/s items_per_second=1.82606G/s
BM_Sobel_CPU_Unrolled/1920/1080               1.22 ms         1.22 ms          547 bytes_per_second=12.7016Gi/s items_per_second=1.70478G/s
BM_Sobel_CPU_Unrolled/3840/2160               5.59 ms         5.56 ms          136 bytes_per_second=11.1059Gi/s items_per_second=1.4906G/s
BM_Sobel_CPU_Unrolled/7680/4320               21.1 ms         21.0 ms           33 bytes_per_second=11.7491Gi/s items_per_second=1.57694G/s
[AdaptiveCpp Warning] This application uses SYCL buffers; the SYCL buffer-accessor model is well-known to introduce unnecessary overheads. Please consider migrating to the SYCL2020 USM model, in particular device USM (sycl::malloc_device) combined with in-order queues for more performance. See the AdaptiveCpp performance guide for more information: 
https://github.com/AdaptiveCpp/AdaptiveCpp/blob/develop/doc/performance.md
[AdaptiveCpp Warning] kernel_cache: This application run has resulted in new binaries being JIT-compiled. This indicates that the runtime optimization process has not yet reached peak performance. You may want to run the application again until this warning no longer appears to achieve optimal performance.
BM_Sobel_Buffers_Naive/640/480               0.401 ms        0.162 ms         4408 bytes_per_second=14.1421Gi/s items_per_second=1.89812G/s
BM_Sobel_Buffers_Naive/1280/720              0.682 ms        0.087 ms         8201 bytes_per_second=78.7661Gi/s items_per_second=10.5718G/s
BM_Sobel_Buffers_Naive/1920/1080              1.10 ms        0.127 ms         5998 bytes_per_second=121.867Gi/s items_per_second=16.3567G/s
BM_Sobel_Buffers_Naive/3840/2160              3.52 ms        0.317 ms         1000 bytes_per_second=194.703Gi/s items_per_second=26.1326G/s
BM_Sobel_Buffers_Naive/7680/4320              13.4 ms         1.22 ms          560 bytes_per_second=202.228Gi/s items_per_second=27.1426G/s
BM_Sobel_Buffers_Unrolled/640/480            0.235 ms        0.048 ms        14718 bytes_per_second=47.7488Gi/s items_per_second=6.40873G/s
BM_Sobel_Buffers_Unrolled/1280/720           0.615 ms        0.062 ms        10963 bytes_per_second=110.677Gi/s items_per_second=14.8548G/s
BM_Sobel_Buffers_Unrolled/1920/1080           1.01 ms        0.077 ms         9065 bytes_per_second=200.218Gi/s items_per_second=26.8728G/s
BM_Sobel_Buffers_Unrolled/3840/2160           3.33 ms        0.153 ms         1000 bytes_per_second=404.555Gi/s items_per_second=54.2984G/s
BM_Sobel_Buffers_Unrolled/7680/4320           12.7 ms        0.523 ms         1331 bytes_per_second=472.946Gi/s items_per_second=63.4777G/s
BM_Sobel_DeviceUSM_Basic/640/480             0.032 ms        0.027 ms        26367 bytes_per_second=85.929Gi/s items_per_second=11.5332G/s
BM_Sobel_DeviceUSM_Basic/1280/720            0.039 ms        0.034 ms        20853 bytes_per_second=203.937Gi/s items_per_second=27.372G/s
BM_Sobel_DeviceUSM_Basic/1920/1080           0.054 ms        0.047 ms        14925 bytes_per_second=327.507Gi/s items_per_second=43.9572G/s
BM_Sobel_DeviceUSM_Basic/3840/2160           0.137 ms        0.129 ms         5537 bytes_per_second=480.549Gi/s items_per_second=64.4982G/s
BM_Sobel_DeviceUSM_Basic/7680/4320           0.530 ms        0.520 ms         1349 bytes_per_second=475.013Gi/s items_per_second=63.7552G/s
BM_Sobel_DeviceUSM_Tiled_Demo/640/480        0.036 ms        0.028 ms        24357 bytes_per_second=80.4722Gi/s items_per_second=10.8008G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1280/720       0.045 ms        0.037 ms        18953 bytes_per_second=186.747Gi/s items_per_second=25.0647G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1920/1080      0.060 ms        0.052 ms        13368 bytes_per_second=299.297Gi/s items_per_second=40.171G/s
BM_Sobel_DeviceUSM_Tiled_Demo/3840/2160      0.150 ms        0.141 ms         4991 bytes_per_second=438.536Gi/s items_per_second=58.8593G/s
BM_Sobel_DeviceUSM_Tiled_Demo/7680/4320      0.660 ms        0.648 ms         1090 bytes_per_second=381.664Gi/s items_per_second=51.226G/s
BM_Sobel_Optimized_Combo/640/480             0.035 ms        0.026 ms        26865 bytes_per_second=88.7281Gi/s items_per_second=11.9089G/s
BM_Sobel_Optimized_Combo/1280/720            0.041 ms        0.032 ms        22110 bytes_per_second=217.407Gi/s items_per_second=29.1798G/s
BM_Sobel_Optimized_Combo/1920/1080           0.051 ms        0.041 ms        16806 bytes_per_second=373.677Gi/s items_per_second=50.1541G/s
BM_Sobel_Optimized_Combo/3840/2160           0.113 ms        0.103 ms         6976 bytes_per_second=601.982Gi/s items_per_second=80.7967G/s
BM_Sobel_Optimized_Combo/7680/4320           0.512 ms        0.500 ms         1000 bytes_per_second=493.998Gi/s items_per_second=66.3033G/s
BM_FullPipeline/640/480                      0.080 ms        0.057 ms        12089 bytes_per_second=59.7093Gi/s items_per_second=5.34269G/s
BM_FullPipeline/1280/720                     0.102 ms        0.079 ms         8752 bytes_per_second=129.566Gi/s items_per_second=11.5934G/s
BM_FullPipeline/1920/1080                    0.145 ms        0.122 ms         5728 bytes_per_second=189.289Gi/s items_per_second=16.9373G/s
BM_FullPipeline/3840/2160                    0.407 ms        0.384 ms         1830 bytes_per_second=241.58Gi/s items_per_second=21.6162G/s
BM_FullPipeline/7680/4320                     1.83 ms         1.79 ms          392 bytes_per_second=206.697Gi/s items_per_second=18.495G/s
```

(note: if you are getting a warning about JIT like above, it's recommended to re-run the benchmark. Final results will be in our report, this run was chosen specifically to point this out)

### CMake

1. make sure you have cmake installed on your system (e.g. `sudo apt install cmake`) - ninja is also recommended (`sudo apt install ninja`)
2. Follow [AdaptiveCpp docs on building and installing acpp](https://github.com/AdaptiveCpp/AdaptiveCpp/blob/develop/doc/installing.md)
3. (if running benchmarks) follow [Google Benchmark installation instructions](https://github.com/google/benchmark?tab=readme-ov-file#installation)
4. run `cmake -S . -B build -DACPP_TARGETS="generic" -DCMAKE_BUILD_TYPE=Release -DBUILD_BENCHMARKS=ON -GNinja` to configure the build environment (remove the build benchmarks option if you're not planning to run them)
5. run `cmake --build build` to build the project

The resulting binaries should be in the `build` directory

### oneAPI (windows)

Similar to cmake, except for replacing the dependency installation with windows equivalent and removing adaptivecpp to install oneAPI instead.

And probably an hour debugging your oneAPI installation, because I still have no idea why mine was broken and how exactly I fixed it.

I highly do **not** recommend it. Even for an Intel platform. Just use Linux ;-;