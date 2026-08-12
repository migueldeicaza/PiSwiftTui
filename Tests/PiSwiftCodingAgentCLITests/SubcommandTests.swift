import ArgumentParser
import Foundation
import PiSwiftAI
@testable import PiSwiftCodingAgent
@testable import PiSwiftCodingAgentCLI
import Testing

@Test func commandTreeDispatchesPackageAndConfigAndPreservesBareCLI() throws {
    let packageCommand = try parseRootCommand([
        "package", "install", "npm:test-package", "--approve",
    ])
    let package = try #require(packageCommand as? PackageSubcommand)
    #expect(package.cli.rawMessages == ["install", "npm:test-package"])
    #expect(package.cli.approve)

    let configCommand = try parseRootCommand(["config", "-l"])
    let config = try #require(configCommand as? ConfigSubcommand)
    #expect(config.cli.configLocal)

    let leadingConfigCommand = try parseRootCommand(["-l", "config"])
    let leadingConfig = try #require(leadingConfigCommand as? ConfigSubcommand)
    #expect(leadingConfig.cli.configLocal)

    let bareCommand = try parseRootCommand([
        "--print", "--provider", "openai", "hello",
    ])
    let session = try #require(bareCommand as? SessionSubcommand)
    #expect(session.cli.print)
    #expect(session.cli.provider == "openai")
    #expect(session.cli.rawMessages == ["hello"])
}

@Test func packageHelpStillReachesTheExistingDispatcher() throws {
    let command = try parseRootCommand(["package", "install", "--help"])
    let package = try #require(command as? PackageSubcommand)
    #expect(package.cli.rawMessages == ["install"])
    #expect(package.packageHelp)
}

@Test func authSubcommandsParseSelectionAndMinimumValidity() throws {
    let checkCommand = try parseRootCommand([
        "auth", "check", "--provider", "openai", "--credentials",
    ])
    let check = try #require(checkCommand as? AuthCheckSubcommand)
    #expect(check.parent.provider == "openai")
    #expect(check.showCredential)

    let bearerCommand = try parseRootCommand([
        "auth", "print-bearer-token", "--provider", "openai-codex",
        "--min-expiry", "30m",
    ])
    let bearer = try #require(bearerCommand as? PrintBearerTokenSubcommand)
    #expect(bearer.parent.provider == "openai-codex")
    #expect(bearer.minimumValidity?.milliseconds == 1_800_000.0)
}

@Test func authCheckReportsConfiguredAndUnconfiguredWithoutLeakingByDefault() async {
    let secret = "test-auth-check-secret"
    let storage = AuthStorage.inMemory([
        "openai": .apiKey(ApiKeyCredential(key: secret)),
    ])
    let registry = makeTestModelRegistry(storage)

    let configured = await runAuthCheck(
        provider: "openai",
        model: nil,
        showCredential: false,
        registry: registry,
        authStorage: storage
    )
    #expect(configured.exitCode == 0)
    #expect(configured.stdout?.contains("usable") == true)
    #expect(configured.stdout?.contains("auth.json") == true)
    #expect(configured.stdout?.contains(secret) == false)
    #expect(configured.stderr == nil)

    let revealed = await runAuthCheck(
        provider: "openai",
        model: nil,
        showCredential: true,
        registry: registry,
        authStorage: storage
    )
    #expect(revealed.exitCode == 0)
    #expect(revealed.stdout?.hasSuffix(secret) == true)

    let missingStorage = AuthStorage.inMemory()
    let missing = await runAuthCheck(
        provider: "openai",
        model: nil,
        showCredential: false,
        registry: makeTestModelRegistry(missingStorage),
        authStorage: missingStorage
    )
    #expect(missing.exitCode != 0)
    #expect(missing.stdout == nil)
    #expect(missing.stderr?.contains("not configured") == true)
}

@Test func authCheckResolvesProviderFromModelReference() async {
    let storage = AuthStorage.inMemory([
        "groq": .apiKey(ApiKeyCredential(key: "model-secret")),
    ])
    let result = await runAuthCheck(
        provider: nil,
        model: "groq/llama-3.3-70b-versatile",
        showCredential: false,
        registry: makeTestModelRegistry(storage),
        authStorage: storage
    )
    #expect(result.stderr == nil)
    #expect(result.exitCode == 0)
    #expect(result.stdout?.contains("groq") == true)
}

