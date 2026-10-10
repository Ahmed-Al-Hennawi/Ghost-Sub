//
//  GhostSubApp.swift
//  GhostSub
//
//  Created by USER on 01/06/2026.
//

import SwiftUI
import FirebaseCore

import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Set notification delegate to present in foreground
    UNUserNotificationCenter.current().delegate = self
    
    // Request notification permissions
    NotificationManager.shared.requestPermission()
    
    return true
  }
  
  // Allow notifications to appear while the app is in the foreground
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.banner, .sound, .badge])
  }
}

@main
struct GhostSubApp: App { // Make sure this matches your app name
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // We create the auth manager here...
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // ...and we inject it into ContentView so the whole app can use it!
                .environmentObject(authManager)
        }
    }
}
