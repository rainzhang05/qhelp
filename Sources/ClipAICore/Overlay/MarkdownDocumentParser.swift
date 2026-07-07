import Foundation

/// A parsed markdown block for overlay rendering.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String?, code: String)
    case bulletList(items: [String])
    case numberedList(items: [String])
    case blockquote(lines: [String])
    case thematicBreak
}

/// Parses common GitHub-flavored markdown from AI model output.
enum MarkdownDocumentParser {

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var index = 0
        let lines = markdown.components(separatedBy: "\n")

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }
                blocks.append(.codeBlock(
                    language: language.isEmpty ? nil : language,
                    code: codeLines.joined(separator: "\n")
                ))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            if let level = headingLevel(for: trimmed) {
                blocks.append(.heading(level: level, text: String(trimmed.dropFirst(level + 1))))
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteTrimmed.hasPrefix(">") else { break }
                    let quoteText = quoteTrimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(quoteText))
                    index += 1
                }
                if !quoteLines.isEmpty {
                    blocks.append(.blockquote(lines: quoteLines))
                }
                continue
            }

            if isBulletItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let itemTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isBulletItem(itemTrimmed) else { break }
                    items.append(bulletText(from: itemTrimmed))
                    index += 1
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            if isNumberedItem(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let itemTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isNumberedItem(itemTrimmed) else { break }
                    items.append(numberedText(from: itemTrimmed))
                    index += 1
                }
                blocks.append(.numberedList(items: items))
                continue
            }

            if trimmed.isEmpty {
                index += 1
                continue
            }

            var paragraphLines: [String] = []
            while index < lines.count {
                let paragraphTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if paragraphTrimmed.isEmpty
                    || paragraphTrimmed.hasPrefix("```")
                    || headingLevel(for: paragraphTrimmed) != nil
                    || paragraphTrimmed.hasPrefix(">")
                    || isBulletItem(paragraphTrimmed)
                    || isNumberedItem(paragraphTrimmed)
                    || paragraphTrimmed == "---"
                    || paragraphTrimmed == "***"
                    || paragraphTrimmed == "___" {
                    break
                }
                paragraphLines.append(lines[index])
                index += 1
            }

            let paragraph = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                blocks.append(.paragraph(text: paragraph))
            }
        }

        return blocks
    }

    // MARK: - Helpers

    private static func headingLevel(for line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }
        guard (1...6).contains(level) else { return nil }
        let afterHashes = line.dropFirst(level)
        guard afterHashes.first == " " || afterHashes.isEmpty else { return nil }
        return level
    }

    private static func isBulletItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func bulletText(from line: String) -> String {
        String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    private static func isNumberedItem(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return false }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return false }
        return true
    }

    private static func numberedText(from line: String) -> String {
        guard let dotIndex = line.firstIndex(of: ".") else { return line }
        var start = line.index(after: dotIndex)
        if start < line.endIndex, line[start] == " " {
            start = line.index(after: start)
        }
        return String(line[start...]).trimmingCharacters(in: .whitespaces)
    }
}
