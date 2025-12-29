//
//  AppConfiguration.swift
//  AreaCodeBlocker
//
//  Shared configuration constants across the app and extensions
//

import Foundation

enum AppConfiguration {
    /// The App Group identifier for sharing data between the app and extensions
    /// Must match the App Group registered in Apple Developer Portal
    static let appGroupIdentifier = "group.com.manceps.AreaCodeBlocker"

    /// UserDefaults key for storing blocked area codes
    static let blockedAreaCodesKey = "blockedAreaCodes"

    /// UserDefaults key for storing individually blocked phone numbers
    static let blockedNumbersKey = "blockedNumbers"

    /// Call Directory Extension identifier
    static let callDirectoryExtensionIdentifier = "com.manceps.AreaCodeBlocker.CallDirectoryExtension"

    /// Message Filter Extension identifier
    static let messageFilterExtensionIdentifier = "com.manceps.AreaCodeBlocker.MessageFilterExtension"

    /// Country code for phone numbers (1 = USA/Canada)
    static let defaultCountryCode: Int64 = 1
}
