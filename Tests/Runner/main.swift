import Foundation

@main
enum TestRunner {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let suites = args.isEmpty ? TestSuites.all : TestSuites.matching(args)
        let failures = runTestSuites(suites)
        if failures > 0 {
            exit(1)
        }
    }
}
