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
    @StateObject private var nearbyPermissions = NearbyPermissionsManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
                .environmentObject(nearbyPermissions)
        }
    }
}
