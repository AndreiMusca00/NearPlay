//
//  Game.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

struct Game: Identifiable, Hashable {
    let id: String
    let title: String
    let minPlayers: Int
    let maxPlayers: Int
}

extension Game {
    static let ticTacToe = Game(id: "tic_tac_toe", title: "Tic Tac Toe", minPlayers: 2, maxPlayers: 2)
    static let all: [Game] = [ticTacToe]
}
