#include <cuda_runtime.h>
#include <iostream>


__global__ void vector_add_kernel( //defines the kernel
    const int *A,
    const int *B,
    int *C,
    int length
){
    int index = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (index < length) {
        C[index] = A[index] + B[index];
    }
}

extern "C" __declspec(dllexport) //exports the function to C ABI
int cuda_vector_add(
    const int *A,
    const int *B,
    int *C,
    int length
);



int cuda_vector_add(
    const int *A,
    const int *B,
    int *C,
    int length
){
    int *d_A, *d_B, *d_C;
    size_t size = length * sizeof(int);

    cudaError_t Error_Array[11];

    Error_Array[0] = cudaMalloc((void**)&d_A, size);
    Error_Array[1] = cudaMalloc((void**)&d_B, size); 
    Error_Array[2] = cudaMalloc((void**)&d_C, size);

    Error_Array[3] = cudaMemcpy(d_A,A,size,cudaMemcpyHostToDevice);
    Error_Array[4] = cudaMemcpy(d_B,B,size,cudaMemcpyHostToDevice);

    const int threads_per_block = 64;
    int block_count = (length + threads_per_block - 1) / threads_per_block; //round up formula

    vector_add_kernel<<<block_count,threads_per_block>>>(d_A,d_B,d_C,length);
    Error_Array[5] = cudaGetLastError();
    Error_Array[6] = cudaDeviceSynchronize();
    Error_Array[7] = cudaMemcpy(C,d_C,size,cudaMemcpyDeviceToHost);
    Error_Array[8] = cudaFree(d_A);
    Error_Array[9] = cudaFree(d_B);
    Error_Array[10] = cudaFree(d_C);

    for(int i=0;i<11;i++){
        if(Error_Array[i] != cudaSuccess){
            std::cout<<"CUDA Error: "<<cudaGetErrorString(Error_Array[i])<<std::endl;
            return -1;
        }
    }
    return 0;
}

//compiled with:
// nvcc -arch=sm_86 --shared cuda_vector.cu -o cuda_vector.dll -Xlinker /IMPLIB:cuda_vector.lib