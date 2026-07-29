//
//  RPSGame.swift
//  NearPlay
//
//  Created by Andrei Musca on 29/07/2026.
//

import Foundation

enum RPSChoice: String, Codable, CaseIterable, Identifiable {
    case rock
    case paper
    case scissors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rock: return "Rock"
        case .paper: return "Paper"
        case .scissors: return "Scissors"
        }
    }

    var emoji: String {
        switch self {
        case .rock: return "🪨"
        case .paper: return "📄"
        case .scissors: return "✂️"
        }
    }
}

enum RPSRoundResult: String, Codable {
    case waiting
    case draw
    case localWin
    case remoteWin
}

struct RPSGame: Codable, Equatable {
    var localChoice: RPSChoice?
    var remoteChoice: RPSChoice?
    var result: RPSRoundResult = .waiting

    var isRoundComplete: Bool {
        localChoice != nil && remoteChoice != nil
    }

    mutating func setLocalChoice(_ choice: RPSChoice) {
        guard localChoice == nil else { return }
        localChoice = choice
        updateResultIfNeeded()
    }

    mutating func setRemoteChoice(_ choice: RPSChoice) {
        guard remoteChoice == nil else { return }
        remoteChoice = choice
        updateResultIfNeeded()
    }

    mutating func reset() {
        localChoice = nil
        remoteChoice = nil
        result = .waiting
    }

    private mutating func updateResultIfNeeded() {
        guard let localChoice, let remoteChoice else {
            result = .waiting
            return
        }

        if localChoice == remoteChoice {
            result = .draw
            return
        }

        switch (localChoice, remoteChoice) {
        case (.rock, .scissors),
             (.paper, .rock),
             (.scissors, .paper):
            result = .localWin

        default:
            result = .remoteWin
        }
    }
}
