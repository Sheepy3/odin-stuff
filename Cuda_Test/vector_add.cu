#include <cuda_runtime.h>
#include <iostream>
#include <vector>



cudaError_t allocate_array(int** array,int length){ //has to be a pointer to the pointer, for some f!$&ing reason
    return cudaMalloc((void**)array, length*sizeof(int));
}

__global__ void vector_add(const int* A, const int* B, int* C, int length);

int main() {
    int deviceCount;
    
    cudaError_t error = cudaGetDeviceCount(&deviceCount);
    if (error != cudaSuccess) {
        std::cerr << "Error getting device count: " << cudaGetErrorString(error) << std::endl;
        return -1;
    }
    std::cout << "Number of CUDA devices: " << deviceCount << std::endl;
    
    const size_t arr_size = 400000000ULL;
    std::vector<int> A(arr_size);
    std::vector<int> B(arr_size);
    std::vector<int> C(arr_size);

    
    for (int i = 1; i < arr_size+1; i++) {
        A[i-1] = i;
        B[i-1] = i*10;
        C[i-1] = 0;
    }
    
    // std::cout << "A: ";
    // for (int i = 0; i < arr_size; i++){
    //     std::cout << A[i] << " ";
    // }
    // std::cout << std::endl;
    // std::cout << "B: ";
    // for (int i = 0; i < arr_size; i++){
    //     std::cout << B[i] << " ";
    // }
    // std::cout << std::endl;
    // std::cout << "C: ";
    // for (int i = 0; i < arr_size; i++){
    //     std::cout << C[i] << " ";
    // }
    // std::cout << std::endl;
    int *d_A, *d_B, *d_C;


    cudaError_t allocA = allocate_array(&d_A, arr_size);
    if (allocA != cudaSuccess) {
        std::cerr << "Error allocating memory for A: " << cudaGetErrorString(allocA) << std::endl;
        return -1;
    }else{
        std::cout << "Allocated memory for A successfully." << std::endl;
    }
    cudaError_t allocB = allocate_array(&d_B, arr_size);
    if (allocB != cudaSuccess) {
        std::cerr << "Error allocating memory for B: " << cudaGetErrorString(allocB) << std::endl;
        return -1;
    }else{
        std::cout << "Allocated memory for B successfully." << std::endl;
    }
    cudaError_t allocC = allocate_array(&d_C, arr_size);
    if (allocC != cudaSuccess) {
        std::cerr << "Error allocating memory for C: " << cudaGetErrorString(allocC) << std::endl;
        return -1;
    }else{
        std::cout << "Allocated memory for C successfully." << std::endl;
    }



    cudaError_t copyA = cudaMemcpy(d_A, A.data(), arr_size*sizeof(int),cudaMemcpyHostToDevice);
    cudaError_t copyB = cudaMemcpy(d_B, B.data(), arr_size*sizeof(int),cudaMemcpyHostToDevice);

    if (copyA != cudaSuccess) {
        std::cerr << "Error copying A: "
                << cudaGetErrorString(copyA) << std::endl;
        return -1;
    }else{
        std::cout << "Copied A to device successfully." << std::endl;
    }

    if (copyB != cudaSuccess) {
        std::cerr << "Error copying B: "
                << cudaGetErrorString(copyB) << std::endl;
        return -1;
    }else{
        std::cout << "Copied B to device successfully." << std::endl;
    }

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    vector_add<<<32, 64>>>(d_A, d_B, d_C, arr_size); // Launch kernel with 1 block and 16 threads
    cudaEventRecord(start);
    vector_add<<<32, 64>>>(d_A, d_B, d_C, arr_size); // Launch kernel with 1 block and 16 threads
    cudaError_t launch_error = cudaGetLastError();
    if (launch_error != cudaSuccess) {
        std::cerr << "Error launching kernel: "
                << cudaGetErrorString(launch_error) << std::endl;
        return -1;
    }
    cudaError_t synchronization = cudaDeviceSynchronize(); // Wait for the kernel to finish
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float miliseconds = 0.0f;
    cudaEventElapsedTime(&miliseconds, start, stop);
    std::cout << "Kernel execution time: " << miliseconds << " ms" << std::endl;
    cudaEventDestroy(start);
    cudaEventDestroy(stop);



    if (synchronization != cudaSuccess) {
        std::cerr << "Error during kernel execution: "
                << cudaGetErrorString(synchronization) << std::endl;
        return -1;
    }

    cudaError_t copyCBack = cudaMemcpy(C.data(), d_C, arr_size*sizeof(int),cudaMemcpyDeviceToHost);
    if (copyCBack != cudaSuccess) {
        std::cerr << "Error copying C back to host: "
                << cudaGetErrorString(copyCBack) << std::endl;
        return -1;
    }else{   
        std::cout << "Copied C back to host successfully." << std::endl;
    }    
    
    // std::cout << "C after addition: ";
    // for (int i = 0; i < arr_size; i++){
    //     std::cout << C[i] << " ";
    // }
    // std::cout << std::endl;

    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    


    return 0;
}

__global__ void vector_add(const int* A, const int* B, int* C, int length){
    size_t  index = (size_t)(blockIdx.x * blockDim.x) + threadIdx.x;
    if (index < length) {
        C[index] = A[index] + B[index];
    }
}

