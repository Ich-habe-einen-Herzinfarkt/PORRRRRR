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

using ImageF = std::vector<float>;
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

ImageF convolve(const ImageF &in, int w, int h, const std::vector<float>& kernel, int kw, int kh){
    ImageF out(w*h, 0.0f);
    int padX = kw/2, padY = kh/2;
    for(int y=0;y<h;++y){
        for(int x=0;x<w;++x){
            float s = 0.0f;
            for(int ky=0; ky<kh; ++ky){
                for(int kx=0; kx<kw; ++kx){
                    int ix = x + kx - padX;
                    int iy = y + ky - padY;
                    if(ix>=0 && ix<w && iy>=0 && iy<h){
                        s += in[idx(ix,iy,w)] * kernel[ky*kw + kx];
                    }
                }
            }
            out[idx(x,y,w)] = s;
        }
    }
    return out;
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

    // albo to inaczej nie pójdzie, albo mam skill issue
    // grayscale conversion
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

    // convolve
    ImageF gx = convolve(gray, w, h, sobelX, 3, 3);
    ImageF gy = convolve(gray, w, h, sobelY, 3, 3);

    // gradient magnitude
    ImageF mag(w*h);
    for(int i=0;i<w*h;++i) mag[i] = std::hypot(gx[i], gy[i]);

    // normalize vectors before save
    std::vector<uint8_t> out_u8 = normalizeToU8(mag);


    if(!stbi_write_png(output_path, w, h, 1, out_u8.data(), w)) {
        std::cerr << "Failed to write PNG: " << output_path << "\n";
        return 1;
    }



    std::cout<<"Saved: "<<output_path<<"\n";
    return 0;
}
