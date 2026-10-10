import SwiftUI
import Combine
import FirebaseFirestore

struct UserProfile: Codable {
    var uid: String
    var firstName: String
    var lastName: String
    var gender: String
    var dob: Date
    var email: String
    var countryCode: String
    var phoneNumber: String
    var profileImageBase64: String?

    enum CodingKeys: String, CodingKey {
        case uid, firstName, lastName, gender, dob, email, countryCode, phoneNumber, profileImageBase64
    }

    // SAFE DECODING: Prevents infinite loading if older profiles are missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid           = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
        firstName     = try container.decodeIfPresent(String.self, forKey: .firstName) ?? "User"
        lastName      = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        gender        = try container.decodeIfPresent(String.self, forKey: .gender) ?? "Not Specified"
        dob           = try container.decodeIfPresent(Date.self,   forKey: .dob) ?? Date()
        email         = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        countryCode   = try container.decodeIfPresent(String.self, forKey: .countryCode)  ?? "+44"
        phoneNumber   = try container.decodeIfPresent(String.self, forKey: .phoneNumber)  ?? ""
        profileImageBase64 = try container.decodeIfPresent(String.self, forKey: .profileImageBase64)
    }

    init(uid: String, firstName: String, lastName: String, gender: String, dob: Date,
         email: String, countryCode: String, phoneNumber: String, profileImageBase64: String? = nil) {
        self.uid               = uid
        self.firstName         = firstName
        self.lastName          = lastName
        self.gender            = gender
        self.dob               = dob
        self.email             = email
        self.countryCode       = countryCode
        self.phoneNumber       = phoneNumber
        self.profileImageBase64 = profileImageBase64
    }
}

@MainActor
class DatabaseManager: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var currentUserProfile: UserProfile?

    private let db = Firestore.firestore()

    // MARK: - User Profiles

    func saveUserProfile(_ profile: UserProfile) throws {
        try db.collection("users").document(profile.uid).setData(from: profile)
    }

    func updateUserProfile(_ profile: UserProfile) throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
        self.currentUserProfile = profile
    }

    func fetchUserProfile(uid: String) {
        // Real-time listener: instantly snaps the UI into place when Google finishes saving
        db.collection("users").document(uid).addSnapshotListener { snapshot, _ in
            do {
                if let data = try snapshot?.data(as: UserProfile.self) {
                    self.currentUserProfile = data
                }
            } catch {
                print("[DB] UserProfile decode error: \(error)")
                // Emergency fallback to prevent infinite loading spinner
                self.currentUserProfile = UserProfile(uid: uid, firstName: "User", lastName: "", gender: "Not Specified", dob: Date(), email: "", countryCode: "+44", phoneNumber: "")
            }
        }
    }

    // MARK: - Subscriptions

    func fetchSubscriptions(for userId: String?) {
        guard let userId = userId, !userId.isEmpty else { return }
        db.collection("subscriptions")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("[DB] Fetch error: \(error.localizedDescription)")
                    return
                }
                self.subscriptions = querySnapshot?.documents.compactMap { document in
                    var sub = try? document.data(as: Subscription.self)
                    sub?.id = document.documentID
                    return sub
                } ?? []
                NotificationManager.shared.scheduleNotifications(for: self.subscriptions)
            }
    }

    func addSubscription(_ subscription: Subscription) throws {
        let isDuplicate = subscriptions.contains {
            $0.providerName.lowercased() == subscription.providerName.lowercased() && $0.cost == subscription.cost
        }
        
        if isDuplicate {
            throw NSError(domain: "GhostSub", code: 1, userInfo: [NSLocalizedDescriptionKey: "A subscription with this name and price already exists."])
        }

        var fresh = subscription
        fresh.id = nil
        try db.collection("subscriptions").addDocument(from: fresh)
    }

    func updateSubscription(_ subscription: Subscription) throws {
        guard let documentId = subscription.id, !documentId.isEmpty else { return }
        var updated = subscription
        updated.lastUpdatedAt = Date()
        try db.collection("subscriptions")
            .document(documentId)
            .setData(from: updated, merge: false)
    }

    func softDeleteSubscription(_ subscription: Subscription) {
        guard let documentId = subscription.id, !documentId.isEmpty else { return }
        db.collection("subscriptions").document(documentId)
            .updateData(["status": "Deleted", "lastUpdatedAt": Timestamp(date: Date())])
    }

    func permanentDeleteSubscription(subscriptionId: String?) {
        guard let documentId = subscriptionId, !documentId.isEmpty else { return }
        db.collection("subscriptions").document(documentId).delete()
    }
}
