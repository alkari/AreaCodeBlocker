//
//  BlockedAreaCode.swift
//  AreaCodeBlocker
//
//  Shared data models for blocked area codes and phone numbers
//

import Foundation

// MARK: - Blocked Area Code Model

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

// MARK: - Blocked Phone Number Model

/// Represents an individually blocked phone number
struct BlockedNumber: Codable, Hashable, Identifiable {
    let id: UUID
    let phoneNumber: String
    let formattedNumber: String
    let areaCode: String
    let source: BlockSource
    let dateBlocked: Date

    enum BlockSource: String, Codable {
        case call = "call"
        case text = "text"
        case manual = "manual"
    }

    init(id: UUID = UUID(), phoneNumber: String, areaCode: String, source: BlockSource, dateBlocked: Date = Date()) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.areaCode = areaCode
        self.source = source
        self.dateBlocked = dateBlocked
        self.formattedNumber = BlockedNumber.formatPhoneNumber(phoneNumber)
    }

    /// Formats a phone number for display (e.g., +1 (206) 555-1234)
    static func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("1") {
            let areaCode = String(digits.dropFirst().prefix(3))
            let exchange = String(digits.dropFirst(4).prefix(3))
            let subscriber = String(digits.dropFirst(7).prefix(4))
            return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
        } else if digits.count == 10 {
            let areaCode = String(digits.prefix(3))
            let exchange = String(digits.dropFirst(3).prefix(3))
            let subscriber = String(digits.dropFirst(6).prefix(4))
            return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
        }

        return number
    }

    /// Converts phone number to E.164 format for CallKit (e.g., 12065551234)
    var e164Number: Int64? {
        let digits = phoneNumber.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("1") {
            return Int64(digits)
        } else if digits.count == 10 {
            return Int64("1" + digits)
        }

        return nil
    }
}

// MARK: - Data Manager

/// Manages loading and saving of blocked area codes and phone numbers
final class BlockedAreaCodeManager {
    static let shared = BlockedAreaCodeManager()

    private init() {}

    // MARK: - Blocked Area Codes

    /// Load blocked area codes from shared UserDefaults
    func loadBlockedItems() -> [BlockedAreaCode] {
        NSLog("🔧 [BlockedAreaCodeManager] Loading blocked area codes")

        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not create UserDefaults with suite: \(AppConfiguration.appGroupIdentifier)")
            return []
        }

        guard let data = userDefaults.data(forKey: AppConfiguration.blockedAreaCodesKey) else {
            NSLog("⚠️ [BlockedAreaCodeManager] No area codes data found")
            return []
        }

