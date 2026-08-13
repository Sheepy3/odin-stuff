package main

import "core:fmt"
import rl "vendor:raylib"
import time "core:time"
import "core:mem"
import "core:slice" // Required for slice.clone

foreign import cuda_solver "cuda_solver.lib"

SIM_STAGE :: enum {
	Iterate,
	Velocity,
	Display
}

Vec2 :: struct{
	x: f32,
	y: f32
}

SCREEN_WIDTH  :: 860
SCREEN_HEIGHT :: 480
PIXEL_X_COUNT :: 1000
PIXEL_Y_COUNT :: 1000
ITERATIONS_PER_FRAME :: 1000



Velo_Potential_Data : [PIXEL_X_COUNT*PIXEL_Y_COUNT]f32
Old_Potential_Data : [PIXEL_X_COUNT*PIXEL_Y_COUNT]f32
Solid_Data : [PIXEL_X_COUNT*PIXEL_Y_COUNT]u8


foreign cuda_solver {
    cuda_allocate_mem :: proc(
		Velo_Potential_Data: ^f32,
		Solid_Data: ^u8,
		Texture_id: u32,
		Palette: ^[4]u8,
        width: i32,
		height: i32
    ) -> rawptr --- //odin never touches the sim struct, so we can just pass its pointer around without caring about its internals

	cuda_iterate :: proc(
		Velo_Potential_Data: ^f32,
		sim: rawptr,
		iterations: i32		
	) -> i32 ---

	cuda_free_data :: proc(
		sim: rawptr
	) -> i32 --- 
}

