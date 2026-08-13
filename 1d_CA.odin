package main

import "core:fmt"

BOARD_WIDTH :: 200

Board :: struct {
    iterations: int,
    board_array: [BOARD_WIDTH]BoardCell,
    rule: int,
}

BoardCell :: struct {
    alive: bool,
}

BOARD :: Board{
    iterations = 100,
    board_array = [BOARD_WIDTH]BoardCell{},
    rule = 30,
}

main :: proc() {
    
    previous_board := initialize()
    render(previous_board.board_array)
    
    for i in 1..<BOARD.iterations {
        //fmt.printf("Iteration %d:\n", i)
        next_board := step(previous_board)
        render(next_board.board_array)
        previous_board = next_board
    }
}

initialize :: proc() -> Board {
    board := Board{iterations= BOARD.iterations, board_array= [BOARD_WIDTH]BoardCell{}, rule= BOARD.rule}

    initial_board_array : [BOARD_WIDTH]BoardCell

    for i in 0..<BOARD_WIDTH {
        initial_board_array[i] = BoardCell{alive = false}
    }

    // manually set initial conditions
    initial_board_array[BOARD_WIDTH/2] = BoardCell{alive = true}
    
    
    board.board_array = initial_board_array
    return board
}

step :: proc(board: Board) -> Board {
    previous_board := board.board_array

    new_board_array : [BOARD_WIDTH]BoardCell

    for i in 0..<BOARD_WIDTH {
        left := false
        center := false
        right := false
        if i == 0{
            left = false
            center = previous_board[i].alive
            right = previous_board[i+1].alive
        }
        else if i == BOARD_WIDTH-1{
            left = previous_board[i-1].alive
            center = previous_board[i].alive
            right = false
        }
        else {
            left = previous_board[i-1].alive
            center = previous_board[i].alive
            right = previous_board[i+1].alive
        }

            value := int(left)<<2 | int(center)<<1 | int(right)
            rule_value := (board.rule >> uint(value)) & 1
            if rule_value == 1 {
                new_board_array[i] = BoardCell{alive = true}
            } else {
                new_board_array[i] = BoardCell{alive = false}
            }
    }
    return Board{iterations = board.iterations, board_array = new_board_array, rule = board.rule}
}

render :: proc(board_array: [BOARD_WIDTH]BoardCell) {
    for i in 0..<BOARD_WIDTH {
        if board_array[i].alive {
            fmt.printf("█")
        } else {
            fmt.printf("░")
        }
    }
    fmt.printf("\n")
}