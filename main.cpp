// +++++++++++++++++++++++++++++++++++++++
// add input.jpg to the build dir or change the path!!!!
// +++++++++++++++++++++++++++++++++++++++

#include <cmath>
#include <vector>
#include <cstdint>
#include <iostream>
#include <cstdlib>          // std::stoi
#include <omp.h>            // OpenMP
#include <chrono>           // std::chrono
#include <iomanip>          // std::setprecision

#define STB_IMAGE_IMPLEMENTATION
#include "include/stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "include/stb_image_write.h"

using ImageF = std::vector<float>;

inline int idx(int x, int y, int w) { return y * w + x; }

ImageF toGray(const uint8_t *data, int w, int h, int channels) {
    ImageF gray(w * h);
#pragma omp parallel for schedule(static) default(none) shared(data, w, h, channels, gray)
    for (int i = 0; i < w * h; ++i) {
        const uint8_t *p = data + i * channels;
        float v;
        if (channels == 1) v = p[0];
        else if (channels == 3 || channels == 4)
            v = 0.299f * p[0] + 0.587f * p[1] + 0.114f * p[2];
        else v = 0.0f;
        gray[i] = v;
    }
    return gray;
}

ImageF convolve(const ImageF &in, int w, int h,
                const std::vector<float> &kernel, int kw, int kh) {
    ImageF out(w * h, 0.0f);
    int padX = kw / 2, padY = kh / 2;

#pragma omp parallel for schedule(static) default(none) shared(in, out, w, h, kernel, kw, kh, padX, padY)
    for (int i = 0; i < w * h; ++i) {
        int x = i % w;
        int y = i / w;
        float sum = 0.0f;
        for (int ky = 0; ky < kh; ++ky) {
            for (int kx = 0; kx < kw; ++kx) {
                int ix = x + kx - padX;
                int iy = y + ky - padY;
                if (ix >= 0 && ix < w && iy >= 0 && iy < h) {
                    sum += in[idx(ix, iy, w)] * kernel[ky * kw + kx];
                }
            }
        }
        out[i] = sum;
    }
    return out;
}

ImageF magnitude(const ImageF &gx, const ImageF &gy, int size) {
    ImageF mag(size);
#pragma omp parallel for schedule(static) default(none) shared(gx, gy, mag, size)
    for (int i = 0; i < size; ++i) {
        mag[i] = std::hypot(gx[i], gy[i]);
    }
    return mag;
}


std::vector<uint8_t> normalizeToU8(const ImageF &img) {
    float mn = img[0], mx = img[0];

#pragma omp parallel for reduction(min:mn) reduction(max:mx) default(none) shared(img)
    for (size_t i = 0; i < img.size(); ++i) {
        if (img[i] < mn) mn = img[i];
        if (img[i] > mx) mx = img[i];
    }

    float range = mx - mn;
    if (range < 1e-6f) range = 1.0f;

    std::vector<uint8_t> out(img.size());

#pragma omp parallel for schedule(static) default(none) shared(img, out, mn, mx, range)
    for (size_t i = 0; i < img.size(); ++i) {
        float v = (img[i] - mn) / range * 255.0f;
        int iv = static_cast<int>(std::round(v));
        if (iv < 0) iv = 0;
        if (iv > 255) iv = 255;
        out[i] = static_cast<uint8_t>(iv);
    }
    return out;
}


int main(int argc, char *argv[]) {

    // default if not specified
    omp_set_num_threads(128);
    // Usage: ./PORRRRRR [num_threads]
    if (argc > 1) {
        int requested = std::stoi(argv[1]);
        if (requested > 0) {
            omp_set_num_threads(requested);
            std::cout << "Forcing OpenMP to use " << requested << " thread(s).\n";
        }
    }

    const char *input_path  = "input.jpg";
    const char *output_path = "output.png";

    auto t_start = std::chrono::high_resolution_clock::now();


    int w, h, channels;
    uint8_t *data = stbi_load(input_path, &w, &h, &channels, 0);
    if (!data) {
        std::cerr << "Failed to load image: " << input_path << "\n";
        return 1;
    }
    std::cout << "Loaded: " << input_path << " (" << w << "x" << h
              << ", ch=" << channels << ")\n";
    auto t_accel_start = std::chrono::high_resolution_clock::now();

    double t_gray_start = omp_get_wtime();
    ImageF gray = toGray(data, w, h, channels);
    double t_gray_end   = omp_get_wtime();
    stbi_image_free(data);

    std::vector<float> sobelX = {
            -1, 0, 1,
            -2, 0, 2,
            -1, 0, 1
    };
    std::vector<float> sobelY = {
            -1, -2, -1,
            0,  0,  0,
            1,  2,  1
    };

    double t_conv_start = omp_get_wtime();
    ImageF gx = convolve(gray, w, h, sobelX, 3, 3);
    ImageF gy = convolve(gray, w, h, sobelY, 3, 3);
    double t_conv_end = omp_get_wtime();

    double t_mag_start = omp_get_wtime();
    ImageF mag = magnitude(gx, gy, w * h);
    double t_mag_end = omp_get_wtime();

    double t_norm_start = omp_get_wtime();
    std::vector<uint8_t> out_u8 = normalizeToU8(mag);
    double t_norm_end = omp_get_wtime();
    auto t_accel_end = std::chrono::high_resolution_clock::now();

    if (!stbi_write_png(output_path, w, h, 1, out_u8.data(), w)) {
        std::cerr << "Failed to write PNG: " << output_path << "\n";
        return 1;
    }
    std::cout << "Saved: " << output_path << "\n";

    auto t_end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> total = t_end - t_start;
    std::chrono::duration<double> processing = t_accel_end - t_accel_start;
    std::cout << std::fixed << std::setprecision(4);
    std::cout << "\n--- Timing (seconds) ---\n";
    std::cout << "Grayscale conversion : " << (t_gray_end - t_gray_start) << "\n";
    std::cout << "Convolution (both axes) : " << (t_conv_end - t_conv_start) << "\n";
    std::cout << "Gradient magnitude   : " << (t_mag_end - t_mag_start) << "\n";
    std::cout << "Normalisation & write: " << (t_norm_end - t_norm_start) << "\n";
    std::cout << "Processing runtime   : " << processing.count() << "\n";
    std::cout << "Total runtime        : " << total.count() << "\n";

    return 0;
}
