//
//  TicTacToePayloads.swift
//  NearPlay
//
//  Created by Andrei Musca on 01/07/2026.
//

import Foundation

// Payloads used with NearbyMessage for Tic-Tac-Toe
public struct TicTacToeStartPayload: Codable, Equatable {
    public let xPlayerName: String
    public let oPlayerName: String

    public init(xPlayerName: String, oPlayerName: String) {
        self.xPlayerName = xPlayerName
        self.oPlayerName = oPlayerName
    }
}

public struct TicTacToeMovePayload: Codable, Equatable {
    public let index: Int
    public let mark: TicTacToeMark

    public init(index: Int, mark: TicTacToeMark) {
        self.index = index
        self.mark = mark
    }
}

public struct TicTacToeResetPayload: Codable, Equatable {
    public let requestedBy: String

    public init(requestedBy: String) {
        self.requestedBy = requestedBy
    }
}
public struct TicTacToePlayAgainPayload: Codable, Equatable {
    public let requestedBy: String

    public init(requestedBy: String) {
        self.requestedBy = requestedBy
    }
}

