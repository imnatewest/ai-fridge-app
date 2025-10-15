//
//  Item.swift
//  AIFridge
//
//  Created by Nathan West on 10/14/25.
//

import Foundation
import FirebaseFirestoreSwift

struct Item: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: String?
    var quantity: Double
    var unit: String
    var expirationDate: Date
    var timestamp: Date
}
