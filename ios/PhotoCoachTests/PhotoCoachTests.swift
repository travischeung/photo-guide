import Testing
@testable import PhotoCoach

// Smoke test: proves the Swift Testing target builds against the app module.
@Test @MainActor func appModuleLoads() {
    _ = ContentView()
}
