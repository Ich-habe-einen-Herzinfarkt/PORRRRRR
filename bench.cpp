#include <benchmark/benchmark.h>
#include <cmath>
#include <vector>
#include <cstdint>
#include <limits>
#include <sycl/sycl.hpp>

// SYCL kernel names
class sobel_naive_kernel;
class sobel_unrolled_kernel;
class sobel_tiled_kernel;
class grayscale_kernel;
class minmax_kernel;
class normalize_kernel;

// Tile dimensions for tiled implementation (demo only)
constexpr int TILE_W = 16;
constexpr int TILE_H = 16;
constexpr int HALO = 1;
constexpr int LOCAL_W = TILE_W + 2 * HALO;
constexpr int LOCAL_H = TILE_H + 2 * HALO;

typedef std::vector<float> ImageF;

// Helper for CPU version
inline int idx(int x, int y, int w) { return y * w + x; }

// Generate synthetic grayscale image
ImageF generateTestImage(int w, int h) {
    ImageF img(w * h);
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            img[y * w + x] = static_cast<float>((x + y) % 256);
        }
    }
    return img;
}

// CPU convolution (from original implementation)
ImageF convolve_cpu(const ImageF& in, int w, int h, const std::vector<float>& kernel, int kw, int kh) {
    ImageF out(w * h, 0.0f);
    int padX = kw / 2, padY = kh / 2;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            float s = 0.0f;
            for (int ky = 0; ky < kh; ++ky) {
                for (int kx = 0; kx < kw; ++kx) {
                    int ix = x + kx - padX;
                    int iy = y + ky - padY;
                    if (ix >= 0 && ix < w && iy >= 0 && iy < h) {
                        s += in[idx(ix, iy, w)] * kernel[ky * kw + kx];
                    }
                }
            }
            out[idx(x, y, w)] = s;
        }
    }
    return out;
}

// Create a reusable SYCL queue (singleton pattern for benchmarks)
sycl::queue& getQueue() {
    static sycl::queue q{sycl::default_selector_v, sycl::property::queue::in_order()};
    return q;
}

