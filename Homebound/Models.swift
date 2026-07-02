import Foundation
import Supabase

// MARK: - DATA MODELS
struct MyTrip: Codable, Identifiable {
    var id: Int?
    let category: String?
    let title: String?
    let subtitle: String?
    let start_date: Date?
    let end_date: Date?
    let from_location: String?
    let to_location: String?
    let confirmation: String?
    let notes: String?
}

struct MyTripInsert: Encodable {
    let category: String
    let title: String
    let subtitle: String
    let start_date: String?
    let end_date: String?
    let from_location: String?
    let to_location: String?
    let confirmation: String?
    let notes: String?
}

struct VaultDoc: Codable, Identifiable {
    let id: Int
    let title: String?
    let doc_type: String?
    let details: String?
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
