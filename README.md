# 👻 GhostSub

> **Privacy-First Subscription Tracking for iOS**
>
> Never get surprised by an auto-renewal again.

**Repository:**  https://git.arts.ac.uk/a-alhennawi0520251/GhostSub

---

## 📱 Overview

GhostSub is a privacy-first subscription tracker built to protect users from dark patterns, hidden renewals, and unwanted recurring charges.

Unlike traditional subscription managers that require invasive access to your email inbox, GhostSub allows users to simply upload a screenshot of a subscription receipt. Using Apple's on-device OCR technology, the app extracts relevant subscription details and automatically creates a personalized financial dashboard.

GhostSub acts as a proactive financial shield by warning users before upcoming charges and providing direct access to cancellation pages.

---

## ✨ Features

### 🔍 On-Device OCR
- Powered by Apple's Vision Framework
- Extracts subscription details from screenshots
- No receipt images are uploaded to external servers
- Fast, private, and secure

### 📊 Smart Subscription Dashboard
- Track all active subscriptions in one place
- View monthly and annual spending totals
- Supports:
  - Weekly Billing
  - Monthly Billing
  - Yearly Billing

### 🔔 Proactive Renewal Alerts
Receive local notifications:

- 72 Hours Before Renewal
- 48 Hours Before Renewal
- 24 Hours Before Renewal

Helping users avoid unwanted charges before they happen.

### 🚪 Direct Cancellation Access
GhostSub provides direct links to cancellation pages, helping users bypass confusing user interfaces and dark-pattern tactics.

### ☁️ Secure Cloud Sync
- Firebase Firestore integration
- Real-time synchronization across devices
- Automatic data persistence

### 🔐 Authentication
Supports:

- Email & Password Authentication
- Google OAuth Sign-In

---

## 🏗️ Architecture

### OCR Pipeline

```text
Screenshot
    ↓
Vision Framework OCR
    ↓
Text Recognition
    ↓
Regex Parsing
    ↓
Subscription Model
    ↓
Dashboard
```

`ScanViewModel` communicates with Apple's `VNRecognizeTextRequest` to extract text from uploaded screenshots.

The resulting text is parsed using deterministic pattern matching to identify:

- Provider Name
- Price
- Billing Frequency
- Renewal Date

---

### Data Layer

`DatabaseManager` handles:

- Firestore CRUD Operations
- Real-Time Listeners
- Authentication State
- Data Synchronization

Additional safeguards include:

- Deterministic Hashing
- Backward Compatibility Support
- Safe Decoding via `decodeIfPresent()`

---

### UI Layer

Built entirely with SwiftUI.

Main Views:

- DashboardView
- SubsTabView
- ProfileView
- ScanView

State persistence is managed using:

- @StateObject
- @Published
- @AppStorage

---

## 🛠️ Technology Stack

| Layer | Technology |
|---------|------------|
| Language | Swift |
| UI Framework | SwiftUI |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| OCR | Vision Framework |
| Notifications | UserNotifications |
| Image Picker | PhotosUI |
| Architecture | MVVM |

---

## 🔒 Privacy First

GhostSub follows a **Zero-Leak Philosophy**.

### What Stays On Device

✅ Receipt Screenshots

✅ OCR Processing

✅ Raw Receipt Text

### What Can Be Synced

Only user-approved metadata:

- Subscription Provider
- Cost
- Renewal Date
- Billing Frequency

No screenshots are uploaded.

No inbox access is required.

No sensitive financial documents leave the device.

---

## 🚀 Installation

### Requirements

- macOS Sonoma or newer
- Xcode 16+
- iOS 26.0+
- Firebase Project

### Setup

1. Clone the repository

```bash
git clone https://git.arts.ac.uk/a-alhennawi0520251/GhostSub
```

2. Install Firebase SDK

Using:

- Swift Package Manager (Recommended)
- CocoaPods

3. Add Firebase Configuration

Place:

```text
GoogleService-Info.plist
```

inside the Xcode project root.

4. Open Project

```text
GhostSub.xcodeproj
```

or

```text
GhostSub.xcworkspace
```

5. Build & Run

Run on:

- Physical Device
- iOS Simulator

---

## 📂 Project Structure

```text
## 📂 Project Structure


GhostSub
│
├── GhostSubApp.swift                # App entry point
├── ContentView.swift                # Root navigation view
│
├── Authentication
│   ├── LoginView.swift
│   ├── RegisterView.swift
│   └── AuthManager.swift
│
├── Dashboard
│   └── DashboardView.swift
│
├── Subscriptions
│   ├── Subscription.swift
│   ├── AddEditSubscriptionView.swift
│   ├── SubscriptionDetailView.swift
│   └── DatabaseManager.swift
│
├── OCR & Scanning
│   ├── ScanTabView.swift
│   ├── ScanViewModel.swift
│   ├── OCRService.swift
│   └── SubscriptionParserService.swift
│
├── Notifications
│   └── NotificationManager.swift
│
├── Profile
│   └── ProfileView.swift
│
├── Utilities
│   ├── CurrencyHelper.swift
│   └── AppStyles.swift
│
├── Assets.xcassets
│   
│
├── Firebase
│   └── GoogleService-Info.plist
│
└── Dependencies
    ├── Firebase Authentication
    ├── Cloud Firestore
    ├── Google Sign-In
    ├── Vision Framework
    ├── PhotosUI
    └── UserNotifications
```

---

## 🎯 Mission

GhostSub was created to help users regain control over recurring payments.

The app focuses on:

- Transparency
- User Control
- Financial Awareness
- Privacy Protection

without sacrificing convenience.

---

## 🛣️ Future Roadmap

- [ ] Subscription detection improvements
- [ ] Multiple screenshot batch scanning
- [ ] Spending analytics and trends
- [ ] Budget planning tools
- [ ] Subscription sharing for families
- [ ] Apple Watch companion app
- [ ] Multi-currency support
- [ ] App Store release

---

## 🤝 Contributing

Contributions, feature suggestions, and bug reports are welcome.

Please open an issue or submit a pull request.

---

## 📄 License

This project is currently proprietary.

If GhostSub becomes open source in the future, an appropriate license will be added.
