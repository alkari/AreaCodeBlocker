//
//  BlockedNumbersView.swift
//  AreaCodeBlocker
//
//  Displays a list of individually blocked phone numbers
//

import SwiftUI

struct BlockedNumbersView: View {
    @State private var blockedNumbers: [BlockedNumber] = []
    @State private var showingClearConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if blockedNumbers.isEmpty {
                    emptyStateView
                } else {
                    blockedNumbersList
                }
            }
            .navigationTitle("Blocked Numbers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !blockedNumbers.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                showingClearConfirmation = true
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear All Blocked Numbers?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllNumbers()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all individually blocked phone numbers. Area code blocking rules will remain.")
            }
            .onAppear {
                loadBlockedNumbers()
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "phone.badge.checkmark")
                .font(.system(size: 70))
                .foregroundColor(.secondary)

            Text("No Blocked Numbers")
                .font(.title2.weight(.semibold))

            Text("When calls or texts from blocked area codes are detected, their phone numbers will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.arrow.down.left")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Incoming calls from blocked area codes")
                        .font(.subheadline)
                }

                HStack(spacing: 12) {
                    Image(systemName: "message.badge.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Text messages from blocked area codes")
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

    private var blockedNumbersList: some View {
        List {
            Section {
                ForEach(blockedNumbers) { number in
                    BlockedNumberRow(number: number)
                }
                .onDelete(perform: deleteNumbers)
            } header: {
                Text("\(blockedNumbers.count) blocked number\(blockedNumbers.count == 1 ? "" : "s")")
            } footer: {
                Text("These numbers were detected from calls or texts matching your blocked area codes. Swipe to remove individual numbers.")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Data Functions

    private func loadBlockedNumbers() {
        blockedNumbers = BlockedAreaCodeManager.shared.loadBlockedNumbers()
    }

    private func deleteNumbers(at offsets: IndexSet) {
        for index in offsets {
            let number = blockedNumbers[index]
            _ = BlockedAreaCodeManager.shared.removeBlockedNumber(number)
        }
        blockedNumbers.remove(atOffsets: offsets)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func clearAllNumbers() {
        _ = BlockedAreaCodeManager.shared.saveBlockedNumbers([])
        blockedNumbers = []
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Blocked Number Row

struct BlockedNumberRow: View {
    let number: BlockedNumber

    var body: some View {
        HStack(spacing: 14) {
            // Source icon
            ZStack {
                Circle()
                    .fill(sourceColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: sourceIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(sourceColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(number.formattedNumber)
                    .font(.system(size: 16, weight: .medium, design: .rounded))

                HStack(spacing: 8) {
                    Text("Area code \(number.areaCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundColor(sourceColor)
                }
            }

            Spacer()

            Text(number.dateBlocked, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: String {
        switch number.source {
        case .call:
            return "phone.fill"
        case .text:
            return "message.fill"
        case .manual:
            return "hand.raised.fill"
        }
    }

    private var sourceColor: Color {
        switch number.source {
        case .call:
            return .red
        case .text:
            return .orange
        case .manual:
            return .blue
        }
    }

    private var sourceLabel: String {
        switch number.source {
        case .call:
            return "Call"
        case .text:
            return "Text"
        case .manual:
            return "Manual"
        }
    }
}

// MARK: - Preview

#Preview {
    BlockedNumbersView()
}
