import Foundation
import FirebaseFirestore

// MARK: - Subscription Model
struct Subscription: Identifiable, Codable, Hashable {
    @DocumentID var id: String?       // Firebase auto-generated unique ID
    let userId: String
    var providerName: String
    var cost: Double
    var renewalDate: Date
    var cancellationUrl: String
    var isTrial: Bool
    var status: String                // "Active" | "Cancelled" | "Expired"
    var currency: String              // "GBP" | "USD" | "EUR"
    var billingFrequency: String      // "Monthly" | "Yearly" | "Weekly" | "Quarterly"
    var category: String
    var notes: String
    var createdAt: Date
    var lastUpdatedAt: Date

    // MARK: - Flawless Math Normalization
    var normalizedMonthlyCost: Double {
        switch billingFrequency {
        case "Yearly":    return cost / 12.0
        case "Weekly":    return cost * (52.0 / 12.0)
        default:          return cost // Monthly
        }
    }

    // MARK: - Fixed Deterministic Hashable Conformance
    func hash(into hasher: inout Hasher) {
        // Fixed: Only hash stable, non-random properties to guarantee a consistent value.
        hasher.combine(id)
        hasher.combine(providerName)
        hasher.combine(createdAt)
    }
    
    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
        return lhs.id == rhs.id &&
               lhs.createdAt == rhs.createdAt &&
               lhs.providerName == rhs.providerName &&
               lhs.cost == rhs.cost
    }

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, userId, providerName, cost, renewalDate, cancellationUrl,
             isTrial, status, currency, billingFrequency, category, notes,
             createdAt, lastUpdatedAt
    }

    // MARK: - Standard Initialiser
    init(
        userId: String,
        providerName: String,
        cost: Double,
        renewalDate: Date,
        cancellationUrl: String,
        isTrial: Bool,
        status: String           = "Active",
        currency: String         = "GBP",
        billingFrequency: String = "Monthly",
        category: String         = "Uncategorized",
        notes: String            = "",
        createdAt: Date          = Date(),
        lastUpdatedAt: Date      = Date()
    ) {
        self.userId           = userId
        self.providerName     = providerName
        self.cost             = cost
        self.renewalDate      = renewalDate
        self.cancellationUrl  = cancellationUrl
        self.isTrial          = isTrial
        self.status           = status
        self.currency         = currency
        self.billingFrequency = billingFrequency
        self.category         = category
        self.notes            = notes
        self.createdAt        = createdAt
        self.lastUpdatedAt    = lastUpdatedAt
    }

    // MARK: - Backwards-Compatible Decoder
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(String.self,  forKey: .id)
        userId           = try c.decode(String.self,           forKey: .userId)
        providerName     = try c.decode(String.self,           forKey: .providerName)
        cost             = try c.decode(Double.self,           forKey: .cost)
        renewalDate      = try c.decode(Date.self,             forKey: .renewalDate)
        cancellationUrl  = try c.decode(String.self,           forKey: .cancellationUrl)
        isTrial          = try c.decode(Bool.self,             forKey: .isTrial)
        status           = try c.decodeIfPresent(String.self,  forKey: .status)           ?? "Active"
        currency         = try c.decodeIfPresent(String.self,  forKey: .currency)         ?? "GBP"
        billingFrequency = try c.decodeIfPresent(String.self,  forKey: .billingFrequency) ?? "Monthly"
        category         = try c.decodeIfPresent(String.self,  forKey: .category)         ?? "Uncategorized"
        notes            = try c.decodeIfPresent(String.self,  forKey: .notes)            ?? ""
        createdAt        = try c.decodeIfPresent(Date.self,    forKey: .createdAt)        ?? Date.distantPast
        lastUpdatedAt    = try c.decodeIfPresent(Date.self,    forKey: .lastUpdatedAt)    ?? Date.distantPast
    }
}
