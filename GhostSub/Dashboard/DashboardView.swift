import SwiftUI
import FirebaseAuth

// MARK: - Global Design System
let themePurple = Color(red: 0.38, green: 0.21, blue: 1.0)
let bgGray = Color(UIColor.systemGroupedBackground)

enum AppTab: String, CaseIterable {
    case home = "house.fill"
    case scan = "viewfinder.circle.fill"
    case subs = "square.stack.3d.up.fill"
    case account = "person.crop.circle.fill"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .scan: return "Scan"
        case .subs: return "Subs"
        case .account: return "Account"
        }
    }
}

// MARK: - Notification Data Model
struct AppNotif: Identifiable {
    let id: String
    let sub: Subscription
    let title: String
    let message: String
    let timeAgo: Date
}

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var dbManager = DatabaseManager()
    @Binding var currentScreen: AppScreen
    
    @State private var selectedTab: AppTab = .home
    @State private var isTabBarHidden = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeTabView(dbManager: dbManager, selectedTab: $selectedTab, isTabBarHidden: $isTabBarHidden)
                case .scan:
                    ScanTabView(dbManager: dbManager)
                case .subs:
                    SubsTabView(dbManager: dbManager, isTabBarHidden: $isTabBarHidden)
                case .account:
                    ProfileView(dbManager: dbManager, currentScreen: $currentScreen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if !isTabBarHidden {
                FloatingTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .onAppear {
            if let uid = authManager.currentUserSession?.uid {
                dbManager.fetchSubscriptions(for: uid)
                dbManager.fetchUserProfile(uid: uid)
            }
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == tab ? themePurple : .gray)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? themePurple : .gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }
}