@Test func credentialPrintReturnsOnlyTheRequestedCredential() async {
    let apiKey = "pipeable-api-key"
    let apiStorage = AuthStorage.inMemory([
        "openai": .apiKey(ApiKeyCredential(key: apiKey)),
    ])
    let apiResult = await runCredentialPrint(
        kind: .apiKey,
        provider: "openai",
        model: nil,
        registry: makeTestModelRegistry(apiStorage),
        authStorage: apiStorage
    )
    #expect(apiResult.stdout == apiKey)
    #expect(apiResult.stderr == nil)
    #expect(apiResult.exitCode == 0)

    let now = Date().timeIntervalSince1970 * 1_000
    let bearer = "pipeable-bearer-token"
    let oauthStorage = AuthStorage.inMemory([
        "openai-codex": .oauth(OAuthCredential(
            access: bearer,
            refresh: "refresh-token",
            expires: now + 60 * 60 * 1_000
        )),
    ])
    let bearerResult = await runCredentialPrint(
        kind: .bearerToken,
        provider: "openai-codex",
        model: nil,
        registry: makeTestModelRegistry(oauthStorage),
        authStorage: oauthStorage
    )
    #expect(bearerResult.stdout == bearer)
    #expect(bearerResult.stderr == nil)
    #expect(bearerResult.exitCode == 0)
}

@Test func bearerPrintRefreshesOAuthAndRejectsInsufficientValidity() async {
    let now = Date().timeIntervalSince1970 * 1_000
    let storage = AuthStorage.inMemory([
        "openai-codex": .oauth(OAuthCredential(
            access: "stale-token",
            refresh: "refresh-token",
            expires: now
        )),
    ])
    storage.setOAuthOverridesForTesting(OAuthOverrides(
        getOAuthApiKey: { _, credentials in
            let current = credentials["openai-codex"]
            let refreshed = OAuthCredentials(
                refresh: current?.refresh ?? "refresh-token",
                access: "fresh-token",
                expires: Date().timeIntervalSince1970 * 1_000 + 60 * 60 * 1_000
            )
            return (refreshed, refreshed.access)
        },
        oauthApiKey: { _, access, _ in access }
    ))
    let success = await runCredentialPrint(
        kind: .bearerToken,
        provider: "openai-codex",
        model: nil,
        minimumOAuthValidityMs: defaultOAuthMinimumValidityMs,
        registry: makeTestModelRegistry(storage),
        authStorage: storage
    )
    #expect(success.stdout == "fresh-token")
    #expect(success.stderr == nil)

    let insufficient = AuthStorage.inMemory([
        "openai-codex": .oauth(OAuthCredential(
            access: "stale-token-must-not-print",
            refresh: "refresh-token",
            expires: now
        )),
    ])
    insufficient.setOAuthOverridesForTesting(OAuthOverrides(
        getOAuthApiKey: { _, credentials in
            let current = credentials["openai-codex"]
            let refreshed = OAuthCredentials(
                refresh: current?.refresh ?? "refresh-token",
                access: "still-too-stale",
                expires: Date().timeIntervalSince1970 * 1_000 + 1_000
            )
            return (refreshed, refreshed.access)
        },
        oauthApiKey: { _, access, _ in access }
    ))
    let failure = await runCredentialPrint(
        kind: .bearerToken,
        provider: "openai-codex",
        model: nil,
        minimumOAuthValidityMs: defaultOAuthMinimumValidityMs,
        registry: makeTestModelRegistry(insufficient),
        authStorage: insufficient
    )
    #expect(failure.exitCode != 0)
    #expect(failure.stdout == nil)
    #expect(failure.stderr?.contains("minimum validity") == true)
    #expect(failure.stderr?.contains("still-too-stale") == false)
}

