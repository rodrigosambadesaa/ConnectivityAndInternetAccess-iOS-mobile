# Validation & Testing Documentation

This document details the architectural mapping, verification matrix, unit testing setup, and GitHub Actions CI configuration for the Swift re-implementation of the Android `ConnectivityAndInternetAccess` Gist.

---

## 🔍 Feature Parity & Architectural Mapping Matrix

| Android Gist Feature (Java/Kotlin) | iOS Swift Implementation | Status |
| :--- | :--- | :--- |
| `NetworkState` (connected, validated, captive portal, timestamp) | `NetworkState` struct (isConnected, interfaceType, isExpensive, isConstrained, isInternetValidated, isCaptivePortalDetected, timestamp) | ✅ Implemented |
| Passive observation via `ConnectivityManager.NetworkCallback` | Passive observation via `NWPathMonitor` (`NetworkObserver`) | ✅ Implemented |
| Callback delivery on main thread | `DispatchQueue.main.async` delivery | ✅ Implemented |
| Duplicate state suppression | Property equality filter ignoring timestamp | ✅ Implemented |
| Stage 1: System DNS preflight (~350ms) | `DNSProbeStrategy.resolveSystemDNS` (`getaddrinfo`) | ✅ Implemented |
| Stage 2: Direct UDP DNS queries to 1.1.1.1, 8.8.8.8, 9.9.9.9, 208.67.222.222 | `UDPResolver.probe` raw BSD socket UDP client | ✅ Implemented |
| Stage 3: HTTP/HTTPS probe endpoints | Parallel ephemeral `URLSession` HEAD/GET probes | ✅ Implemented |
| Strict Captive Portal mode (`generate_204`) | `strictCaptivePortalBuilder()` disallowing HTTP redirects | ✅ Implemented |
| Fluent Builder pattern | `ConnectivityBuilder` class | ✅ Implemented |
| Cancellation handles (`Request.cancel()`) | `ConnectivityRequest.cancel()` & `NetworkObserverToken.close()` | ✅ Implemented |
| Combine & AsyncSequence integration | `NetworkObserver.publisher` & `NetworkObserver.states` | ✅ Implemented |
| SwiftUI & UIKit Lifecycle Examples | `ConnectivityObserver` (@ObservableObject), `ContentView.swift`, `ConnectivityViewController.swift` | ✅ Implemented |

---

## 🧪 Unit Test Matrix (`Tests/ConnectivityAndInternetAccessTests/`)

1. **`NetworkStateTests.swift`**:
   - `testNetworkStateInitialization`: Validates correct assignment of property flags.
   - `testOfflineStateHelper`: Verifies offline default snapshot state.
   - `testNetworkStateEquatable`: Verifies custom equality logic.
   - `testCodableConformity`: Verifies JSON encoding/decoding accuracy.

2. **`NetworkObserverTests.swift`**:
   - `testSnapshotNetworkStateReturnsValidObject`: Verifies immediate non-null state snapshot.
   - `testObserveNetworkDeliversInitialState`: Verifies initial delivery of state to observer callbacks.
   - `testTokenCancellationIdempotency`: Verifies idempotent closing of `NetworkObserverToken`.

3. **`DiagnosticEngineTests.swift`**:
   - `testSystemDNSSuccess`: Tests Stage 1 system DNS preflight resolution.
   - `testDirectUDPProbeFallbackWhenSystemDNSFails`: Tests fallback to Stage 2 direct UDP DNS queries.
   - `testHTTPProbeFallbackWhenDNSStageFails`: Tests fallback to Stage 3 HTTP probes.
   - `testAllStagesFailureReturnsUnreachable`: Tests graceful return of unreachable result when all probes fail.
   - `testAsyncDiagnosticWithCancellation`: Tests request cancellation via `ConnectivityRequest`.

4. **`ConnectivityBuilderTests.swift`**:
   - `testBuilderCustomConfiguration`: Tests fluent builder setters.
   - `testStrictCaptivePortalBuilder`: Tests strict captive portal builder configuration.

5. **`IntegrationTests.swift`**:
   - `testStaticSnapshotNetworkState`: Verifies static snapshot convenience method.
   - `testStaticObserveNetwork`: Verifies static observer convenience method.
   - `testAsyncAwaitConcurrencyAPI`: Verifies Swift Concurrency (`async/await`) API.

---

## ⚙️ GitHub Actions CI Workflow Setup

The repository is configured with `.github/workflows/ci.yml` targeting `macos-14` / `macos-latest` runners:

- **Build Matrix:** Xcode 15.4 and Xcode 16.0.
- **Commands Executed:**
  - `swift build -v`
  - `swift test --enable-code-coverage --parallel -v`
- **Artifacts:** Code coverage reports are automatically generated using `llvm-cov` and saved as GitHub Actions artifacts.
