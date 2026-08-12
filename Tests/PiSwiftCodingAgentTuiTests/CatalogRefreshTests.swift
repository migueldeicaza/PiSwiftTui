import Foundation
import PiSwiftAI
import PiSwiftCodingAgent
import Testing
@testable import PiSwiftCodingAgentTui

// No test here may touch the real network: every registry is built with a stubbed
// `ProviderHTTPClient` against an `.invalid` catalog host, mirroring
// `PiSwift/Tests/PiSwiftCodingAgentTests/DynamicModelCatalogTests.swift`.

private struct StubCatalogHTTPClient: ProviderHTTPClient {
    let handler: @Sendable (URLRequest) async throws -> ProviderHTTPResponse

    func send(_ request: URLRequest) async throws -> ProviderHTTPResponse {
        try await handler(request)
    }
}

private func testModel(id: String, provider: String = "openai") -> Model {
    Model(
        id: id,
        name: id,
        api: .openAIResponses,
        provider: provider,
        baseUrl: "https://api.example.invalid/v1",
        reasoning: false,
        input: [.text],
        cost: ModelCost(input: 1, output: 2, cacheRead: 0, cacheWrite: 0),
        contextWindow: 128_000,
        maxTokens: 16_384
    )
}

private func stubRegistry(
    client: any ProviderHTTPClient,
    networkEnabled: Bool = true
) -> ModelRegistry {
    ModelRegistry(
        AuthStorage.inMemory(["openai": .apiKey(ApiKeyCredential(key: "test-key"))]),
        nil,
        modelsStore: InMemoryModelsStore(),
        catalogBaseURL: "https://catalog.example.invalid",
        remoteHTTPClient: client,
        networkEnabled: networkEnabled
    )
}

// MARK: - ModelReference

@Test func modelReferenceParsesBareIdAndProviderQualifiedForms() {
    let bare = ModelReference("GPT-5")
    #expect(bare?.provider == nil)
    #expect(bare?.id == "gpt-5")

    let qualified = ModelReference("  OpenAI / GPT-5  ")
    #expect(qualified?.provider == "openai")
    #expect(qualified?.id == "gpt-5")

    #expect(ModelReference("") == nil)
    #expect(ModelReference("   ") == nil)
    // A provider with no model id is not a usable reference.
    #expect(ModelReference("openai/") == nil)
}

@Test func modelReferenceMatchesExactlyOneModelOrNothing() {
    let models = [
        testModel(id: "gpt-5", provider: "openai"),
        testModel(id: "gpt-5", provider: "azure"),
        testModel(id: "o3", provider: "openai"),
    ]

    // Unqualified and ambiguous -> no match.
    #expect(ModelReference("gpt-5")?.exactMatch(in: models) == nil)
    // Qualifying disambiguates.
    #expect(ModelReference("azure/gpt-5")?.exactMatch(in: models)?.provider == "azure")
    // Unique id needs no qualifier, and matching is case-insensitive.
    #expect(ModelReference("O3")?.exactMatch(in: models)?.id == "o3")
    #expect(ModelReference("nope")?.exactMatch(in: models) == nil)
}

// MARK: - Failure reporting

private struct StubCatalogError: Error {}

private func outcome(
    aborted: Bool = false,
    errors: [String] = [],
    timedOut: Bool = false
) -> BoundedCatalogRefreshOutcome {
    var map: [String: any Error] = [:]
    for id in errors { map[id] = StubCatalogError() }
    return BoundedCatalogRefreshOutcome(
        result: ModelsRefreshResult(aborted: aborted, errors: map),
        timedOut: timedOut
    )
}

@Test func failedCatalogNamesAreSortedForDeterministicMessages() {
    let names = failedCatalogNames(outcome(errors: ["zed", "openai", "anthropic"]).result)
    #expect(names == ["anthropic", "openai", "zed"])
}

// The follow-up calls this out explicitly: a refresh failure must name *every* catalog that
// failed, not just the first one.
@Test func refreshFailureMessagesNameEveryFailedCatalog() {
    let multi = outcome(errors: ["openai", "anthropic", "google"])

    let selector = CatalogRefreshStatus.selectorMessage(multi)
    #expect(selector == "Could not refresh 3 model catalogs (anthropic, google, openai); showing cached models.")

    let exact = CatalogRefreshStatus.exactMatchWarning(multi)
    #expect(exact == "Could not refresh anthropic, google, openai; searching cached models.")

    let scoped = CatalogRefreshStatus.scopedModelsMessage(multi)
    #expect(scoped.text == "Could not refresh anthropic, google, openai; showing cached models.")
    #expect(scoped.isError)
}

@Test func selectorMessageUsesSingularFormForOneFailure() {
    #expect(
        CatalogRefreshStatus.selectorMessage(outcome(errors: ["openai"]))
            == "Could not refresh openai; showing cached models."
    )
}

