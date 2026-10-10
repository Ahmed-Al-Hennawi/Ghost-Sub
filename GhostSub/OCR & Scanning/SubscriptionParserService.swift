import Foundation

// MARK: - ParsedSubscriptionData
/// Intermediate value-object returned by the parser.
/// Confidence is a 0.0–1.0 score; below 0.5 the UI should prompt user confirmation.
struct ParsedSubscriptionData {
    let providerName: String?       // nil if cannot be determined
    let cost: Double?               // nil if cannot be determined
    let currency: String            // default GBP when no symbol found
    let billingFrequency: String    // default Monthly
    let renewalDate: Date?          // nil if no future date found
    let category: String
    let isTrial: Bool
    let confidence: Double          // 0.0 = nothing detected, 1.0 = all fields found
}

// MARK: - SubscriptionParserService
/// Parses raw OCR text into structured subscription data.
/// Designed to be replaced by / augmented with an AI backend without changing callers.
final class SubscriptionParserService {

    static let shared = SubscriptionParserService()
    private init() {}

    // MARK: - Provider Catalogue
    // Each entry: (canonical display name, aliases that must appear in the text)
    private let providerCatalogue: [(name: String, aliases: [String], category: String)] = [
        // Streaming — Video
        ("Netflix",          ["netflix"],                              "Entertainment"),
        ("Disney+",          ["disney+", "disney plus", "disneyplus"], "Entertainment"),
        ("Apple TV+",        ["apple tv+", "apple tv plus", "appletv"],"Entertainment"),
        ("Amazon Prime",     ["amazon prime", "prime video", "primevideo"], "Entertainment"),
        ("YouTube Premium",  ["youtube premium", "youtube music"],     "Entertainment"),
        ("Hulu",             ["hulu"],                                 "Entertainment"),
        ("HBO Max",          ["hbo max", "hbomax", "max.com"],         "Entertainment"),
        ("Peacock",          ["peacock"],                              "Entertainment"),
        ("Paramount+",       ["paramount+", "paramount plus"],         "Entertainment"),
        ("Sky",              ["sky go", "sky sports", "sky cinema", "sky tv"], "Entertainment"),
        ("Now TV",           ["now tv", "nowtv"],                      "Entertainment"),
        ("BritBox",          ["britbox"],                              "Entertainment"),
        // Streaming — Music
        ("Spotify",          ["spotify"],                              "Entertainment"),
        ("Apple Music",      ["apple music"],                          "Entertainment"),
        ("Tidal",            ["tidal"],                                "Entertainment"),
        ("Deezer",           ["deezer"],                               "Entertainment"),
        // Cloud / Productivity
        ("iCloud",           ["icloud", "icloud+", "apple one"],       "Software & Cloud"),
        ("Google One",       ["google one", "google storage"],         "Software & Cloud"),
        ("Dropbox",          ["dropbox"],                              "Software & Cloud"),
        ("Microsoft 365",    ["microsoft 365", "office 365", "microsoft office"], "Software & Cloud"),
        ("Adobe Creative",   ["adobe", "creative cloud", "creativecloud"], "Software & Cloud"),
        ("Notion",           ["notion"],                               "Software & Cloud"),
        ("Evernote",         ["evernote"],                             "Software & Cloud"),
        ("LastPass",         ["lastpass"],                             "Software & Cloud"),
        ("1Password",        ["1password"],                            "Software & Cloud"),
        ("NordVPN",          ["nordvpn"],                              "Software & Cloud"),
        ("ExpressVPN",       ["expressvpn"],                           "Software & Cloud"),
        // Shopping / Retail
        ("Amazon Prime",     ["amazon.co.uk/prime", "amazon.com/prime"], "Shopping"),
        ("Costco",           ["costco"],                               "Shopping"),
        // Gaming
        ("PlayStation Plus", ["playstation plus", "ps plus", "ps now"], "Gaming"),
        ("Xbox Game Pass",   ["xbox game pass", "xbox pass", "xbox live"], "Gaming"),
        ("Nintendo Switch Online", ["nintendo switch online", "nintendo online"], "Gaming"),
        ("EA Play",          ["ea play", "origin access"],             "Gaming"),
        ("Steam",            ["steam"],                                "Gaming"),
        // News / Reading
        ("The Times",        ["the times", "times subscription"],      "News & Reading"),
        ("The Guardian",     ["the guardian", "guardian"],             "News & Reading"),
        ("Apple News+",      ["apple news+", "apple news plus"],       "News & Reading"),
        ("Audible",          ["audible"],                              "News & Reading"),
        ("Kindle Unlimited", ["kindle unlimited"],                     "News & Reading"),
        // Fitness / Health
        ("Peloton",          ["peloton"],                              "Health & Fitness"),
        ("Headspace",        ["headspace"],                            "Health & Fitness"),
        ("Calm",             ["calm"],                                 "Health & Fitness"),
        ("Strava",           ["strava"],                               "Health & Fitness"),
        ("Apple Fitness+",   ["apple fitness", "fitness+"],            "Health & Fitness"),
        // Finance
        ("Monzo Plus",       ["monzo plus", "monzo premium"],          "Finance"),
        ("Revolut",          ["revolut premium", "revolut metal"],     "Finance"),
    ]

