import Foundation
import SwiftData

@Model
final class TextBlockRecord {
    var id: UUID
    var text: String
    var timestamp: Date

    init(id: UUID, text: String, timestamp: Date) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
