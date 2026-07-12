import Foundation

private let RUN_ANTHROPIC_TESTS: Bool = {
    let env = ProcessInfo.processInfo.environment
    let flag = (env["PI_RUN_ANTHROPIC_TESTS"] ?? env["PI_RUN_LIVE_TESTS"])?.lowercased()
    return flag == "1" || flag == "true" || flag == "yes"
}()

let API_KEY: String? = {
    guard RUN_ANTHROPIC_TESTS else { return nil }
    let env = ProcessInfo.processInfo.environment
    return env["ANTHROPIC_OAUTH_TOKEN"] ?? env["ANTHROPIC_API_KEY"]
}()
