//
//  NearPlayApp.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import SwiftUI

@main
struct NearPlayApp: App {
    @StateObject private var purchaseManager = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
        }
    }
}
