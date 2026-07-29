//
//  RPSPayloads.swift
//  NearPlay
//
//  Created by Andrei Musca on 29/07/2026.
//

import Foundation

struct RPSStartPayload: Codable, Equatable {
    let playerOneName: String
    let playerTwoName: String
}

struct RPSChoicePayload: Codable, Equatable {
    let playerName: String
    let choice: RPSChoice
}

struct RPSPlayAgainPayload: Codable, Equatable {
    let requestedBy: String
}
