//
//  ConnectFourModes.swift
//  NearPlay
//

import Foundation

enum ConnectFourDifficulty: String, CaseIterable, Identifiable, Sendable {
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
            return "Blocks wins and plays smart"
        case .hard:
            return "Looks several moves ahead"
        }
    }
}
