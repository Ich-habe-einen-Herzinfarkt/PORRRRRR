# Build & Run

## CLion (Testowana opcja)
Tej metody użyto w trakcie tworzenia kodu - kompilator MinGW z Ninja
```sh
"C:\Program Files\JetBrains\CLion 2023.2.2\bin\cmake\win\x64\bin\cmake.exe" --build C:\Users\Mateusz\CLionProjects\PORRRRRR\cmake-build-debug --target PORRRRRR -j 30
```

## Windows (MinGW)
```sh
mkdir build
cd build
cmake -G "MinGW Makefiles" ..
mingw32-make
.\PORRRRRR.exe
```


## Linux
```sh
mkdir build
cd build
cmake ..
cmake --build .
./PORRRRRR
```


# Building and running the benchmark

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
# generic build launched with MPI via mpexec
nix run .#bench-mpi
# for AMD specifically
nix run .#bench-rocm
# rocm build launched with MPI via mpexec
nix run .#bench-rocm-mpi
# for Nvidia specifically
nix run .#bench-cuda
# cuda build launched with MPI via mpexec
nix run .#bench-cuda-mpi
```

Example results with additional parameters to add warmup:
```bash
$ nix run .#bench-rocm-mpi -- --benchmark_display_aggregates_only=true --benchmark_out=benchmark.json --benchmark_repetitions=5 --benchmark_min_warmup_time=10
Run on (24 X 5299.32 MHz CPU s)
CPU Caches:
  L1 Data 32 KiB (x12)
  L1 Instruction 32 KiB (x12)
  L2 Unified 1024 KiB (x12)
  L3 Unified 32768 KiB (x2)
