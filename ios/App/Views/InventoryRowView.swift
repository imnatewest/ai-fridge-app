import SwiftUI

struct InventoryRowView: View {
    let item: InventoryItem

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(colorForStatus.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundColor(colorForStatus)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(item.quantity, specifier: "%.0f") \(item.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let expiration = expirationLabel {
                        Text(expiration)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(colorForStatus)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForStatus.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch item.category.lowercased() {
        case _ where item.isExpired: return "exclamationmark.triangle"
        case "produce": return "leaf"
        case "dairy": return "carton"
        case "meat": return "takeoutbag.and.cup.and.straw"
        case "beverages": return "cup.and.saucer"
        default: return "shippingbox"
        }
    }

    private var colorForStatus: Color {
        if item.isExpired {
            return .red
        }

        if let days = item.expiresInDays(), days <= 2 {
            return .orange
        }

        return .accentColor
    }

    private var expirationLabel: String? {
        if item.isExpired {
            return "Expired"
        }

        guard let days = item.expiresInDays() else { return nil }
        switch days {
        case ..<0:
            return "Expired"
        case 0:
            return "Expires today"
        case 1:
            return "1 day left"
        default:
            return "\(days) days left"
        }
    }
}

struct InventoryRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            InventoryRowView(item: .placeholder)
        }
    }
}
