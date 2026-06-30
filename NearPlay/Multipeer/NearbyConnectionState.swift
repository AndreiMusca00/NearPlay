//
//  NearbyConnectionState.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

enum NearbyConnectionState: Equatable, Codable {
    case idle
    case searching
    case inviting
    case invited
    case connecting
    case connected
    case disconnected
    case failed(String)
}
