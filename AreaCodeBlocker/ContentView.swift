//
//  ContentView.swift
//  AreaCodeBlocker
//
//  Created by Al Kari on 9/18/25.
//

import SwiftUI
import CallKit

// Defines the structure for a blocked area code item
struct BlockedAreaCode: Codable, Hashable, Identifiable {
    let id = UUID() // To make it identifiable for SwiftUI lists
    let code: String
    var blockCalls: Bool
    var blockTexts: Bool
}

// Main view for the application
struct ContentView: View {
    // State variable to hold the list of blocked items
    @State private var blockedItems: [BlockedAreaCode] = []
    // State variable for the new area code input
    @State private var newAreaCode: String = ""
    // State for the toggles
    @State private var shouldBlockCalls = true
    @State private var shouldBlockTexts = true
    
    // State variables to show alerts to the user
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // The key for saving data in shared UserDefaults
    private let userDefaultsKey = "blockedAreaCodes"
    // The identifier for our App Group
    private let appGroupIdentifier = "group.com.yourdomain.areacodeblocker" // IMPORTANT: Change this!

    var body: some View {
        NavigationView {
            VStack {
                // Input section for adding new area codes
                VStack(spacing: 15) {
                    TextField("Enter 3-digit area code", text: $newAreaCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    Toggle(isOn: $shouldBlockCalls) {
                        Text("Block Calls")
                    }
                    
                    Toggle(isOn: $shouldBlockTexts) {
                        Text("Block Texts")
                    }

                    Button(action: addAreaCode) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Area Code")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()

                // List of currently blocked area codes
                List {
                    ForEach($blockedItems) { $item in
                        HStack {
                            Text(item.code).font(.headline)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Calls: \(item.blockCalls ? "Blocked" : "Allowed")")
                                    .foregroundColor(item.blockCalls ? .red : .green)
                                Text("Texts: \(item.blockTexts ? "Blocked" : "Allowed")")
                                    .foregroundColor(item.blockTexts ? .red : .green)
                            }
                        }
                        // Allow toggling directly from the list view
                        .onTapGesture {
                            if let index = blockedItems.firstIndex(where: { $0.id == item.id }) {
                                blockedItems[index].blockCalls.toggle()
                                saveAndReloadExtensions()
                            }
                        }
                    }
                    .onDelete(perform: deleteAreaCode)
                }
                .navigationTitle("Area Code Blocker")
                .toolbar {
                    EditButton()
                }
                .onAppear(perform: loadBlockedItems)
                
                // Instructions for the user
                Text("Enable in:\n- Settings > Phone > Call Blocking\n- Settings > Messages > Unknown & Spam")
                    .padding()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Invalid Input"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // --- Data Management Functions ---

    /// Loads the saved items from shared UserDefaults
    private func loadBlockedItems() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = userDefaults.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.blockedItems = try decoder.decode([BlockedAreaCode].self, from: data)
        } catch {
            print("Error decoding blocked items: \(error)")
        }
    }

    /// Saves the current list to shared UserDefaults and reloads the extensions
    private func saveAndReloadExtensions() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Could not access shared UserDefaults. Check your App Group identifier.")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(blockedItems)
            userDefaults.set(data, forKey: userDefaultsKey)
            
            // Reload Call Directory Extension
            CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: "com.yourdomain.areacodeblocker.CallDirectoryExtension") { error in
                if let error = error {
                    print("Error reloading call extension: \(error.localizedDescription)")
                } else {
                    print("Call extension reloaded successfully.")
                }
            }
            // The message extension will read this updated data automatically
            // when the next message arrives, so no direct reload call is needed.
            
        } catch {
            print("Error encoding blocked items: \(error)")
        }
    }
    
    /// Adds a new area code to the list
    private func addAreaCode() {
        // Input validation
        guard newAreaCode.count == 3, let _ = Int(newAreaCode) else {
            alertMessage = "Please enter a valid 3-digit area code."
            showingAlert = true
            return
        }
        
        if !shouldBlockCalls && !shouldBlockTexts {
            alertMessage = "You must select to block either calls or texts (or both)."
            showingAlert = true
            return
        }
        
        if !blockedItems.contains(where: { $0.code == newAreaCode }) {
            let newItem = BlockedAreaCode(code: newAreaCode, blockCalls: shouldBlockCalls, blockTexts: shouldBlockTexts)
            blockedItems.append(newItem)
            blockedItems.sort(by: { $0.code < $1.code }) // Keep the list sorted
            saveAndReloadExtensions()
        } else {
            alertMessage = "This area code is already in the list."
            showingAlert = true
        }
        newAreaCode = "" // Clear the text field
    }

    /// Deletes an area code from the list
    private func deleteAreaCode(at offsets: IndexSet) {
        blockedItems.remove(atOffsets: offsets)
        saveAndReloadExtensions()
    }
}
