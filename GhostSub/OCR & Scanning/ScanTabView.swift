import SwiftUI
import PhotosUI

struct ScanTabView: View {
    @ObservedObject var dbManager: DatabaseManager
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 8) {
                Text("Screenshot Scanner")
                    .font(.largeTitle).bold().foregroundColor(.primary)
                Text("Upload a subscription email or receipt")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.top, 60)

            Spacer()

            // Image preview or upload button
            ZStack {
                if let image = viewModel.selectedImage {
                    imagePreview(image: image)
                } else {
                    uploadButton
                }
            }
            .padding(.horizontal)

            Spacer()

            // Status & Action
            bottomSection

        }
        .background(bgGray.ignoresSafeArea())
        // Review sheet
        .sheet(isPresented: $viewModel.showingEditSheet, onDismiss: {
            viewModel.clearSelection()
        }) {
            if let parsed = viewModel.parsedSubscription {
                AddEditSubscriptionView(dbManager: dbManager, subscriptionToEdit: parsed)
            }
        }
        // Error alert
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        // Low-confidence alert
        .alert("Low Confidence", isPresented: $viewModel.showingLowConfidenceAlert) {
            Button("Fill In Manually") { viewModel.proceedDespiteLowConfidence() }
            Button("Cancel", role: .cancel) { viewModel.clearSelection() }
        } message: {
            Text(viewModel.lowConfidenceMessage)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func imagePreview(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 300)
                .cornerRadius(20)
                .shadow(radius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themePurple, lineWidth: 2)
                )

            if viewModel.isScanning {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 15) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Analysing…")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    )
            }
        }
    }

    private var uploadButton: some View {
        PhotosPicker(
            selection: $viewModel.selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themePurple, themePurple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)
                    .shadow(color: themePurple.opacity(0.4), radius: 20, x: 0, y: 10)

                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 46, weight: .thin))
                        .foregroundColor(.white)
                    Text("Upload")
                        .font(.caption).bold()
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .buttonStyle(ScannerButtonStyle())
        .accessibilityLabel("Upload subscription screenshot")
    }

    private var bottomSection: some View {
        VStack(spacing: 15) {
            Text(viewModel.statusText)
                .font(.headline)
                .foregroundColor(viewModel.isScanning ? themePurple : .primary)
                .multilineTextAlignment(.center)

            if viewModel.selectedImage != nil && !viewModel.isScanning {
                HStack(spacing: 20) {
                    Button("Clear") { viewModel.clearSelection() }
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 30).padding(.vertical, 15)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .accessibilityLabel("Clear selected screenshot")

                    Button("Analyse Screenshot") { viewModel.analyzeScreenshot() }
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30).padding(.vertical, 15)
                        .background(themePurple)
                        .cornerRadius(12)
                        .accessibilityLabel("Analyse screenshot for subscription details")
                }
            } else if !viewModel.isScanning {
                Text("We use on-device OCR to securely extract subscription details. Nothing leaves your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 120)
    }
}

// MARK: - Tactile Button Style
struct ScannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
