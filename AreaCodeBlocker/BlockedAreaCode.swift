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
        NSLog("🔧 [BlockedAreaCodeManager] Attempting to load items")
        NSLog("🔧 [BlockedAreaCodeManager] App Group ID: \(AppConfiguration.appGroupIdentifier)")
        NSLog("🔧 [BlockedAreaCodeManager] Storage key: \(AppConfiguration.blockedAreaCodesKey)")
        
        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not create UserDefaults with suite name")
            return []
        }
        
        NSLog("✅ [BlockedAreaCodeManager] UserDefaults created successfully")
        
        guard let data = userDefaults.data(forKey: AppConfiguration.blockedAreaCodesKey) else {
            NSLog("⚠️ [BlockedAreaCodeManager] No data found for key (may be empty)")
            return []
        }
        
        NSLog("✅ [BlockedAreaCodeManager] Data found: \(data.count) bytes")
        
        do {
            let decoder = JSONDecoder()
            let items = try decoder.decode([BlockedAreaCode].self, from: data)
            NSLog("✅ [BlockedAreaCodeManager] Successfully decoded \(items.count) item(s)")
            return items
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error decoding blocked items: \(error)")
            return []
        }
    }
    
    /// Save blocked area codes to shared UserDefaults
    func saveBlockedItems(_ items: [BlockedAreaCode]) -> Bool {
        NSLog("🔧 [BlockedAreaCodeManager] Attempting to save \(items.count) item(s)")
        NSLog("🔧 [BlockedAreaCodeManager] App Group ID: \(AppConfiguration.appGroupIdentifier)")
        
        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not access shared UserDefaults. Check your App Group identifier.")
            return false
        }
        
        NSLog("✅ [BlockedAreaCodeManager] UserDefaults created successfully")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            NSLog("✅ [BlockedAreaCodeManager] Encoded data: \(data.count) bytes")
            
            userDefaults.set(data, forKey: AppConfiguration.blockedAreaCodesKey)
            let success = userDefaults.synchronize()
            NSLog("✅ [BlockedAreaCodeManager] Save \(success ? "succeeded" : "may have issues (synchronize returned false)")")
            
            // Verify the save
            if let savedData = userDefaults.data(forKey: AppConfiguration.blockedAreaCodesKey) {
                NSLog("✅ [BlockedAreaCodeManager] Verified: \(savedData.count) bytes saved")
            } else {
                NSLog("⚠️ [BlockedAreaCodeManager] Warning: Could not verify saved data")
            }
            
            return true
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error encoding blocked items: \(error)")
            return false
        }
    }
}
