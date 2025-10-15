//
//  AIFridgeApp.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import Firebase
import UIKit

@main
struct AIFridgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    await ExpirationNotificationScheduler.shared.requestAuthorizationIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                ExpirationNotificationScheduler.shared.scheduleBackgroundRefresh()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        ExpirationNotificationScheduler.shared.registerBackgroundTasks()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        ExpirationNotificationScheduler.shared.scheduleBackgroundRefresh()
    }
}
