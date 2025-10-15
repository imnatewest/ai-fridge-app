//
//  ContentView.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ContentView: View {
    let db = Firestore.firestore()

    @State private var name: String = ""
    @State private var quantity: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Firestore Test")
                .font(.title.bold())

            Text("Item: \(name)")
            Text("Quantity: \(quantity)")

            Divider()
                .padding(.vertical)

            // Input fields for adding new data
            TextField("Enter item name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            TextField("Enter quantity", value: $quantity, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button("Add Item to Firestore") {
                addItem()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .onAppear {
            fetchData()
        }
    }


    func fetchData() {
        db.collection("testCollection").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error getting documents: \(error)")
                return
            }

            if let doc = snapshot?.documents.first {
                let data = doc.data()
                name = data["name"] as? String ?? "Unknown"
                quantity = data["quantity"] as? Int ?? 0
                print("✅ Successfully fetched data: \(data)")
            }
        }
    }
    func addItem() {
        let newItem: [String: Any] = [
            "name": name,
            "quantity": quantity,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("testCollection").addDocument(data: newItem) { error in
            if let error = error {
                print("❌ Error adding document: \(error)")
            } else {
                print("✅ Successfully added new item: \(newItem)")
            }
        }
        
        fetchData()
    }

}

#Preview {
    ContentView()
}
