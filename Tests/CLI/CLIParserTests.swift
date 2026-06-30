import Foundation
import QHelpCore

enum CLIParserTests: TestCase {
    static let name = "CLIParserTests"

    static func run() throws {
        let result = CLIParser.parseResult(["qhelp", "claude-sonnet-4-6"])
        guard case .config(let config) = result else {
            throw TestFailure.message("Expected config result")
        }
        try assertEqual(config.modelName, "claude-sonnet-4-6")

        try assertEqual(CLIParser.parseResult(["qhelp", "--help"]), CLIParseResult.help)
        try assertEqual(CLIParser.parseResult(["qhelp", "-h"]), CLIParseResult.help)
        try assertEqual(CLIParser.parseResult(["qhelp", "--version"]), CLIParseResult.version)
        try assertEqual(CLIParser.parseResult(["qhelp"]), CLIParseResult.invalidUsage)
        try assertEqual(CLIParser.parseResult(["qhelp", "--unknown"]), CLIParseResult.invalidUsage)

        let usage = CLIParser.usageText()
        try assertTrue(usage.contains("exact model name"))
        try assertTrue(usage.contains("claude-*"))
        try assertTrue(usage.contains("click the header"))
    }
}
