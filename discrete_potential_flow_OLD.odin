package main

import "core:fmt"
import rl "vendor:raylib"
import time "core:time"

SCREEN_WIDTH  :: 860
SCREEN_HEIGHT :: 480
PIXEL_X_COUNT :: 300
PIXEL_Y_COUNT :: 300

TICKS_PER_SECOND :: 1000.0
SUBTICKS_PER_TICK :: 5.0
TICK_INTERVAL    :: 1.0 / TICKS_PER_SECOND

NEIGHBOR_VECTORS := [4]Vector2{
	Vector2{-1.0, 0.0}, // left
	Vector2{1.0, 0.0},  // right
	Vector2{0.0, -1.0}, // up
	Vector2{0.0, 1.0},  // down
}


sim_data : [PIXEL_X_COUNT*PIXEL_Y_COUNT]float


PixelGrid :: struct {
	pixels: [PIXEL_X_COUNT][PIXEL_Y_COUNT]Pixel
}

iteration: int = 0

Pixel :: struct {
	solid: bool,
	x: i32,
	y: i32,
	potential: f32,
	boundary_condition: bool,
	color: rl.Color,
} 

Vector2 :: struct {
	x: f32,
	y: f32,
}




main :: proc() {
	rl.InitWindow(
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		"Jacobi Iteration Method for determining Velocity Potential scalar field from Laplace's equation",
	)
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)


	pixel_grid: ^PixelGrid = new(PixelGrid)
	new_pixel_grid: ^PixelGrid = new(PixelGrid)

	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			pixel_grid.pixels[x][y] = Pixel{solid = false, x = i32(x), y = i32(y), potential = 0.0, boundary_condition = false} // odin dereferences when you use .
		}
	}

	//set right boundary to 1.0
	for y in 0..<PIXEL_Y_COUNT {
		pixel_grid.pixels[PIXEL_X_COUNT-1][y].boundary_condition = true
		pixel_grid.pixels[PIXEL_X_COUNT-1][y].potential = 1.0
	}
	//set left boundary to 0.0
	for y in 0..<PIXEL_Y_COUNT {
		pixel_grid.pixels[0][y].boundary_condition = true
		pixel_grid.pixels[0][y].potential = 0.0
	}

	//set every column to gradient (free stream)
	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			pixel_grid.pixels[x][0].boundary_condition = true	
			pixel_grid.pixels[x][PIXEL_Y_COUNT-1].boundary_condition = true	
			pixel_grid.pixels[x][y].potential = f32(x) / f32(PIXEL_X_COUNT - 1)
		}
	}

	//centralized cylinder obstacle
	radius := 40
	center_x := PIXEL_X_COUNT / 2
	center_y := PIXEL_Y_COUNT / 2
	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			dx := x - center_x
			dy := y - center_y
			if dx*dx + dy*dy <= radius*radius {
				pixel_grid.pixels[x][y].solid = true
				pixel_grid.pixels[x][y].boundary_condition = false
			}
		}
	}

	//centralized square obstacle
	// obstacle_size := 50
	// center_x := PIXEL_X_COUNT / 2
	// center_y := PIXEL_Y_COUNT / 2
	// for x in (center_x - obstacle_size/2)..<(center_x + obstacle_size/2) {
	// 	for y in (center_y - obstacle_size/2)..<(center_y + obstacle_size/2) {
	// 		pixel_grid.pixels[x][y].solid = true
	// 		pixel_grid.pixels[x][y].boundary_condition = false
	// 	}
	// }


	tick_accumulator: f32 = 0.0
	simulation_running: bool = true
	image := rl.GenImageColor(PIXEL_X_COUNT, PIXEL_Y_COUNT, rl.BLANK)
	texture := rl.LoadTextureFromImage(image)
	

	pixel_size: i32 = SCREEN_HEIGHT / PIXEL_Y_COUNT

	origin_y := 0 
	origin_x := (SCREEN_WIDTH - SCREEN_HEIGHT) / 2

	for !rl.WindowShouldClose() {
		delta_time := rl.GetFrameTime()
		cycle_start := time.tick_now() 
		rl.BeginDrawing()
		
		rl.ClearBackground(rl.LIGHTGRAY)

		for x in 0..<PIXEL_X_COUNT {
			for y in 0..<PIXEL_Y_COUNT {
				pixel := &pixel_grid.pixels[x][y]
				if pixel.solid {
					pixel.color = rl.WHITE
				} else {
					hue := (1.0 - pixel.potential) * 240.0
					pixel.color = rl.ColorFromHSV(hue, 1.0, 1.0)
				}
				rl.ImageDrawPixel(&image, i32(x), i32(y), pixel.color)
			}
		}

		rl.UpdateTexture(texture, image.data)

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
		
		if simulation_running {
			tick_accumulator += delta_time
			if tick_accumulator >= TICK_INTERVAL {
				for subtick in 0..<SUBTICKS_PER_TICK {
					attempt_iter := iterate(pixel_grid,new_pixel_grid)
					if attempt_iter {
						pixel_grid, new_pixel_grid = new_pixel_grid, pixel_grid
						iteration += 1
						tick_accumulator -= TICK_INTERVAL / SUBTICKS_PER_TICK
					}
				}
			}
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			mouse := rl.GetMousePosition()

			mouse_x := i32(mouse[0])
			mouse_y := i32(mouse[1])

			cell_clicked_x := ((mouse_x - display_origin_x) / pixel_size)
			cell_clicked_y := ((mouse_y - display_origin_y) / pixel_size)

			if cell_clicked_x >= 0 && cell_clicked_x < PIXEL_X_COUNT && cell_clicked_y >= 0 && cell_clicked_y < PIXEL_Y_COUNT {
				pixel_grid.pixels[cell_clicked_x][cell_clicked_y].solid = !pixel_grid.pixels[cell_clicked_x][cell_clicked_y].solid
			}
		}	

		if rl.GuiButton(rl.Rectangle{0, 0, 140, 40}, "Next iteration") {
				attempt_iter := iterate(pixel_grid,new_pixel_grid)
				if attempt_iter {
					pixel_grid, new_pixel_grid = new_pixel_grid, pixel_grid
					iteration += 1
					tick_accumulator -= TICK_INTERVAL
				}
		}
		iteration_text := fmt.ctprintf("Iteration: %d", iteration)
		elapsed := time.tick_since(cycle_start)
		rl.DrawText(fmt.ctprintf("Cycle Duration: %.2f ms", time.duration_milliseconds(elapsed)), 5, 30, 20, rl.BLACK)
		rl.DrawText(iteration_text, 5, 50, 20, rl.BLACK)
		rl.EndDrawing()
		
	}
}