// MARK: - PREMIUM SUBS TAB
struct SubsTabView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Binding var isTabBarHidden: Bool
    
    @State private var selectedSub: Subscription?
    @State private var scrollOffset: CGFloat = 0
    @State private var showingAddSheet = false
    @State private var showingNotifications = false
    @State private var showingPrivacyAlert = false
    
    @State private var selectedFilter = "All"
    @State private var selectedSort = "Renewal Date" // Default set to Renewal Date
    
    // Tracks notifications the user has swiped away
    @AppStorage("dismissedNotifs") var dismissedNotifs: String = ""
    
    let filters = ["All", "Active", "Cancelled", "Expired"]
    let sortOptions = ["Renewal Date", "Newest", "Oldest", "Price High → Low", "Price Low → High"]
    
    // PERFECT MATH: Uses the normalized function for accurate dashboards
    var monthlyTotal: Double { dbManager.subscriptions.reduce(0) { $0 + $1.normalizedMonthlyCost } }
    var yearlyTotal: Double { monthlyTotal * 12 }
    
    var renewsSoonCount: Int { dbManager.subscriptions.filter { daysUntil($0.renewalDate) <= 2 }.count }
    
    var filteredAndSortedSubs: [Subscription] {
        var result = dbManager.subscriptions
        if selectedFilter != "All" { result = result.filter { $0.status == selectedFilter } }
        switch selectedSort {
        case "Price High → Low": result.sort { $0.normalizedMonthlyCost > $1.normalizedMonthlyCost }
        case "Price Low → High": result.sort { $0.normalizedMonthlyCost < $1.normalizedMonthlyCost }
        case "Renewal Date":    result.sort { $0.renewalDate < $1.renewalDate }
        case "Newest":          result.sort { $0.createdAt > $1.createdAt }
        case "Oldest":          result.sort { $0.createdAt < $1.createdAt }
        default: break
        }
        return result
    }
    
    // MARK: Dynamic In-App Notification Engine
    var activeNotifs: [AppNotif] {
        var notifs: [AppNotif] = []
        let now = Date()
        let dismissedList = dismissedNotifs.components(separatedBy: ",").filter { !$0.isEmpty }
        
        for sub in dbManager.subscriptions {
            guard sub.status == "Active", let subId = sub.id else { continue }
            
            guard let d72 = Calendar.current.date(byAdding: .hour, value: -72, to: sub.renewalDate),
                  let d48 = Calendar.current.date(byAdding: .hour, value: -48, to: sub.renewalDate),
                  let d24 = Calendar.current.date(byAdding: .hour, value: -24, to: sub.renewalDate) else { continue }
            
            let costString = CurrencyHelper.format(sub.cost, currency: sub.currency)
            
            if now >= d24 && now < sub.renewalDate {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-24h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews Tomorrow", message: "\(sub.providerName) will charge \(costString) in 24 hours.", timeAgo: d24)) }
            } else if now >= d48 && now < d24 {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-48h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews in 2 Days", message: "\(sub.providerName) will renew for \(costString) in 48 hours.", timeAgo: d48)) }
            } else if now >= d72 && now < d48 {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-72h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews in 3 Days", message: "Your \(costString) subscription for \(sub.providerName) renews soon.", timeAgo: d72)) }
            }
        }
        return notifs.sorted { $0.timeAgo > $1.timeAgo }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                GeometryReader { proxy -> Color in
                    let offset = proxy.frame(in: .global).minY
                    DispatchQueue.main.async {
                        if offset < scrollOffset - 10 { withAnimation(.easeOut(duration: 0.3)) { isTabBarHidden = true } }
                        else if offset > scrollOffset + 10 { withAnimation(.easeIn(duration: 0.3)) { isTabBarHidden = false } }
                        scrollOffset = offset
                    }
                    return Color.clear
                }.frame(height: 0)
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscriptions").font(.largeTitle).bold().foregroundColor(.primary)
                            Text("Manage your subscriptions all in one place").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: { showingAddSheet = true }) {
                                Image(systemName: "plus").font(.title3).foregroundColor(.primary)
                                    .padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                            }
                            Button(action: { showingNotifications = true }) {
                                Image(systemName: "bell").font(.title3).foregroundColor(.primary)
                                    .padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                                    .overlay(
                                        Group {
                                            if !activeNotifs.isEmpty {
                                                Circle().fill(themePurple).frame(width: 8, height: 8).offset(x: 8, y: -8)
                                            }
                                        }
                                    )
                            }
                        }
                    }
                    
                    HStack(spacing: 0) {
                        MetricColumn(icon: "creditcard.fill", value: "\(dbManager.subscriptions.count)", label: "Active", isActive: true)
                        MetricColumn(icon: "chart.line.uptrend.xyaxis", value: CurrencyHelper.format(monthlyTotal, currency: "GBP"), label: "Monthly spend", isActive: false)
                        MetricColumn(icon: "calendar.badge.clock", value: "\(renewsSoonCount)", label: "Renews soon", isActive: false)
                        MetricColumn(icon: "tag.fill", value: CurrencyHelper.format(yearlyTotal, currency: "GBP"), label: "Yearly spend", isActive: false)
                    }
                    .padding(.vertical, 20).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filters, id: \.self) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    Text(filter).font(.caption).bold()
                                        .foregroundColor(selectedFilter == filter ? themePurple : .secondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selectedFilter == filter ? themePurple.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                }
                            }
                            
                            Menu {
                                ForEach(sortOptions, id: \.self) { option in
                                    Button(option) { selectedSort = option }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease")
                                    Text(selectedSort)
                                    Image(systemName: "chevron.down")
                                }
                                .font(.caption).bold().foregroundColor(.primary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    if filteredAndSortedSubs.isEmpty {
                        Text("No subscriptions found.").padding().frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            // OVERWRITE FIX: id: \.self strictly separates items
                            ForEach(filteredAndSortedSubs, id: \.self) { sub in
                                Button(action: { selectedSub = sub }) {
                                    RenewalRow(sub: sub)
                                        .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    HStack(spacing: 15) {
                        Image(systemName: "shield.checkered").font(.title).foregroundColor(themePurple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("We've got you covered").font(.subheadline).bold().foregroundColor(.primary)
                            Text("Your data is private and secure.").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Learn more") { showingPrivacyAlert = true }
                            .font(.caption).bold().foregroundColor(themePurple).padding(.horizontal, 12).padding(.vertical, 6).overlay(RoundedRectangle(cornerRadius: 8).stroke(themePurple.opacity(0.3), lineWidth: 1))
                    }
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).padding(.top, 10)
                    
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal).padding(.top, 10)
            }
            .background(bgGray.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                // Un-hides Tab Bar and refreshes data on pull-down
                withAnimation(.easeIn(duration: 0.3)) { isTabBarHidden = false }
                if let uid = dbManager.currentUserProfile?.uid {
                    dbManager.fetchSubscriptions(for: uid)
                }
            }
            .sheet(item: $selectedSub) { sub in
                SubscriptionDetailView(subscription: sub, dbManager: dbManager)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditSubscriptionView(dbManager: dbManager)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationCenterView(notifications: activeNotifs, dismissedNotifs: $dismissedNotifs)
            }
            .alert("Data Privacy", isPresented: $showingPrivacyAlert) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Your data is strictly private. We use entirely on-device processing, meaning no sensitive screenshot or email data ever leaves your phone.")
            }
        }
    }
    func daysUntil(_ date: Date) -> Int {
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
    }
}