    // MARK: - Public API
    func parse(text: String) -> ParsedSubscriptionData {
        let lower = text.lowercased()

        let (providerName, category) = detectProvider(in: lower)
        let (cost, currency)         = detectCost(in: text)
        let frequency                = detectFrequency(in: lower)
        let renewalDate              = detectDate(in: text, frequency: frequency)
        let isTrial                  = detectTrial(in: lower)
        let confidence               = computeConfidence(
            hasProvider: providerName != nil,
            hasCost:     cost != nil,
            hasDate:     renewalDate != nil
        )

        return ParsedSubscriptionData(
            providerName:    providerName,
            cost:            cost,
            currency:        currency,
            billingFrequency: frequency,
            renewalDate:     renewalDate,
            category:        category,
            isTrial:         isTrial,
            confidence:      confidence
        )
    }

    // MARK: - Provider Detection
    private func detectProvider(in lower: String) -> (name: String?, category: String) {
        for entry in providerCatalogue {
            for alias in entry.aliases where lower.contains(alias) {
                return (entry.name, entry.category)
            }
        }
        // Try to find a capitalised service-name-like word near "subscription" or "membership"
        return (nil, "Uncategorized")
    }

    // MARK: - Cost & Currency Detection
    /// Only accepts values in the realistic subscription range: £0.50 – £1,500
    private func detectCost(in text: String) -> (cost: Double?, currency: String) {
        let patterns: [(pattern: String, currency: String)] = [
            ("£\\s?(\\d{1,4}[.,]\\d{2})",    "GBP"),
            ("\\$\\s?(\\d{1,4}[.,]\\d{2})",   "USD"),
            ("€\\s?(\\d{1,4}[.,]\\d{2})",     "EUR"),
            ("GBP\\s?(\\d{1,4}[.,]\\d{2})",   "GBP"),
            ("USD\\s?(\\d{1,4}[.,]\\d{2})",   "USD"),
            ("EUR\\s?(\\d{1,4}[.,]\\d{2})",   "EUR"),
            // Fallback: bare decimal numbers only if near price keywords
            ("(\\d{1,4}[.,]\\d{2})\\s*/(?:mo|month|yr|year|week)",  "GBP"),
        ]

        var candidates: [(value: Double, currency: String, score: Int)] = []

        for (pattern, currency) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                // The capture group index: last group is the number
                let groupIndex = match.numberOfRanges - 1
                guard match.range(at: groupIndex).location != NSNotFound else { continue }
                let numStr = ns.substring(with: match.range(at: groupIndex))
                    .replacingOccurrences(of: ",", with: ".")
                if let value = Double(numStr),
                   value >= 0.49, value <= 1500.0 {
                    // Prioritise matches with an explicit currency symbol
                    let score = ["£", "$", "€", "GBP", "USD", "EUR"]
                        .contains(where: { pattern.hasPrefix($0) }) ? 2 : 1
                    candidates.append((value, currency, score))
                }
            }
        }

        // Sort by score desc then value asc (prefer smaller, explicitly-labelled price)
        candidates.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.value < rhs.value
        }

        if let best = candidates.first {
            return (best.value, best.currency)
        }
        return (nil, "GBP")
    }

    // MARK: - Billing Frequency Detection
    private func detectFrequency(in lower: String) -> String {
        if lower.contains("annual") || lower.contains("/year") || lower.contains("per year")
            || lower.contains("yearly") || lower.contains("12 month") { return "Yearly" }
        if lower.contains("week") || lower.contains("/wk")            { return "Weekly" }
        if lower.contains("quarter") || lower.contains("3 month")
            || lower.contains("every 3")                               { return "Quarterly" }
        return "Monthly"
    }

    // MARK: - Date Detection
    private func detectDate(in text: String, frequency: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return fallbackDate(frequency: frequency)
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let futureDates = matches.compactMap(\.date).filter { $0 > Date() }

        // Prefer dates that are not "now" (detector sometimes returns today for year-only strings)
        if let nearest = futureDates.min(by: { $0 < $1 }) {
            return nearest
        }
        return fallbackDate(frequency: frequency)
    }

    private func fallbackDate(frequency: String) -> Date? {
        let cal = Calendar.current
        switch frequency {
        case "Yearly":    return cal.date(byAdding: .year,  value: 1, to: Date())
        case "Weekly":    return cal.date(byAdding: .day,   value: 7, to: Date())
        case "Quarterly": return cal.date(byAdding: .month, value: 3, to: Date())
        default:          return cal.date(byAdding: .month, value: 1, to: Date())
        }
    }

    // MARK: - Trial Detection
    private func detectTrial(in lower: String) -> Bool {
        let trialKeywords = ["free trial", "trial period", "trial subscription",
                             "first month free", "try for free", "trial ends",
                             "your trial", "trial plan", "30-day free", "7-day free",
                             "14-day free", "trial expir"]
        return trialKeywords.contains { lower.contains($0) }
    }

    // MARK: - Confidence Score
    private func computeConfidence(hasProvider: Bool, hasCost: Bool, hasDate: Bool) -> Double {
        var score = 0.0
        if hasProvider { score += 0.45 }  // Provider is most important signal
        if hasCost     { score += 0.40 }  // Price second
        if hasDate     { score += 0.15 }  // Date is bonus
        return score
    }
}
