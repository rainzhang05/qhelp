import Foundation
import ClipAICore

enum ClipboardContentTests: TestCase {
    static let name = "ClipboardContentTests"

    static func run() throws {
        let first = ClipboardContent.text("hello")
        let second = ClipboardContent.text("hello")
        try assertEqual(first.contentHash, second.contentHash)

        let third = ClipboardContent.text("world")
        try assertNotEqual(first.contentHash, third.contentHash)

        let data = Data([0x01, 0x02, 0x03])
        let png = ClipboardContent.image(data, mediaType: "image/png")
        let jpeg = ClipboardContent.image(data, mediaType: "image/jpeg")
        try assertEqual(png.contentHash, jpeg.contentHash)

        let secret = ClipboardContent.text("super-secret clipboard contents")
        try assertEqual(secret.typeDescription, "text (31 chars)")
        try assertTrue(!secret.typeDescription.contains("super-secret"))
    }
}
