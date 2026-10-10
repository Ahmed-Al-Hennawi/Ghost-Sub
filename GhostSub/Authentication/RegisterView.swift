import SwiftUI
import FirebaseAuth

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dbManager = DatabaseManager()
    @Binding var currentScreen: AppScreen
    
    // Form States
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = "Male"
    @State private var dob = Date()
    @State private var email = ""
    @State private var countryCode = "+44"
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    @State private var missingFieldsMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    let genders = ["Male", "Female", "Else"]
    
    // Explicitly includes +970 and omits +972
    let countryCodes = ["+44", "+1", "+970", "+61", "+49", "+33", "+81", "+971", "+966", "+91", "+34", "+39"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Account").font(.largeTitle).bold().padding(.top, 40)
                
                if !successMessage.isEmpty { Text(successMessage).foregroundColor(.green).fontWeight(.bold) }
                if !missingFieldsMessage.isEmpty { Text(missingFieldsMessage).foregroundColor(.red).font(.footnote).fontWeight(.semibold) }
                
                VStack(spacing: 15) {
                    HStack {
                        TextField("First Name", text: $firstName).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                        TextField("Last Name", text: $lastName).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }.pickerStyle(SegmentedPickerStyle())
                    
                    DatePicker("Date of Birth", selection: $dob, displayedComponents: .date).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    
                    TextField("@gmail.com", text: $email)
                        .autocapitalization(.none).keyboardType(.emailAddress).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    
                    HStack {
                        Picker("Code", selection: $countryCode) {
                            ForEach(countryCodes, id: \.self) { code in Text(code).tag(code) }
                        }
                        .frame(width: 90).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.numberPad).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    }
                    
                    SecureField("Password", text: $password).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        CheckRow(title: "At least 8 characters", isMet: password.count >= 8)
                        CheckRow(title: "At least 1 number", isMet: password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil)
                        CheckRow(title: "At least 1 capital letter", isMet: password.range(of: ".*[A-Z]+.*", options: .regularExpression) != nil)
                        CheckRow(title: "At least 1 special character", isMet: password.range(of: ".*[!@#$%^&*()_+{}|:\"<>?]+.*", options: .regularExpression) != nil)
                    }.padding(.horizontal, 5)
                    
                    SecureField("Confirm Password", text: $confirmPassword).padding().background(Color(UIColor.systemGray6)).cornerRadius(8)
                    if !confirmPassword.isEmpty && password != confirmPassword { Text("Passwords do not match").foregroundColor(.red).font(.caption) }
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 15) {
                    Button(action: { Task { await registerUser() } }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.primary).frame(height: 50)
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Register").foregroundColor(Color(UIColor.systemBackground)).fontWeight(.bold) }
                        }
                    }.buttonStyle(PressableButtonStyle())
                    
                    Button("Back to Login") { withAnimation { currentScreen = .login } }.foregroundColor(.secondary)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }
    
    func registerUser() async {
        missingFieldsMessage = ""
        if firstName.isEmpty || lastName.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            missingFieldsMessage = "Please fill in all fields. Every field is mandatory."
            return
        }
        
        let hasNum = password.range(of: ".*[0-9]+.*", options: .regularExpression) != nil
        let hasCap = password.range(of: ".*[A-Z]+.*", options: .regularExpression) != nil
        let hasSpec = password.range(of: ".*[!@#$%^&*()_+{}|:\"<>?]+.*", options: .regularExpression) != nil
        if password.count < 8 || !hasNum || !hasCap || !hasSpec { return }
        if password != confirmPassword { return }
        
        isLoading = true
        do {
            try await authManager.register(email: email, password: password)
            if let uid = authManager.currentUserSession?.uid {
                let profile = UserProfile(uid: uid, firstName: firstName, lastName: lastName, gender: gender, dob: dob, email: email, countryCode: countryCode, phoneNumber: phoneNumber)
                try dbManager.saveUserProfile(profile)
            }
            successMessage = "Created successfully!"
            try await authManager.signOut()
            try await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { currentScreen = .login }
        } catch {
            missingFieldsMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct CheckRow: View {
    let title: String
    let isMet: Bool
    var body: some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundColor(isMet ? .green : .gray)
            Text(title).font(.caption).foregroundColor(isMet ? .primary : .gray)
        }
    }
}
