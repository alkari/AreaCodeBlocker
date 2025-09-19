//
//  CallDirectoryHandler.swift
//  CallDirectoryExtension
//
//  Created by Al Kari on 9/18/25.
//

import Foundation
import CallKit

// Defines the structure for a blocked area code item (must match the main app)
struct BlockedAreaCode: Codable {
    let code: String
    var blockCalls: Bool
    var blockTexts: Bool
}

class CallDirectoryHandler: CXCallDirectoryProvider {

    private let userDefaultsKey = "blockedAreaCodes"
    private let appGroupIdentifier = "group.com.manceps.areacodeblocker" // IMPORTANT: Must match the main app's identifier

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        guard !context.isIncremental else {
            context.completeRequest()
            return
        }
        
        let blockedItems = loadBlockedItems()

        guard !blockedItems.isEmpty else {
            NSLog("No area codes to block.")
            context.completeRequest()
            return
        }
        
        let countryCode: CXCallDirectoryPhoneNumber = 1 // USA/Canada

        // Filter for only the items where call blocking is enabled
        for item in blockedItems where item.blockCalls {
            if let areaCodeInt = Int64(item.code) {
                // Number format: [Country Code][Area Code][7-digit number]
                let baseNumber: CXCallDirectoryPhoneNumber = countryCode * 1_000_000_0000 + areaCodeInt * 1_000_0000
                
                // Add all 10 million numbers for this area code
                for i in 0..<10_000_000 {
                    context.addBlockingEntry(withNextSequentialPhoneNumber: baseNumber + Int64(i))
                }
                NSLog("Added call blocking entries for area code: \(item.code)")
            }
        }

        context.completeRequest()
    }

    private func loadBlockedItems() -> [BlockedAreaCode] {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = userDefaults.data(forKey: userDefaultsKey) else {
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
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for context: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("Call Directory request failed: \(error.localizedDescription)")
    }
}