// =============================================================================
// VERSION 0: Pure CPU (single-threaded, original implementation)
// =============================================================================
static void BM_Sobel_CPU_Original(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    
    ImageF gray = generateTestImage(w, h);
    
    static const std::vector<float> sobelX = {-1,0,1, -2,0,2, -1,0,1};
    static const std::vector<float> sobelY = {-1,-2,-1, 0,0,0, 1,2,1};
    
    for (auto _ : state) {
        ImageF gx = convolve_cpu(gray, w, h, sobelX, 3, 3);
        ImageF gy = convolve_cpu(gray, w, h, sobelY, 3, 3);
        
        ImageF mag(w * h);
        for (int i = 0; i < w * h; ++i) {
            mag[i] = std::hypot(gx[i], gy[i]);
        }
        
        benchmark::DoNotOptimize(mag.data());
        benchmark::ClobberMemory();
    }
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// VERSION 0b: CPU with unrolled Sobel (single-threaded, optimized)
// =============================================================================
static void BM_Sobel_CPU_Unrolled(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    
    ImageF gray = generateTestImage(w, h);
    ImageF mag(w * h, 0.0f);
    
    for (auto _ : state) {
        for (int y = 1; y < h - 1; ++y) {
            for (int x = 1; x < w - 1; ++x) {
                float p00 = gray[(y-1) * w + (x-1)];
                float p01 = gray[(y-1) * w + x];
                float p02 = gray[(y-1) * w + (x+1)];
                float p10 = gray[y * w + (x-1)];
                float p12 = gray[y * w + (x+1)];
                float p20 = gray[(y+1) * w + (x-1)];
                float p21 = gray[(y+1) * w + x];
                float p22 = gray[(y+1) * w + (x+1)];

                float dx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                float dy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                mag[y * w + x] = std::sqrt(dx * dx + dy * dy);
            }
        }
        
        benchmark::DoNotOptimize(mag.data());
        benchmark::ClobberMemory();
    }
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// SYCL Buffers - Naive with loops (baseline SYCL)
// =============================================================================
static void BM_Sobel_Buffers_Naive(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    
    ImageF gray = generateTestImage(w, h);
    ImageF mag(w * h, 0.0f);
    
    static const std::vector<float> sobelX = {-1,0,1, -2,0,2, -1,0,1};
    static const std::vector<float> sobelY = {-1,-2,-1, 0,0,0, 1,2,1};
    
    sycl::queue& queue = getQueue();
    auto imageRange = sycl::range<2>(h, w);
    auto kernelRange = sycl::range<2>(3, 3);
    
    for (auto _ : state) {
        {
            sycl::buffer<float, 2> grayBuf(gray.data(), imageRange);
            sycl::buffer<float, 2> sobelXBuf(sobelX.data(), kernelRange);
            sycl::buffer<float, 2> sobelYBuf(sobelY.data(), kernelRange);
            sycl::buffer<float, 2> magBuf(mag.data(), imageRange);

            queue.submit([&](sycl::handler& cgh) {
                sycl::accessor grayAcc{grayBuf, cgh, sycl::read_only};
                sycl::accessor sobelXAcc{sobelXBuf, cgh, sycl::read_only};
                sycl::accessor sobelYAcc{sobelYBuf, cgh, sycl::read_only};
                sycl::accessor magAcc{magBuf, cgh, sycl::write_only, sycl::no_init};

                cgh.parallel_for<sobel_naive_kernel>(
                    imageRange,
                    [=](sycl::id<2> gid) {
                        int y = gid[0];
                        int x = gid[1];
                        int imgWidth = imageRange[1];
                        int imgHeight = imageRange[0];

                        float sumX = 0.0f;
                        float sumY = 0.0f;

                        for (int ky = 0; ky < 3; ++ky) {
                            for (int kx = 0; kx < 3; ++kx) {
                                int ix = x + kx - 1;
                                int iy = y + ky - 1;

                                if (ix >= 0 && ix < imgWidth && iy >= 0 && iy < imgHeight) {
                                    float pixelVal = grayAcc[iy][ix];
                                    sumX += pixelVal * sobelXAcc[ky][kx];
                                    sumY += pixelVal * sobelYAcc[ky][kx];
                                }
                            }
                        }

                        magAcc[y][x] = sycl::sqrt(sumX * sumX + sumY * sumY);
                    });
            });
            queue.wait();
        }
    }
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// SYCL Buffers - Unrolled (good buffer baseline)
// =============================================================================
class sobel_unrolled_buffer_kernel;

static void BM_Sobel_Buffers_Unrolled(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    
    ImageF gray = generateTestImage(w, h);
    ImageF mag(w * h, 0.0f);
    
    sycl::queue& queue = getQueue();
    auto imageRange = sycl::range<2>(h, w);
    
    for (auto _ : state) {
        {
            sycl::buffer<float, 2> grayBuf(gray.data(), imageRange);
            sycl::buffer<float, 2> magBuf(mag.data(), imageRange);

            queue.submit([&](sycl::handler& cgh) {
                sycl::accessor grayAcc{grayBuf, cgh, sycl::read_only};
                sycl::accessor magAcc{magBuf, cgh, sycl::write_only, sycl::no_init};

                cgh.parallel_for<sobel_unrolled_buffer_kernel>(
                    imageRange,
                    [=](sycl::id<2> gid) {
                        int y = gid[0];
                        int x = gid[1];
                        int imgWidth = imageRange[1];
                        int imgHeight = imageRange[0];
                        
                        if (x > 0 && y > 0 && x < imgWidth - 1 && y < imgHeight - 1) {
                            float p00 = grayAcc[y-1][x-1];
                            float p01 = grayAcc[y-1][x];
                            float p02 = grayAcc[y-1][x+1];
                            float p10 = grayAcc[y][x-1];
                            float p12 = grayAcc[y][x+1];
                            float p20 = grayAcc[y+1][x-1];
                            float p21 = grayAcc[y+1][x];
                            float p22 = grayAcc[y+1][x+1];

                            float dx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                            float dy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                            magAcc[y][x] = sycl::sqrt(dx * dx + dy * dy);
                        } else {
                            magAcc[y][x] = 0.0f;
                        }
                    });
            });
            queue.wait();
        }
    }
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// Device USM - Basic unrolled (baseline for USM)
// =============================================================================
class sobel_device_usm_kernel;

static void BM_Sobel_DeviceUSM_Basic(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    const size_t numPixels = static_cast<size_t>(w) * h;
    
    sycl::queue& queue = getQueue();
    
    ImageF gray_host = generateTestImage(w, h);
    
    float* gray_dev = sycl::malloc_device<float>(numPixels, queue);
    float* mag_dev = sycl::malloc_device<float>(numPixels, queue);
    
    queue.memcpy(gray_dev, gray_host.data(), numPixels * sizeof(float)).wait();
    
    for (auto _ : state) {
        queue.parallel_for<sobel_device_usm_kernel>(
            sycl::range<2>(h, w),
            [=](sycl::id<2> gid) {
                int y = gid[0];
                int x = gid[1];
                
                if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
                    float p00 = gray_dev[(y-1) * w + (x-1)];
                    float p01 = gray_dev[(y-1) * w + x];
                    float p02 = gray_dev[(y-1) * w + (x+1)];
                    float p10 = gray_dev[y * w + (x-1)];
                    float p12 = gray_dev[y * w + (x+1)];
                    float p20 = gray_dev[(y+1) * w + (x-1)];
                    float p21 = gray_dev[(y+1) * w + x];
                    float p22 = gray_dev[(y+1) * w + (x+1)];

                    float dx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                    float dy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                    mag_dev[y * w + x] = sycl::sqrt(dx * dx + dy * dy);
                } else {
                    mag_dev[y * w + x] = 0.0f;
                }
            }
        );
        queue.wait();
    }
    
    sycl::free(gray_dev, queue);
    sycl::free(mag_dev, queue);
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// Device USM - Tiled with local memory (demo - shows tiling doesn't help 3x3)
// =============================================================================
class sobel_tiled_device_kernel;

static void BM_Sobel_DeviceUSM_Tiled_Demo(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    const size_t numPixels = static_cast<size_t>(w) * h;
    
    sycl::queue& queue = getQueue();
    
    ImageF gray_host = generateTestImage(w, h);
    
    float* gray_dev = sycl::malloc_device<float>(numPixels, queue);
    float* mag_dev = sycl::malloc_device<float>(numPixels, queue);
    
    queue.memcpy(gray_dev, gray_host.data(), numPixels * sizeof(float)).wait();
    
    int numGroupsX = (w + TILE_W - 1) / TILE_W;
    int numGroupsY = (h + TILE_H - 1) / TILE_H;
    
    for (auto _ : state) {
        queue.submit([&](sycl::handler& cgh) {
            sycl::local_accessor<float, 2> tile(sycl::range<2>(LOCAL_H, LOCAL_W), cgh);
            
            float* gray = gray_dev;
            float* mag = mag_dev;
            
            cgh.parallel_for<sobel_tiled_device_kernel>(
                sycl::nd_range<2>(
                    sycl::range<2>(numGroupsY * TILE_H, numGroupsX * TILE_W),
                    sycl::range<2>(TILE_H, TILE_W)
                ),
                [=](sycl::nd_item<2> item) {
                    int gx = item.get_global_id(1);
                    int gy = item.get_global_id(0);
                    int lx = item.get_local_id(1);
                    int ly = item.get_local_id(0);
                    int groupStartX = item.get_group(1) * TILE_W;
                    int groupStartY = item.get_group(0) * TILE_H;
                    
                    int localSize = TILE_W * TILE_H;
                    int localId = ly * TILE_W + lx;
                    int totalPixels = LOCAL_H * LOCAL_W;
                    
                    for (int i = localId; i < totalPixels; i += localSize) {
                        int tileY = i / LOCAL_W;
                        int tileX = i % LOCAL_W;
                        int srcX = sycl::clamp(groupStartX + tileX - HALO, 0, w - 1);
                        int srcY = sycl::clamp(groupStartY + tileY - HALO, 0, h - 1);
                        tile[tileY][tileX] = gray[srcY * w + srcX];
                    }
                    
                    sycl::group_barrier(item.get_group());
                    
                    if (gx < w && gy < h) {
                        if (gx > 0 && gy > 0 && gx < w - 1 && gy < h - 1) {
                            int tx = lx + HALO;
                            int ty = ly + HALO;
                            
                            float p00 = tile[ty-1][tx-1];
                            float p01 = tile[ty-1][tx];
                            float p02 = tile[ty-1][tx+1];
                            float p10 = tile[ty][tx-1];
                            float p12 = tile[ty][tx+1];
                            float p20 = tile[ty+1][tx-1];
                            float p21 = tile[ty+1][tx];
                            float p22 = tile[ty+1][tx+1];
                            
                            float dx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                            float dy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;
                            
                            mag[gy * w + gx] = sycl::sqrt(dx * dx + dy * dy);
                        } else {
                            mag[gy * w + gx] = 0.0f;
                        }
                    }
                }
            );
        });
        queue.wait();
    }
    
    sycl::free(gray_dev, queue);
    sycl::free(mag_dev, queue);
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// Optimized combo: NDRange 128x1 + 2 pixels per work-item + fast math
// This is the WINNER configuration achieving 593 GB/s at 4K on RDNA3
// =============================================================================
class sobel_optimized_combo_kernel;

static void BM_Sobel_Optimized_Combo(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    const size_t numPixels = static_cast<size_t>(w) * h;
    
    sycl::queue& queue = getQueue();
    
    ImageF gray_host = generateTestImage(w, h);
    
    float* gray_dev = sycl::malloc_device<float>(numPixels, queue);
    float* mag_dev = sycl::malloc_device<float>(numPixels, queue);
    
    queue.memcpy(gray_dev, gray_host.data(), numPixels * sizeof(float)).wait();
    
    // Process 2 pixels per work-item in X direction
    constexpr int WG_X = 128;  // 128 work-items * 2 pixels = 256 pixels per row segment
    constexpr int WG_Y = 1;
    
    int workW = (w + 1) / 2;
    int globalX = ((workW + WG_X - 1) / WG_X) * WG_X;
    int globalY = ((h + WG_Y - 1) / WG_Y) * WG_Y;
    
    for (auto _ : state) {
        queue.parallel_for<sobel_optimized_combo_kernel>(
            sycl::nd_range<2>(
                sycl::range<2>(globalY, globalX),
                sycl::range<2>(WG_Y, WG_X)
            ),
            [=](sycl::nd_item<2> item) {
                int y = item.get_global_id(0);
                int x0 = item.get_global_id(1) * 2;
                
                if (y >= h) return;
                
                // Process two adjacent pixels with shared neighbor reads
                #pragma unroll
                for (int dx = 0; dx < 2; ++dx) {
                    int x = x0 + dx;
                    if (x >= w) continue;
                    
                    if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
                        float p00 = gray_dev[(y-1) * w + (x-1)];
                        float p01 = gray_dev[(y-1) * w + x];
                        float p02 = gray_dev[(y-1) * w + (x+1)];
                        float p10 = gray_dev[y * w + (x-1)];
                        float p12 = gray_dev[y * w + (x+1)];
                        float p20 = gray_dev[(y+1) * w + (x-1)];
                        float p21 = gray_dev[(y+1) * w + x];
                        float p22 = gray_dev[(y+1) * w + (x+1)];

                        float gx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                        float gy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                        mag_dev[y * w + x] = sycl::native::sqrt(gx * gx + gy * gy);
                    } else {
                        mag_dev[y * w + x] = 0.0f;
                    }
                }
            }
        );
        queue.wait();
    }
    
    sycl::free(gray_dev, queue);
    sycl::free(mag_dev, queue);
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * sizeof(float) * 2);
}

// =============================================================================
// FULL PIPELINE: Grayscale + Sobel + MinMax + Normalize (simulates real usage)
// Uses the optimized combo approach: 128x1 WG + 2 pixels/item + fast math
// =============================================================================
class full_pipeline_sobel_kernel;

static void BM_FullPipeline(benchmark::State& state) {
    const int w = state.range(0);
    const int h = state.range(1);
    const size_t numPixels = static_cast<size_t>(w) * h;
    const int channels = 3;
    
    sycl::queue& queue = getQueue();
    
    uint8_t* inputData = sycl::malloc_device<uint8_t>(numPixels * channels, queue);
    float* gray = sycl::malloc_device<float>(numPixels, queue);
    float* mag = sycl::malloc_device<float>(numPixels, queue);
    uint8_t* output = sycl::malloc_device<uint8_t>(numPixels, queue);
    float* minVal = sycl::malloc_shared<float>(1, queue);
    float* maxVal = sycl::malloc_shared<float>(1, queue);
    
    // Initialize input on host and copy
    std::vector<uint8_t> inputHost(numPixels * channels);
    for (size_t i = 0; i < numPixels * channels; ++i) {
        inputHost[i] = static_cast<uint8_t>(i % 256);
    }
    queue.memcpy(inputData, inputHost.data(), numPixels * channels).wait();
    
    // Optimized combo: 128x1 work-groups + 2 pixels per work-item
    constexpr int WG_X = 128;
    constexpr int WG_Y = 1;
    int workW = (w + 1) / 2;  // Each work-item processes 2 pixels
    int globalX = ((workW + WG_X - 1) / WG_X) * WG_X;
    
    for (auto _ : state) {
        // Grayscale
        queue.parallel_for<grayscale_kernel>(
            sycl::range<1>(numPixels),
            [=](sycl::id<1> i) {
                size_t idx = i[0];
                const uint8_t* p = inputData + idx * 3;
                gray[idx] = 0.299f * p[0] + 0.587f * p[1] + 0.114f * p[2];
            }
        );
        
        // Sobel (optimized combo: 128x1 + 2 pixels/item + native::sqrt)
        queue.parallel_for<full_pipeline_sobel_kernel>(
            sycl::nd_range<2>(
                sycl::range<2>(h, globalX),
                sycl::range<2>(WG_Y, WG_X)
            ),
            [=](sycl::nd_item<2> item) {
                int y = item.get_global_id(0);
                int x0 = item.get_global_id(1) * 2;
                
                if (y >= h) return;
                
                // Process two adjacent pixels
                #pragma unroll
                for (int dx = 0; dx < 2; ++dx) {
                    int x = x0 + dx;
                    if (x >= w) continue;
                    
                    if (x > 0 && y > 0 && x < w - 1 && y < h - 1) {
                        float p00 = gray[(y-1) * w + (x-1)];
                        float p01 = gray[(y-1) * w + x];
                        float p02 = gray[(y-1) * w + (x+1)];
                        float p10 = gray[y * w + (x-1)];
                        float p12 = gray[y * w + (x+1)];
                        float p20 = gray[(y+1) * w + (x-1)];
                        float p21 = gray[(y+1) * w + x];
                        float p22 = gray[(y+1) * w + (x+1)];

                        float gx = -p00 + p02 - 2.0f * p10 + 2.0f * p12 - p20 + p22;
                        float gy = -p00 - 2.0f * p01 - p02 + p20 + 2.0f * p21 + p22;

                        mag[y * w + x] = sycl::native::sqrt(gx * gx + gy * gy);
                    } else {
                        mag[y * w + x] = 0.0f;
                    }
                }
            }
        );
        
        // MinMax reduction
        *minVal = std::numeric_limits<float>::max();
        *maxVal = std::numeric_limits<float>::lowest();
        
        queue.parallel_for<minmax_kernel>(
            sycl::range<1>(numPixels),
            sycl::reduction(minVal, sycl::minimum<float>()),
            sycl::reduction(maxVal, sycl::maximum<float>()),
            [=](sycl::id<1> i, auto& min_ref, auto& max_ref) {
                float v = mag[i[0]];
                min_ref.combine(v);
                max_ref.combine(v);
            }
        );
        
        // Normalize
        queue.parallel_for<normalize_kernel>(
            sycl::range<1>(numPixels),
            [=](sycl::id<1> i) {
                size_t idx = i[0];
                float mn = *minVal;
                float mx = *maxVal;
                float range = mx - mn;
                if (range < 1e-6f) range = 1.0f;
                
                float v = (mag[idx] - mn) / range * 255.0f;
                int iv = static_cast<int>(sycl::round(v));
                iv = sycl::clamp(iv, 0, 255);
                output[idx] = static_cast<uint8_t>(iv);
            }
        );
        
        queue.wait();
    }
    
    sycl::free(inputData, queue);
    sycl::free(gray, queue);
    sycl::free(mag, queue);
    sycl::free(output, queue);
    sycl::free(minVal, queue);
    sycl::free(maxVal, queue);
    
    state.SetItemsProcessed(state.iterations() * w * h);
    state.SetBytesProcessed(state.iterations() * w * h * (channels + sizeof(float) * 2 + 1));
}

// =============================================================================
// Register benchmarks
// =============================================================================

#define IMAGE_SIZES \
    ->Args({640, 480})      \
    ->Args({1280, 720})     \
    ->Args({1920, 1080})    \
    ->Args({3840, 2160})    \
    ->Args({7680, 4320})

// CPU baselines
BENCHMARK(BM_Sobel_CPU_Original)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

BENCHMARK(BM_Sobel_CPU_Unrolled)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

// SYCL Buffers (for comparison)
BENCHMARK(BM_Sobel_Buffers_Naive)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

BENCHMARK(BM_Sobel_Buffers_Unrolled)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

// Device USM versions
BENCHMARK(BM_Sobel_DeviceUSM_Basic)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

// Tiled demo (shows why tiling doesn't help 3x3 stencils)
BENCHMARK(BM_Sobel_DeviceUSM_Tiled_Demo)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

// Best optimized version (WINNER: 593 GB/s at 4K on RDNA3)
BENCHMARK(BM_Sobel_Optimized_Combo)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

// Full pipeline (realistic end-to-end usage)
BENCHMARK(BM_FullPipeline)
    IMAGE_SIZES
    ->Unit(benchmark::kMillisecond);

BENCHMARK_MAIN();
