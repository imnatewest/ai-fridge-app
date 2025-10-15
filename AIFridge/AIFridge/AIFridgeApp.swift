//
//  AIFridgeApp.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import Firebase

@main
struct AIFridgeApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            InventoryListView()
        }
    }
}
