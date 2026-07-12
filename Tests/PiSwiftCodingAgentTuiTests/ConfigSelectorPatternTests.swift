import XCTest
import PiSwiftCodingAgent
@testable import PiSwiftCodingAgentTui

final class ConfigSelectorPatternTests: XCTestCase {
    func testUpdateResourcePatternsReplacesEntry() {
        let current = ["-skills/foo", "+skills/bar", "skills/baz"]
        let updated = updateResourcePatterns(current: current, pattern: "skills/foo", enabled: true)
        XCTAssertEqual(updated, ["+skills/bar", "skills/baz", "+skills/foo"])
    }

    func testUpdatePackageSourcesAddsFilterPreservingExisting() {
        let packages: [PackageSource] = [
            .filtered(PackageFilterSource(source: "pkg", skills: ["+a"]))
        ]
        let updated = updatePackageSources(
            packages: packages,
            source: "pkg",
            resourceType: .prompts,
            pattern: "prompts/example.md",
            enabled: true
        )
        guard case .filtered(let filter) = updated.first else {
            XCTFail("Expected filtered package source")
            return
        }
        XCTAssertEqual(filter.skills ?? [], ["+a"])
        XCTAssertEqual(filter.prompts ?? [], ["+prompts/example.md"])
    }
}
