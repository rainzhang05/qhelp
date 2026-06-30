import Foundation
import CryptoKit

/// Represents content read from the macOS system clipboard.
///
/// Each clipboard event produces exactly one `ClipboardContent` value.
/// Images are stored as data with their MIME type for API transmission.
public enum ClipboardContent {

    /// Plain text content.
    case text(String)

    /// Image content as raw data with its MIME type (e.g., "image/png").
    case image(Data, mediaType: String)

    // MARK: - Duplicate Detection

    /// Computes a SHA-256 hash of the content for duplicate detection.
    ///
    /// Identical clipboard contents produce the same hash,
    /// preventing redundant API requests.
    public var contentHash: String {
        let data: Data
        switch self {
        case .text(let text):
            data = Data(text.utf8)
        case .image(let imageData, _):
            data = imageData
        }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Display

    /// A concise human-readable description for terminal logging.
    public var typeDescription: String {
        switch self {
        case .text(let text):
            return "text (\(text.count) chars)"
        case .image(let data, let mediaType):
            let sizeKB = data.count / 1024
            return "image (\(mediaType), \(sizeKB) KB)"
        }
    }
}
