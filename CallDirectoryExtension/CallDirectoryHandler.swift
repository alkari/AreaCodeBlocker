//
//  CallDirectoryHandler.swift
//  CallDirectoryExtension
//
//  Created by Al Kari on 9/18/25.
//

import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    // The key for reading data from shared UserDefaults
    private let userDefaultsKey = "blockedAreaCodes"
    // The identifier for our App Group
    private let appGroupIdentifier = "group.com.manceps.areacodeblocker" // IMPORTANT: Must match the main app's identifier

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Check if the extension is enabled. If not, we can't do anything.
        guard context.isIncremental == false else {
            context.completeRequest()
            return
        }
        
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        let areaCodes = userDefaults?.stringArray(forKey: userDefaultsKey) ?? []

        if areaCodes.isEmpty {
            NSLog("No area codes to block.")
            context.completeRequest()
            return
        }
        
        // The country code for USA/Canada
        let countryCode: CXCallDirectoryPhoneNumber = 1

        for code in areaCodes {
            if let areaCodeInt = Int64(code) {
                // An area code covers 10 million numbers (from 000-0000 to 999-9999)
                // We will add all of them to the block list.
                // The number format is [Country Code][Area Code][7-digit number]
                let baseNumber: CXCallDirectoryPhoneNumber = countryCode * 1_000_000_0000 + areaCodeInt * 1_000_0000
                
                // Add all 10 million numbers for this area code
                for i in 0..<10_000_000 {
                    let phoneNumber = baseNumber + Int64(i)
                    context.addBlockingEntry(withNextSequentialPhoneNumber: phoneNumber)
                }
                NSLog("Added blocking entries for area code: \(code)")
            }
        }

        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for context: CXCallDirectoryExtensionContext, withError error: Error) {
        // Log any errors that occur during the request
        NSLog("Call Directory request failed: \(error.localizedDescription)")
    }
}
