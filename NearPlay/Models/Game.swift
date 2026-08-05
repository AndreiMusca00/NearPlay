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
    let shortDescription: String

    let minPlayers: Int
    let maxPlayers: Int

    // Numele imaginii din Assets.xcassets
    let imageName: String

    // SF Symbol folosit dacă imaginea nu există încă
    let fallbackSystemImage: String

    // Culoarea specifică jocului
    let accentHex: String

    var playerCountText: String {
        if minPlayers == maxPlayers {
            return minPlayers == 1
                ? "1 player"
                : "\(minPlayers) players"
        }

        return "\(minPlayers)–\(maxPlayers) players"
    }
}

// MARK: - Available games

extension Game {
    static let ticTacToe = Game(
        id: "tic_tac_toe",
        title: "Tic Tac Toe",
        shortDescription: "The classic game of Xs and Os.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_tic_tac_toe",
        fallbackSystemImage: "grid",
        accentHex: "#18C8FF"
    )

    static let rockPaperScissors = Game(
        id: "rock_paper_scissors",
        title: "Rock Paper Scissors",
        shortDescription: "Choose your move and defeat your opponent.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_rock_paper_scissors",
        fallbackSystemImage: "hand.raised.fill",
        accentHex: "#914DFF"
    )


    static let numberRush = Game(
        id: "number_rush",
        title: "Number Rush",
        shortDescription: "Find the numbers in order before time runs out.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_number_rush",
        fallbackSystemImage: "number.square.fill",
        accentHex: "#19B9FF"
    )


    static let battleship = Game(
        id: "battleship",
        title: "Battleship",
        shortDescription: "Deploy your fleet and sink your opponent's ships.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_battleship",
        fallbackSystemImage: "ferry.fill",
        accentHex: "#11C7FF"
    )

    static let all: [Game] = [
        ticTacToe,
        rockPaperScissors,
        numberRush,
        battleship
    ]
}
