//
//  GamePlayMode.swift
//  NearPlay
//

import Foundation

enum GamePlayMode:
    String,
    Codable,
    Hashable,
    CaseIterable,
    Identifiable {

    case nearby
    case local
    case computer

    var id: String {
        rawValue
    }
}

enum GameAIDifficulty:
    String,
    Codable,
    Hashable,
    CaseIterable,
    Identifiable {

    case easy
    case medium
    case hard

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .easy:
            return "Easy"
        case .medium:
            return "Medium"
        case .hard:
            return "Hard"
        }
    }

    var subtitle: String {
        switch self {
        case .easy:
            return "Relaxed and unpredictable"
        case .medium:
            return "Balanced and competitive"
        case .hard:
            return "A tougher challenge"
        }
    }
}
