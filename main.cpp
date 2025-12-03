// +++++++++++++++++++++++++++++++++++++++
// add input.jpg to the build dir or change the path!!!!
// +++++++++++++++++++++++++++++++++++++++
#include <cmath>
#include <vector>
#include <cstdint>
#include <iostream>
#define STB_IMAGE_IMPLEMENTATION
#include "include/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "include/stb_image_write.h"

#include <sycl/sycl.hpp>

// SYCL kernel names
class grayscale_kernel;
class sobel_kernel;

typedef std::vector<float> ImageF;
inline int idx(int x, int y, int w){ return y*w + x; }

ImageF toGray(const uint8_t* data, int w, int h, int channels){
    ImageF g(w*h);
    for(int y=0;y<h;++y){
        for(int x=0;x<w;++x){
            int i = idx(x,y,w);
            const uint8_t* p = data + i*channels;
            float val;
            if(channels == 1) val = p[0];
            else if(channels == 3 || channels == 4)
                val = 0.299f*p[0] + 0.587f*p[1] + 0.114f*p[2];
            else val = 0.0f;
            g[i] = val;
        }
    }
    return g;
}

std::vector<uint8_t> normalizeToU8(const ImageF &img){
    float mn = img[0], mx = img[0];
    for(float v: img){ if(v<mn) mn=v; if(v>mx) mx=v; }
    float range = mx-mn; if(range < 1e-6f) range = 1.0f;
    std::vector<uint8_t> out(img.size());
    for(size_t i=0;i<img.size();++i){
        float v = (img[i]-mn)/range*255.0f;
        int iv = (int)std::round(v);
        if(iv<0) iv=0; if(iv>255) iv=255;
        out[i] = (uint8_t)iv;
    }
    return out;
}

int main(){
    // input
    const char* input_path  = "input.jpg";
    const char* output_path = "output.png";

    // load
    int w,h,channels;
    uint8_t* data = stbi_load(input_path, &w, &h, &channels, 0);
    if(!data){
        std::cerr<<"Failed to load image: "<<input_path<<"\n";
        return 1;
    }
    std::cout<<"Loaded: "<<input_path<<" ("<<w<<"x"<<h<<", ch="<<channels<<")\n";

    // grayscale conversion (CPU - simple preprocessing)
    ImageF gray = toGray(data, w, h, channels);
    stbi_image_free(data);

    // kernels - https://en.wikipedia.org/wiki/Sobel_operator
    std::vector<float> sobelX = {
            -1,0,1,
            -2,0,2,
            -1,0,1
    };
    std::vector<float> sobelY = {
            -1,-2,-1,
            0, 0, 0,
            1, 2, 1
    };

    // Output magnitude buffer
    ImageF mag(w*h, 0.0f);

    constexpr int kernelSize = 3;
    constexpr int halo = kernelSize / 2;

    try {
        // Create SYCL queue - prefer GPU, fallback to default
        sycl::queue queue{sycl::default_selector_v};
        
        std::cout << "Running on: " 
                  << queue.get_device().get_info<sycl::info::device::name>()
                  << "\n";

        // Create buffers
        auto imageRange = sycl::range<2>(h, w);
        auto kernelRange = sycl::range<2>(kernelSize, kernelSize);

        {
            // Input grayscale image buffer
            sycl::buffer<float, 2> grayBuf(gray.data(), imageRange);
            
            // Sobel kernel buffers
            sycl::buffer<float, 2> sobelXBuf(sobelX.data(), kernelRange);
            sycl::buffer<float, 2> sobelYBuf(sobelY.data(), kernelRange);
            
            // Output magnitude buffer
            sycl::buffer<float, 2> magBuf(mag.data(), imageRange);

            // Submit Sobel edge detection kernel
        queue.submit([&](sycl::handler& cgh) {
            // Accessors
            sycl::accessor grayAcc{grayBuf, cgh, sycl::read_only};
            sycl::accessor sobelXAcc{sobelXBuf, cgh, sycl::read_only};
            sycl::accessor sobelYAcc{sobelYBuf, cgh, sycl::read_only};
            sycl::accessor magAcc{magBuf, cgh, sycl::write_only, sycl::no_init};

            cgh.parallel_for<sobel_kernel>(
                imageRange,
                [=](sycl::id<2> gid) {
                    int y = gid[0];
                    int x = gid[1];
                    int imgWidth = imageRange[1];
                    int imgHeight = imageRange[0];

                    float sumX = 0.0f;
                    float sumY = 0.0f;

                    // Apply both Sobel kernels
                    for (int ky = 0; ky < kernelSize; ++ky) {
                        for (int kx = 0; kx < kernelSize; ++kx) {
                            int ix = x + kx - halo;
                            int iy = y + ky - halo;

                            // Boundary check - use 0 for out of bounds
                            if (ix >= 0 && ix < imgWidth && iy >= 0 && iy < imgHeight) {
                                float pixelVal = grayAcc[iy][ix];
                                sumX += pixelVal * sobelXAcc[ky][kx];
                                sumY += pixelVal * sobelYAcc[ky][kx];
                            }
                        }
                    }

                    // Compute gradient magnitude
                    magAcc[y][x] = sycl::sqrt(sumX * sumX + sumY * sumY);
                });
        });

            // Wait for completion
            queue.wait_and_throw();
        }
        // Buffers go out of scope here, data is copied back to host

    } catch (const sycl::exception& e) {
        std::cerr << "SYCL exception: " << e.what() << std::endl;
        return 1;
    }

    // normalize vectors before save
    std::vector<uint8_t> out_u8 = normalizeToU8(mag);

    if(!stbi_write_png(output_path, w, h, 1, out_u8.data(), w)) {
        std::cerr << "Failed to write PNG: " << output_path << "\n";
        return 1;
    }

    std::cout<<"Saved: "<<output_path<<"\n";
    return 0;
}
