//
//  NearbyInvitation.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

struct NearbyInvitation: Identifiable, Equatable {
    let id: UUID
    let fromPeer: NearbyPeer
    let context: InvitationContext
    let receivedAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        fromPeer: NearbyPeer,
        context: InvitationContext,
        receivedAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.fromPeer = fromPeer
        self.context = context
        self.receivedAt = receivedAt
        self.expiresAt = expiresAt
    }
}

struct NearbyOutgoingInvitation: Identifiable, Equatable {
    let id: UUID
    let toPeer: NearbyPeer
    let context: InvitationContext
    let sentAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        toPeer: NearbyPeer,
        context: InvitationContext,
        sentAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.toPeer = toPeer
        self.context = context
        self.sentAt = sentAt
        self.expiresAt = expiresAt
    }
}

enum NearbyInvitationFeedbackKind: Equatable {
    case declined
}

/// Short-lived result shown to the player who sent the invitation.
struct NearbyInvitationFeedback: Identifiable, Equatable {
    let id: UUID
    let peer: NearbyPeer
    let kind: NearbyInvitationFeedbackKind
    let shownAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        peer: NearbyPeer,
        kind: NearbyInvitationFeedbackKind,
        shownAt: Date = Date(),
        expiresAt: Date
    ) {
        self.id = id
        self.peer = peer
        self.kind = kind
        self.shownAt = shownAt
        self.expiresAt = expiresAt
    }
}
