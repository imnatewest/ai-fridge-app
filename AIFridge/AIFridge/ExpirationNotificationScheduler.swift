//
//  ExpirationNotificationScheduler.swift
//  AIFridge
//
//  Created by Nathan West on 10/15/25.
//

import Foundation
import UserNotifications
import BackgroundTasks
import FirebaseFirestore
import FirebaseFirestoreSwift

final class ExpirationNotificationScheduler {
    static let shared = ExpirationNotificationScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()
    private let refreshTaskIdentifier = "com.nathanwest.AIFridge.expirationRefresh"

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let status = await currentAuthorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            scheduleBackgroundRefresh()
        case .denied:
            return
        case .notDetermined:
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    scheduleBackgroundRefresh()
                }
            } catch {
                print("❌ Notification authorization failed: \(error)")
            }
        @unknown default:
            break
        }
    }

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 12) // roughly twice a day

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ Unable to schedule background refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let refreshWork = Task {
            do {
                let items = try await fetchItems()
                syncNotifications(with: items)
                task.setTaskCompleted(success: true)
            } catch {
                if error is CancellationError {
                    print("⚠️ Background refresh cancelled")
                } else {
                    print("❌ Background refresh failed: \(error)")
                }
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            refreshWork.cancel()
        }
    }

    func scheduleNotification(for item: Item) {
        guard let itemID = item.id else { return }

        let daysRemaining = daysUntilExpiration(from: item.expirationDate)
        if daysRemaining < 0 || daysRemaining > 3 {
            cancelNotification(for: itemID)
            return
        }

        let triggerDate = triggerDate(for: item.expirationDate)
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Expiring soon: \(item.name)"
        content.body = "Expires \(item.expirationDate.formatted(date: .long, time: .omitted))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: itemID),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Unable to schedule notification for \(item.name): \(error)")
            } else {
                print("🔔 Scheduled notification for \(item.name) at \(triggerDate)")
            }
        }
    }

    func cancelNotification(for itemID: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier(for: itemID)])
    }

    func rescheduleNotification(for item: Item) {
        guard let itemID = item.id else { return }
        cancelNotification(for: itemID)
        scheduleNotification(for: item)
    }

    func syncNotifications(with items: [Item]) {
        let qualifyingItems = items.filter { item in
            guard item.id != nil else { return false }
            let days = daysUntilExpiration(from: item.expirationDate)
            return days >= 0 && days <= 3
        }

        let validIdentifiers = Set(qualifyingItems.compactMap { $0.id }.map(identifier))

        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let existingIdentifiers = Set(requests.map(\.identifier))
            let toRemove = Array(existingIdentifiers.subtracting(validIdentifiers))
            if !toRemove.isEmpty {
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: toRemove)
            }

            qualifyingItems.forEach { self.scheduleNotification(for: $0) }
        }
    }

    private func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    @MainActor
    private func fetchItems() async throws -> [Item] {
        try await withCheckedThrowingContinuation { continuation in
            db.collection("items").getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    continuation.resume(returning: [])
                    return
                }

                let items = documents.compactMap { document in
                    try? document.data(as: Item.self)
                }
                continuation.resume(returning: items)
            }
        }
    }

    private func identifier(for itemID: String) -> String {
        "item-expiration-\(itemID)"
    }

    private func daysUntilExpiration(from expirationDate: Date) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expirationDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return components.day ?? 0
    }

    private func triggerDate(for expirationDate: Date) -> Date {
        let calendar = Calendar.current

        if let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: expirationDate),
           morning > Date() {
            return morning
        }

        // If the computed trigger is in the past, fire within the next minute.
        return Date().addingTimeInterval(60)
    }
}