// Sub-component for the top 4 stats
struct MetricColumn: View {
    let icon: String; let value: String; let label: String; let isActive: Bool
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(themePurple.opacity(0.6)).frame(height: 30)
            Text(value).font(.headline).bold().minimumScaleFactor(0.7).lineLimit(1)
            VStack(spacing: 4) {
                Text(label).font(.caption2).foregroundColor(.secondary).minimumScaleFactor(0.7).lineLimit(1)
                if isActive { Rectangle().fill(themePurple).frame(width: 30, height: 2).cornerRadius(1) }
                else { Rectangle().fill(Color.clear).frame(height: 2) }
            }
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - HomeTabView
struct HomeTabView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Binding var selectedTab: AppTab
    @Binding var isTabBarHidden: Bool
    
    @State private var selectedMonth = Date().formatted(.dateTime.month())
    @State private var scrollOffset: CGFloat = 0
    @State private var showingNotifications = false
    @State private var showingBudgetAlert = false
    @State private var editingBudget: String = ""
    @State private var selectedSub: Subscription?
    @State private var showingInvalidBudgetAlert = false
    @AppStorage("monthlyBudget") var monthlyBudget: Double = 150.0
    
    @AppStorage("dismissedNotifs") var dismissedNotifs: String = ""
    
    var safeMonthlyBudget: Double { monthlyBudget > 0 ? monthlyBudget : 150.0 }
    
    // PERFECT CALENDAR PROJECTION LOGIC
    var filteredHomeSubscriptions: [Subscription] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let shortMonths = Calendar.current.shortMonthSymbols
        guard let targetMonthIndex = shortMonths.firstIndex(of: selectedMonth) else { return [] }
        let targetMonth = targetMonthIndex + 1
        
