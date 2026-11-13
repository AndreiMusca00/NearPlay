#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/nearplay-player-names.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$repo_dir"
xcrun --sdk macosx swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path "$build_dir/module-cache" \
    NearPlay/Data/PlayerProfile.swift \
    NearPlay/Nearby/NearPlay/NearbyPeer.swift \
    NearPlay/Nearby/NearPlay/NearbyService.swift \
    NearPlay/Nearby/NearPlay/NearbyInvitation.swift \
    NearPlay/Nearby/NearPlay/NearbyConnectionState.swift \
    NearPlay/Nearby/NearPlay/NearbyMessage.swift \
    NearPlay/Nearby/NearPlay/LobbySessionModels.swift \
    NearPlay/Nearby/Transport/NearbyTransport.swift \
    Tests/PlayerNames/PlayerNamesChecks.swift \
    -o "$build_dir/checks"
"$build_dir/checks"
