//
//  MessageFilterExtension.swift
//  MessageFilterExtension
//
//  Filters SMS/MMS messages from blocked area codes and adds them to blocked list
//

import IdentityLookup
import Foundation

final class MessageFilterExtension: ILMessageFilterExtension {}

// MARK: - Message Filter Query Handling

extension MessageFilterExtension: ILMessageFilterQueryHandling {

    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let response = ILMessageFilterQueryResponse()

        NSLog("💬 [MessageFilter] Processing message filter request")

        guard let sender = queryRequest.sender else {
            NSLog("💬 [MessageFilter] No sender - allowing message")
            response.action = .allow
            completion(response)
            return
        }

        NSLog("💬 [MessageFilter] Sender: \(sender)")

        guard let areaCode = BlockedAreaCodeManager.extractAreaCode(from: sender) else {
            NSLog("💬 [MessageFilter] Could not extract area code - allowing")
            response.action = .allow
            completion(response)
            return
        }

        NSLog("💬 [MessageFilter] Area code: \(areaCode)")

        // Check if this area code is configured for text blocking
        let blockedAreaCodes = BlockedAreaCodeManager.shared.getBlockedAreaCodesForTexts()

        if blockedAreaCodes.contains(areaCode) {
            NSLog("💬 [MessageFilter] Area code \(areaCode) is blocked - filtering message")

            // Add this number to the blocked list
            let normalizedNumber = sender.filter { $0.isNumber }
            let success = BlockedAreaCodeManager.shared.addBlockedNumber(
                phoneNumber: normalizedNumber,
                areaCode: areaCode,
                source: .text
            )

            if success {
                NSLog("💬 [MessageFilter] Added \(normalizedNumber) to blocked numbers list")
            }

            response.action = .junk
            // Note: subAction is iOS 16+ only, omitting for iOS 13+ compatibility
        } else {
            NSLog("💬 [MessageFilter] Area code \(areaCode) not blocked - allowing")
            response.action = .allow
        }

        completion(response)
    }
}

// MARK: - Capabilities Query Handling (iOS 16+)

@available(iOS 16.0, *)
extension MessageFilterExtension: ILMessageFilterCapabilitiesQueryHandling {

    func handle(
        _ capabilitiesQueryRequest: ILMessageFilterCapabilitiesQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterCapabilitiesQueryResponse) -> Void
    ) {
        let response = ILMessageFilterCapabilitiesQueryResponse()

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