        return dbManager.subscriptions.filter { sub in
            let subMonth = Calendar.current.component(.month, from: sub.renewalDate)
            let createdMonth = Calendar.current.component(.month, from: sub.createdAt)
            let createdYear = Calendar.current.component(.year, from: sub.createdAt)
            
            // 1. Exclude if target month is before the subscription even existed (in the current year)
            if currentYear == createdYear && targetMonth < createdMonth {
                return false
            }
            
            // 2. Base match: Exact renewal month matches selected month
            if subMonth == targetMonth {
                return true
            }
            
            // 3. Projection: If it's active and recurs, project it into valid future/past months
            if sub.status == "Active" {
                switch sub.billingFrequency {
                case "Monthly", "Weekly":
                    return true // Occurs every month
                
                default:
                    return false // Yearly only appears in its exact month
                }
            }
            return false
        }.sorted { $0.renewalDate < $1.renewalDate }
    }
    
    // PERFECT MATH
    var monthlyTotal: Double { filteredHomeSubscriptions.reduce(0) { $0 + $1.normalizedMonthlyCost } }
    var budgetPercentage: Double { monthlyTotal / safeMonthlyBudget }
    
    var firstName: String { dbManager.currentUserProfile?.firstName ?? "" }
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, \(firstName)" }
        if hour < 17 { return "Good afternoon, \(firstName)" }
        return "Good evening, \(firstName)"
    }
    
    var highestExpenseSub: Subscription? {
        filteredHomeSubscriptions.max(by: { $0.normalizedMonthlyCost < $1.normalizedMonthlyCost })
    }
    
    var insightMessage: String {
        if filteredHomeSubscriptions.isEmpty { return "No subscriptions for this month." }
        if let highest = highestExpenseSub {
            return "Insight: \(highest.providerName) is your highest expense at £\(String(format: "%.2f", highest.normalizedMonthlyCost))."
        }
        return "You're on track!"
    }
    
    var activeNotifs: [AppNotif] {
        var notifs: [AppNotif] = []
        let now = Date()
        let dismissedList = dismissedNotifs.components(separatedBy: ",").filter { !$0.isEmpty }
        
        for sub in dbManager.subscriptions {
            guard sub.status == "Active", let subId = sub.id else { continue }
            
            guard let d72 = Calendar.current.date(byAdding: .hour, value: -72, to: sub.renewalDate),
                  let d48 = Calendar.current.date(byAdding: .hour, value: -48, to: sub.renewalDate),
                  let d24 = Calendar.current.date(byAdding: .hour, value: -24, to: sub.renewalDate) else { continue }
            
            let costString = CurrencyHelper.format(sub.cost, currency: sub.currency)
            
            if now >= d24 && now < sub.renewalDate {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-24h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews Tomorrow", message: "\(sub.providerName) will charge \(costString) in 24 hours.", timeAgo: d24)) }
            } else if now >= d48 && now < d24 {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-48h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews in 2 Days", message: "\(sub.providerName) will renew for \(costString) in 48 hours.", timeAgo: d48)) }
            } else if now >= d72 && now < d48 {
                let id = "\(subId)-\(sub.renewalDate.timeIntervalSince1970)-72h"
                if !dismissedList.contains(id) { notifs.append(AppNotif(id: id, sub: sub, title: "Renews in 3 Days", message: "Your \(costString) subscription for \(sub.providerName) renews soon.", timeAgo: d72)) }
            }
        }
        return notifs.sorted { $0.timeAgo > $1.timeAgo }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                GeometryReader { proxy -> Color in
                    let offset = proxy.frame(in: .global).minY
                    DispatchQueue.main.async {
                        if offset < scrollOffset - 10 { withAnimation(.easeOut(duration: 0.3)) { isTabBarHidden = true } }
                        else if offset > scrollOffset + 10 { withAnimation(.easeIn(duration: 0.3)) { isTabBarHidden = false } }
                        scrollOffset = offset
                    }
                    return Color.clear
                }.frame(height: 0)
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting).font(.title2).bold().foregroundColor(.primary).minimumScaleFactor(0.8).lineLimit(1)
                            Text("Here's your subscription overview").font(.subheadline).foregroundColor(.secondary).minimumScaleFactor(0.8).lineLimit(1)
                        }
                        Spacer()
                        Button(action: { showingNotifications = true }) {
                            Image(systemName: "bell").font(.title3).foregroundColor(.primary)
                                .padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .overlay(
                                    Group {
                                        if !activeNotifs.isEmpty {
                                            Circle().fill(themePurple).frame(width: 8, height: 8).offset(x: 8, y: -8)
                                        }
                                    }
                                )
                        }
                    }.padding(.horizontal).padding(.top, 10)
                    
                    VStack(spacing: 20) {
                        HStack {
                            Text("Your spend").foregroundColor(.secondary)
                            Spacer()
                            Menu {
                                let currentYear = Calendar.current.component(.year, from: Date())
                                ForEach(Calendar.current.shortMonthSymbols, id: \.self) { month in
                                    Button("\(month) \(currentYear)") { selectedMonth = month }
                                }
                            } label: {
                                let currentYear = Calendar.current.component(.year, from: Date())
                                HStack { Text("\(selectedMonth) \(currentYear)"); Image(systemName: "chevron.down") }
                                .font(.caption).bold().padding(.horizontal, 12).padding(.vertical, 8)
                                .background(themePurple.opacity(0.1)).foregroundColor(themePurple).cornerRadius(15)
                            }
                        }
                        
                        HStack(spacing: 15) {
                            VStack(spacing: 5) {
                                Image(systemName: "chart.pie.fill").foregroundColor(themePurple).padding(8).background(themePurple.opacity(0.1)).cornerRadius(8)
                                Text("\(Int(budgetPercentage * 100))%").font(.headline).bold()
                                Text("of budget").font(.caption2).foregroundColor(.secondary)
                            }.frame(width: 60)
                            Spacer()
                            ZStack {
                                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 18).frame(width: 180, height: 180)
                                Circle().trim(from: 0, to: monthlyTotal == 0 ? 0 : CGFloat(min(budgetPercentage, 1.0))).stroke(themePurple, style: StrokeStyle(lineWidth: 18, lineCap: .round)).frame(width: 180, height: 180).rotationEffect(.degrees(-90)).animation(.easeOut(duration: 1.0), value: budgetPercentage)
                                VStack(spacing: 4) {
                                    Text(String(format: "£%.2f", monthlyTotal)).font(.system(size: 38, weight: .bold, design: .rounded))
                                    Button(action: { editingBudget = String(format: "%.2f", safeMonthlyBudget); showingBudgetAlert = true }) {
                                        HStack(spacing: 4) {
                                            Text(String(format: "of £%.2f budget", safeMonthlyBudget))
                                            Image(systemName: "pencil")
                                        }
                                        .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Button(action: { selectedTab = .subs }) {
                                VStack(spacing: 5) {
                                    Image(systemName: "arrow.right.circle.fill").foregroundColor(themePurple).padding(8).background(themePurple.opacity(0.1)).cornerRadius(8)
                                    Text("\(dbManager.subscriptions.count)").font(.headline).bold().foregroundColor(.primary)
                                    Text("active subs").font(.caption2).foregroundColor(.secondary)
                                }.frame(width: 60)
                            }
                        }
                        
                        Button(action: {
                            if let highest = highestExpenseSub { selectedSub = highest }
                        }) {
                            HStack {
                                Image(systemName: "sparkles").foregroundColor(themePurple)
                                Text(insightMessage).font(.caption).foregroundColor(themePurple).minimumScaleFactor(0.8).lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(themePurple)
                            }
                            .padding().background(themePurple.opacity(0.08)).cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                    }.padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(24).shadow(color: .black.opacity(0.03), radius: 15, x: 0, y: 8).padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        MetricCard(title: "MONTHLY SPEND", icon: "calendar", amount: monthlyTotal, subtitle: "\(selectedMonth) 2026", trend: "Active")
                        MetricCard(title: "ANNUAL SPEND", icon: "chart.line.uptrend.xyaxis", amount: monthlyTotal * 12, subtitle: "Total this year", trend: "Proj.")
                    }.padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Upcoming renewals").font(.title3).bold()
                            Spacer()
                            Button("See all") { selectedTab = .subs }.foregroundColor(themePurple).font(.subheadline)
                        }
                        if filteredHomeSubscriptions.isEmpty {
                            Text("No renewals for this month.").padding().frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(15)
                        } else {
                            VStack(spacing: 0) {
                                // OVERWRITE FIX: id: \.self strictly separates items
                                ForEach(filteredHomeSubscriptions, id: \.self) { sub in
                                    Button(action: { selectedSub = sub }) {
                                        RenewalRow(sub: sub)
                                    }
                                    .buttonStyle(.plain)
                                    if sub.id != filteredHomeSubscriptions.last?.id { Divider().padding(.leading, 60) }
                                }
                                HStack {
                                    Image(systemName: "calendar")
                                    Text("\(filteredHomeSubscriptions.count) renewals • Total £\(String(format: "%.2f", monthlyTotal))")
                                }.font(.caption).bold().foregroundColor(themePurple).padding(.vertical, 12).frame(maxWidth: .infinity).background(themePurple.opacity(0.08)).cornerRadius(12).padding(.top, 10)
                            }.padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20).shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                        }
                    }.padding(.horizontal)
                    Spacer().frame(height: 120)
                }
            }
            .background(bgGray.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                // Un-hides Tab Bar and refreshes data on pull-down
                withAnimation(.easeIn(duration: 0.3)) { isTabBarHidden = false }
                if let uid = dbManager.currentUserProfile?.uid {
                    dbManager.fetchSubscriptions(for: uid)
                }
            }
            .sheet(item: $selectedSub) { sub in
                SubscriptionDetailView(subscription: sub, dbManager: dbManager)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationCenterView(notifications: activeNotifs, dismissedNotifs: $dismissedNotifs)
            }
            .alert("Edit Budget", isPresented: $showingBudgetAlert) {
                TextField("Budget", text: $editingBudget).keyboardType(.decimalPad)
                Button("Save") {
                    if let newBudget = Double(editingBudget), newBudget > 0 {
                        monthlyBudget = newBudget
                    } else {
                        showingInvalidBudgetAlert = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your new monthly budget.")
            }
            .alert("Invalid Budget", isPresented: $showingInvalidBudgetAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Budget must be greater than £0.")
            }
        }
    }
}

