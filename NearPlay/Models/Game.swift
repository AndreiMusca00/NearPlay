//
//  Game.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

enum GameBadge: String, Hashable {
    case new = "NEW"
    case updated = "UPDATED"
}

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

    // Marcaje editoriale folosite în lista principală.
    let badge: GameBadge?
    let isPopular: Bool
    let displayPriority: Int

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
        badge: GameBadge? = nil,
        isPopular: Bool = false,
        displayPriority: Int = 0,
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
        self.badge = badge
        self.isPopular = isPopular
        self.displayPriority = displayPriority
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
        productID: PurchaseCatalog.numberRush
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
    
    static let backgammon = Game(
        id: "backgammon",
        title: "Backgammon",
        shortDescription: "Race your checkers home and bear them off before your opponent.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_backgammon",
        fallbackSystemImage: "circle.grid.cross.fill",
        accentHex: "#D9A35F",
        supportedModes: [
            .nearby,
            .local,
            .computer
        ],
        isPopular: true,
        displayPriority: 80
    )

    static let dotsAndBoxes = Game(
        id: "dots_and_boxes",
        title: "Dots & Boxes",
        shortDescription: "Draw lines, close boxes, and control the board.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_dots_and_boxes",
        fallbackSystemImage: "square.grid.3x3.square",
        accentHex: "#20C7FF",
        supportedModes: [.nearby, .local, .computer],
        badge: .new,
        isPopular: true,
        displayPriority: 60,
        productID: PurchaseCatalog.dotsAndBoxes
    )

    static let ricochet = Game(
        id: "ricochet",
        title: "Ricochet",
        shortDescription: "Tilt, deflect, and send the pulse across two screens.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_ricochet",
        fallbackSystemImage: "bolt.shield.fill",
        accentHex: "#26E6F2",
        supportedModes: [.nearby],
        badge: .new,
        isPopular: true,
        displayPriority: 100,
        productID: PurchaseCatalog.ricochet
    )

    static let tiltRace = Game(
        id: "tilt_race",
        title: "Tilt Race",
        shortDescription: "Tilt your phone and race through every glowing gate.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_tilt_race",
        fallbackSystemImage: "circle.circle.fill",
        accentHex: "#9DFF2E",
        supportedModes: [.nearby],
        badge: .new,
        isPopular: true,
        displayPriority: 90,
        productID: PurchaseCatalog.tiltRace
    )

    static let laserDuel = Game(
        id: "laser_duel",
        title: "Laser Duel",
        shortDescription: "Tilt, fire, and dodge lasers crossing between two screens.",
        minPlayers: 2,
        maxPlayers: 2,
        imageName: "game_laser_duel",
        fallbackSystemImage: "scope",
        accentHex: "#FF365F",
        supportedModes: [.nearby],
        badge: .new,
        isPopular: true,
        displayPriority: 95,
        productID: PurchaseCatalog.laserDuel
    )

    static let all: [Game] = [
        ticTacToe,
        ricochet,
        tiltRace,
        laserDuel,
        dotsAndBoxes,
        backgammon,
        numberRush,
        battleship,
        connectFour
    ]

    static var purchasableProductIDs: [String] {
        Array(Set(all.compactMap(\.productID))).sorted()
    }
}