Load Average: 1.45, 2.72, 2.32
***WARNING*** ASLR is enabled, the results may have unreproducible noise in them.
-----------------------------------------------------------------------------------------------------------
Benchmark                                                 Time             CPU   Iterations UserCounters...
-----------------------------------------------------------------------------------------------------------
BM_Sobel_CPU_Original/640/480_mean                     5.47 ms         5.45 ms            5 bytes_per_second=431.271Mi/s items_per_second=56.5275M/s
BM_Sobel_CPU_Original/640/480_median                   5.26 ms         5.24 ms            5 bytes_per_second=447.4Mi/s items_per_second=58.6416M/s
BM_Sobel_CPU_Original/640/480_stddev                  0.354 ms        0.353 ms            5 bytes_per_second=27.0652Mi/s items_per_second=3.54749M/s
BM_Sobel_CPU_Original/640/480_cv                       6.47 %          6.48 %             5 bytes_per_second=6.28% items_per_second=6.28%
BM_Sobel_CPU_Original/1280/720_mean                    16.4 ms         16.4 ms            5 bytes_per_second=431.082Mi/s items_per_second=56.5027M/s
BM_Sobel_CPU_Original/1280/720_median                  15.8 ms         15.8 ms            5 bytes_per_second=445.565Mi/s items_per_second=58.401M/s
BM_Sobel_CPU_Original/1280/720_stddev                 0.989 ms        0.982 ms            5 bytes_per_second=24.5551Mi/s items_per_second=3.21849M/s
BM_Sobel_CPU_Original/1280/720_cv                      6.03 %          6.00 %             5 bytes_per_second=5.70% items_per_second=5.70%
BM_Sobel_CPU_Original/1920/1080_mean                   38.4 ms         38.3 ms            5 bytes_per_second=414.519Mi/s items_per_second=54.3319M/s
BM_Sobel_CPU_Original/1920/1080_median                 38.0 ms         37.9 ms            5 bytes_per_second=417.414Mi/s items_per_second=54.7113M/s
BM_Sobel_CPU_Original/1920/1080_stddev                 2.17 ms         2.17 ms            5 bytes_per_second=22.395Mi/s items_per_second=2.93536M/s
BM_Sobel_CPU_Original/1920/1080_cv                     5.65 %          5.66 %             5 bytes_per_second=5.40% items_per_second=5.40%
BM_Sobel_CPU_Original/3840/2160_mean                    164 ms          163 ms            5 bytes_per_second=388.929Mi/s items_per_second=50.9777M/s
BM_Sobel_CPU_Original/3840/2160_median                  164 ms          164 ms            5 bytes_per_second=386.421Mi/s items_per_second=50.649M/s
BM_Sobel_CPU_Original/3840/2160_stddev                 10.5 ms         10.5 ms            5 bytes_per_second=25.0626Mi/s items_per_second=3.28501M/s
BM_Sobel_CPU_Original/3840/2160_cv                     6.44 %          6.42 %             5 bytes_per_second=6.44% items_per_second=6.44%
BM_Sobel_CPU_Original/7680/4320_mean                    758 ms          756 ms            5 bytes_per_second=334.964Mi/s items_per_second=43.9044M/s
BM_Sobel_CPU_Original/7680/4320_median                  762 ms          759 ms            5 bytes_per_second=333.671Mi/s items_per_second=43.7349M/s
BM_Sobel_CPU_Original/7680/4320_stddev                 6.93 ms         6.93 ms            5 bytes_per_second=3.08018Mi/s items_per_second=403.725k/s
BM_Sobel_CPU_Original/7680/4320_cv                     0.91 %          0.92 %             5 bytes_per_second=0.92% items_per_second=0.92%
BM_Sobel_CPU_Unrolled/640/480_mean                    0.175 ms        0.174 ms            5 bytes_per_second=13.1445Gi/s items_per_second=1.76422G/s
BM_Sobel_CPU_Unrolled/640/480_median                  0.175 ms        0.174 ms            5 bytes_per_second=13.1399Gi/s items_per_second=1.76361G/s
BM_Sobel_CPU_Unrolled/640/480_stddev                  0.000 ms        0.000 ms            5 bytes_per_second=17.5322Mi/s items_per_second=2.29798M/s
BM_Sobel_CPU_Unrolled/640/480_cv                       0.12 %          0.13 %             5 bytes_per_second=0.13% items_per_second=0.13%
BM_Sobel_CPU_Unrolled/1280/720_mean                   0.529 ms        0.527 ms            5 bytes_per_second=13.0196Gi/s items_per_second=1.74746G/s
BM_Sobel_CPU_Unrolled/1280/720_median                 0.529 ms        0.528 ms            5 bytes_per_second=13.0101Gi/s items_per_second=1.74618G/s
BM_Sobel_CPU_Unrolled/1280/720_stddev                 0.002 ms        0.002 ms            5 bytes_per_second=45.7802Mi/s items_per_second=6.00051M/s
BM_Sobel_CPU_Unrolled/1280/720_cv                      0.38 %          0.34 %             5 bytes_per_second=0.34% items_per_second=0.34%
BM_Sobel_CPU_Unrolled/1920/1080_mean                   1.21 ms         1.20 ms            5 bytes_per_second=12.836Gi/s items_per_second=1.72281G/s
BM_Sobel_CPU_Unrolled/1920/1080_median                 1.20 ms         1.20 ms            5 bytes_per_second=12.8874Gi/s items_per_second=1.72971G/s
BM_Sobel_CPU_Unrolled/1920/1080_stddev                0.011 ms        0.011 ms            5 bytes_per_second=117.19Mi/s items_per_second=15.3603M/s
BM_Sobel_CPU_Unrolled/1920/1080_cv                     0.90 %          0.90 %             5 bytes_per_second=0.89% items_per_second=0.89%
BM_Sobel_CPU_Unrolled/3840/2160_mean                   5.25 ms         5.23 ms            5 bytes_per_second=11.8124Gi/s items_per_second=1.58543G/s
BM_Sobel_CPU_Unrolled/3840/2160_median                 5.25 ms         5.23 ms            5 bytes_per_second=11.814Gi/s items_per_second=1.58565G/s
BM_Sobel_CPU_Unrolled/3840/2160_stddev                0.009 ms        0.009 ms            5 bytes_per_second=20.7108Mi/s items_per_second=2.71461M/s
BM_Sobel_CPU_Unrolled/3840/2160_cv                     0.17 %          0.17 %             5 bytes_per_second=0.17% items_per_second=0.17%
BM_Sobel_CPU_Unrolled/7680/4320_mean                   21.4 ms         21.3 ms            5 bytes_per_second=11.6154Gi/s items_per_second=1.55899G/s
BM_Sobel_CPU_Unrolled/7680/4320_median                 21.4 ms         21.3 ms            5 bytes_per_second=11.6154Gi/s items_per_second=1.55899G/s
BM_Sobel_CPU_Unrolled/7680/4320_stddev                0.022 ms        0.018 ms            5 bytes_per_second=10.0811Mi/s items_per_second=1.32136M/s
BM_Sobel_CPU_Unrolled/7680/4320_cv                     0.10 %          0.08 %             5 bytes_per_second=0.08% items_per_second=0.08%
BM_Sobel_OpenMP/640/480_mean                           5.41 ms         5.39 ms            5 bytes_per_second=489.214Mi/s items_per_second=56.9976M/s
BM_Sobel_OpenMP/640/480_median                         5.41 ms         5.39 ms            5 bytes_per_second=489.138Mi/s items_per_second=56.9887M/s
BM_Sobel_OpenMP/640/480_stddev                        0.004 ms        0.003 ms            5 bytes_per_second=282.044Ki/s items_per_second=32.0903k/s
BM_Sobel_OpenMP/640/480_cv                             0.07 %          0.06 %             5 bytes_per_second=0.06% items_per_second=0.06%
BM_Sobel_OpenMP/1280/720_mean                          16.0 ms         15.9 ms            5 bytes_per_second=497.572Mi/s items_per_second=57.9714M/s
BM_Sobel_OpenMP/1280/720_median                        16.0 ms         15.9 ms            5 bytes_per_second=497.555Mi/s items_per_second=57.9693M/s
BM_Sobel_OpenMP/1280/720_stddev                       0.009 ms        0.010 ms            5 bytes_per_second=305.193Ki/s items_per_second=34.7241k/s
BM_Sobel_OpenMP/1280/720_cv                            0.05 %          0.06 %             5 bytes_per_second=0.06% items_per_second=0.06%
BM_Sobel_OpenMP/1920/1080_mean                         36.0 ms         35.8 ms            5 bytes_per_second=497.06Mi/s items_per_second=57.9117M/s
BM_Sobel_OpenMP/1920/1080_median                       36.0 ms         35.8 ms            5 bytes_per_second=496.922Mi/s items_per_second=57.8956M/s
BM_Sobel_OpenMP/1920/1080_stddev                      0.036 ms        0.030 ms            5 bytes_per_second=432.097Ki/s items_per_second=49.1631k/s
BM_Sobel_OpenMP/1920/1080_cv                           0.10 %          0.08 %             5 bytes_per_second=0.08% items_per_second=0.08%
BM_Sobel_OpenMP/3840/2160_mean                          197 ms          196 ms            5 bytes_per_second=363.005Mi/s items_per_second=42.2931M/s
BM_Sobel_OpenMP/3840/2160_median                        197 ms          196 ms            5 bytes_per_second=363.373Mi/s items_per_second=42.336M/s
BM_Sobel_OpenMP/3840/2160_stddev                      0.484 ms        0.478 ms            5 bytes_per_second=902.201Ki/s items_per_second=102.65k/s
BM_Sobel_OpenMP/3840/2160_cv                           0.25 %          0.24 %             5 bytes_per_second=0.24% items_per_second=0.24%
BM_Sobel_OpenMP/7680/4320_mean                          830 ms          827 ms            5 bytes_per_second=344.425Mi/s items_per_second=40.1284M/s
BM_Sobel_OpenMP/7680/4320_median                        830 ms          827 ms            5 bytes_per_second=344.405Mi/s items_per_second=40.1261M/s
BM_Sobel_OpenMP/7680/4320_stddev                      0.548 ms        0.620 ms            5 bytes_per_second=264.619Ki/s items_per_second=30.1078k/s
BM_Sobel_OpenMP/7680/4320_cv                           0.07 %          0.08 %             5 bytes_per_second=0.08% items_per_second=0.08%
BM_FullPipeline_OpenMP/640/480_mean                    5.65 ms         5.63 ms            5 bytes_per_second=624.684Mi/s items_per_second=54.5857M/s
BM_FullPipeline_OpenMP/640/480_median                  5.65 ms         5.63 ms            5 bytes_per_second=624.913Mi/s items_per_second=54.6058M/s
BM_FullPipeline_OpenMP/640/480_stddev                 0.006 ms        0.005 ms            5 bytes_per_second=605.389Ki/s items_per_second=51.6598k/s
BM_FullPipeline_OpenMP/640/480_cv                      0.11 %          0.09 %             5 bytes_per_second=0.09% items_per_second=0.09%
BM_FullPipeline_OpenMP/1280/720_mean                   17.0 ms         17.0 ms            5 bytes_per_second=621.57Mi/s items_per_second=54.3136M/s
BM_FullPipeline_OpenMP/1280/720_median                 16.9 ms         16.8 ms            5 bytes_per_second=626.517Mi/s items_per_second=54.7459M/s
BM_FullPipeline_OpenMP/1280/720_stddev                0.333 ms        0.332 ms            5 bytes_per_second=11.835Mi/s items_per_second=1.03416M/s
BM_FullPipeline_OpenMP/1280/720_cv                     1.96 %          1.95 %             5 bytes_per_second=1.90% items_per_second=1.90%
BM_FullPipeline_OpenMP/1920/1080_mean                  38.3 ms         37.9 ms            5 bytes_per_second=626.266Mi/s items_per_second=54.724M/s
BM_FullPipeline_OpenMP/1920/1080_median                38.1 ms         37.9 ms            5 bytes_per_second=625.896Mi/s items_per_second=54.6916M/s
BM_FullPipeline_OpenMP/1920/1080_stddev               0.397 ms        0.050 ms            5 bytes_per_second=851.251Ki/s items_per_second=72.6401k/s
BM_FullPipeline_OpenMP/1920/1080_cv                    1.04 %          0.13 %             5 bytes_per_second=0.13% items_per_second=0.13%
BM_FullPipeline_OpenMP/3840/2160_mean                   243 ms          242 ms            5 bytes_per_second=392.277Mi/s items_per_second=34.2777M/s
BM_FullPipeline_OpenMP/3840/2160_median                 243 ms          241 ms            5 bytes_per_second=393.137Mi/s items_per_second=34.3528M/s
BM_FullPipeline_OpenMP/3840/2160_stddev                1.28 ms         1.39 ms            5 bytes_per_second=2.24144Mi/s items_per_second=195.86k/s
BM_FullPipeline_OpenMP/3840/2160_cv                    0.52 %          0.57 %             5 bytes_per_second=0.57% items_per_second=0.57%
BM_FullPipeline_OpenMP/7680/4320_mean                   953 ms          950 ms            5 bytes_per_second=399.79Mi/s items_per_second=34.9342M/s
BM_FullPipeline_OpenMP/7680/4320_median                 953 ms          950 ms            5 bytes_per_second=399.875Mi/s items_per_second=34.9416M/s
BM_FullPipeline_OpenMP/7680/4320_stddev                2.59 ms         2.58 ms            5 bytes_per_second=1.08362Mi/s items_per_second=94.6877k/s
BM_FullPipeline_OpenMP/7680/4320_cv                    0.27 %          0.27 %             5 bytes_per_second=0.27% items_per_second=0.27%
[AdaptiveCpp Warning] This application uses SYCL buffers; the SYCL buffer-accessor model is well-known to introduce unnecessary overheads. Please consider migrating to the SYCL2020 USM model, in particular device USM (sycl::malloc_device) combined with in-order queues for more performance. See the AdaptiveCpp performance guide for more information:
https://github.com/AdaptiveCpp/AdaptiveCpp/blob/develop/doc/performance.md
BM_Sobel_Buffers_Naive/640/480_mean                   0.436 ms        0.182 ms            5 bytes_per_second=12.566Gi/s items_per_second=1.68657G/s
BM_Sobel_Buffers_Naive/640/480_median                 0.432 ms        0.182 ms            5 bytes_per_second=12.6093Gi/s items_per_second=1.69239G/s
BM_Sobel_Buffers_Naive/640/480_stddev                 0.011 ms        0.007 ms            5 bytes_per_second=493.365Mi/s items_per_second=64.6664M/s
BM_Sobel_Buffers_Naive/640/480_cv                      2.49 %          3.81 %             5 bytes_per_second=3.83% items_per_second=3.83%
BM_Sobel_Buffers_Naive/1280/720_mean                  0.691 ms        0.162 ms            5 bytes_per_second=44.1133Gi/s items_per_second=5.92078G/s
BM_Sobel_Buffers_Naive/1280/720_median                0.693 ms        0.174 ms            5 bytes_per_second=39.4563Gi/s items_per_second=5.29573G/s
BM_Sobel_Buffers_Naive/1280/720_stddev                0.005 ms        0.031 ms            5 bytes_per_second=10.8018Gi/s items_per_second=1.44979G/s
BM_Sobel_Buffers_Naive/1280/720_cv                     0.69 %         19.06 %             5 bytes_per_second=24.49% items_per_second=24.49%
BM_Sobel_Buffers_Naive/1920/1080_mean                  1.13 ms        0.186 ms            5 bytes_per_second=83.3273Gi/s items_per_second=11.184G/s
BM_Sobel_Buffers_Naive/1920/1080_median                1.12 ms        0.181 ms            5 bytes_per_second=85.4304Gi/s items_per_second=11.4663G/s
BM_Sobel_Buffers_Naive/1920/1080_stddev               0.005 ms        0.009 ms            5 bytes_per_second=4.15825Gi/s items_per_second=558.111M/s
BM_Sobel_Buffers_Naive/1920/1080_cv                    0.46 %          5.06 %             5 bytes_per_second=4.99% items_per_second=4.99%
BM_Sobel_Buffers_Naive/3840/2160_mean                  3.54 ms        0.339 ms            5 bytes_per_second=183.595Gi/s items_per_second=24.6417G/s
BM_Sobel_Buffers_Naive/3840/2160_median                3.54 ms        0.344 ms            5 bytes_per_second=179.575Gi/s items_per_second=24.1022G/s
BM_Sobel_Buffers_Naive/3840/2160_stddev               0.018 ms        0.029 ms            5 bytes_per_second=15.7157Gi/s items_per_second=2.10933G/s
BM_Sobel_Buffers_Naive/3840/2160_cv                    0.51 %          8.52 %             5 bytes_per_second=8.56% items_per_second=8.56%
BM_Sobel_Buffers_Naive/7680/4320_mean                  13.5 ms         1.26 ms            5 bytes_per_second=196.358Gi/s items_per_second=26.3547G/s
BM_Sobel_Buffers_Naive/7680/4320_median                13.5 ms         1.26 ms            5 bytes_per_second=196.506Gi/s items_per_second=26.3746G/s
BM_Sobel_Buffers_Naive/7680/4320_stddev               0.013 ms        0.009 ms            5 bytes_per_second=1.33828Gi/s items_per_second=179.621M/s
BM_Sobel_Buffers_Naive/7680/4320_cv                    0.10 %          0.69 %             5 bytes_per_second=0.68% items_per_second=0.68%
BM_Sobel_Buffers_Unrolled/640/480_mean                0.267 ms        0.052 ms            5 bytes_per_second=43.9438Gi/s items_per_second=5.89803G/s
BM_Sobel_Buffers_Unrolled/640/480_median              0.266 ms        0.052 ms            5 bytes_per_second=44.0985Gi/s items_per_second=5.9188G/s
BM_Sobel_Buffers_Unrolled/640/480_stddev              0.004 ms        0.001 ms            5 bytes_per_second=514.998Mi/s items_per_second=67.5018M/s
BM_Sobel_Buffers_Unrolled/640/480_cv                   1.57 %          1.15 %             5 bytes_per_second=1.14% items_per_second=1.14%
BM_Sobel_Buffers_Unrolled/1280/720_mean               0.658 ms        0.064 ms            5 bytes_per_second=108.077Gi/s items_per_second=14.5058G/s
BM_Sobel_Buffers_Unrolled/1280/720_median             0.657 ms        0.064 ms            5 bytes_per_second=107.89Gi/s items_per_second=14.4807G/s
BM_Sobel_Buffers_Unrolled/1280/720_stddev             0.007 ms        0.000 ms            5 bytes_per_second=677.411Mi/s items_per_second=88.7896M/s
BM_Sobel_Buffers_Unrolled/1280/720_cv                  1.03 %          0.61 %             5 bytes_per_second=0.61% items_per_second=0.61%
BM_Sobel_Buffers_Unrolled/1920/1080_mean               1.07 ms        0.075 ms            5 bytes_per_second=206.601Gi/s items_per_second=27.7295G/s
BM_Sobel_Buffers_Unrolled/1920/1080_median             1.06 ms        0.075 ms            5 bytes_per_second=206.164Gi/s items_per_second=27.6709G/s
BM_Sobel_Buffers_Unrolled/1920/1080_stddev            0.006 ms        0.001 ms            5 bytes_per_second=1.38766Gi/s items_per_second=186.248M/s
BM_Sobel_Buffers_Unrolled/1920/1080_cv                 0.61 %          0.67 %             5 bytes_per_second=0.67% items_per_second=0.67%
BM_Sobel_Buffers_Unrolled/3840/2160_mean               3.38 ms        0.149 ms            5 bytes_per_second=416.148Gi/s items_per_second=55.8545G/s
BM_Sobel_Buffers_Unrolled/3840/2160_median             3.38 ms        0.149 ms            5 bytes_per_second=415.978Gi/s items_per_second=55.8316G/s
BM_Sobel_Buffers_Unrolled/3840/2160_stddev            0.008 ms        0.000 ms            5 bytes_per_second=1.31963Gi/s items_per_second=177.118M/s
BM_Sobel_Buffers_Unrolled/3840/2160_cv                 0.24 %          0.32 %             5 bytes_per_second=0.32% items_per_second=0.32%
BM_Sobel_Buffers_Unrolled/7680/4320_mean               12.8 ms        0.494 ms            5 bytes_per_second=500.277Gi/s items_per_second=67.146G/s
BM_Sobel_Buffers_Unrolled/7680/4320_median             12.8 ms        0.495 ms            5 bytes_per_second=499.878Gi/s items_per_second=67.0925G/s
BM_Sobel_Buffers_Unrolled/7680/4320_stddev            0.002 ms        0.003 ms            5 bytes_per_second=3.47907Gi/s items_per_second=466.953M/s
BM_Sobel_Buffers_Unrolled/7680/4320_cv                 0.02 %          0.69 %             5 bytes_per_second=0.70% items_per_second=0.70%
BM_Sobel_DeviceUSM_Basic/640/480_mean                 0.035 ms        0.027 ms            5 bytes_per_second=85.0649Gi/s items_per_second=11.4172G/s
BM_Sobel_DeviceUSM_Basic/640/480_median               0.035 ms        0.027 ms            5 bytes_per_second=84.9358Gi/s items_per_second=11.3999G/s
BM_Sobel_DeviceUSM_Basic/640/480_stddev               0.000 ms        0.000 ms            5 bytes_per_second=280.459Mi/s items_per_second=36.7603M/s
BM_Sobel_DeviceUSM_Basic/640/480_cv                    0.44 %          0.32 %             5 bytes_per_second=0.32% items_per_second=0.32%
BM_Sobel_DeviceUSM_Basic/1280/720_mean                0.042 ms        0.034 ms            5 bytes_per_second=199.783Gi/s items_per_second=26.8145G/s
BM_Sobel_DeviceUSM_Basic/1280/720_median              0.042 ms        0.034 ms            5 bytes_per_second=199.55Gi/s items_per_second=26.7831G/s
BM_Sobel_DeviceUSM_Basic/1280/720_stddev              0.000 ms        0.000 ms            5 bytes_per_second=633.344Mi/s items_per_second=83.0136M/s
BM_Sobel_DeviceUSM_Basic/1280/720_cv                   0.32 %          0.31 %             5 bytes_per_second=0.31% items_per_second=0.31%
BM_Sobel_DeviceUSM_Basic/1920/1080_mean               0.055 ms        0.047 ms            5 bytes_per_second=326.044Gi/s items_per_second=43.7609G/s
BM_Sobel_DeviceUSM_Basic/1920/1080_median             0.055 ms        0.047 ms            5 bytes_per_second=325.767Gi/s items_per_second=43.7237G/s
BM_Sobel_DeviceUSM_Basic/1920/1080_stddev             0.000 ms        0.000 ms            5 bytes_per_second=1.10577Gi/s items_per_second=148.414M/s
BM_Sobel_DeviceUSM_Basic/1920/1080_cv                  0.44 %          0.34 %             5 bytes_per_second=0.34% items_per_second=0.34%
BM_Sobel_DeviceUSM_Basic/3840/2160_mean               0.138 ms        0.130 ms            5 bytes_per_second=475.255Gi/s items_per_second=63.7876G/s
BM_Sobel_DeviceUSM_Basic/3840/2160_median             0.138 ms        0.130 ms            5 bytes_per_second=475.994Gi/s items_per_second=63.8868G/s
BM_Sobel_DeviceUSM_Basic/3840/2160_stddev             0.000 ms        0.000 ms            5 bytes_per_second=1.42582Gi/s items_per_second=191.371M/s
BM_Sobel_DeviceUSM_Basic/3840/2160_cv                  0.16 %          0.30 %             5 bytes_per_second=0.30% items_per_second=0.30%
BM_Sobel_DeviceUSM_Basic/7680/4320_mean               0.541 ms        0.531 ms            5 bytes_per_second=465.365Gi/s items_per_second=62.4603G/s
BM_Sobel_DeviceUSM_Basic/7680/4320_median             0.542 ms        0.531 ms            5 bytes_per_second=465.436Gi/s items_per_second=62.4698G/s
BM_Sobel_DeviceUSM_Basic/7680/4320_stddev             0.001 ms        0.001 ms            5 bytes_per_second=926.662Mi/s items_per_second=121.459M/s
BM_Sobel_DeviceUSM_Basic/7680/4320_cv                  0.22 %          0.19 %             5 bytes_per_second=0.19% items_per_second=0.19%
BM_Sobel_DeviceUSM_Tiled_Demo/640/480_mean            0.036 ms        0.028 ms            5 bytes_per_second=82.5204Gi/s items_per_second=11.0757G/s
BM_Sobel_DeviceUSM_Tiled_Demo/640/480_median          0.036 ms        0.028 ms            5 bytes_per_second=82.5025Gi/s items_per_second=11.0733G/s
BM_Sobel_DeviceUSM_Tiled_Demo/640/480_stddev          0.000 ms        0.000 ms            5 bytes_per_second=236.794Mi/s items_per_second=31.0371M/s
BM_Sobel_DeviceUSM_Tiled_Demo/640/480_cv               0.57 %          0.28 %             5 bytes_per_second=0.28% items_per_second=0.28%
BM_Sobel_DeviceUSM_Tiled_Demo/1280/720_mean           0.045 ms        0.036 ms            5 bytes_per_second=189.381Gi/s items_per_second=25.4183G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1280/720_median         0.045 ms        0.036 ms            5 bytes_per_second=189.498Gi/s items_per_second=25.434G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1280/720_stddev         0.000 ms        0.000 ms            5 bytes_per_second=707.222Mi/s items_per_second=92.697M/s
BM_Sobel_DeviceUSM_Tiled_Demo/1280/720_cv              0.30 %          0.36 %             5 bytes_per_second=0.36% items_per_second=0.36%
BM_Sobel_DeviceUSM_Tiled_Demo/1920/1080_mean          0.060 ms        0.052 ms            5 bytes_per_second=298.558Gi/s items_per_second=40.0718G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1920/1080_median        0.061 ms        0.052 ms            5 bytes_per_second=298.558Gi/s items_per_second=40.0717G/s
BM_Sobel_DeviceUSM_Tiled_Demo/1920/1080_stddev        0.000 ms        0.000 ms            5 bytes_per_second=295.731Mi/s items_per_second=38.7621M/s
BM_Sobel_DeviceUSM_Tiled_Demo/1920/1080_cv             0.08 %          0.10 %             5 bytes_per_second=0.10% items_per_second=0.10%
BM_Sobel_DeviceUSM_Tiled_Demo/3840/2160_mean          0.150 ms        0.142 ms            5 bytes_per_second=435.18Gi/s items_per_second=58.4089G/s
BM_Sobel_DeviceUSM_Tiled_Demo/3840/2160_median        0.150 ms        0.142 ms            5 bytes_per_second=434.539Gi/s items_per_second=58.3229G/s
BM_Sobel_DeviceUSM_Tiled_Demo/3840/2160_stddev        0.000 ms        0.000 ms            5 bytes_per_second=1.06969Gi/s items_per_second=143.572M/s
BM_Sobel_DeviceUSM_Tiled_Demo/3840/2160_cv             0.17 %          0.25 %             5 bytes_per_second=0.25% items_per_second=0.25%
BM_Sobel_DeviceUSM_Tiled_Demo/7680/4320_mean          0.678 ms        0.663 ms            5 bytes_per_second=372.938Gi/s items_per_second=50.0549G/s
BM_Sobel_DeviceUSM_Tiled_Demo/7680/4320_median        0.679 ms        0.665 ms            5 bytes_per_second=371.527Gi/s items_per_second=49.8655G/s
BM_Sobel_DeviceUSM_Tiled_Demo/7680/4320_stddev        0.001 ms        0.006 ms            5 bytes_per_second=3.25711Gi/s items_per_second=437.161M/s
BM_Sobel_DeviceUSM_Tiled_Demo/7680/4320_cv             0.14 %          0.86 %             5 bytes_per_second=0.87% items_per_second=0.87%
BM_Sobel_Optimized_Combo/640/480_mean                 0.035 ms        0.026 ms            5 bytes_per_second=87.5017Gi/s items_per_second=11.7443G/s
BM_Sobel_Optimized_Combo/640/480_median               0.035 ms        0.026 ms            5 bytes_per_second=87.8095Gi/s items_per_second=11.7856G/s
BM_Sobel_Optimized_Combo/640/480_stddev               0.000 ms        0.000 ms            5 bytes_per_second=681.015Mi/s items_per_second=89.262M/s
BM_Sobel_Optimized_Combo/640/480_cv                    0.89 %          0.76 %             5 bytes_per_second=0.76% items_per_second=0.76%
BM_Sobel_Optimized_Combo/1280/720_mean                0.040 ms        0.032 ms            5 bytes_per_second=214.507Gi/s items_per_second=28.7907G/s
BM_Sobel_Optimized_Combo/1280/720_median              0.040 ms        0.032 ms            5 bytes_per_second=214.625Gi/s items_per_second=28.8065G/s
BM_Sobel_Optimized_Combo/1280/720_stddev              0.000 ms        0.000 ms            5 bytes_per_second=591.745Mi/s items_per_second=77.5612M/s
BM_Sobel_Optimized_Combo/1280/720_cv                   0.56 %          0.27 %             5 bytes_per_second=0.27% items_per_second=0.27%
BM_Sobel_Optimized_Combo/1920/1080_mean               0.051 ms        0.043 ms            5 bytes_per_second=359.58Gi/s items_per_second=48.2621G/s
BM_Sobel_Optimized_Combo/1920/1080_median             0.051 ms        0.043 ms            5 bytes_per_second=359.348Gi/s items_per_second=48.2309G/s
BM_Sobel_Optimized_Combo/1920/1080_stddev             0.000 ms        0.000 ms            5 bytes_per_second=930.605Mi/s items_per_second=121.976M/s
BM_Sobel_Optimized_Combo/1920/1080_cv                  0.18 %          0.25 %             5 bytes_per_second=0.25% items_per_second=0.25%
BM_Sobel_Optimized_Combo/3840/2160_mean               0.113 ms        0.105 ms            5 bytes_per_second=588.242Gi/s items_per_second=78.9524G/s
BM_Sobel_Optimized_Combo/3840/2160_median             0.113 ms        0.105 ms            5 bytes_per_second=587.74Gi/s items_per_second=78.8851G/s
BM_Sobel_Optimized_Combo/3840/2160_stddev             0.000 ms        0.000 ms            5 bytes_per_second=1.93399Gi/s items_per_second=259.575M/s
BM_Sobel_Optimized_Combo/3840/2160_cv                  0.14 %          0.33 %             5 bytes_per_second=0.33% items_per_second=0.33%
BM_Sobel_Optimized_Combo/7680/4320_mean               0.513 ms        0.501 ms            5 bytes_per_second=493.086Gi/s items_per_second=66.1809G/s
BM_Sobel_Optimized_Combo/7680/4320_median             0.514 ms        0.500 ms            5 bytes_per_second=493.902Gi/s items_per_second=66.2903G/s
BM_Sobel_Optimized_Combo/7680/4320_stddev             0.001 ms        0.002 ms            5 bytes_per_second=1.87293Gi/s items_per_second=251.38M/s
BM_Sobel_Optimized_Combo/7680/4320_cv                  0.14 %          0.38 %             5 bytes_per_second=0.38% items_per_second=0.38%
BM_FullPipeline_CPU/640/480_mean                       5.64 ms         5.62 ms            5 bytes_per_second=627.881Mi/s items_per_second=54.8651M/s
BM_FullPipeline_CPU/640/480_median                     5.48 ms         5.46 ms            5 bytes_per_second=643.791Mi/s items_per_second=56.2553M/s
BM_FullPipeline_CPU/640/480_stddev                    0.383 ms        0.378 ms            5 bytes_per_second=41.0276Mi/s items_per_second=3.58505M/s
BM_FullPipeline_CPU/640/480_cv                         6.78 %          6.73 %             5 bytes_per_second=6.53% items_per_second=6.53%
BM_FullPipeline_CPU/1280/720_mean                      15.9 ms         15.9 ms            5 bytes_per_second=663.946Mi/s items_per_second=58.0165M/s
BM_FullPipeline_CPU/1280/720_median                    15.9 ms         15.9 ms            5 bytes_per_second=663.945Mi/s items_per_second=58.0164M/s
BM_FullPipeline_CPU/1280/720_stddev                   0.007 ms        0.008 ms            5 bytes_per_second=350.358Ki/s items_per_second=29.8972k/s
BM_FullPipeline_CPU/1280/720_cv                        0.05 %          0.05 %             5 bytes_per_second=0.05% items_per_second=0.05%
BM_FullPipeline_CPU/1920/1080_mean                     39.7 ms         39.5 ms            5 bytes_per_second=602.745Mi/s items_per_second=52.6687M/s
BM_FullPipeline_CPU/1920/1080_median                   39.5 ms         39.4 ms            5 bytes_per_second=602.933Mi/s items_per_second=52.6851M/s
BM_FullPipeline_CPU/1920/1080_stddev                   2.66 ms         2.65 ms            5 bytes_per_second=41.2646Mi/s items_per_second=3.60576M/s
BM_FullPipeline_CPU/1920/1080_cv                       6.70 %          6.71 %             5 bytes_per_second=6.85% items_per_second=6.85%
BM_FullPipeline_CPU/3840/2160_mean                      194 ms          193 ms            5 bytes_per_second=491.231Mi/s items_per_second=42.9244M/s
BM_FullPipeline_CPU/3840/2160_median                    195 ms          194 ms            5 bytes_per_second=488.968Mi/s items_per_second=42.7267M/s
BM_FullPipeline_CPU/3840/2160_stddev                   5.09 ms         4.84 ms            5 bytes_per_second=12.3521Mi/s items_per_second=1.07934M/s
BM_FullPipeline_CPU/3840/2160_cv                       2.62 %          2.50 %             5 bytes_per_second=2.51% items_per_second=2.51%
BM_FullPipeline_CPU/7680/4320_mean                      785 ms          782 ms            5 bytes_per_second=485.535Mi/s items_per_second=42.4267M/s
BM_FullPipeline_CPU/7680/4320_median                    792 ms          789 ms            5 bytes_per_second=480.927Mi/s items_per_second=42.0241M/s
BM_FullPipeline_CPU/7680/4320_stddev                   14.9 ms         15.0 ms            5 bytes_per_second=9.53895Mi/s items_per_second=833.526k/s
BM_FullPipeline_CPU/7680/4320_cv                       1.89 %          1.92 %             5 bytes_per_second=1.96% items_per_second=1.96%
BM_FullPipeline/640/480_mean                          0.078 ms        0.060 ms            5 bytes_per_second=57.2199Gi/s items_per_second=5.11995G/s
BM_FullPipeline/640/480_median                        0.078 ms        0.060 ms            5 bytes_per_second=57.1512Gi/s items_per_second=5.1138G/s
BM_FullPipeline/640/480_stddev                        0.000 ms        0.000 ms            5 bytes_per_second=204.128Mi/s items_per_second=17.837M/s
BM_FullPipeline/640/480_cv                             0.26 %          0.35 %             5 bytes_per_second=0.35% items_per_second=0.35%
BM_FullPipeline/1280/720_mean                         0.100 ms        0.081 ms            5 bytes_per_second=126.586Gi/s items_per_second=11.3268G/s
BM_FullPipeline/1280/720_median                       0.100 ms        0.081 ms            5 bytes_per_second=126.694Gi/s items_per_second=11.3364G/s
BM_FullPipeline/1280/720_stddev                       0.000 ms        0.001 ms            5 bytes_per_second=1.22949Gi/s items_per_second=110.013M/s
BM_FullPipeline/1280/720_cv                            0.09 %          0.97 %             5 bytes_per_second=0.97% items_per_second=0.97%
BM_FullPipeline/1920/1080_mean                        0.144 ms        0.118 ms            5 bytes_per_second=195.917Gi/s items_per_second=17.5304G/s
BM_FullPipeline/1920/1080_median                      0.144 ms        0.119 ms            5 bytes_per_second=195.42Gi/s items_per_second=17.4859G/s
BM_FullPipeline/1920/1080_stddev                      0.000 ms        0.000 ms            5 bytes_per_second=784.244Mi/s items_per_second=68.5283M/s
BM_FullPipeline/1920/1080_cv                           0.18 %          0.39 %             5 bytes_per_second=0.39% items_per_second=0.39%
BM_FullPipeline/3840/2160_mean                        0.409 ms        0.387 ms            5 bytes_per_second=239.691Gi/s items_per_second=21.4472G/s
BM_FullPipeline/3840/2160_median                      0.410 ms        0.388 ms            5 bytes_per_second=239.015Gi/s items_per_second=21.3867G/s
BM_FullPipeline/3840/2160_stddev                      0.001 ms        0.002 ms            5 bytes_per_second=1.51767Gi/s items_per_second=135.799M/s
BM_FullPipeline/3840/2160_cv                           0.20 %          0.63 %             5 bytes_per_second=0.63% items_per_second=0.63%
BM_FullPipeline/7680/4320_mean                         1.85 ms         1.82 ms            5 bytes_per_second=203.779Gi/s items_per_second=18.2339G/s
BM_FullPipeline/7680/4320_median                       1.85 ms         1.82 ms            5 bytes_per_second=203.499Gi/s items_per_second=18.2088G/s
BM_FullPipeline/7680/4320_stddev                      0.005 ms        0.010 ms            5 bytes_per_second=1.12295Gi/s items_per_second=100.479M/s
BM_FullPipeline/7680/4320_cv                           0.28 %          0.55 %             5 bytes_per_second=0.55% items_per_second=0.55%
BM_Sobel_MPI/640/480/manual_time_mean                 0.355 ms        0.354 ms            5 bytes_per_second=6.44886Gi/s items_per_second=865.552M/s
BM_Sobel_MPI/640/480/manual_time_median               0.355 ms        0.355 ms            5 bytes_per_second=6.44586Gi/s items_per_second=865.149M/s
BM_Sobel_MPI/640/480/manual_time_stddev               0.001 ms        0.001 ms            5 bytes_per_second=14.1808Mi/s items_per_second=1.8587M/s
BM_Sobel_MPI/640/480/manual_time_cv                    0.21 %          0.23 %             5 bytes_per_second=0.21% items_per_second=0.21%
BM_Sobel_MPI/1280/720/manual_time_mean                 1.02 ms         1.01 ms            5 bytes_per_second=6.75233Gi/s items_per_second=906.282M/s
BM_Sobel_MPI/1280/720/manual_time_median               1.01 ms         1.01 ms            5 bytes_per_second=6.77371Gi/s items_per_second=909.151M/s
BM_Sobel_MPI/1280/720/manual_time_stddev              0.006 ms        0.006 ms            5 bytes_per_second=43.9036Mi/s items_per_second=5.75453M/s
BM_Sobel_MPI/1280/720/manual_time_cv                   0.64 %          0.61 %             5 bytes_per_second=0.63% items_per_second=0.63%
BM_Sobel_MPI/1920/1080/manual_time_mean                2.18 ms         2.17 ms            5 bytes_per_second=7.08603Gi/s items_per_second=951.071M/s
BM_Sobel_MPI/1920/1080/manual_time_median              2.18 ms         2.17 ms            5 bytes_per_second=7.095Gi/s items_per_second=952.274M/s
BM_Sobel_MPI/1920/1080/manual_time_stddev             0.011 ms        0.011 ms            5 bytes_per_second=35.0535Mi/s items_per_second=4.59453M/s
BM_Sobel_MPI/1920/1080/manual_time_cv                  0.49 %          0.53 %             5 bytes_per_second=0.48% items_per_second=0.48%
BM_Sobel_MPI/3840/2160/manual_time_mean                12.7 ms         11.7 ms            5 bytes_per_second=4.8743Gi/s items_per_second=654.218M/s
BM_Sobel_MPI/3840/2160/manual_time_median              12.7 ms         11.7 ms            5 bytes_per_second=4.87575Gi/s items_per_second=654.412M/s
BM_Sobel_MPI/3840/2160/manual_time_stddev             0.032 ms        0.018 ms            5 bytes_per_second=12.5605Mi/s items_per_second=1.64633M/s
BM_Sobel_MPI/3840/2160/manual_time_cv                  0.25 %          0.15 %             5 bytes_per_second=0.25% items_per_second=0.25%
BM_Sobel_MPI/7680/4320/manual_time_mean                73.8 ms         53.6 ms            5 bytes_per_second=3.34771Gi/s items_per_second=449.322M/s
BM_Sobel_MPI/7680/4320/manual_time_median              73.9 ms         53.6 ms            5 bytes_per_second=3.34614Gi/s items_per_second=449.111M/s
BM_Sobel_MPI/7680/4320/manual_time_stddev             0.176 ms        0.100 ms            5 bytes_per_second=8.16855Mi/s items_per_second=1.07067M/s
BM_Sobel_MPI/7680/4320/manual_time_cv                  0.24 %          0.19 %             5 bytes_per_second=0.24% items_per_second=0.24%
BM_FullPipeline_MPI/640/480/manual_time_mean           1.13 ms         1.13 ms            5 bytes_per_second=3.0291Gi/s items_per_second=271.039M/s
BM_FullPipeline_MPI/640/480/manual_time_median         1.13 ms         1.13 ms            5 bytes_per_second=3.03959Gi/s items_per_second=271.978M/s
BM_FullPipeline_MPI/640/480/manual_time_stddev        0.007 ms        0.007 ms            5 bytes_per_second=18.5745Mi/s items_per_second=1.62307M/s
BM_FullPipeline_MPI/640/480/manual_time_cv             0.60 %          0.59 %             5 bytes_per_second=0.60% items_per_second=0.60%
BM_FullPipeline_MPI/1280/720/manual_time_mean          3.32 ms         3.31 ms            5 bytes_per_second=3.10391Gi/s items_per_second=277.733M/s
BM_FullPipeline_MPI/1280/720/manual_time_median        3.31 ms         3.30 ms            5 bytes_per_second=3.11135Gi/s items_per_second=278.399M/s
BM_FullPipeline_MPI/1280/720/manual_time_stddev       0.015 ms        0.014 ms            5 bytes_per_second=13.9356Mi/s items_per_second=1.21772M/s
BM_FullPipeline_MPI/1280/720/manual_time_cv            0.44 %          0.44 %             5 bytes_per_second=0.44% items_per_second=0.44%
BM_FullPipeline_MPI/1920/1080/manual_time_mean         7.28 ms         7.25 ms            5 bytes_per_second=3.18134Gi/s items_per_second=284.662M/s
BM_FullPipeline_MPI/1920/1080/manual_time_median       7.28 ms         7.25 ms            5 bytes_per_second=3.182Gi/s items_per_second=284.721M/s
BM_FullPipeline_MPI/1920/1080/manual_time_stddev      0.007 ms        0.005 ms            5 bytes_per_second=3.05843Mi/s items_per_second=267.249k/s
BM_FullPipeline_MPI/1920/1080/manual_time_cv           0.09 %          0.07 %             5 bytes_per_second=0.09% items_per_second=0.09%
BM_FullPipeline_MPI/3840/2160/manual_time_mean         34.6 ms         31.9 ms            5 bytes_per_second=2.6811Gi/s items_per_second=239.901M/s
BM_FullPipeline_MPI/3840/2160/manual_time_median       34.6 ms         31.9 ms            5 bytes_per_second=2.67975Gi/s items_per_second=239.78M/s
BM_FullPipeline_MPI/3840/2160/manual_time_stddev      0.061 ms        0.041 ms            5 bytes_per_second=4.81429Mi/s items_per_second=420.679k/s
BM_FullPipeline_MPI/3840/2160/manual_time_cv           0.18 %          0.13 %             5 bytes_per_second=0.18% items_per_second=0.18%
BM_FullPipeline_MPI/7680/4320/manual_time_mean          186 ms          135 ms            5 bytes_per_second=1.99766Gi/s items_per_second=178.748M/s
BM_FullPipeline_MPI/7680/4320/manual_time_median        186 ms          134 ms            5 bytes_per_second=1.9957Gi/s items_per_second=178.572M/s
BM_FullPipeline_MPI/7680/4320/manual_time_stddev       1.58 ms         1.05 ms            5 bytes_per_second=17.4173Mi/s items_per_second=1.52195M/s
BM_FullPipeline_MPI/7680/4320/manual_time_cv           0.85 %          0.78 %             5 bytes_per_second=0.85% items_per_second=0.85%
```

(note: if you are getting a warning about JIT like above, it's recommended to re-run the benchmark. Final results will be in our report, this run was chosen specifically to point this out)
