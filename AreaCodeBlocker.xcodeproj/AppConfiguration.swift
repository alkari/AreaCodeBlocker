//
//  AppConfiguration.swift
//  AreaCodeBlocker
//
//  Shared configuration constants across the app and extensions
//

import Foundation

enum AppConfiguration {
    /// The App Group identifier for sharing data between the app and extensions
    /// IMPORTANT: This must match your App Group in Xcode capabilities
    static let appGroupIdentifier = "group.com.manceps.areacodeblocker"
    
    /// UserDefaults key for storing blocked area codes
    static let blockedAreaCodesKey = "blockedAreaCodes"
    
    /// Call Directory Extension identifier
    /// IMPORTANT: This must match your Call Directory Extension's bundle identifier
    static let callDirectoryExtensionIdentifier = "com.manceps.AreaCodeBlocker.CallDirectoryExtension"
    
    /// Country code for phone numbers (1 = USA/Canada)
    static let defaultCountryCode: Int64 = 1
}
