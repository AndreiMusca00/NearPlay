//
//  AppUpdateManager.swift
//  NearPlay
//
//  Created by Andrei Musca on 08/09/2026.
//

import Foundation
import Combine
import UIKit

@MainActor
final class AppUpdateManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var latestVersion: String?
    @Published private(set) var appStoreURL: URL?
    @Published private(set) var isCheckingForUpdate = false
    @Published var isUpdateAlertPresented = false

    // MARK: - Private state

    private var hasCheckedThisLaunch = false

    // MARK: - Current app version

    var currentVersion: String {
        Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String ?? "0"
    }

    // MARK: - Public API

    /// Checks the public App Store version once per app launch.
    ///
    /// If there is no internet connection or the lookup fails,
    /// NearPlay simply continues normally.
    func checkForUpdate(force: Bool = false) async {

        guard force || !hasCheckedThisLaunch else {
            return
        }

        hasCheckedThisLaunch = true
        isCheckingForUpdate = true

        defer {
            isCheckingForUpdate = false
        }

        guard
            let bundleIdentifier = Bundle.main.bundleIdentifier,
            let lookupURL = makeLookupURL(
                bundleIdentifier: bundleIdentifier
            )
        else {
            return
        }

        do {
            var request = URLRequest(
                url: lookupURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 8
            )

            request.setValue(
                "no-cache",
                forHTTPHeaderField: "Cache-Control"
            )

            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

            let session = URLSession(configuration: configuration)

            let (data, response) = try await session.data(for: request)

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                return
            }

            let lookupResponse = try JSONDecoder().decode(
                AppStoreLookupResponse.self,
                from: data
            )

            guard let app = lookupResponse.results.first else {
                return
            }

            latestVersion = app.version

            if let urlString = app.trackViewUrl {
                appStoreURL = URL(string: urlString)
            }

            if isVersion(
                app.version,
                newerThan: currentVersion
            ) {
                isUpdateAlertPresented = true
            }

        } catch {
            // NearPlay is designed to work offline.
            // Update-check failures should never interrupt the user.
            return
        }
    }

    /// Opens NearPlay's public App Store page.
    func openAppStore() {
        guard let appStoreURL else {
            return
        }

        UIApplication.shared.open(appStoreURL)
    }

    /// Call this from the "Later" action.
    func dismissUpdateAlert() {
        isUpdateAlertPresented = false
    }

    // MARK: - App Store lookup

    private func makeLookupURL(
        bundleIdentifier: String
    ) -> URL? {

        var components = URLComponents(
            string: "https://itunes.apple.com/lookup"
        )

        var queryItems = [
            URLQueryItem(
                name: "bundleId",
                value: bundleIdentifier
            )
        ]

        if let regionCode = Locale.current.region?.identifier.lowercased() {
            queryItems.append(
                URLQueryItem(
                    name: "country",
                    value: regionCode
                )
            )
        }

        components?.queryItems = queryItems

        return components?.url
    }

    // MARK: - Version comparison

    private func isVersion(
        _ candidate: String,
        newerThan installed: String
    ) -> Bool {

        candidate.compare(
            installed,
            options: .numeric
        ) == .orderedDescending
    }
}

// MARK: - App Store response models

private struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    let version: String
    let trackViewUrl: String?
}
