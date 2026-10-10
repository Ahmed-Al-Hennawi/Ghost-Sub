import SwiftUI

let detailThemePurple = Color(red: 0.38, green: 0.21, blue: 1.0)
let detailBgGray = Color(UIColor.systemGroupedBackground)

struct SubscriptionDetailView: View {
    let subscription: Subscription
    @ObservedObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss

    @State private var showingEditSheet      = false
    @State private var showingPermanentModal = false

    var body: some View {
        ZStack {
            // MARK: - Main Content
            NavigationView {
                ScrollView {
                    VStack(spacing: 25) {

                        // Header Logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(detailThemePurple)
                            Text(String(subscription.providerName.prefix(1)))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .padding(.top, 20)

                        // Title & Price
                        VStack(spacing: 8) {
                            Text(subscription.providerName).font(.title).bold()
                            Text(CurrencyHelper.format(subscription.cost, currency: subscription.currency))
                                .font(.title2)
                                .foregroundColor(detailThemePurple)
                                .bold()

                            HStack {
                                Text(subscription.isTrial ? "Trial" : subscription.status)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(statusColor(for: subscription.status).opacity(0.2))
                                    .foregroundColor(statusColor(for: subscription.status))
                                    .cornerRadius(8)

                                Text(subscription.category)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(detailThemePurple.opacity(0.1))
                                    .foregroundColor(detailThemePurple)
                                    .cornerRadius(8)
                            }
                        }

                        // Data Card
                        VStack(spacing: 15) {
                            DetailRow(title: "Billing cycle",  value: subscription.billingFrequency)
                            Divider()
                            DetailRow(title: "Currency",       value: subscription.currency)
                            Divider()
                            DetailRow(title: "Renewal date",   value: subscription.renewalDate.formatted(.dateTime.day().month().year()))
                            Divider()
                            HStack {
                                Text("Monthly equivalent").foregroundColor(.secondary)
                                Spacer()
                                // Calling normalized math function
                                Text(CurrencyHelper.format(subscription.normalizedMonthlyCost, currency: subscription.currency)).bold()
                            }
                            if !subscription.notes.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notes").foregroundColor(.secondary)
                                    Text(subscription.notes).font(.body)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(15)
                        .padding(.horizontal)

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                if let url = URL(string: subscription.cancellationUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Cancel Subscription")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 55)
                                    .background(detailThemePurple)
                                    .cornerRadius(12)
                            }

                            Button(action: { showingEditSheet = true }) {
                                Text("Edit Subscription")
                                    .fontWeight(.semibold)
                                    .foregroundColor(detailThemePurple)
                                    .frame(maxWidth: .infinity).frame(height: 55)
                                    .background(detailThemePurple.opacity(0.1))
                                    .cornerRadius(12)
                            }

                            Button(action: { showingPermanentModal = true }) {
                                Label("Remove Subscription", systemImage: "trash")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity).frame(height: 55)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        Spacer().frame(height: 30)
                    }
                }
                .background(detailBgGray.ignoresSafeArea())
                .navigationBarItems(leading: Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                })
                .sheet(isPresented: $showingEditSheet) {
                    AddEditSubscriptionView(dbManager: dbManager, subscriptionToEdit: subscription)
                }
            }
            .disabled(showingPermanentModal)
            .blur(radius: showingPermanentModal ? 3 : 0)

            // MARK: - Permanent-Delete Modal Only
            if showingPermanentModal {
                DeleteConfirmModal(
                    title: "Delete Forever",
                    providerName: subscription.providerName,
                    message: "Are you sure you want to permanently delete \"\(subscription.providerName)\"?\n\nYou can no longer retrieve it once you delete it.",
                    confirmLabel: "Delete",
                    confirmColor: Color(red: 0.92, green: 0.25, blue: 0.2),
                    onConfirm: {
                        showingPermanentModal = false
                        // Wipes it completely from Firestore and local arrays
                        dbManager.permanentDeleteSubscription(subscriptionId: subscription.id)
                        dismiss()
                    },
                    onCancel: { showingPermanentModal = false }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingPermanentModal)
    }

    // MARK: - Helpers
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Active":    return .green
        case "Cancelled": return Color.gray
        case "Expired":   return .red
        default:          return detailThemePurple
        }
    }
}

// MARK: - Centred Delete Confirmation Modal
struct DeleteConfirmModal: View {
    let title: String
    let providerName: String
    let message: String
    let confirmLabel: String
    let confirmColor: Color
    let onConfirm: () -> Void
    let onCancel:  () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(confirmColor.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(confirmColor)
                }
                .padding(.top, 28)

                Text(title)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                    .padding(.top, 14)
                    .padding(.horizontal, 24)

                Text(providerName)
                    .font(.subheadline).bold()
                    .foregroundColor(detailThemePurple)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(detailThemePurple.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.top, 10)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Divider()

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }

                    Divider().frame(height: 52)

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .fontWeight(.bold)
                            .foregroundColor(confirmColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 10)
            )
            .padding(.horizontal, 36)
        }
    }
}

// MARK: - Reusable Row Component
struct DetailRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
}
