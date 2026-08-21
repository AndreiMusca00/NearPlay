//
//  ContentView.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showMainContent = false
    @State private var didStartLaunchSequence = false

    var body: some View {
        ZStack {
            Color(
                red: 11.0 / 255.0,
                green: 15.0 / 255.0,
                blue: 21.0 / 255.0
            )
            .ignoresSafeArea()

            if showMainContent {
                GamesListView()
                    .withPlayerNameStorage()
                    .transition(.opacity)
            } else {
                NearPlayLoadingView()
                    .transition(.opacity)
            }
        }
        .task {
            guard !didStartLaunchSequence else { return }
            didStartLaunchSequence = true

            // Keep the branding animation visible long enough to feel intentional,
            // while StoreKit checks existing purchases in parallel.
            let minimumAnimation = Task {
                try? await Task.sleep(nanoseconds: 950_000_000)
            }

            await purchaseManager.waitForInitialStorePreparation()
            await minimumAnimation.value

            withAnimation(.easeInOut(duration: 0.32)) {
                showMainContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager())
}