        do {
            let items = try JSONDecoder().decode([BlockedAreaCode].self, from: data)
            NSLog("✅ [BlockedAreaCodeManager] Loaded \(items.count) area code(s)")
            return items
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error decoding area codes: \(error)")
            return []
        }
    }

    /// Save blocked area codes to shared UserDefaults
    func saveBlockedItems(_ items: [BlockedAreaCode]) -> Bool {
        NSLog("🔧 [BlockedAreaCodeManager] Saving \(items.count) area code(s)")

        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not access shared UserDefaults")
            return false
        }

        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: AppConfiguration.blockedAreaCodesKey)
            userDefaults.synchronize()
            NSLog("✅ [BlockedAreaCodeManager] Saved area codes successfully")
            return true
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error encoding area codes: \(error)")
            return false
        }
    }

    // MARK: - Blocked Phone Numbers

    /// Load blocked phone numbers from shared UserDefaults
    func loadBlockedNumbers() -> [BlockedNumber] {
        NSLog("🔧 [BlockedAreaCodeManager] Loading blocked numbers")

        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not create UserDefaults")
            return []
        }

        guard let data = userDefaults.data(forKey: AppConfiguration.blockedNumbersKey) else {
            NSLog("⚠️ [BlockedAreaCodeManager] No blocked numbers data found")
            return []
        }

        do {
            let numbers = try JSONDecoder().decode([BlockedNumber].self, from: data)
            NSLog("✅ [BlockedAreaCodeManager] Loaded \(numbers.count) blocked number(s)")
            return numbers
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error decoding blocked numbers: \(error)")
            return []
        }
    }

    /// Save blocked phone numbers to shared UserDefaults
    func saveBlockedNumbers(_ numbers: [BlockedNumber]) -> Bool {
        NSLog("🔧 [BlockedAreaCodeManager] Saving \(numbers.count) blocked number(s)")

        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            NSLog("❌ [BlockedAreaCodeManager] Could not access shared UserDefaults")
            return false
        }

        do {
            let data = try JSONEncoder().encode(numbers)
            userDefaults.set(data, forKey: AppConfiguration.blockedNumbersKey)
            userDefaults.synchronize()
            NSLog("✅ [BlockedAreaCodeManager] Saved blocked numbers successfully")
            return true
        } catch {
            NSLog("❌ [BlockedAreaCodeManager] Error encoding blocked numbers: \(error)")
            return false
        }
    }

    /// Add a phone number to the blocked list
    func addBlockedNumber(phoneNumber: String, areaCode: String, source: BlockedNumber.BlockSource) -> Bool {
        var numbers = loadBlockedNumbers()

        // Check if already blocked
        let normalizedNumber = phoneNumber.filter { $0.isNumber }
        if numbers.contains(where: { $0.phoneNumber.filter { $0.isNumber } == normalizedNumber }) {
            NSLog("⚠️ [BlockedAreaCodeManager] Number already blocked: \(phoneNumber)")
            return true
        }

        let newNumber = BlockedNumber(phoneNumber: normalizedNumber, areaCode: areaCode, source: source)
        numbers.append(newNumber)
        numbers.sort { $0.dateBlocked > $1.dateBlocked }

        return saveBlockedNumbers(numbers)
    }

    /// Remove a phone number from the blocked list
    func removeBlockedNumber(_ number: BlockedNumber) -> Bool {
        var numbers = loadBlockedNumbers()
        numbers.removeAll { $0.id == number.id }
        return saveBlockedNumbers(numbers)
    }

    /// Get all blocked numbers for call blocking (sorted for CallKit)
    func getBlockedNumbersForCalls() -> [Int64] {
        let numbers = loadBlockedNumbers()
        let areaCodes = loadBlockedItems().filter { $0.blockCalls }

        var e164Numbers: [Int64] = []

        for number in numbers {
            // Check if this number's area code has call blocking enabled
            if areaCodes.contains(where: { $0.code == number.areaCode }) {
                if let e164 = number.e164Number {
                    e164Numbers.append(e164)
                }
            }
        }

        // CallKit requires numbers in ascending order
        return e164Numbers.sorted()
    }

    /// Get blocked area codes for text filtering
    func getBlockedAreaCodesForTexts() -> Set<String> {
        let areaCodes = loadBlockedItems().filter { $0.blockTexts }
        return Set(areaCodes.map { $0.code })
    }

    /// Get blocked numbers for text filtering
    func getBlockedNumbersForTexts() -> Set<String> {
        let numbers = loadBlockedNumbers()
        let areaCodes = loadBlockedItems().filter { $0.blockTexts }

        var blockedSet: Set<String> = []

        for number in numbers {
            if areaCodes.contains(where: { $0.code == number.areaCode }) {
                blockedSet.insert(number.phoneNumber)
            }
        }

        return blockedSet
    }

    // MARK: - Utility

    /// Extract area code from a phone number
    static func extractAreaCode(from phoneNumber: String) -> String? {
        let digits = phoneNumber.filter { $0.isNumber }

        if digits.count == 11 && digits.hasPrefix("1") {
            return String(digits.dropFirst().prefix(3))
        } else if digits.count >= 10 {
            return String(digits.prefix(3))
        }

        return nil
    }
}