iterate :: proc(old_pixel_grid:^PixelGrid, new_pixel_grid: ^PixelGrid) -> bool{
	
	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			if old_pixel_grid.pixels[x][y].boundary_condition == true || old_pixel_grid.pixels[x][y].solid == true {
				new_pixel_grid.pixels[x][y] = old_pixel_grid.pixels[x][y]
				continue
			}else{
				
				//calculate average of neighbors
				sum:f32= 0.0
				count:f32= 0.0


				for neighbor in NEIGHBOR_VECTORS {
					neighbor_x := x + int(neighbor.x)
					neighbor_y := y + int(neighbor.y)

					if neighbor_x >= 0 && neighbor_x < PIXEL_X_COUNT && neighbor_y >= 0 && neighbor_y < PIXEL_Y_COUNT {

						if old_pixel_grid.pixels[neighbor_x][neighbor_y].solid == false {
							sum += old_pixel_grid.pixels[neighbor_x][neighbor_y].potential
							count += 1.0
						}
					}
				}

				new_pixel_grid.pixels[x][y].potential = sum / count
				new_pixel_grid.pixels[x][y].solid = false
				new_pixel_grid.pixels[x][y].x = old_pixel_grid.pixels[x][y].x
				new_pixel_grid.pixels[x][y].y = old_pixel_grid.pixels[x][y].y
			}
		}
	}
return true

}

