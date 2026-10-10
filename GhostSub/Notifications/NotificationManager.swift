import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("[NotificationManager] Permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotifications(for subscriptions: [Subscription]) {
        let center = UNUserNotificationCenter.current()
        
        // Clear existing notifications to prevent duplicates or alerts for deleted items
        center.removeAllPendingNotificationRequests()
        
        for sub in subscriptions {
            guard sub.status == "Active" else { continue }
            
            let costString = CurrencyHelper.format(sub.cost, currency: sub.currency)
            let baseId = sub.id ?? UUID().uuidString
            
            // --- 72 Hour Notification ---
            if let date72 = Calendar.current.date(byAdding: .hour, value: -72, to: sub.renewalDate), date72 > Date() {
                let content72 = UNMutableNotificationContent()
                content72.title = "Renews in 3 Days: \(sub.providerName)"
                content72.body = "Your \(costString) subscription renews in 72 hours."
                content72.sound = .default
                
                let components72 = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date72)
                let trigger72 = UNCalendarNotificationTrigger(dateMatching: components72, repeats: false)
                let request72 = UNNotificationRequest(identifier: "\(baseId)-72h", content: content72, trigger: trigger72)
                
                center.add(request72)
            }
            
            // --- 48 Hour Notification ---
            if let date48 = Calendar.current.date(byAdding: .hour, value: -48, to: sub.renewalDate), date48 > Date() {
                let content48 = UNMutableNotificationContent()
                content48.title = "Renews in 2 Days: \(sub.providerName)"
                content48.body = "Your subscription for \(costString) will auto-renew in 48 hours. Review it now."
                content48.sound = .default
                
                let components48 = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date48)
                let trigger48 = UNCalendarNotificationTrigger(dateMatching: components48, repeats: false)
                let request48 = UNNotificationRequest(identifier: "\(baseId)-48h", content: content48, trigger: trigger48)
                
                center.add(request48)
            }
            
            // --- 24 Hour Notification ---
            if let date24 = Calendar.current.date(byAdding: .hour, value: -24, to: sub.renewalDate), date24 > Date() {
                let content24 = UNMutableNotificationContent()
                content24.title = "Renews Tomorrow: \(sub.providerName)"
                content24.body = "Your \(costString) subscription renews in 24 hours. Cancel now to avoid being charged."
                content24.sound = .default
                
                let components24 = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date24)
                let trigger24 = UNCalendarNotificationTrigger(dateMatching: components24, repeats: false)
                let request24 = UNNotificationRequest(identifier: "\(baseId)-24h", content: content24, trigger: trigger24)
                
                center.add(request24)
            }
        }
    }
}
