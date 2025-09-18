//
//  ContentView.swift
//  AreaCodeBlocker
//
//  Created by Al Kari on 9/18/25.
//

import SwiftUI
import CallKit

// Main view for the application
struct ContentView: View {
    // State variable to hold the list of blocked area codes
    @State private var areaCodes: [String] = []
    // State variable for the new area code input
    @State private var newAreaCode: String = ""
    // State variable to show alerts to the user
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // The key for saving data in shared UserDefaults
    private let userDefaultsKey = "blockedAreaCodes"
    // The identifier for our App Group
    private let appGroupIdentifier = "group.com.manceps.areacodeblocker" // IMPORTANT: Change this!

    var body: some View {
        NavigationView {
            VStack {
                // Input section for adding new area codes
                HStack {
                    TextField("Enter 3-digit area code", text: $newAreaCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                
                    Button(action: addAreaCode) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                }
                .padding()

                // List of currently blocked area codes
                List {
                    ForEach(areaCodes, id: \.self) { code in
                        Text(code)
                    }
                    .onDelete(perform: deleteAreaCode)
                }
                .navigationTitle("Area Code Blocker")
                .toolbar {
                    EditButton()
                }
                .onAppear(perform: loadAreaCodes)
                
                // Instructions for the user
                Text("To enable blocking:\nGo to Settings > Phone > Call Blocking & Identification, and turn on the switch for 'AreaCodeBlocker'.")
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

    /// Loads the saved area codes from shared UserDefaults
    private func loadAreaCodes() {
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.areaCodes = userDefaults.stringArray(forKey: userDefaultsKey) ?? []
        }
    }

    /// Saves the current list of area codes to shared UserDefaults and reloads the extension
    private func saveAndReload() {
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.set(areaCodes, forKey: userDefaultsKey)
            
            // Tell the system to reload our Call Directory Extension
            CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: "com.manceps.areacodeblocker.CallDirectoryExtension") { error in
                if let error = error {
                    print("Error reloading extension: \(error.localizedDescription)")
                } else {
                    print("Extension reloaded successfully.")
                }
            }
        } else {
            print("Could not access shared UserDefaults. Check your App Group identifier.")
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
        
        if !areaCodes.contains(newAreaCode) {
            areaCodes.append(newAreaCode)
            areaCodes.sort() // Keep the list sorted
            saveAndReload()
        }
        newAreaCode = "" // Clear the text field
    }

    /// Deletes an area code from the list
    private func deleteAreaCode(at offsets: IndexSet) {
        areaCodes.remove(atOffsets: offsets)
        saveAndReload()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
