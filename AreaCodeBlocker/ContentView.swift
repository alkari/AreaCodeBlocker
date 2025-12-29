//
//  ContentView.swift
//  AreaCodeBlocker
//
//  Main view for managing blocked area codes
//

import SwiftUI
import CallKit

// MARK: - Main View

struct ContentView: View {
    // MARK: - State Properties

    @State private var blockedItems: [BlockedAreaCode] = []
    @State private var newAreaCode: String = ""
    @State private var shouldBlockCalls = true
    @State private var shouldBlockTexts = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isReloading = false
    @State private var selectedItem: BlockedAreaCode?
    @State private var showingBlockedNumbers = false
    @State private var showingClearConfirmation = false
    @State private var blockedNumbersCount = 0
    @FocusState private var isInputFocused: Bool

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
                        Button {
                            showingBlockedNumbers = true
                        } label: {
                            Label("Blocked Numbers (\(blockedNumbersCount))", systemImage: "list.bullet")
                        }

                        Divider()

                        Button {
                            reloadCallDirectoryExtension()
                        } label: {
                            Label("Reload Extension", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear All Area Codes", systemImage: "trash")
                        }
                        .disabled(blockedItems.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(blockedItems.isEmpty)
                }

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
                Text("This will remove all blocked area codes. Individual blocked numbers will remain.")
            }
            .onAppear {
                loadBlockedItems()
                loadBlockedNumbersCount()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Notice"),
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
            .sheet(isPresented: $showingBlockedNumbers) {
                BlockedNumbersView()
                    .onDisappear {
                        loadBlockedNumbersCount()
                    }
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - View Components

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

            instructionsCard
        }
        .padding()
    }

    private var instructionsCard: some View {
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
                Text("Choose to block calls, texts, or both")
                    .font(.subheadline)
            }

            HStack(spacing: 12) {
                Image(systemName: "3.circle.fill")
                    .foregroundColor(.blue)
                Text("Enable extensions in Settings")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var blockedItemsList: some View {
        List {
            // Blocked numbers summary
            if blockedNumbersCount > 0 {
                Section {
                    Button {
                        showingBlockedNumbers = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blocked Numbers")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(blockedNumbersCount) number\(blockedNumbersCount == 1 ? "" : "s") blocked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Area codes list
            Section {
                ForEach(blockedItems) { item in
                    BlockedItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
                .onDelete(perform: deleteAreaCode)
            } header: {
                Text("Blocked Area Codes")
            }

            // Instructions footer
            Section {
                instructionsFooter
            }
        }
        .listStyle(.insetGrouped)
    }

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
                            Text("Calls")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .tint(shouldBlockCalls ? .red : .secondary)

                    Toggle(isOn: $shouldBlockTexts) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .foregroundColor(shouldBlockTexts ? .orange : .secondary)
                            Text("Texts")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .tint(shouldBlockTexts ? .orange : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private var instructionsFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable Extensions in Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Settings → Phone → Call Blocking", systemImage: "phone.circle.fill")
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

    private func loadBlockedItems() {
        blockedItems = BlockedAreaCodeManager.shared.loadBlockedItems()
        NSLog("📱 [ContentView] Loaded \(blockedItems.count) area code(s)")
    }

    private func loadBlockedNumbersCount() {
        blockedNumbersCount = BlockedAreaCodeManager.shared.loadBlockedNumbers().count
    }

    private func saveAndReloadExtensions() {
        NSLog("📱 [ContentView] Saving \(blockedItems.count) area code(s)")
        isReloading = true

        guard BlockedAreaCodeManager.shared.saveBlockedItems(blockedItems) else {
            alertMessage = "Could not save data. Check your App Group configuration."
            showingAlert = true
            isReloading = false
            return
        }

        reloadCallDirectoryExtension()
    }

    private func reloadCallDirectoryExtension() {
        isReloading = true

        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: AppConfiguration.callDirectoryExtensionIdentifier
        ) { error in
            DispatchQueue.main.async {
                self.isReloading = false

                if let error = error {
                    NSLog("❌ [ContentView] Extension reload error: \(error.localizedDescription)")
                    self.alertMessage = "Extension reload failed. Please enable in Settings → Phone → Call Blocking & Identification"
                    self.showingAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    NSLog("✅ [ContentView] Extension reloaded successfully")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                self.loadBlockedItems()
                self.loadBlockedNumbersCount()
            }
        }
    }

    private func addAreaCode() {
        isInputFocused = false

        guard newAreaCode.count == 3, Int(newAreaCode) != nil else {
            alertMessage = "Please enter a valid 3-digit area code."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        guard shouldBlockCalls || shouldBlockTexts else {
            alertMessage = "Select at least one: Block Calls or Block Texts."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        guard !blockedItems.contains(where: { $0.code == newAreaCode }) else {
            alertMessage = "This area code is already blocked."
            showingAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        let newItem = BlockedAreaCode(
            code: newAreaCode,
            blockCalls: shouldBlockCalls,
            blockTexts: shouldBlockTexts
        )

        blockedItems.append(newItem)
        blockedItems.sort { $0.code < $1.code }
        newAreaCode = ""

        saveAndReloadExtensions()
    }

    private func deleteAreaCode(at offsets: IndexSet) {
        blockedItems.remove(atOffsets: offsets)

        guard BlockedAreaCodeManager.shared.saveBlockedItems(blockedItems) else {
            loadBlockedItems()
            alertMessage = "Could not delete. Please try again."
            showingAlert = true
            return
        }

        reloadCallDirectoryExtension()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func clearAllAreaCodes() {
        blockedItems.removeAll()

        guard BlockedAreaCodeManager.shared.saveBlockedItems([]) else {
            loadBlockedItems()
            alertMessage = "Could not clear data. Please try again."
            showingAlert = true
            return
        }

        reloadCallDirectoryExtension()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Supporting Views

struct BlockedItemRow: View {
    let item: BlockedAreaCode

    var body: some View {
        HStack(spacing: 16) {
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
                        .foregroundColor(item.blockTexts ? .orange : .green)
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
                    .tint(.orange)
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
