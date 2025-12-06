// +++++++++++++++++++++++++++++++++++++++
// add input.jpg to the build dir or change the path!!!!
// +++++++++++++++++++++++++++++++++++++++
#include <cmath>
#include <vector>
#include <cstdint>
#include <iostream>
#include <limits>
#define STB_IMAGE_IMPLEMENTATION
#include "include/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "include/stb_image_write.h"

#include <sycl/sycl.hpp>

// SYCL kernel names
class grayscale_kernel;
class sobel_kernel;
class minmax_kernel;
class normalize_kernel;

// Tile dimensions for local memory caching
// Each workgroup processes a TILE_W x TILE_H block of output pixels
// 16 was chosen because I remember that number in the context of CUDA, but I think it was for matmul :)
// Anyway, it works
constexpr int TILE_W = 16;
constexpr int TILE_H = 16;
constexpr int HALO = 1;  // Sobel needs 1-pixel border
// We need a (TILE_W+2) x (TILE_H+2) halo to include neighbors for border pixels
constexpr int LOCAL_W = TILE_W + 2 * HALO;
constexpr int LOCAL_H = TILE_H + 2 * HALO;

int main(){
    #pragma region Image Loading
    // input
    const char* input_path  = "input.png";
    const char* output_path = "output.png";

    // load
    int w,h,channels;
    uint8_t* data = stbi_load(input_path, &w, &h, &channels, 0);
    if(!data){
        std::cerr<<"Failed to load image: "<<input_path<<"\n";
        return 1;
    }
    std::cout<<"Loaded: "<<input_path<<" ("<<w<<"x"<<h<<", ch="<<channels<<")\n";

    const size_t numPixels = static_cast<size_t>(w) * h;
    #pragma endregion

    try {
        sycl::queue queue{sycl::default_selector_v, sycl::property::queue::in_order()};
        
        std::cout << "Running on: " 
                  << queue.get_device().get_info<sycl::info::device::name>()
                  << "\n";
        
        // shared buffers because I don't want to deal with manual management any more than I have to...
        // and it *probably* won't have any significant performance impact anyway
        uint8_t* inputData = sycl::malloc_shared<uint8_t>(numPixels * channels, queue);
        float* gray = sycl::malloc_shared<float>(numPixels, queue);
        float* mag = sycl::malloc_shared<float>(numPixels, queue);
        uint8_t* output = sycl::malloc_shared<uint8_t>(numPixels, queue);
        
        // For normalization
        float* minVal = sycl::malloc_shared<float>(1, queue);
        float* maxVal = sycl::malloc_shared<float>(1, queue);

        // Copy input data to shared memory
        std::memcpy(inputData, data, numPixels * channels);
        // we don't need the original data anymore
        stbi_image_free(data);
        #pragma region Grayscale
        // Convert to grayscale, depending on number of channels
        if (channels == 4) {
            // RGBA
            queue.parallel_for<grayscale_kernel>(
                sycl::range<1>(numPixels),
                [=](sycl::id<1> i) {
                    size_t idx = i[0];
                    sycl::uchar4 rgba = *reinterpret_cast<const sycl::uchar4*>(inputData + idx * 4);
                    gray[idx] = 0.299f * rgba.x() + 0.587f * rgba.y() + 0.114f * rgba.z();
                }
            );
        } else if (channels == 3) {
            // RGB
            queue.parallel_for<grayscale_kernel>(
                sycl::range<1>(numPixels),
                [=](sycl::id<1> i) {
                    size_t idx = i[0];
                    const uint8_t* p = inputData + idx * 3;
                    gray[idx] = 0.299f * p[0] + 0.587f * p[1] + 0.114f * p[2];
                }
            );
        } else if (channels == 1) {
            // just cast to float
            queue.parallel_for<grayscale_kernel>(
                sycl::range<1>(numPixels),
                [=](sycl::id<1> i) {
                    size_t idx = i[0];
                    gray[idx] = static_cast<float>(inputData[idx]);
                }
            );
        }
        else {
            // Who uses 2/5+ channels???
            throw std::runtime_error("Unsupported number of channels");
        }
        #pragma endregion
        #pragma region Sobel
        
        // Calculate number of workgroups needed
        int numGroupsX = (w + TILE_W - 1) / TILE_W;
        int numGroupsY = (h + TILE_H - 1) / TILE_H;
        
        // h was taken so this just means "sycl handler" I guess
        queue.submit([&](sycl::handler& sh) {
            sycl::local_accessor<float, 2> tile(sycl::range<2>(LOCAL_H, LOCAL_W), sh);
            
            sh.parallel_for<sobel_kernel>(
                sycl::nd_range<2>(
                    sycl::range<2>(numGroupsY * TILE_H, numGroupsX * TILE_W),  // global size
                    sycl::range<2>(TILE_H, TILE_W)  // workgroup size
                ),
                [=](sycl::nd_item<2> item) {
                    // Global position
                    int gx = item.get_global_id(1);
                    int gy = item.get_global_id(0);
                    
                    // Local position within workgroup
                    int lx = item.get_local_id(1);
                    int ly = item.get_local_id(0);
                    
                    // Workgroup origin in global coordinates
                    int groupStartX = item.get_group(1) * TILE_W;
                    int groupStartY = item.get_group(0) * TILE_H;
                    
                    // Load data into workgroup memory
                    
                    int localSize = TILE_W * TILE_H;
                    int localId = ly * TILE_W + lx;
                    int totalPixels = LOCAL_H * LOCAL_W;
                    
                    // Each work-item loads ceil(324/256) ~= 1-2 pixels
                    // Honestly not sure if this is optimal, but after running into issues
                    // tiling in a CUDA lab, I wanted to see how SYCL handles it 
                    // and if it was just a stupid mistake in address calc or I didn't get somehting.
                    for (int i = localId; i < totalPixels; i += localSize) {
                        int tileY = i / LOCAL_W;
                        int tileX = i % LOCAL_W;
                        
                        // Map to global coordinates (with halo offset)
                        int srcX = groupStartX + tileX - HALO;
                        int srcY = groupStartY + tileY - HALO;
                        
                        // Clamp to image boundaries
                        srcX = sycl::clamp(srcX, 0, w - 1);
                        srcY = sycl::clamp(srcY, 0, h - 1);
                        
                        tile[tileY][tileX] = gray[srcY * w + srcX];
                    }
                    
                    // Synchronize to ensure all data is loaded
                    sycl::group_barrier(item.get_group());
                    
                    // Actually compute Sobel for valid output pixels
                    if (gx < w && gy < h) {
                        if (gx > 0 && gy > 0 && gx < w - 1 && gy < h - 1) {
                            // Local coordinates with halo offset
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
                            
                            // Sobel gradients
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
        #pragma region Normalization
        // Parallel min/max reduction for normalization
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

        // Normalize to [0,255] and convert to uint8_t
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
        #pragma endregion

        #pragma region Image Saving
        // Wait for all kernels to complete before writing output
        queue.wait();

        // Write output (output buffer is in shared memory, accessible from host)
        int result = stbi_write_png(output_path, w, h, 1, output, w);
        sycl::free(inputData, queue);
        sycl::free(gray, queue);
        sycl::free(mag, queue);
        sycl::free(output, queue);
        sycl::free(minVal, queue);
        sycl::free(maxVal, queue);
        if(!result) {
            std::cerr << "Failed to write PNG: " << output_path << "\n";
            return 1;
        }

        std::cout<<"Saved: "<<output_path<<"\n";
        #pragma endregion
    } catch (const sycl::exception& e) {
        std::cerr << "SYCL exception: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
