//
//  WidgetPerformanceOptimizer.swift
//  MoneyTracker
//
//  Created on 2026-01-29.
//

import Foundation
import SwiftData

/// Performance optimizer for widgets to reduce redundant calculations during scroll
@Observable
final class WidgetPerformanceOptimizer {
    static let shared = WidgetPerformanceOptimizer()

    // Cache for expensive calculations with timestamps
    private var calculationCache: [String: (result: Any, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 2.0 // Cache valid for 2 seconds

    private init() {}

    /// Get cached result or calculate and cache
    func getCached<T>(key: String, calculation: () -> T) -> T {
        // Check if cached value exists and is still valid
        if let cached = calculationCache[key],
           let cachedResult = cached.result as? T,
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cachedResult
        }

        // Calculate new value
        let result = calculation()
        calculationCache[key] = (result, Date())
        return result
    }

    /// Clear specific cache entry
    func clearCache(forKey key: String) {
        calculationCache.removeValue(forKey: key)
    }

    /// Clear all cache
    func clearAllCache() {
        calculationCache.removeAll()
    }

    /// Clear expired cache entries
    func cleanExpiredCache() {
        let now = Date()
        calculationCache = calculationCache.filter { key, value in
            now.timeIntervalSince(value.timestamp) < cacheValidityDuration
        }
    }

    /// Generate cache key from multiple parameters
    func cacheKey(widget: String, params: [String: Any]) -> String {
        let sortedKeys = params.keys.sorted()
        let paramsString = sortedKeys.map { key in
            "\(key)=\(params[key] ?? "nil")"
        }.joined(separator: "&")
        return "\(widget)?\(paramsString)"
    }
}
