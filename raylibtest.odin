package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450
PIXEL_X_COUNT :: 20
PIXEL_Y_COUNT :: 20

POPULATED_RULESTRING:: 12
DEAD_RULESTRING :: 8

PixelGrid :: struct {
	pixels: [PIXEL_X_COUNT][PIXEL_Y_COUNT]Pixel
}

iteration: int = 0

Pixel :: struct {
	alive: bool,
	x: i32,
	y: i32
} 

main :: proc() {
	rl.InitWindow(
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		"My first Raylib program",
	)
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	pixel_grid := PixelGrid{pixels = [PIXEL_X_COUNT][PIXEL_Y_COUNT]Pixel{}}

	for x in 0..<PIXEL_X_COUNT {
		for y in 0..<PIXEL_Y_COUNT {
			pixel_grid.pixels[x][y] = Pixel{alive = false, x = i32(x), y = i32(y)}
		}
	}

	//manually set some pixels to alive for testing
	pixel_grid.pixels[5][5].alive = true
	pixel_grid.pixels[6][6].alive = true
	pixel_grid.pixels[7][6].alive = true
	pixel_grid.pixels[7][5].alive = true
	pixel_grid.pixels[7][4].alive = true

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()

		pixel_size: i32 = SCREEN_HEIGHT / PIXEL_Y_COUNT
		
		rl.ClearBackground(rl.LIGHTGRAY)
		
		display_origin_x := SCREEN_WIDTH / 2 - ((PIXEL_X_COUNT * pixel_size) / 2)
		display_origin_y := SCREEN_HEIGHT / 2 - ((PIXEL_Y_COUNT * pixel_size) / 2)

		for x in 0..<PIXEL_X_COUNT {
			for y in 0..<PIXEL_Y_COUNT {
				pixel := pixel_grid.pixels[x][y]
				if pixel.alive {
					rl.DrawRectangle(display_origin_x + i32(x) * pixel_size, display_origin_y + i32(y) * pixel_size, pixel_size, pixel_size, rl.RAYWHITE)
				} else {
					rl.DrawRectangle(display_origin_x + i32(x) * pixel_size, display_origin_y + i32(y) * pixel_size, pixel_size, pixel_size, rl.BLACK)
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
				pixel_grid.pixels[cell_clicked_x][cell_clicked_y].alive = !pixel_grid.pixels[cell_clicked_x][cell_clicked_y].alive
			}
		}

		if rl.GuiButton(rl.Rectangle{0, 0, 140, 40}, "Next iteration") {
            update_pixel_grid := iterate(pixel_grid)
			pixel_grid = update_pixel_grid
            iteration += 1
        }
		iteration_text := fmt.ctprintf("Iteration: %d", iteration)
		rl.DrawText(iteration_text, 5, 50, 20, rl.BLACK)
		rl.EndDrawing()
	}
}

iterate ::proc(pixel_grid:PixelGrid) -> PixelGrid{
new_pixel_grid := PixelGrid{pixels = [PIXEL_X_COUNT][PIXEL_Y_COUNT]Pixel{}}

		for x in 0..<PIXEL_X_COUNT {
			for y in 0..<PIXEL_Y_COUNT {
				pixel := pixel_grid.pixels[x][y]
				
				living_neighbors := 0
				for x2 in -1..=1 {
					for y2 in -1..=1 {

						if x2 == 0 && y2 == 0 {
							continue
						}

						neighbor_x := x + x2
						neighbor_y := y + y2
						
						if neighbor_x >= 0 && neighbor_x < PIXEL_X_COUNT && neighbor_y >= 0 && neighbor_y < PIXEL_Y_COUNT {
							neighbor_pixel := pixel_grid.pixels[neighbor_x][neighbor_y]
							if neighbor_pixel.alive {
								living_neighbors += 1
							}
						}
					}
				}
				
				rule_value := 0	
				if pixel.alive {
					rule_value = (POPULATED_RULESTRING >> uint(living_neighbors)) & 1
				} else {
					rule_value = (DEAD_RULESTRING >> uint(living_neighbors)) & 1
				}
				if rule_value == 1 {
					new_pixel_grid.pixels[x][y] = Pixel{alive = true, x = pixel.x, y = pixel.y}
				} else {
					new_pixel_grid.pixels[x][y] = Pixel{alive = false, x = pixel.x, y = pixel.y}
				}
			}
		}
return new_pixel_grid

}