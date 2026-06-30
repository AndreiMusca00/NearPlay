//
//  TicTacToeGame.swift
//  NearPlay
//
//  Created by Andrei Musca on 01/07/2026.
//

import Foundation

public enum TicTacToeMark: String, Codable, Equatable {
    case x
    case o
}

public struct TicTacToeGame: Codable, Equatable {
    public private(set) var board: [TicTacToeMark?]
    public private(set) var currentTurn: TicTacToeMark
    public private(set) var winner: TicTacToeMark?
    public private(set) var isDraw: Bool

    public init(startingTurn: TicTacToeMark = .x) {
        self.board = Array(repeating: nil, count: 9)
        self.currentTurn = startingTurn
        self.winner = nil
        self.isDraw = false
    }

    @discardableResult
    public mutating func makeMove(at index: Int, by mark: TicTacToeMark) -> Bool {
        // Validate move
        guard (0...8).contains(index) else { return false }
        guard board[index] == nil else { return false }
        guard winner == nil else { return false }
        guard isDraw == false else { return false }
        guard mark == currentTurn else { return false }

        // Apply move
        board[index] = mark

        // Update game state
        updateWinner()
        updateDraw()

        // Switch turn if game not over
        if winner == nil && !isDraw {
            currentTurn = (currentTurn == .x) ? .o : .x
        }

        return true
    }

    public mutating func reset(startingTurn: TicTacToeMark = .x) {
        board = Array(repeating: nil, count: 9)
        currentTurn = startingTurn
        winner = nil
        isDraw = false
    }

    private mutating func updateWinner() {
        let lines = [
            // Rows
            [0,1,2], [3,4,5], [6,7,8],
            // Columns
            [0,3,6], [1,4,7], [2,5,8],
            // Diagonals
            [0,4,8], [2,4,6]
        ]

        for line in lines {
            if let a = board[line[0]], let b = board[line[1]], let c = board[line[2]], a == b, b == c {
                winner = a
                return
            }
        }
    }

    private mutating func updateDraw() {
        if winner == nil {
            isDraw = board.allSatisfy { $0 != nil }
        } else {
            isDraw = false
        }
    }
}
