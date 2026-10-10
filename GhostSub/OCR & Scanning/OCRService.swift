import Foundation
import UIKit
import Vision

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// Extracts text from a given UIImage using Apple's Vision framework.
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.recognitionFailed)
                    return
                }
                
                let extractedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: extractedText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed
    case noTextFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed."
        case .recognitionFailed:
            return "Failed to recognize text in the image."
        case .noTextFound:
            return "No readable text was found in the image."
        }
    }
}
