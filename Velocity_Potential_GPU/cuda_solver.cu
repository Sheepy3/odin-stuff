#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <iostream>

struct Simulation {
    float   *d_Velo_Potential_Data;
    uint8_t *d_Solid_Data;
    uchar4 *d_Pixels;
    uchar4 *d_Palette;
    cudaGraphicsResource* display_texture_resource; // the visualization texture
    int length;
    int width;
    int height;
};

__global__ void iteration_kernel( //defines the kernel. cannot pass sim into this as sim is a cpu struct.
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    int length,
    int width,
    int height,
    uint8_t red
);

__global__ void pixel_color_kernel(
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    uchar4 *Pixels,
    uchar4 *Palette,
    int length,
    int width,
    int height
);

__device__ int index_from_coords(int x, int y, int width);
__device__ uchar4 rgb_from_potential(float potential, uchar4 *palette);

/* ABI DEFINITION*/
extern "C" __declspec(dllexport) //exports the function to C ABI
Simulation* cuda_allocate_mem(
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    unsigned int texture_id,
    uchar4 *pallette,
    int width,
    int height
);

extern "C" __declspec(dllexport)
int cuda_iterate(
    float *Velo_Potential_Data,
    Simulation *sim,
    int iterations
);

extern "C" __declspec(dllexport)
int cuda_free_data(Simulation *sim);
/* ABI DEFINITION */


int check_cuda_error(cudaError_t error, const char *what){ // what is a pointer to the first char in the string, which you can do apparently
    if(error != cudaSuccess){
        std::cerr << what << ": " << cudaGetErrorString(error) << std::endl;
        return -1;
    }
    return 0;
}

Simulation* cuda_allocate_mem(
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    unsigned int texture_id,
    uchar4 *pallette,
    int width,
    int height
){
    int length = width * height;
    size_t velo_size = length * sizeof(float);  // SIZE MEANS ARRAY SIZE IN BYTES!!!
    size_t solid_size = length * sizeof(uint8_t);
    Simulation *sim = new Simulation{};
    sim->length = length;

    if (check_cuda_error(cudaMalloc((void**)&sim->d_Velo_Potential_Data, velo_size), "cudaMalloc d_Velo_Potential_Data")) { //&sim->d_Velo_Potential_Data uses the d_Velo_Potential_Data pointer for the malloc
        return nullptr; //allows odin to see if initialized correctly
    }
    if (check_cuda_error(cudaMalloc((void**)&sim->d_Solid_Data, solid_size), "cudaMalloc d_Solid_Data")) {
        cudaFree(sim->d_Velo_Potential_Data);
        return nullptr;
    }
    if (check_cuda_error(cudaMalloc((void**)&sim->d_Palette, 512*sizeof(uchar4)), "cudaMalloc d_pixels")) {
        cudaFree(sim->d_Velo_Potential_Data);
        cudaFree(sim->d_Solid_Data);
        return nullptr;
    }
   
    if (check_cuda_error(cudaMemcpy(sim->d_Velo_Potential_Data,Velo_Potential_Data,velo_size,cudaMemcpyHostToDevice), "cudaMemcpy d_Velo_Potential_Data")) {
        cudaFree(sim->d_Velo_Potential_Data);
        cudaFree(sim->d_Solid_Data);
        cudaFree(sim->d_Palette);
        return nullptr;
    }
    if (check_cuda_error(cudaMemcpy(sim->d_Solid_Data,Solid_Data,solid_size,cudaMemcpyHostToDevice), "cudaMemcpy d_Solid_Data")) {
        cudaFree(sim->d_Velo_Potential_Data);
        cudaFree(sim->d_Solid_Data);
        cudaFree(sim->d_Palette);
        return nullptr;
    }
    if (check_cuda_error(cudaMemcpy(sim->d_Palette,pallette,512*sizeof(uchar4),cudaMemcpyHostToDevice), "cudaMemcpy d_palette")) {
        cudaFree(sim->d_Velo_Potential_Data);
        cudaFree(sim->d_Solid_Data);
        cudaFree(sim->d_Palette);
        return nullptr;
    }

    if (check_cuda_error(cudaGraphicsGLRegisterImage(&sim->display_texture_resource, texture_id, GL_TEXTURE_2D, cudaGraphicsRegisterFlagsWriteDiscard), "cudaGraphicsGLRegisterImage")) {
        cudaFree(sim->d_Velo_Potential_Data);
        cudaFree(sim->d_Solid_Data);
        cudaFree(sim->d_Palette);
        return nullptr;
    }

    sim->length = length;
    sim->width = width;
    sim->height = height;
    return sim;
}


