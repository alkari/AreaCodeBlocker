//
//  ContentView.swift
//  AreaCodeBlocker
//
//  Created by Al Kari on 9/18/25.
//  Enhanced with modern UI and performance improvements
//

import SwiftUI
import CallKit

// MARK: - Main View

/// Main view for managing blocked area codes
struct ContentView: View {
    // MARK: - State Properties
    
    /// List of blocked area codes
    @State private var blockedItems: [BlockedAreaCode] = []
    
    /// New area code input field
    @State private var newAreaCode: String = ""
    
    /// Toggle states for new entries
    @State private var shouldBlockCalls = true
    @State private var shouldBlockTexts = true
    
    /// Alert presentation
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    /// Loading state during extension reload
    @State private var isReloading = false
    
    /// Selected item for editing
    @State private var selectedItem: BlockedAreaCode?
    @State private var showingDetailSheet = false
    
    /// Focus state for keyboard management
    @FocusState private var isInputFocused: Bool
    
    /// Confirmation dialog for clearing all data
    @State private var showingClearConfirmation = false

    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    if blockedItems.isEmpty {
                        emptyStateView
                    } else {
                        blockedItemsList
                    }
                }
                
                inputSection
            }
            .navigationTitle("Area Code Blocker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                        .disabled(blockedItems.isEmpty)
                        
                        Button {
                            NSLog("🔄 [ContentView] Manual reload requested")
                            reloadCallDirectoryExtension()
                        } label: {
                            Label("Force Reload Extension", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                
                // Add keyboard toolbar with Done button
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .confirmationDialog(
                "Clear All Blocked Area Codes?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllAreaCodes()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all blocked area codes and reset the Call Directory Extension. You'll need to toggle the extension off and on again in Settings.")
            }
            .onAppear {
                NSLog("📱 [ContentView] App appeared - starting up")
                loadBlockedItems()
                NSLog("📱 [ContentView] Loaded \(blockedItems.count) existing items")
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Invalid Input"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(item: $selectedItem) { item in
                DetailSheet(item: item) { updatedItem in
                    if let index = blockedItems.firstIndex(where: { $0.id == updatedItem.id }) {
                        blockedItems[index] = updatedItem
                        saveAndReloadExtensions()
                    }
                }
            }
            // Dismiss keyboard when tapping outside
            .onTapGesture {
                isInputFocused = false
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - View Components
    
    /// Empty state view shown when no area codes are blocked
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "phone.down.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No Blocked Area Codes")
                .font(.title2.weight(.semibold))
            
            Text("Add an area code below to start blocking unwanted calls and texts")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Enter a 3-digit area code")
                        .font(.subheadline)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Choose what to block")
                        .font(.subheadline)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Enable in Settings")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding()
    }
    
    /// List of blocked area codes
    private var blockedItemsList: some View {
        List {
            ForEach(blockedItems) { item in
                BlockedItemRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                        showingDetailSheet = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            .onDelete(perform: deleteAreaCode)
            
            instructionsFooter
        }
        .listStyle(.insetGrouped)
    }
    
    /// Input section for adding new area codes
    private var inputSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Area Code", text: $newAreaCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .frame(height: 44)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isInputFocused)
                        .onChange(of: newAreaCode) { newValue in
                            if newValue.count > 3 {
                                newAreaCode = String(newValue.prefix(3))
                            }
                        }
                        .submitLabel(.done)
                        .onSubmit {
                            addAreaCode()
                        }
                    
                    Button(action: {
                        addAreaCode()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        if isReloading {
                            ProgressView()
                                .frame(width: 44, height: 44)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isReloading || newAreaCode.isEmpty)
                }
                
                HStack(spacing: 20) {
                    Toggle(isOn: $shouldBlockCalls) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(shouldBlockCalls ? .red : .secondary)
                            Text("Block Calls")
                                .font(.subheadline)
                        }
                    }
                    
                    Toggle(isOn: $shouldBlockTexts) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .foregroundColor(shouldBlockTexts ? .red : .secondary)
                            Text("Block Texts")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }
    
    /// Instructions footer in list
    private var instructionsFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable Extensions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Settings → Phone → Call Blocking & Identification", systemImage: "phone.circle.fill")
                    .font(.caption)
                
                Label("Settings → Messages → Unknown & Spam", systemImage: "message.circle.fill")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .listRowBackground(Color(.systemGroupedBackground))
    }

    // MARK: - Data Management Functions

    /// Loads the saved items from shared UserDefaults
    private func loadBlockedItems() {
        blockedItems = BlockedAreaCodeManager.shared.loadBlockedItems()
    }

    /// Saves the current list to shared UserDefaults and reloads the extensions
    private func saveAndReloadExtensions() {
        NSLog("📱 [ContentView] saveAndReloadExtensions called with \(blockedItems.count) item(s)")
        isReloading = true
        
        guard BlockedAreaCodeManager.shared.saveBlockedItems(blockedItems) else {
            alertMessage = "Could not save data. Check your App Group configuration."
            showingAlert = true
            isReloading = false
            NSLog("❌ [ContentView] Save failed!")
            return
        }
        
        NSLog("✅ [ContentView] Save succeeded, reloading extension...")
        reloadCallDirectoryExtension()
    }
    
    /// Reloads the Call Directory Extension
    private func reloadCallDirectoryExtension() {
        isReloading = true
        
        // Reload Call Directory Extension
        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: AppConfiguration.callDirectoryExtensionIdentifier
        ) { error in
            DispatchQueue.main.async {
                self.isReloading = false
                
                if let error = error {
                    NSLog("❌ Error reloading call extension: \(error.localizedDescription)")
                    self.alertMessage = "Extension reload failed: \(error.localizedDescription)\n\nYou may need to enable the extension in Settings → Phone → Call Blocking & Identification"
                    self.showingAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    NSLog("✅ Call extension reloaded successfully")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                
                // Reload items from storage to ensure UI is in sync
                self.loadBlockedItems()
            }
        }
    }
    
    /// Adds a new area code to the list
    private func addAreaCode() {
        // Dismiss keyboard
        isInputFocused = false
        
        NSLog("📱 [ContentView] addAreaCode called")
        
        // Input validation
        guard newAreaCode.count == 3, Int(newAreaCode) != nil else {
            alertMessage = "Please enter a valid 3-digit area code."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            NSLog("❌ [ContentView] Invalid area code: \(newAreaCode)")
            return
        }
        
        guard shouldBlockCalls || shouldBlockTexts else {
            alertMessage = "You must select to block either calls or texts (or both)."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            NSLog("❌ [ContentView] No blocking options selected")
            return
        }
        
        guard !blockedItems.contains(where: { $0.code == newAreaCode }) else {
            alertMessage = "This area code is already in the list."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            NSLog("❌ [ContentView] Area code already exists: \(newAreaCode)")
            return
        }
        
        let newItem = BlockedAreaCode(
            code: newAreaCode,
            blockCalls: shouldBlockCalls,
            blockTexts: shouldBlockTexts
        )
        
        NSLog("📱 [ContentView] Adding new item: code=\(newItem.code), blockCalls=\(newItem.blockCalls), blockTexts=\(newItem.blockTexts)")
        
        blockedItems.append(newItem)
        blockedItems.sort(by: { $0.code < $1.code })
        
        NSLog("📱 [ContentView] Total items now: \(blockedItems.count)")
        
        newAreaCode = ""
        saveAndReloadExtensions()
    }

    /// Deletes an area code from the list
    private func deleteAreaCode(at offsets: IndexSet) {
        // Store the items to delete for potential rollback
        let itemsToDelete = offsets.map { blockedItems[$0] }
        
        // Remove from the array
        blockedItems.remove(atOffsets: offsets)
        
        // Attempt to save
        guard BlockedAreaCodeManager.shared.saveBlockedItems(blockedItems) else {
            // Rollback if save fails
            for (index, item) in zip(offsets, itemsToDelete) {
                blockedItems.insert(item, at: index)
            }
            alertMessage = "Could not delete. Check your App Group configuration."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        // Reload the extension
        reloadCallDirectoryExtension()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Clears all blocked area codes
    private func clearAllAreaCodes() {
        blockedItems.removeAll()
        
        // Save empty list
        guard BlockedAreaCodeManager.shared.saveBlockedItems([]) else {
            alertMessage = "Could not clear data. Check your App Group configuration."
            showingAlert = true
            loadBlockedItems() // Reload to restore UI
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        // Reload the extension to clear CallKit database
        reloadCallDirectoryExtension()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
// MARK: - Supporting Views

/// Row view for displaying a blocked area code item
struct BlockedItemRow: View {
    let item: BlockedAreaCode
    
    var body: some View {
        HStack(spacing: 16) {
            // Area code badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(item.code)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Status indicators
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.blockCalls ? "phone.down.fill" : "phone.fill")
                        .font(.caption)
                        .foregroundColor(item.blockCalls ? .red : .green)
                    Text("Calls: \(item.blockCalls ? "Blocked" : "Allowed")")
                        .font(.subheadline.weight(.medium))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: item.blockTexts ? "message.fill" : "message")
                        .font(.caption)
                        .foregroundColor(item.blockTexts ? .red : .green)
                    Text("Texts: \(item.blockTexts ? "Blocked" : "Allowed")")
                        .font(.subheadline.weight(.medium))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// Detail sheet for editing a blocked area code
struct DetailSheet: View {
    let item: BlockedAreaCode
    let onSave: (BlockedAreaCode) -> Void
    
    @State private var blockCalls: Bool
    @State private var blockTexts: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(item: BlockedAreaCode, onSave: @escaping (BlockedAreaCode) -> Void) {
        self.item = item
        self.onSave = onSave
        _blockCalls = State(initialValue: item.blockCalls)
        _blockTexts = State(initialValue: item.blockTexts)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Text(item.code)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("Blocking Options") {
                    Toggle(isOn: $blockCalls) {
                        Label("Block Calls", systemImage: "phone.down.fill")
                    }
                    .tint(.red)
                    
                    Toggle(isOn: $blockTexts) {
                        Label("Block Texts", systemImage: "message.fill")
                    }
                    .tint(.red)
                }
                
                Section {
                    Text("Added: \(item.dateAdded.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Area Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedItem = BlockedAreaCode(
                            id: item.id,
                            code: item.code,
                            blockCalls: blockCalls,
                            blockTexts: blockTexts,
                            dateAdded: item.dateAdded
                        )
                        onSave(updatedItem)
                        dismiss()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .disabled(!blockCalls && !blockTexts)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