main :: proc() {
	rl.InitWindow(
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		"Red-Black Gauss-Seidel Method for determining Velocity Potential scalar field from Laplace's equation",
	)
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	//set every column to gradient (free stream)
	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			set_velocity_potential(x, y, f32(x) / f32(PIXEL_X_COUNT - 1))
		}
	}

	//cylinder obstacle (to left)
	radius := 200
	center_x := (PIXEL_X_COUNT / 2)
	center_y := PIXEL_Y_COUNT / 2
	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			dx := x - center_x
			dy := y - center_y
			if dx*dx + dy*dy <= radius*radius {
				set_velocity_potential(x, y, 0.0)
				set_solid(x,y)
			}
		}
	}

	// //centralized square obstacle
	// obstacle_size := 400
	// center_x2 := (PIXEL_X_COUNT / 2) - 100
	// center_y2 := PIXEL_Y_COUNT / 2
	// for x2 in (center_x2 - obstacle_size/2)..<(center_x2 + obstacle_size/2) {
	// 	for y2 in (center_y2 - obstacle_size/2)..<(center_y2 + obstacle_size/2) {
	// 		set_velocity_potential(x2,y2,0.0)
	// 		set_solid(x2,y2)
	// 	}
	// }

	image := rl.GenImageColor(PIXEL_X_COUNT, PIXEL_Y_COUNT, rl.BLANK)
	texture := rl.LoadTextureFromImage(image)
	texture_id := texture.id

	pixel_size: i32 = SCREEN_HEIGHT / PIXEL_Y_COUNT

	origin_y := 0 
	origin_x := (SCREEN_WIDTH - SCREEN_HEIGHT) / 2

	//build 512 color pallete to match behavior of:
	//hue := (1.0 - Velo_Potential_Data[i]) * 240.0
	//img_pixels[i] = rl.ColorFromHSV(hue, 1.0, 1.0)
	palette: [512][4]u8

	for i in 0..<512 {
		hue:= (1.0 - f32(i)/511.0) * 240.0
		color := rl.ColorFromHSV(hue, 1.0, 1.0)
		palette[i][0] = color.r
		palette[i][1] = color.g
		palette[i][2] = color.b
		palette[i][3] = 255
	}

	sim:rawptr = cuda_allocate_mem(
		&Velo_Potential_Data[0],
		&Solid_Data[0],
		texture_id,
		&palette[0],
		PIXEL_X_COUNT,
		PIXEL_Y_COUNT,
	)
	if sim == nil {
		fmt.println("Failed to allocate CUDA memory.")
		return
	}
	
	iterations:int = 0
	stage := SIM_STAGE.Iterate
	sim_start_time := time.tick_now()
	for !rl.WindowShouldClose() { 
		
		rl.BeginDrawing()
		rl.ClearBackground(rl.LIGHTGRAY)
		
		if(stage == SIM_STAGE.Iterate){
		
			Old_Potential_Data = Velo_Potential_Data
			result := cuda_iterate(
				&Velo_Potential_Data[0],
				sim,
				ITERATIONS_PER_FRAME,
			)
			
			if result != 0 {
				fmt.println("cuda_iterate failed:", result)
				break
			}

			residual := find_residual(Old_Potential_Data, Velo_Potential_Data, PIXEL_X_COUNT*PIXEL_Y_COUNT)
			if (residual < 1e-10){
				stage = SIM_STAGE.Velocity
				elapsed_time := time.tick_since(sim_start_time)
				fmt.printf("Converged after %d iterations in %.2f seconds.", iterations, elapsed_time)

			}

			/* rendering */
			// img_pixels := mem.slice_ptr((^rl.Color)(image.data), len(Velo_Potential_Data))

			// if(stage != SIM_STAGE.Display){
			// 	for i in 0..<len(Velo_Potential_Data) {
			// 		if Solid_Data[i] == 1{
			// 			img_pixels[i] = rl.WHITE
			// 		}else{
			// 			hue := (1.0 - Velo_Potential_Data[i]) * 240.0
			// 			img_pixels[i] = rl.ColorFromHSV(hue, 1.0, 1.0)
			// 		}
			// 	}
			// }

			//rl.UpdateTexture(texture, image.data)

			iterations += ITERATIONS_PER_FRAME
			
		} else if(stage == SIM_STAGE.Velocity){
		
		
		}
		else if(stage == SIM_STAGE.Display){
			//do nothing, just display the results
		}


        source := rl.Rectangle{
            x      = 0,
            y      = 0,
            width  = f32(PIXEL_X_COUNT),
            height = f32(PIXEL_Y_COUNT),
        }

        destination := rl.Rectangle{
            x      = f32(origin_x),
            y      = f32(origin_y),
            width  = f32(SCREEN_HEIGHT) * f32(PIXEL_X_COUNT) / f32(PIXEL_Y_COUNT),
            height = f32(SCREEN_HEIGHT),
        }

		rl.DrawTexturePro(
			texture,
			source,
			destination,
			[2]f32{0.0, 0.0},
			0.0,
			rl.WHITE
		)
		
		frame_time:= rl.GetFrameTime()
		
		iteration_text := fmt.ctprintf("Iteration: %d", iterations)
		frametime_text := fmt.ctprintf("Frame Time: %d", i32(frame_time*1000.0))
		rl.DrawText(iteration_text, 5, 50, 20, rl.BLACK)
		rl.DrawText(frametime_text, 5, 70, 20, rl.BLACK)
		rl.EndDrawing()
		
	}
	cuda_free_data(sim)
}

// iterate :: proc(old_pixel_grid:^PixelGrid, new_pixel_grid: ^PixelGrid) -> bool{

// return true

// }

set_velocity_potential :: proc(x:int, y:int, potential: f32) {
	Velo_Potential_Data[y*PIXEL_X_COUNT + x] = potential
}

set_solid :: proc(x:int, y:int) {
	Solid_Data[y*PIXEL_X_COUNT + x] = 1
}

find_residual :: proc(Old: [PIXEL_X_COUNT*PIXEL_Y_COUNT]f32, New: [PIXEL_X_COUNT*PIXEL_Y_COUNT]f32, length:int) -> f32{
	residual:f32= 0
	for i in 0..<length {
		diff := Old[i] - New[i]
		residual += diff * diff //prevents negative and positive differences from cancelling out 
	}
	return residual/f32(length)
}

find_velocity_field :: proc(){
	fmt.println("WIP")
}