int cuda_iterate(
    float *Velo_Potential_Data,
    Simulation *sim,
    int iterations
){
    //const int threads_per_block = 64;
    dim3 threads_per_block(16, 16);
    dim3 block_count(
    (sim->width  + 15) / 16,
    (sim->height + 15) / 16
    );
    //int block_count = (length + threads_per_block - 1) / threads_per_block; //round up formula
    
    float *d_Velo_Potential_Data = sim->d_Velo_Potential_Data;
    uint8_t *d_Solid_Data = sim->d_Solid_Data;
    int length = sim->length;
    size_t velo_size = sim->length * sizeof(float);
    uchar4 *d_Palette = sim->d_Palette;
    uchar4 *d_Pixels = sim->d_Pixels;
    
    for (int i =0; i<iterations; i++){
        iteration_kernel<<<block_count,threads_per_block>>>(d_Velo_Potential_Data,d_Solid_Data,length,sim->width,sim->height,0);
        iteration_kernel<<<block_count,threads_per_block>>>(d_Velo_Potential_Data,d_Solid_Data,length,sim->width,sim->height,1);
    }

    if (check_cuda_error(cudaGetLastError(), "cudaGetLastError")) {
        return -1;
    }
    
    pixel_color_kernel<<<block_count,threads_per_block>>>(d_Velo_Potential_Data,d_Solid_Data,d_Pixels,d_Palette,length,sim->width,sim->height);

    if (check_cuda_error(cudaGetLastError(), "cudaGetLastError")) {
        return -1;
    }

    if (check_cuda_error(cudaDeviceSynchronize(), "cudaDeviceSynchronize")) {
        return -1;
    }

    if (check_cuda_error(cudaMemcpy(Velo_Potential_Data,d_Velo_Potential_Data,velo_size,cudaMemcpyDeviceToHost), "cudaMemcpy Velo_Potential_Data")) {
        return -1;
    }

    return 0;
}

int cuda_free_data(
    Simulation *sim
){
    if (!sim) {
        return -1;
    }
    if (check_cuda_error(cudaFree(sim->d_Velo_Potential_Data), "cudaFree d_Velo_Potential_Data")) {
        return -1;
    }
    if (check_cuda_error(cudaFree(sim->d_Solid_Data), "cudaFree d_Solid_Data")) {
        return -1;
    }
    if (check_cuda_error(cudaFree(sim->d_Pixels), "cudaFree d_pixels")) {
        return -1;
    }
    if (check_cuda_error(cudaFree(sim->d_Palette), "cudaFree d_palette")) {
        return -1;
    }
    delete sim;
    return 0;
}

__global__ void iteration_kernel( //defines the kernel
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    int length,
    int width,
    int height,
    uint8_t red
)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) {
        return;
    }

    int index = index_from_coords(x,y,width);
    if (index < 0 || index >= length) {
        return;
    }
    
    if (Solid_Data[index] == 1) {
    return;
    }
    
    //determine boundary cells
    if (red == 1 && (x + y) % 2 == 0){ // we're doing red
        return;
    }else if (red == 0 && ( (x + y) % 2 == 1)){ // we're doing black
        return;
    }

    if ((index < width) || (index >= length - width) || (index % width == 0) || (index % width == width - 1)) {
        return;
    } //dont modify boundaries

    int stencil[4];
    stencil[0] = index_from_coords(x+1,y,width);
    stencil[1] = index_from_coords(x-1,y,width);
    stencil[2] = index_from_coords(x,y+1,width);
    stencil[3] = index_from_coords(x,y-1,width);

    float sum = 0.0f;
    int count = 0;
    for (int i = 0; i<4; i++){
        if (Solid_Data[stencil[i]] == 1){
            continue;
        }
        sum += Velo_Potential_Data[stencil[i]];
        count +=1;
    }
    Velo_Potential_Data[index] = sum / count;
}

__global__ void pixel_color_kernel(
    float *Velo_Potential_Data,
    const uint8_t *Solid_Data,
    uchar4 *Pixels,
    uchar4 *Palette,
    int length,
    int width,
    int height
)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) {
        return;
    }

    int index = index_from_coords(x,y,width);
    if (index < 0 || index >= length) {
        return;
    }

    if (Solid_Data[index] == 1) {
        Pixels[index] = uchar4{255, 255, 255, 255}; // white for solid cells
        return;
    }
    Pixels[index] = rgb_from_potential(Velo_Potential_Data[index], Palette);
}

__device__ int index_from_coords(int x, int y, int width){
    return y * width + x;
}

__device__ uchar4 rgb_from_potential(float potential, uchar4 *palette){
    int palette_index = static_cast<int>(potential*511.0);
    return palette[palette_index];
}

//compiled with:
// nvcc -arch=sm_86 --shared cuda_solver.cu -o cuda_solver.dll -Xlinker /IMPLIB:cuda_solver.lib
