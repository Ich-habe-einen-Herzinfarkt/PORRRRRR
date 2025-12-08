// +++++++++++++++++++++++++++++++++++++++
// add input.png to the build dir or change the path!!!!
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

// Warning: this configuration is optimized for RDNA3 (RX7800XT) and may need adjustment for other GPUs
// 128 work-items processing 2 pixels each = 256 pixels per row segment
constexpr int WG_X = 128;
constexpr int WG_Y = 1;
constexpr int PIXELS_PER_WI = 2;

int main(){
    #pragma region Image Loading
    const char* input_path  = "input.jpg";
    const char* output_path = "output.png";

    int w, h, channels;
    uint8_t* data = stbi_load(input_path, &w, &h, &channels, 0);
    if(!data){
        std::cerr << "Failed to load image: " << input_path << "\n";
        return 1;
    }
    std::cout << "Loaded: " << input_path << " (" << w << "x" << h << ", ch=" << channels << ")\n";

    const size_t numPixels = static_cast<size_t>(w) * h;
    #pragma endregion

    try {
        sycl::queue queue{sycl::default_selector_v, sycl::property::queue::in_order()};
        
        std::cout << "Running on: " 
                  << queue.get_device().get_info<sycl::info::device::name>()
                  << "\n";
        
        uint8_t* inputData = sycl::malloc_device<uint8_t>(numPixels * channels, queue);
        float* gray = sycl::malloc_device<float>(numPixels, queue);
        float* mag = sycl::malloc_device<float>(numPixels, queue);
        uint8_t* output = sycl::malloc_device<uint8_t>(numPixels, queue);
        
        // Shared memory for reductions (needs host access)
        float* minVal = sycl::malloc_shared<float>(1, queue);
        float* maxVal = sycl::malloc_shared<float>(1, queue);

        // Copy input data to device
        queue.memcpy(inputData, data, numPixels * channels).wait();
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
                    gray[i[0]] = static_cast<float>(inputData[i[0]]);
                }
            );
        } else {
            // Who uses 2/5+ channels???
            throw std::runtime_error("Unsupported number of channels");
        }
        #pragma endregion
        
        #pragma region Sobel
        // Sobel optimized for RDNA3: 128x1 work-groups, 2 pixels per work-item
        // Might need adjustment for other GPUs, especially other vendors
        int workW = (w + 1) / PIXELS_PER_WI;  
        int globalX = ((workW + WG_X - 1) / WG_X) * WG_X;
        int globalY = h;
        
        queue.parallel_for<sobel_kernel>(
            sycl::nd_range<2>(
                sycl::range<2>(globalY, globalX),
                sycl::range<2>(WG_Y, WG_X)
            ),
            [=](sycl::nd_item<2> item) {
                int y = item.get_global_id(0);
                int x0 = item.get_global_id(1) * 2;
                
                if (y >= h) return;
                
                // Process two adjacent pixels
                #pragma unroll
                for (int dx = 0; dx < PIXELS_PER_WI; ++dx) {
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
        #pragma endregion
        
        #pragma region Normalization
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
        
        // Copy output back to host for saving
        std::vector<uint8_t> outputHost(numPixels);
        queue.memcpy(outputHost.data(), output, numPixels).wait();

        int result = stbi_write_png(output_path, w, h, 1, outputHost.data(), w);
        
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

        std::cout << "Saved: " << output_path << "\n";
        #pragma endregion
    } catch (const sycl::exception& e) {
        std::cerr << "SYCL exception: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}