@Test func credentialSubcommandsKeepProcessStdoutPipeable() throws {
    let agentDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("pi-credential-subcommands-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: agentDirectory) }

    let apiKey = "process-api-key"
    let bearerToken = "process-bearer-token"
    let auth: [String: Any] = [
        "openai": ["type": "api_key", "key": apiKey],
        "openai-codex": [
            "type": "oauth",
            "access": bearerToken,
            "refresh": "unused-refresh-token",
            "expires": Date().timeIntervalSince1970 * 1_000 + 60 * 60 * 1_000,
        ],
    ]
    let authData = try JSONSerialization.data(withJSONObject: auth, options: [.sortedKeys])
    try authData.write(to: agentDirectory.appendingPathComponent("auth.json"))

    let apiResult = try runTestCLI(
        ["auth", "print-api-key", "--provider", "openai"],
        agentDirectory: agentDirectory
    )
    #expect(apiResult.status == 0)
    #expect(apiResult.stdout == "\(apiKey)\n")
    #expect(apiResult.stderr.isEmpty)

    let bearerResult = try runTestCLI(
        ["auth", "print-bearer-token", "--provider", "openai-codex"],
        agentDirectory: agentDirectory
    )
    #expect(bearerResult.status == 0)
    #expect(bearerResult.stdout == "\(bearerToken)\n")
    #expect(bearerResult.stderr.isEmpty)

    let checkResult = try runTestCLI(
        ["auth", "check", "--provider", "openai"],
        agentDirectory: agentDirectory
    )
    #expect(checkResult.status == 0)
    #expect(checkResult.stdout.contains(apiKey) == false)
    #expect(checkResult.stderr.isEmpty)

    let oauthCheckResult = try runTestCLI(
        ["auth", "check", "--provider", "openai-codex"],
        agentDirectory: agentDirectory
    )
    #expect(oauthCheckResult.status == 0)
    #expect(oauthCheckResult.stdout.contains("OAuth in auth.json"))
    #expect(oauthCheckResult.stdout.contains(bearerToken) == false)
    #expect(oauthCheckResult.stderr.isEmpty)

    let environmentSecret = "process-environment-key"
    let environmentCheckResult = try runTestCLI(
        ["auth", "check", "--provider", "groq"],
        agentDirectory: agentDirectory,
        environmentOverrides: ["GROQ_API_KEY": environmentSecret]
    )
    #expect(environmentCheckResult.status == 0)
    #expect(environmentCheckResult.stdout.contains("environment variable GROQ_API_KEY"))
    #expect(environmentCheckResult.stdout.contains(environmentSecret) == false)
    #expect(environmentCheckResult.stderr.isEmpty)
}

@Test func modelUpdateReportsEveryProviderErrorAndUsesForcedNetworkRefresh() async {
    let captured = LockedState<ModelsRefreshOptions?>(nil)
    let result = await runModelsUpdate { options in
        captured.withLock { $0 = options }
        return ModelsRefreshResult(aborted: false, errors: [
            "openai": TestRefreshError(message: "catalog unavailable"),
            "anthropic": TestRefreshError(message: "access denied"),
        ])
    }

    #expect(result.exitCode != 0)
    #expect(result.stdout == nil)
    #expect(result.stderr?.contains("anthropic: access denied") == true)
    #expect(result.stderr?.contains("openai: catalog unavailable") == true)
    let options = captured.withLock { $0 }
    #expect(options?.allowNetwork == true)
    #expect(options?.force == true)
    #expect(options?.signal != nil)
}

@Test func modelUpdateReportsAbortedRefreshAsTimeout() async {
    let result = await runModelsUpdate(timeoutNanoseconds: 1_000_000) { _ in
        ModelsRefreshResult(aborted: true)
    }
    #expect(result.exitCode != 0)
    #expect(result.stdout == nil)
    #expect(result.stderr?.localizedCaseInsensitiveContains("timed out") == true)
}

private func makeTestModelRegistry(_ storage: AuthStorage) -> ModelRegistry {
    ModelRegistry(
        storage,
        nil,
        modelsStore: InMemoryModelsStore(),
        networkEnabled: false
    )
}

private func parseRootCommand(_ arguments: [String]) throws -> any ParsableCommand {
    try PiCodingAgentCLI.parseAsRoot(PiCodingAgentCLI.preprocessArguments(arguments))
}

private struct TestRefreshError: Error, LocalizedError, Sendable {
    var message: String

    var errorDescription: String? { message }
}

private struct TestCLIResult {
    var status: Int32
    var stdout: String
    var stderr: String
}

private func runTestCLI(
    _ arguments: [String],
    agentDirectory: URL,
    environmentOverrides: [String: String] = [:]
) throws -> TestCLIResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: testCLIPath())
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment[ENV_AGENT_DIR] = agentDirectory.path
    environment.removeValue(forKey: "OPENAI_API_KEY")
    for (name, value) in environmentOverrides {
        environment[name] = value
    }
    process.environment = environment

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()

    return TestCLIResult(
        status: process.terminationStatus,
        stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
        stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func testCLIPath() -> String {
    let fileManager = FileManager.default
    let testExecutableDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        .deletingLastPathComponent()
    let candidates = [
        testExecutableDirectory.appendingPathComponent("pi-coding-agent").path,
        URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent(".build/out/Products/Debug/pi-coding-agent").path,
        URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent(".build/arm64-apple-macosx/debug/pi-coding-agent").path,
    ]
    return candidates.first(where: fileManager.isExecutableFile(atPath:)) ?? candidates[0]
}
