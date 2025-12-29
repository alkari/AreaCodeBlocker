//
//  TestAppGroupView.swift
//  AreaCodeBlocker
//
//  Temporary test view to debug App Group
//

import SwiftUI

struct TestAppGroupView: View {
    @State private var testResult = "Tap button to test"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("App Group Test")
                .font(.title)
            
            Text(testResult)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Test Save & Load") {
                testAppGroup()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    func testAppGroup() {
        NSLog("🧪 [Test] Starting App Group test")
        
        // Test 1: Can we create UserDefaults?
        guard let userDefaults = UserDefaults(suiteName: AppConfiguration.appGroupIdentifier) else {
            testResult = "❌ FAILED: Cannot create UserDefaults with App Group ID:\n\(AppConfiguration.appGroupIdentifier)"
            NSLog("🧪 [Test] FAILED: Cannot create UserDefaults")
            return
        }
        
        NSLog("🧪 [Test] ✅ UserDefaults created")
        
        // Test 2: Can we save data?
        let testData = "TestValue_\(Date().timeIntervalSince1970)".data(using: .utf8)!
        userDefaults.set(testData, forKey: "test_key")
        userDefaults.synchronize()
        
        NSLog("🧪 [Test] ✅ Data saved")
        
        // Test 3: Can we read it back?
        if let readData = userDefaults.data(forKey: "test_key"),
           let readString = String(data: readData, encoding: .utf8) {
            testResult = "✅ SUCCESS!\n\nApp Group ID:\n\(AppConfiguration.appGroupIdentifier)\n\nSaved and loaded:\n\(readString)"
            NSLog("🧪 [Test] ✅ Data read back: \(readString)")
        } else {
            testResult = "❌ FAILED: Could not read data back"
            NSLog("🧪 [Test] FAILED: Could not read data back")
        }
        
        // Test 4: Try to save actual blocked item
        let testItem = BlockedAreaCode(code: "555", blockCalls: true, blockTexts: true)
        let success = BlockedAreaCodeManager.shared.saveBlockedItems([testItem])
        
        if success {
            NSLog("🧪 [Test] ✅ BlockedAreaCodeManager save succeeded")
            
            // Try to load it back
            let loaded = BlockedAreaCodeManager.shared.loadBlockedItems()
            if loaded.count > 0 {
                testResult += "\n\n✅ Saved and loaded blocked area code: \(loaded[0].code)"
                NSLog("🧪 [Test] ✅ Loaded \(loaded.count) items back")
            } else {
                testResult += "\n\n⚠️ Save worked but load returned 0 items"
                NSLog("🧪 [Test] ⚠️ Save worked but load returned 0 items")
            }
        } else {
            testResult += "\n\n❌ BlockedAreaCodeManager save failed"
            NSLog("🧪 [Test] ❌ BlockedAreaCodeManager save failed")
        }
    }
}

#Preview {
    TestAppGroupView()
}
