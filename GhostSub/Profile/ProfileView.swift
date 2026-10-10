import SwiftUI
import PhotosUI
import FirebaseAuth

let profileThemePurple = Color(red: 0.38, green: 0.21, blue: 1.0)

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var dbManager: DatabaseManager
    @Binding var currentScreen: AppScreen
    @AppStorage("themePreference") var themePreference: Int = 0
    
    @State private var isEditing = false
    @State private var showingFullImage = false
    
    // Edit Form States
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var editPhone = ""
    @State private var editGender = ""
    
    // Photo Picker
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    
    // Community Alerts
    @State private var showingSupportAlert = false
    @State private var showingInviteAlert = false
    
    let genders = ["Male", "Female", "Else", "Not Specified"]
    
    var body: some View {
        NavigationView {
            List {
                if let profile = dbManager.currentUserProfile {
                    Section {
                        HStack(spacing: 15) {
                            
                            // Avatar Image Logic
                            ZStack {
                                Circle().fill(profileThemePurple.opacity(0.1)).frame(width: 70, height: 70)
                                
                                if let photoData = profile.profileImageBase64, let uiImage = UIImage(data: Data(base64Encoded: photoData) ?? Data()) {
                                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 70, height: 70).clipShape(Circle())
                                } else if let pendingData = profileImageData, let uiImage = UIImage(data: pendingData) {
                                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 70, height: 70).clipShape(Circle())
                                } else {
                                    Text(String(profile.firstName.prefix(1))).font(.title).bold().foregroundColor(profileThemePurple)
                                }
                                
                                if isEditing {
                                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                        Circle().fill(Color.black.opacity(0.5)).frame(width: 70, height: 70)
                                            .overlay(Image(systemName: "camera.fill").foregroundColor(.white))
                                    }
                                    .onChange(of: selectedItem) { oldValue, newValue in
                                        Task {
                                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                                profileImageData = data
                                            }
                                        }
                                    }
                                } else {
                                    Button(action: { showingFullImage = true }) {
                                        Circle().fill(Color.clear).frame(width: 70, height: 70)
                                    }
                                }
                            }
                            
                            if isEditing {
                                VStack {
                                    TextField("First Name", text: $editFirstName).textFieldStyle(RoundedBorderTextFieldStyle())
                                    TextField("Last Name", text: $editLastName).textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(profile.firstName) \(profile.lastName)").font(.title3).fontWeight(.bold)
                                    Text(profile.email).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        DisclosureGroup("Account Details") {
                            HStack { Text("Email"); Spacer(); Text(profile.email).foregroundColor(.secondary) }
                            if isEditing {
                                HStack { Text("Phone"); Spacer(); TextField("Phone", text: $editPhone).multilineTextAlignment(.trailing) }
                                HStack {
                                    Text("Gender")
                                    Spacer()
                                    Picker("", selection: $editGender) {
                                        ForEach(genders, id: \.self) { Text($0) }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                            } else {
                                HStack { Text("Phone"); Spacer(); Text("\(profile.countryCode) \(profile.phoneNumber)").foregroundColor(.secondary) }
                                HStack { Text("Gender"); Spacer(); Text(profile.gender).foregroundColor(.secondary) }
                            }
                        }
                    }
                } else {
                    Section { ProgressView("Loading Profile...") }
                }
                
                Section(header: Text("App Settings")) {
                    Picker("Appearance", selection: $themePreference) {
                        Text("System").tag(0); Text("Light").tag(1); Text("Dark").tag(2)
                    }.pickerStyle(SegmentedPickerStyle()).padding(.vertical, 5)
                }
                
                Section(header: Text("Ghost Community")) {
                    Button(action: { showingSupportAlert = true }) { Label("Ghost Support", systemImage: "questionmark.bubble.fill").foregroundColor(.primary) }
                    Button(action: { showingInviteAlert = true }) {
                        HStack {
                            Label("Invite Friends", systemImage: "gift.fill").foregroundColor(.primary)
                            Spacer()
                            Text("Earn £5").font(.caption).bold().foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 5).background(Color.green).cornerRadius(8)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        try? authManager.signOut()
                        withAnimation { currentScreen = .login }
                    }) {
                        Text("Sign Out").fontWeight(.bold).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing, var profile = dbManager.currentUserProfile {
                            profile.firstName = editFirstName
                            profile.lastName = editLastName
                            profile.phoneNumber = editPhone
                            profile.gender = editGender
                            if let photoData = profileImageData {
                                profile.profileImageBase64 = photoData.base64EncodedString()
                            }
                            try? dbManager.updateUserProfile(profile)
                        } else if let profile = dbManager.currentUserProfile {
                            editFirstName = profile.firstName
                            editLastName = profile.lastName
                            editPhone = profile.phoneNumber
                            editGender = profile.gender
                        }
                        isEditing.toggle()
                    }
                }
            }
            .alert("Ghost Support", isPresented: $showingSupportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Our support team will be available 24/7 once the app launches!")
            }
            .alert("Invite Friends", isPresented: $showingInviteAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Referral links will be generated in the final release.")
            }
            .fullScreenCover(isPresented: $showingFullImage) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let profile = dbManager.currentUserProfile,
                       let photoData = profile.profileImageBase64,
                       let uiImage = UIImage(data: Data(base64Encoded: photoData) ?? Data()) {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                    } else if let pendingData = profileImageData,
                              let uiImage = UIImage(data: pendingData) {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                    } else {
                        Image(systemName: "person.circle.fill").resizable().scaledToFit().foregroundColor(.gray).padding(40)
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button("Close") { showingFullImage = false }
                                .padding().foregroundColor(.white).font(.headline)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
