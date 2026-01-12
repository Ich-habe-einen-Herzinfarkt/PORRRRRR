#include <iostream>
#include <mpi.h>
#include <vector>

#define STB_IMAGE_IMPLEMENTATION
#include "include/stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "include/stb_image_write.h"

using ImageF = std::vector<float>;
inline int idx(int x, int y, int width) { return y * width + x; }

// --- [ helper functions ] ---
int convert_to_greyscale(const uint8_t *data, int width, int height, int channels, ImageF& greydata) {
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int local_id = idx(x, y, width);
            int grey_id = width + local_id; // we add extra row for ghost row!

            if (channels == 1) {
                greydata[grey_id] = static_cast<float>(data[local_id]);
            }
            else if (channels == 3 || channels == 4) {
                int r = data[local_id * channels];
                int g = data[local_id * channels + 1];
                int b = data[local_id * channels + 2];
                greydata[grey_id] = static_cast<float>(0.299 * r + 0.587 * g + 0.114 * b);
            }
            else {
                return 0;
            }

        }
    }
    return 1;
}

void apply_sobel_operator(const ImageF& input, ImageF& output, int width, int height) {
    float sobel_x[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
    float sobel_y[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {

            float gx = 0, gy = 0;
            for (int i = -1; i <= 1; i++) {
                for (int j = -1; j <= 1; j++) {

                    if (x+j >= 0 && x+j < width) { // y boundaries are guarded by ghost rows!
                        gx += input[idx(x+j, y+1+i, width)] * sobel_x[i+1][j+1];
                        gy += input[idx(x+j, y+1+i, width)] * sobel_y[i+1][j+1];
                    }

                }
            }

            float magnitude = std::hypot(gx, gy);
            output[idx(x,y,width)] = magnitude;

        }
    }
}

std::vector<uint8_t> normalize_image(const ImageF& input) {
    std::vector<uint8_t> output(input.size());

    float max_val = input[0];
    float min_val = input[0];
    for (float x : input) {
        if (x > max_val) { max_val = x; }
        if (x < min_val) { min_val = x; }
    }

    float range = max_val - min_val;
    if (range < 1e-6f) range = 1.0f;

    for (size_t i = 0; i < input.size(); i++) {
        float normal_x = (input[i] - min_val) / range * 255.0f;
        int i_normal_x = static_cast<int>(std::round(normal_x));
        if (i_normal_x < 0) i_normal_x = 0;
        if (i_normal_x > 255) i_normal_x = 255;
        output[i] = static_cast<uint8_t>(i_normal_x);
    }

    return output;
}

// --- [ main ] ---
int main(int argc, char** argv) {
    const char *input_path = "input.jpg";
    const char *output_path = "output.png";

    MPI_Init(&argc, &argv);

    int num_processes;    // total number of processes in MPI communication world
    int rank;             // unique identifier of the current process within MPI communication world
    MPI_Comm_size(MPI_COMM_WORLD, &num_processes);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    // Load image using STB library
    int width, height, channels;
    uint8_t *data = stbi_load(input_path, &width, &height, &channels, 0);
    if (!data) {
        std::cerr << "Failed to load image: " << input_path << "\n";
        MPI_Abort(MPI_COMM_WORLD, 1);
        return 1;
    }
    std::cout << "Loaded: " << input_path << " (" << width << "x" << height << ", ch=" << channels << ")\n";

    // Distribute work across processes
    int rows_per_process = height / num_processes;
    int remainder = height % num_processes;
    int start_row = rank * rows_per_process + std::min(rank, remainder);
    int end_row = start_row + rows_per_process + (rank < remainder ? 1 : 0);
    int local_height = end_row - start_row;

    // "Local" work part
    std::vector<uint8_t> local_data(local_height * width * channels);
    for (int y = start_row; y < end_row; y++) {
        for (int x = 0; x < width * channels; x++) {
            local_data[idx(x, y - start_row, width*channels)] = data[idx(x, y, width*channels)];
        }
    }
    stbi_image_free(data);

    // Convert to greyscale
    // (upper ghost + local rows + lower ghost) * width
    ImageF greydata((local_height + 2) * width);
    if (!convert_to_greyscale(local_data.data(), width, local_height, channels, greydata)) {
        std::cerr << "Failed to convert image: " << input_path << "\n";
        MPI_Abort(MPI_COMM_WORLD, 1);
        return 1;
    };

    // Exchange common cells
    MPI_Request requests[4];
    for(int i=0; i<4; i++) requests[i] = MPI_REQUEST_NULL;

    // Send "real" rows, receive into "ghost" rows
    if (rank > 0) {
        MPI_Isend(&greydata[width], width, MPI_FLOAT, rank - 1, 0, MPI_COMM_WORLD, &requests[0]);
        MPI_Irecv(&greydata[0], width, MPI_FLOAT, rank - 1, 1, MPI_COMM_WORLD, &requests[1]);
    }
    if (rank < num_processes - 1) {
        MPI_Isend(&greydata[local_height * width], width, MPI_FLOAT, rank + 1, 1, MPI_COMM_WORLD, &requests[2]);
        MPI_Irecv(&greydata[(local_height+1) * width], width, MPI_FLOAT, rank + 1, 0, MPI_COMM_WORLD, &requests[3]);
    }

    MPI_Waitall(4, requests, MPI_STATUSES_IGNORE);

    // Perform Sobel operator
    ImageF output(local_height * width);
    apply_sobel_operator(greydata, output, width, local_height);

    // Gather results
    ImageF final_result;
    if (rank == 0) final_result.resize(width * height);

    std::vector<int> recvcounts(num_processes);
    std::vector<int> displs(num_processes);
    if (rank == 0) {
        int current_disp = 0;
        for (int r = 0; r < num_processes; r++) {
            // Re-calculate the layout logic for other ranks
            int r_start = r * rows_per_process + std::min(r, remainder);
            int r_end = r_start + rows_per_process + (r < remainder ? 1 : 0);
            int r_height = r_end - r_start;

            recvcounts[r] = r_height * width;
            displs[r] = current_disp;
            current_disp += recvcounts[r];
        }
    }

    MPI_Gatherv(output.data(), local_height * width, MPI_FLOAT, final_result.data(), recvcounts.data(), displs.data(), MPI_FLOAT, 0, MPI_COMM_WORLD);

    // Save result
    if (rank == 0) {
        std::vector<uint8_t> normalized_output = normalize_image(final_result);
        if (!stbi_write_png(output_path, width, height, 1, normalized_output.data(), width)) {
            std::cerr << "Failed to write PNG: " << output_path << "\n";
            MPI_Abort(MPI_COMM_WORLD, 1);
            return 1;
        }
        else {
            std::cout << "Done! Saved to " << output_path << "\n";
        }
    }

    MPI_Finalize(); // Clean up MPI world
    return 0;
}
