import SwiftUI
import PhotosUI
import FirebaseAuth
import Combine

// MARK: - ScanViewModel
@MainActor
final class ScanViewModel: ObservableObject {

    // MARK: - State
    @Published var isScanning   = false
    @Published var statusText   = "Upload a Screenshot"

    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            guard let item = selectedItem else { return }
            loadImage(from: item)
        }
    }
    @Published var selectedImage: UIImage?

    // Review sheet
    @Published var parsedSubscription: Subscription?
    @Published var showingEditSheet     = false

    // Confidence warning
    @Published var showingLowConfidenceAlert = false
    @Published var lowConfidenceMessage      = ""

    // Error alert
    @Published var showingErrorAlert = false
    @Published var alertTitle        = "Error"
    @Published var alertMessage      = ""

    // MARK: - Services
    private let ocrService    = OCRService.shared
    private let parserService = SubscriptionParserService.shared

    // Low-confidence threshold: below this we ask the user to confirm
    private let confidenceThreshold = 0.5

    // MARK: - Public API

    func clearSelection() {
        selectedImage    = nil
        selectedItem     = nil
        statusText       = "Upload a Screenshot"
        parsedSubscription = nil
    }

    func analyzeScreenshot() {
        guard let image = selectedImage else { return }
        isScanning  = true
        statusText  = "Extracting text…"

        Task {
            do {
                // 1. OCR
                let extractedText = try await ocrService.extractText(from: image)
                statusText = "Analysing details…"

                // 2. Parse
                let parsed = parserService.parse(text: extractedText)

                // 3. Build draft Subscription
                let draft = buildDraft(from: parsed)

                // Small UX delay so the status text is readable
                try await Task.sleep(nanoseconds: 400_000_000)

                isScanning = false

                // 4. Route based on confidence
                if parsed.confidence < confidenceThreshold {
                    lowConfidenceMessage = buildLowConfidenceMessage(parsed)
                    parsedSubscription   = draft
                    showingLowConfidenceAlert = true
                } else {
                    parsedSubscription   = draft
                    showingEditSheet     = true
                    statusText          = "Review Extracted Info"
                }

            } catch let error as OCRError {
                isScanning = false
                switch error {
                case .noTextFound:
                    showError(
                        title: "Unable to Detect Subscription",
                        message: "No readable text was found. Please upload a clearer screenshot or add the subscription manually."
                    )
                default:
                    showError(message: error.localizedDescription)
                }
            } catch {
                isScanning = false
                showError(message: "An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }

    /// Called when the user taps "Proceed" on the low-confidence alert
    func proceedDespiteLowConfidence() {
        showingLowConfidenceAlert = false
        showingEditSheet = true
        statusText = "Review & Complete Info"
    }

    // MARK: - Private Helpers

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    statusText    = "Ready to analyse"
                } else {
                    showError(message: "Failed to load the selected image. Please try again.")
                }
            } catch {
                showError(message: "Error loading image: \(error.localizedDescription)")
            }
        }
    }

    private func buildDraft(from parsed: ParsedSubscriptionData) -> Subscription {
        let uid = Auth.auth().currentUser?.uid ?? ""
        let name = parsed.providerName ?? ""
        let cancelUrl = name.isEmpty
            ? "https://support.apple.com/en-gb/HT202039"
            : "https://www.google.com/search?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)+cancel+subscription"

        return Subscription(
            userId:           uid,
            providerName:     name,
            cost:             parsed.cost ?? 0.0,
            renewalDate:      parsed.renewalDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            cancellationUrl:  cancelUrl,
            isTrial:          parsed.isTrial,
            status:           "Active",
            currency:         parsed.currency,
            billingFrequency: parsed.billingFrequency,
            category:         parsed.category,
            notes:            "",
            createdAt:        Date()
        )
    }

    private func buildLowConfidenceMessage(_ parsed: ParsedSubscriptionData) -> String {
        var missing: [String] = []
        if parsed.providerName == nil { missing.append("subscription name") }
        if parsed.cost == nil         { missing.append("price") }
        if parsed.renewalDate == nil  { missing.append("renewal date") }

        if missing.isEmpty {
            return "The scanner found details but is not fully confident. Please review before saving."
        }
        return "The scanner could not reliably detect: \(missing.joined(separator: ", ")). You can fill in the missing information manually."
    }

    private func showError(title: String = "Scan Failed", message: String) {
        alertTitle   = title
        alertMessage = message
        showingErrorAlert = true
        statusText   = "Tap to upload a new screenshot"
        // NOTE: We do NOT clear the image here so the user can try again
    }
}
