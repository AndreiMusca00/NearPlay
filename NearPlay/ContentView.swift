//
//  ContentView.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        OfflineGamesRootView()
            .withPlayerNameStorage()
    }
}

#Preview {
    OfflineGamesRootView()
        .withPlayerNameStorage()
}

