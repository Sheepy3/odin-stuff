package main

import "core:fmt"

foreign import cuda_vector "cuda_vector.lib"

CALCULATION_SIZE :: 4000000

A : [CALCULATION_SIZE]i32
B : [CALCULATION_SIZE]i32
C : [CALCULATION_SIZE]i32


foreign cuda_vector {
    cuda_vector_add :: proc(
        A: ^i32,
        B: ^i32,
        C: ^i32,
        length: i32,
    ) -> i32 ---
}

main :: proc() {
    fmt.println("Started Odin")

    for i in 0..<CALCULATION_SIZE{
        A[i]= i32(i)
        B[i]= i32(i*10)
        C[i]= 0
    }

    fmt.println("Calling CUDA")

    result := cuda_vector_add(&A[0], &B[0], &C[0], CALCULATION_SIZE)

    fmt.println("Returned from CUDA")

    if result != 0{
    fmt.println("Error in CUDA vector addition: ", result)
    return
    }

    fmt.println(C[CALCULATION_SIZE-1])
    
}