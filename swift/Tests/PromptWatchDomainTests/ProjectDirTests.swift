import Testing
import Foundation
@testable import PromptWatchDomain

@Suite("ProjectDir Tests")
struct ProjectDirTests {
    @Test("Encode project path correctly")
    func testEncodePath() {
        let path = "/Users/test/Projects/MyProject"
        let encoded = ProjectDir.encode(path: path)

        #expect(encoded == "--Users-test-Projects-MyProject")
    }

    @Test("Decode project path correctly")
    func testDecodePath() {
        let encoded = "--Users-test-Projects-MyProject"
        let decoded = ProjectDir.decode(encodedName: encoded)

        #expect(decoded == "/Users/test/Projects/MyProject")
    }

    @Test("Round trip encoding")
    func testRoundTrip() {
        let original = "/Users/test/Projects/MyProject"
        let encoded = ProjectDir.encode(path: original)
        let decoded = ProjectDir.decode(encodedName: encoded)

        #expect(decoded == original)
    }

    @Test("Project name is last path component")
    func testProjectName() {
        let project = ProjectDir(
            encodedName: "--Users-test-Projects-MyProject",
            originalPath: "/Users/test/Projects/MyProject"
        )

        #expect(project.name == "MyProject")
    }

    @Test("Sessions directory path is constructed correctly")
    func testSessionsDirectoryPath() {
        let project = ProjectDir(
            encodedName: "--Users-test-Projects-MyProject",
            originalPath: "/Users/test/Projects/MyProject"
        )

        let expected = "\(NSHomeDirectory())/.claude/projects/--Users-test-Projects-MyProject"
        #expect(project.sessionsDirectoryPath == expected)
    }

    @Test("Handle paths with special characters")
    func testSpecialCharacters() {
        // Note: The encoding scheme uses simple replacement
        let path = "/Users/test/My Project"
        let encoded = ProjectDir.encode(path: path)

        // Spaces remain as spaces in this simple encoding
        #expect(encoded.hasPrefix("-"))
    }
}
