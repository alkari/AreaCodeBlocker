//
//  CallDirectoryHandler.swift
//  CallDirectoryExtension
//
//  Handles call blocking using individual phone numbers from blocked area codes
//

import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        NSLog("📞 [CallDirectory] Begin request - isIncremental: \(context.isIncremental)")

        context.delegate = self

        if context.isIncremental {
            // For incremental updates, remove all and re-add
            // This ensures consistency with the current blocked list
            context.removeAllBlockingEntries()
            NSLog("📞 [CallDirectory] Cleared existing entries for incremental update")
        }

        // Add blocking entries for individually blocked numbers
        addBlockingPhoneNumbers(to: context)

        context.completeRequest()
    }

    private func addBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Get blocked numbers that should be blocked for calls
        let blockedNumbers = BlockedAreaCodeManager.shared.getBlockedNumbersForCalls()

        guard !blockedNumbers.isEmpty else {
            NSLog("📞 [CallDirectory] No phone numbers to block")
            return
        }

        NSLog("📞 [CallDirectory] Adding \(blockedNumbers.count) blocked number(s)")

        // Numbers must be added in ascending order
        for phoneNumber in blockedNumbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
            NSLog("📞 [CallDirectory] Blocked: \(phoneNumber)")
        }

        NSLog("✅ [CallDirectory] Successfully added \(blockedNumbers.count) blocking entries")
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        NSLog("❌ [CallDirectory] Request failed: \(error.localizedDescription)")

        if let cxError = error as? CXErrorCodeCallDirectoryManagerError {
            switch cxError.code {
            case .unknown:
                NSLog("❌ [CallDirectory] Unknown error")
            case .noExtensionFound:
                NSLog("❌ [CallDirectory] No extension found")
            case .loadingInterrupted:
                NSLog("❌ [CallDirectory] Loading interrupted")
            case .entriesOutOfOrder:
                NSLog("❌ [CallDirectory] Entries out of order - numbers must be in ascending order")
            case .duplicateEntries:
                NSLog("❌ [CallDirectory] Duplicate entries found")
            case .maximumEntriesExceeded:
                NSLog("❌ [CallDirectory] Maximum entries exceeded")
            case .extensionDisabled:
                NSLog("❌ [CallDirectory] Extension disabled - user needs to enable in Settings")
            case .currentlyLoading:
                NSLog("❌ [CallDirectory] Currently loading")
            case .unexpectedIncrementalRemoval:
                NSLog("❌ [CallDirectory] Unexpected incremental removal")
            @unknown default:
                NSLog("❌ [CallDirectory] Unknown error code: \(cxError.code.rawValue)")
            }
        }
    }
}
