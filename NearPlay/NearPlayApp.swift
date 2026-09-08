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
    @StateObject private var appUpdateManager = AppUpdateManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
                .environmentObject(nearbyPermissions)
                .environmentObject(appUpdateManager)
        }
    }
}
