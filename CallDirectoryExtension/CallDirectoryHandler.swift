//
//  CallDirectoryHandler.swift
//  CallDirectoryExtension
//
//  Created by Al Kari on 9/18/25.
//  Enhanced with batched processing and memory management
//

import Foundation
import CallKit

// MARK: - Call Directory Handler

/// Handles call blocking using the Call Directory Extension framework
/// Implements batched processing for better performance and memory management
class CallDirectoryHandler: CXCallDirectoryProvider {
    
    // MARK: - Constants
    
    /// Number of entries to process in each batch
    private let batchSize = 100_000
    
    /// Total numbers per area code (xxx-0000 through xxx-9999 for all suffixes)
    private let numbersPerAreaCode = 10_000_000
    
    // MARK: - Request Handling
    
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        NSLog("📞 [CallDirectory] Begin request - isIncremental: \(context.isIncremental)")
        
        // For now, treat incremental updates as full reloads
        // This is simpler and ensures all entries are always in sync
        if context.isIncremental {
            NSLog("📞 [CallDirectory] Incremental update requested - performing full reload instead")
            
            // Remove all existing entries first
            context.removeAllBlockingEntries()
            NSLog("📞 [CallDirectory] Removed all existing blocking entries")
        }
        
        // Load blocked area codes
        let blockedItems = BlockedAreaCodeManager.shared.loadBlockedItems()
        NSLog("📞 [CallDirectory] Loaded \(blockedItems.count) total items from storage")
        
        guard !blockedItems.isEmpty else {
            NSLog("📞 [CallDirectory] No area codes to block")
            context.completeRequest()
            return
        }
        
        // Log all loaded items for debugging
        for item in blockedItems {
            NSLog("📞 [CallDirectory] Item: code=\(item.code), blockCalls=\(item.blockCalls), blockTexts=\(item.blockTexts)")
        }
        
        NSLog("📞 [CallDirectory] Processing \(blockedItems.count) area code(s)")
        
        do {
            try addBlockingEntries(to: context, for: blockedItems)
            NSLog("✅ [CallDirectory] Successfully added all blocking entries")
            context.completeRequest()
        } catch {
            NSLog("❌ [CallDirectory] Error adding blocking entries: \(error.localizedDescription)")
            context.cancelRequest(withError: error)
        }
    }
    
    // MARK: - Blocking Entry Management
    
    /// Adds blocking entries for all specified area codes with batched processing
    private func addBlockingEntries(
        to context: CXCallDirectoryExtensionContext,
        for blockedItems: [BlockedAreaCode]
    ) throws {
        // Filter for items with call blocking enabled
        let callBlockingItems = blockedItems.filter { $0.blockCalls }
        
        guard !callBlockingItems.isEmpty else {
            NSLog("📞 [CallDirectory] No area codes configured for call blocking")
            return
        }
        
        // CRITICAL: Sort area codes numerically to ensure phone numbers are added in ascending order
        // CallKit requires phone numbers to be added in strictly ascending order
        let sortedItems = callBlockingItems.sorted { (item1, item2) -> Bool in
            guard let code1 = Int(item1.code), let code2 = Int(item2.code) else {
                return item1.code < item2.code
            }
            return code1 < code2
        }
        
        for item in sortedItems {
            guard let areaCodeInt = Int64(item.code) else {
                NSLog("⚠️ [CallDirectory] Invalid area code: \(item.code)")
                continue
            }
            
            try addBlockingEntriesForAreaCode(
                areaCodeInt,
                to: context,
                code: item.code
            )
        }
    }
    
    /// Adds blocking entries for a single area code using batched processing
    private func addBlockingEntriesForAreaCode(
        _ areaCodeInt: Int64,
        to context: CXCallDirectoryExtensionContext,
        code: String
    ) throws {
        let countryCode: CXCallDirectoryPhoneNumber = AppConfiguration.defaultCountryCode
        let baseNumber: CXCallDirectoryPhoneNumber = countryCode * 1_000_000_0000 + areaCodeInt * 1_000_0000
        
        NSLog("📞 [CallDirectory] Adding entries for area code \(code) - Base: \(baseNumber)")
        
        let totalBatches = (numbersPerAreaCode + batchSize - 1) / batchSize
        
        for batchIndex in 0..<totalBatches {
            autoreleasepool {
                let startOffset = batchIndex * batchSize
                let endOffset = min(startOffset + batchSize, numbersPerAreaCode)
                
                for offset in startOffset..<endOffset {
                    let phoneNumber = baseNumber + Int64(offset)
                    context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
                }
                
                NSLog("📞 [CallDirectory] Batch \(batchIndex + 1)/\(totalBatches) completed for \(code)")
            }
        }
        
        NSLog("✅ [CallDirectory] Completed \(numbersPerAreaCode) entries for area code \(code)")
    }
}

