import SwiftUI
import FirebaseAuth

struct AddEditSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dbManager: DatabaseManager

    // If nil  → Add mode. If provided → Edit mode.
    var subscriptionToEdit: Subscription?

    // MARK: - Form State
    @State private var providerName:      String = ""
    @State private var costString:        String = ""
    @State private var renewalDate:       Date   = Date()
    @State private var isTrial:           Bool   = false
    @State private var status:            String = "Active"
    @State private var currency:          String = "GBP"
    @State private var billingFrequency:  String = "Monthly"
    @State private var category:          String = "Uncategorized"
    @State private var notes:             String = ""

    // MARK: - Alert State
    @State private var showingDuplicateAlert = false
    @State private var showingSaveErrorAlert = false
    @State private var saveErrorMessage      = ""

    // MARK: - Constants
    let statuses    = ["Active", "Cancelled", "Expired"]
    let currencies  = ["GBP", "USD", "EUR", "CAD", "AUD"]
    let frequencies = ["Monthly", "Yearly", "Weekly"]
    let categories  = [
        "Entertainment", "Software & Cloud", "Gaming",
        "Utility", "Health & Fitness", "News & Reading",
        "Food & Drink", "Finance", "Shopping", "Uncategorized"
    ]

    private let themePurple = Color(red: 0.38, green: 0.21, blue: 1.0)

    // MARK: - Computed
    private var isEditMode: Bool { subscriptionToEdit?.id != nil }
    private var parsedCost: Double { Double(costString) ?? 0.0 }

    private var isDuplicateCandidate: Bool {
        guard !isEditMode else { return false }
        let name = providerName.trimmingCharacters(in: .whitespaces).lowercased()
        return dbManager.subscriptions.contains {
            $0.providerName.lowercased() == name &&
            abs($0.cost - parsedCost) < 0.01
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                detailsSection
                billingSection
                notesSection
            }
            .navigationTitle(isEditMode ? "Edit Subscription" : "Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .onAppear { prefill() }
        }
        // Duplicate confirmation
        .alert("Possible Duplicate", isPresented: $showingDuplicateAlert) {
            Button("Add Anyway", role: .destructive) { performSave() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A subscription for \"\(providerName)\" at \(CurrencyHelper.format(parsedCost, currency: currency)) already exists. Are you sure you want to add another?")
        }
        // Save error
        .alert("Could Not Save", isPresented: $showingSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    // MARK: - Form Sections

    private var detailsSection: some View {
        Section(header: Text("Details")) {
            TextField("Service name (e.g. Netflix)", text: $providerName)
                .autocapitalization(.words)
                .accessibilityLabel("Subscription service name")

            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }

            HStack {
                Picker("", selection: $currency) {
                    ForEach(currencies, id: \.self) { Text($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 85)

                TextField("Price", text: $costString)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Subscription price")
            }
        }
    }

    private var billingSection: some View {
        Section(header: Text("Billing")) {
            Picker("Frequency", selection: $billingFrequency) {
                ForEach(frequencies, id: \.self) { Text($0) }
            }
            DatePicker("Renewal Date", selection: $renewalDate, displayedComponents: .date)
            Toggle("Free Trial", isOn: $isTrial)
            Picker("Status", selection: $status) {
                ForEach(statuses, id: \.self) { Text($0) }
            }
        }
    }

    private var notesSection: some View {
        Section(header: Text("Notes")) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Optional notes about this subscription…")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { handleSaveTapped() }
                .bold()
                .disabled(providerName.trimmingCharacters(in: .whitespaces).isEmpty || costString.isEmpty)
        }
    }

    // MARK: - Logic

    private func prefill() {
        guard let sub = subscriptionToEdit else { return }
        providerName     = sub.providerName
        costString       = sub.cost > 0 ? String(format: "%.2f", sub.cost) : ""
        renewalDate      = sub.renewalDate
        isTrial          = sub.isTrial
        status           = sub.status
        currency         = sub.currency
        billingFrequency = sub.billingFrequency
        category         = sub.category
        notes            = sub.notes
    }

    private func handleSaveTapped() {
        // Check for duplicate only in Add mode
        if isDuplicateCandidate {
            showingDuplicateAlert = true
        } else {
            performSave()
        }
    }

    private func performSave() {
        guard let userId = Auth.auth().currentUser?.uid else {
            saveErrorMessage = "You must be signed in to save a subscription."
            showingSaveErrorAlert = true
            return
        }

        let name      = providerName.trimmingCharacters(in: .whitespaces)
        let cost      = parsedCost
        let now       = Date()
        let cancelUrl = subscriptionToEdit?.cancellationUrl
            ?? "https://www.google.com/search?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)+cancel+subscription"

        // Always create a fresh value type — never mutate a shared reference
        var newSub = Subscription(
            userId:           userId,
            providerName:     name,
            cost:             cost,
            renewalDate:      renewalDate,
            cancellationUrl:  cancelUrl,
            isTrial:          isTrial,
            status:           status,
            currency:         currency,
            billingFrequency: billingFrequency,
            category:         category,
            notes:            notes,
            createdAt:        subscriptionToEdit?.createdAt ?? now,
            lastUpdatedAt:    now
        )

        do {
            if let editSub = subscriptionToEdit, let existingId = editSub.id, !existingId.isEmpty {
                // Edit mode: target ONLY this specific document by its Firestore ID
                newSub.id = existingId
                try dbManager.updateSubscription(newSub)
            } else {
                // Add mode: DatabaseManager.addSubscription always clears the ID
                // so Firestore generates a new unique document — cannot overwrite anything
                try dbManager.addSubscription(newSub)
            }
            dismiss()
        } catch {
            saveErrorMessage = "Failed to save: \(error.localizedDescription)"
            showingSaveErrorAlert = true
        }
    }
}
