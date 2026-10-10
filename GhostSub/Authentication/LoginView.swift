import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dbManager = DatabaseManager()
    @Binding var currentScreen: AppScreen
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 25) {
            
            // MARK: - Header with Logo
            VStack(spacing: 15) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                
                Text("GhostSub")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                
                Text("Protect your budget from dark patterns.")
                    .font(.custom("AvenirNext-Italic", size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            // MARK: - Inputs
            VStack(spacing: 15) {
                TextField("@gmail.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).font(.footnote).multilineTextAlignment(.center)
            }
            
            // MARK: - Actions
            VStack(spacing: 15) {
                // Standard Email Sign In
                Button(action: { Task { await handleSignIn() } }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.primary).frame(height: 50)
                        if isLoading { ProgressView().tint(.white) }
                        else { Text("Sign In").foregroundColor(Color(UIColor.systemBackground)).fontWeight(.semibold) }
                    }
                }
                .buttonStyle(PressableButtonStyle())
                
                // Google Sign In Button
                Button(action: { handleGoogleSignIn() }) {
                    HStack {
                        Image(systemName: "g.circle.fill").foregroundColor(.red)
                        Text("Continue with Google").fontWeight(.semibold).foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                
                Button(action: { withAnimation { currentScreen = .register } }) {
                    Text("Create Account").fontWeight(.medium).foregroundColor(.primary)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 5)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // Standard Email Login
    func handleSignIn() async {
        isLoading = true
        errorMessage = ""
        
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        do {
            try await authManager.signIn(email: cleanEmail, password: password)
            withAnimation { currentScreen = .dashboard }
        } catch {
            errorMessage = "The password or the username is incorrect"
        }
        
        isLoading = false
    }
    
    // Google Sign In & Deep Profile Extraction
    func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                if let uid = authResult?.user.uid {
                    // Extracting all available Google Profile details
                    let givenName = user.profile?.givenName ?? "User"
                    let familyName = user.profile?.familyName ?? ""
                    let email = user.profile?.email ?? ""
                    
                    // Firebase attempts to pull phone numbers if public, but usually nil for privacy
                    let phoneString = authResult?.user.phoneNumber ?? ""
                    
                    // Grab the high-res Google profile picture URL
                    let imageURL = user.profile?.imageURL(withDimension: 400)
                    
                    Task {
                        var base64Image: String? = nil
                        
                        // Download the image securely and convert it to Base64 so it fits your database instantly
                        if let url = imageURL {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                base64Image = data.base64EncodedString()
                            } catch {
                                print("Failed to download Google profile picture: \(error)")
                            }
                        }
                        
                        let newProfile = UserProfile(
                            uid: uid,
                            firstName: givenName,
                            lastName: familyName,
                            gender: "Not Specified", // Restricted by Google OAuth standard
                            dob: Date(),
                            email: email,
                            countryCode: "+44",
                            phoneNumber: phoneString,
                            profileImageBase64: base64Image // The downloaded image is injected here
                        )
                        
                        // Safely merge the profile into Firestore
                        try? dbManager.updateUserProfile(newProfile)
                        
                        await MainActor.run {
                            withAnimation { currentScreen = .dashboard }
                        }
                    }
                }
            }
        }
    }
}
