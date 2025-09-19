//
//  MessageFilterExtension.swift
//  MessageFilterExtension
//
//  Created by Al Kari on 9/18/25.
//

import IdentityLookup

// Defines the structure for a blocked area code item (must match the main app)
struct BlockedAreaCode: Codable {
    let code: String
    var blockCalls: Bool
    var blockTexts: Bool
}

// CORRECTED: Added ILMessageFilterQueryHandling protocol conformance
final class MessageFilterExtension: ILMessageFilterExtension, ILMessageFilterQueryHandling {
    private let userDefaultsKey = "blockedAreaCodes"
    private let appGroupIdentifier = "group.com.yourdomain.areacodeblocker" // IMPORTANT: Must match the main app's identifier
    
    // CORRECTED: Removed 'override' and added back the 'context' parameter
    func handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        let response = ILMessageFilterQueryResponse()
        
        // Load the list of blocked items
        let blockedItems = loadBlockedItems()
        
        // Get the sender's phone number
        guard let sender = queryRequest.sender else {
            response.action = .allow // If no sender, allow it
            completion(response)
            return
        }
        
        // Sanitize the number by removing non-digits
        let numericSender = sender.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // In the US, a full number has 11 digits (1 + area code + number).
        // Check if the number is long enough to have an area code.
        guard numericSender.count >= 10 else {
            response.action = .allow
            completion(response)
            return
        }
        
        // Extract the area code from the sender number
        let areaCode: String
        if numericSender.hasPrefix("1") && numericSender.count == 11 {
            // It's a full number with country code, e.g., 12065551234
            let startIndex = numericSender.index(numericSender.startIndex, offsetBy: 1)
            let endIndex = numericSender.index(startIndex, offsetBy: 3)
            areaCode = String(numericSender[startIndex..<endIndex])
        } else if numericSender.count == 10 {
            // Number without country code, e.g., 2065551234
            let endIndex = numericSender.index(numericSender.startIndex, offsetBy: 3)
            areaCode = String(numericSender[..<endIndex])
        } else {
            // Not a standard US number format
            response.action = .allow
            completion(response)
            return
        }

        // Check if the extracted area code is in our block list for texts
        if blockedItems.contains(where: { $0.code == areaCode && $0.blockTexts }) {
            response.action = .junk // Block the message
        } else {
            response.action = .allow // Allow the message
        }
        
        completion(response)
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
            NSLog("Error decoding blocked items in MessageFilter: \(error)")
            return []
        }
    }
}

