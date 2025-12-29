//  MessageFilterExtension.swift
//  MessageFilterExtension
//
//  Created by Al Kari on 9/18/25.
//  Enhanced with caching for better performance
//

import IdentityLookup

// MARK: - Message Filter Extension

/// Filters SMS/MMS messages based on blocked area codes
/// Implements caching to reduce file I/O operations
final class MessageFilterExtension: ILMessageFilterExtension {
    
    // MARK: - Cache Management
    
    /// Cache for blocked area codes to reduce UserDefaults reads
    private var cachedBlockedCodes: Set<String>?
    
    /// Timestamp of last cache update
    private var cacheTimestamp: Date?
    
    /// Cache validity duration (60 seconds)
    private let cacheValidityDuration: TimeInterval = 60
}

// MARK: - Message Filter Query Handling

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    
    // MARK: - Message Filtering
    
    /// Handles incoming message filter queries
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let response = ILMessageFilterQueryResponse()
        
        NSLog("💬 [MessageFilter] Processing message filter request")
        
        // Get sender's phone number
        guard let sender = queryRequest.sender else {
            NSLog("💬 [MessageFilter] No sender - allowing message")
            response.action = .allow
            completion(response)
            return
        }
        
        // Extract area code from sender number
        guard let areaCode = extractAreaCode(from: sender) else {
            NSLog("💬 [MessageFilter] Could not extract area code from \(sender) - allowing")
            response.action = .allow
            completion(response)
            return
        }
        
        // Check if area code is blocked
        let blockedCodes = getBlockedAreaCodes()
        
        if blockedCodes.contains(areaCode) {
            NSLog("💬 [MessageFilter] Blocking message from area code: \(areaCode)")
            response.action = .junk
        } else {
            NSLog("💬 [MessageFilter] Allowing message from area code: \(areaCode)")
            response.action = .allow
        }
        
        completion(response)
    }
}

// MARK: - Capabilities Query Handling

@available(iOS 16.0, *)
extension MessageFilterExtension: ILMessageFilterCapabilitiesQueryHandling {
    
    /// Declares the capabilities of this message filter extension
    func handle(
        _ capabilitiesQueryRequest: ILMessageFilterCapabilitiesQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterCapabilitiesQueryResponse) -> Void
    ) {
        let response = ILMessageFilterCapabilitiesQueryResponse()
        
        // Declare that this extension handles transactional messages (promotional/junk filtering)
        // as well as promotional messages
        response.transactionalSubActions = [
            .transactionalOthers,
            .transactionalFinance,
            .transactionalOrders,
            .transactionalReminders,
            .transactionalHealth,
            .transactionalWeather,
            .transactionalCarrier,
            .transactionalRewards,
            .transactionalPublicServices
        ]
        
        response.promotionalSubActions = [
            .promotionalOthers,
            .promotionalOffers,
            .promotionalCoupons
        ]
        
        NSLog("💬 [MessageFilter] Capabilities query handled")
        
        completion(response)
    }
}

// MARK: - Private Helper Methods

private extension MessageFilterExtension {
    
    /// Extracts area code from a phone number string
    func extractAreaCode(from sender: String) -> String? {
        // Sanitize the number by removing non-digits
        let numericSender = sender.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check if the number is long enough to have an area code
        guard numericSender.count >= 10 else {
            return nil
        }
        
        // Extract area code based on number format
        let areaCode: String
        
        if numericSender.hasPrefix("1") && numericSender.count == 11 {
            // Full number with country code, e.g., 12065551234
            let startIndex = numericSender.index(numericSender.startIndex, offsetBy: 1)
            let endIndex = numericSender.index(startIndex, offsetBy: 3)
            areaCode = String(numericSender[startIndex..<endIndex])
        } else if numericSender.count == 10 {
            // Number without country code, e.g., 2065551234
            let endIndex = numericSender.index(numericSender.startIndex, offsetBy: 3)
            areaCode = String(numericSender[..<endIndex])
        } else {
            // Not a standard US number format
            return nil
        }
        
        return areaCode
    }
    
    /// Gets blocked area codes with caching
    func getBlockedAreaCodes() -> Set<String> {
        // Check if cache is valid
        if let cached = cachedBlockedCodes,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            NSLog("💬 [MessageFilter] Using cached blocked codes (\(cached.count) codes)")
            return cached
        }
        
        // Load fresh data
        NSLog("💬 [MessageFilter] Cache expired or empty - loading from UserDefaults")
        let blockedItems = BlockedAreaCodeManager.shared.loadBlockedItems()
        
        // Filter for items with text blocking enabled and convert to Set
        let blockedCodes = Set(
            blockedItems
                .filter { $0.blockTexts }
                .map { $0.code }
        )
        
        // Update cache
        cachedBlockedCodes = blockedCodes
        cacheTimestamp = Date()
        
        NSLog("💬 [MessageFilter] Cached \(blockedCodes.count) blocked area codes")
        
        return blockedCodes
    }
}

