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

    // Modurile disponibile. Jocurile vechi rămân Nearby implicit.
    let supportedModes: Set<GamePlayMode>

    // nil = joc gratuit. Pentru un joc premium, pune aici exact Product ID-ul
    // configurat în StoreKit / App Store Connect.
    let productID: String?

    init(
        id: String,
        title: String,
        shortDescription: String,
        minPlayers: Int,
        maxPlayers: Int,
        imageName: String,
        fallbackSystemImage: String,
        accentHex: String,
        supportedModes: Set<GamePlayMode> = [.nearby],
        productID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.shortDescription = shortDescription
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.imageName = imageName
        self.fallbackSystemImage = fallbackSystemImage
        self.accentHex = accentHex
        self.supportedModes = supportedModes
        self.productID = productID
    }

    var isFree: Bool {
        productID == nil
    }

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
        accentHex: "#18C8FF",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ]
    )

    static let rockPaperScissors = Game(
        id: "rock_paper_scissors",
        title: "Rock Paper Scissors",
        shortDescription: "Choose your move and defeat your opponent.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_rock_paper_scissors",
        fallbackSystemImage: "hand.raised.fill",
        accentHex: "#914DFF",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ]
    )


    static let numberRush = Game(
        id: "number_rush",
        title: "Number Rush",
        shortDescription: "Find the numbers in order before time runs out.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_number_rush",
        fallbackSystemImage: "number.square.fill",
        accentHex: "#19B9FF",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ],
        productID: "com.nearplay.numberrush"
    )


    static let battleship = Game(
        id: "battleship",
        title: "Battleship",
        shortDescription: "Deploy your fleet and sink your opponent's ships.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_battleship",
        fallbackSystemImage: "ferry.fill",
        accentHex: "#11C7FF",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ]
    )



    static let connectFour = Game(
        id: "connect_four",
        title: "Connect Four",
        shortDescription: "Drop discs and connect four before your opponent.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_connect_four",
        fallbackSystemImage: "circle.grid.3x3.fill",
        accentHex: "#754DFF",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ]
    )

    static let all: [Game] = [
        ticTacToe,
        rockPaperScissors,
        numberRush,
        battleship,
        connectFour
    ]

    static var purchasableProductIDs: [String] {
        Array(Set(all.compactMap(\.productID))).sorted()
    }
}
