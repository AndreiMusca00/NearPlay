//
//  ContentView.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(Game.all) { game in
                NavigationLink(value: game) {
                    VStack(alignment: .leading) {
                        Text(game.title).font(.headline)
                        Text("Players: \(game.minPlayers)-\(game.maxPlayers)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: Game.self) { game in
                GameLobbyView(game: game)
            }
            .navigationTitle("NearPlay")
        }
    }
}

#Preview {
    ContentView()
}
