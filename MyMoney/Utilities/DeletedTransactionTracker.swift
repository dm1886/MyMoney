//
//  DeletedTransactionTracker.swift
//  MyMoney
//
//  Tracks deleted transaction IDs to prevent UI crashes when SwiftData
//  hasn't fully propagated the deletion yet.
//

import Foundation
import SwiftUI
import Combine
/// Singleton that tracks recently deleted transaction IDs.
/// Views should check this before accessing transaction properties.
@MainActor
class DeletedTransactionTracker: ObservableObject {
    static let shared = DeletedTransactionTracker()

    @Published private(set) var deletedIds: Set<UUID> = []

    private init() {}

    /// Mark a transaction as deleted. Call this BEFORE actually deleting.
    func markAsDeleted(_ id: UUID) {
        print("🚫 [TRACKER] Marking transaction as deleted: \(id)")
        deletedIds.insert(id)
    }

    /// Mark multiple transactions as deleted.
    func markAsDeleted(_ ids: [UUID]) {
        for id in ids {
            print("🚫 [TRACKER] Marking transaction as deleted: \(id)")
            deletedIds.insert(id)
        }
    }

    /// Check if a transaction has been marked as deleted.
    func isDeleted(_ id: UUID) -> Bool {
        deletedIds.contains(id)
    }

    /// Clean up old deleted IDs (call periodically or on app lifecycle events)
    func cleanup() {
        // For now, just clear all - they'll be gone from @Query anyway
        deletedIds.removeAll()
    }
}
