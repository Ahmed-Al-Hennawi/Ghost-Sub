import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUserSession: FirebaseAuth.User?
    
    init() {
        self.currentUserSession = Auth.auth().currentUser
    }
    
    // Secure Registration
    func register(email: String, password: String) async throws {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUserSession = authResult.user
    }
    
    // Secure Login
    func signIn(email: String, password: String) async throws {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUserSession = authResult.user
    }
    
    // Log Out
    func signOut() throws {
        try Auth.auth().signOut()
        self.currentUserSession = nil
    }
}
