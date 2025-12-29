//
//  BlockedAreaCode.swift
//  AreaCodeBlocker
//
//  Shared data model for blocked area codes
//

import Foundation

/// Represents a blocked area code with separate controls for calls and texts
struct BlockedAreaCode: Codable, Hashable, Identifiable {
    let id: UUID
    let code: String
    var blockCalls: Bool
    var blockTexts: Bool
    let dateAdded: Date
    
    init(id: UUID = UUID(), code: String, blockCalls: Bool, blockTexts: Bool, dateAdded: Date = Date()) {
        self.id = id
        self.code = code
        self.blockCalls = blockCalls
        self.blockTexts = blockTexts
        self.dateAdded = dateAdded
    }
}

// MARK: - Data Manager
/// Manages loading and saving of blocked area codes using shared UserDefaults
final class BlockedAreaCodeManager {
    static let shared = BlockedAreaCodeManager()
    
    private init() {}
    
    /// Load blocked area codes from shared UserDefaults
    func loadBlockedItems() -> [BlockedAreaCode] {
        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier),
              let data = userDefaults.data(forKey: AppConfiguration.blockedAreaCodesKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([BlockedAreaCode].self, from: data)
        } catch {
            NSLog("Error decoding blocked items: \(error)")
            return []
        }
    }
    
    /// Save blocked area codes to shared UserDefaults
    func saveBlockedItems(_ items: [BlockedAreaCode]) -> Bool {
        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("Could not access shared UserDefaults. Check your App Group identifier.")
            return false
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            userDefaults.set(data, forKey: AppConfiguration.blockedAreaCodesKey)
            return true
        } catch {
            NSLog("Error encoding blocked items: \(error)")
            return false
        }
    }
}