// MARK: - Dedicated Notification Center View
struct NotificationCenterView: View {
    let notifications: [AppNotif]
    @Binding var dismissedNotifs: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                bgGray.ignoresSafeArea()
                
                if notifications.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "bell.slash.fill").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
                        Text("You're all caught up!").font(.title3).bold().foregroundColor(.primary)
                        Text("No new renewals approaching.").font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(notifications) { notif in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(notif.title).font(.subheadline).bold().foregroundColor(themePurple)
                                    Spacer()
                                    Text(timeAgoString(from: notif.timeAgo)).font(.caption2).foregroundColor(.gray)
                                }
                                Text(notif.message).font(.subheadline).foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    dismissNotification(id: notif.id)
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    func dismissNotification(id: String) {
        var list = dismissedNotifs.components(separatedBy: ",").filter { !$0.isEmpty }
        list.append(id)
        dismissedNotifs = list.joined(separator: ",")
    }
    
    func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Shared Reusable Components
struct MetricCard: View {
    let title: String; let icon: String; let amount: Double; let subtitle: String; let trend: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon).foregroundColor(.white).padding(8).background(themePurple).cornerRadius(8); Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).minimumScaleFactor(0.7).lineLimit(1) }
            HStack(alignment: .bottom) { Text(String(format: "£%.2f", amount)).font(.system(size: 28, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1); Spacer(); Text(trend).font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 4).background(Color.green.opacity(0.2)).foregroundColor(.green).cornerRadius(6) }
            Text(subtitle).font(.caption2).foregroundColor(.secondary).minimumScaleFactor(0.7).lineLimit(1)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20).shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
    }
}