@Test func timeoutIsReportedOnlyWhenOurTimeoutFired() {
    // Aborted because *we* timed out.
    #expect(
        CatalogRefreshStatus.selectorMessage(outcome(aborted: true, timedOut: true))
            == "Model refresh timed out; showing cached models."
    )
    #expect(
        CatalogRefreshStatus.exactMatchWarning(outcome(aborted: true, timedOut: true))
            == "Model refresh timed out; searching cached models."
    )
    // Aborted by the caller (e.g. the selector closed) is not a timeout and reports nothing.
    #expect(CatalogRefreshStatus.selectorMessage(outcome(aborted: true)) == nil)
    #expect(CatalogRefreshStatus.exactMatchWarning(outcome(aborted: true)) == nil)
}

@Test func cleanRefreshReportsSuccessOnlyWhereUpstreamDoes() {
    #expect(CatalogRefreshStatus.selectorMessage(outcome()) == nil)
    #expect(CatalogRefreshStatus.exactMatchWarning(outcome()) == nil)

    let scoped = CatalogRefreshStatus.scopedModelsMessage(outcome())
    #expect(scoped.text == "Model catalogs refreshed.")
    #expect(!scoped.isError)
}

@Test func authMessagesDistinguishTimeoutFromFailure() {
    #expect(
        CatalogRefreshStatus.authMessage(outcome(aborted: true), actionLabel: "Logged in to OpenAI")
            == "Logged in to OpenAI, but its model catalog refresh timed out; using cached models."
    )
    #expect(
        CatalogRefreshStatus.authMessage(outcome(errors: ["openai"]), actionLabel: "Logged out of OpenAI")
            == "Logged out of OpenAI, but its model catalog could not be refreshed; using cached models."
    )
    // A clean refresh says nothing — login already reported success.
    #expect(CatalogRefreshStatus.authMessage(outcome(), actionLabel: "Logged in to OpenAI") == nil)
}

// MARK: - Bounded refresh

@MainActor
@Test func boundedRefreshGivesUpOnAStalledCatalogInsteadOfHanging() async throws {
    // A catalog fetch that never returns; only the bound can end this refresh.
    let client = StubCatalogHTTPClient { _ in
        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        return ProviderHTTPResponse(statusCode: 200, headers: [:], body: Data())
    }

    let start = Date()
    let result = await runBoundedCatalogRefresh(
        registry: stubRegistry(client: client),
        signal: CancellationToken(),
        timeoutMs: 200
    )
    let elapsed = Date().timeIntervalSince(start)

    #expect(result.timedOut)
    #expect(result.result.aborted)
    // Generously bounded: the point is that it returned rather than waiting on the stalled fetch.
    #expect(elapsed < 20)
}

@MainActor
@Test func boundedRefreshDoesNotReportATimeoutWhenTheCallerCancels() async throws {
    let client = StubCatalogHTTPClient { _ in
        try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
        return ProviderHTTPResponse(statusCode: 200, headers: [:], body: Data())
    }

    let signal = CancellationToken()
    let task = Task { @MainActor in
        await runBoundedCatalogRefresh(
            registry: stubRegistry(client: client),
            signal: signal,
            timeoutMs: 60_000
        )
    }
    // Cancel the way a closing selector does.
    try await Task.sleep(nanoseconds: 100 * 1_000_000)
    signal.cancel()

    let result = await task.value
    #expect(!result.timedOut)
    // A caller-initiated cancel must not surface a "timed out" warning.
    #expect(CatalogRefreshStatus.selectorMessage(result) == nil)
}

@MainActor
@Test func boundedRefreshSkipsTheNetworkWhenNetworkIsDisabled() async {
    let attempted = LockedState(false)
    let client = StubCatalogHTTPClient { _ in
        attempted.withLock { $0 = true }
        return ProviderHTTPResponse(statusCode: 200, headers: [:], body: Data())
    }

    let result = await runBoundedCatalogRefresh(
        registry: stubRegistry(client: client, networkEnabled: false),
        signal: CancellationToken()
    )

    #expect(!attempted.withLock { $0 })
    #expect(!result.timedOut)
    #expect(!result.result.aborted)
}

// MARK: - Selector teardown

@MainActor
@Test func selectorCloseBoxClosesExactlyOnce() {
    final class Spy: SelectorClosable {
        var closes = 0
        func closeSelector() { closes += 1 }
    }

    let spy = Spy()
    let box = SelectorCloseBox()
    box.component = spy

    // `done` can run more than once (select, then ctrl+C on a stale handler).
    box.closeOnce()
    box.closeOnce()

    #expect(spy.closes == 1)
}

@MainActor
@Test func selectorCloseBoxToleratesAComponentThatIsNotClosable() {
    let box = SelectorCloseBox()
    box.component = nil
    box.closeOnce()  // must not trap
}