struct RenewalRow: View {
    let sub: Subscription
    var body: some View {
        HStack(spacing: 15) {
            ProviderLogo(providerName: sub.providerName)
            VStack(alignment: .leading, spacing: 4) {
                Text(sub.providerName).font(.headline).foregroundColor(.primary).minimumScaleFactor(0.8).lineLimit(1)
                Text(sub.isTrial ? "Trial Plan" : sub.billingFrequency)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                let days = daysUntil(sub.renewalDate)
                Text(days == 0 ? "Today" : "\(days)d")
                    .font(.caption).bold()
                    .foregroundColor(days <= 3 ? .red : themePurple)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((days <= 3 ? Color.red : themePurple).opacity(0.1))
                    .cornerRadius(10)
                HStack(spacing: 4) {
                    Text(CurrencyHelper.format(sub.cost, currency: sub.currency))
                        .font(.subheadline).bold().minimumScaleFactor(0.8).lineLimit(1)
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                }
            }
        }.padding(.vertical, 10)
    }
    func daysUntil(_ date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
    }
}

struct ProviderLogo: View {
    let providerName: String
    var body: some View {
        let assetName = providerName.lowercased().replacingOccurrences(of: " ", with: "")
        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 45, height: 45).clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ZStack { RoundedRectangle(cornerRadius: 12).fill(themePurple); Text(String(providerName.prefix(1))).font(.title2).bold().foregroundColor(.white) }.frame(width: 45, height: 45)
        }
    }
}
