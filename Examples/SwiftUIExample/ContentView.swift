import SwiftUI
import ConnectivityAndInternetAccess

/// SwiftUI Example View demonstrating recommended passive network observation + active reachability diagnosis on tap.
public struct ConnectivityExampleView: View {
    @StateObject private var observer = ConnectivityObserver()

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Passive Default Network State")) {
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        Label(
                            observer.networkState.isConnected ? "Connected" : "Offline",
                            systemImage: observer.networkState.isConnected ? "wifi" : "wifi.slash"
                        )
                        .foregroundColor(observer.networkState.isConnected ? .green : .red)
                    }

                    HStack {
                        Text("Interface Type")
                        Spacer()
                        Text(observer.networkState.interfaceType.description)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Internet Validated")
                        Spacer()
                        Text(observer.networkState.isInternetValidated ? "Yes" : "No")
                            .foregroundColor(observer.networkState.isInternetValidated ? .green : .orange)
                    }

                    HStack {
                        Text("Captive Portal Detected")
                        Spacer()
                        Text(observer.networkState.isCaptivePortalDetected ? "Yes" : "No")
                            .foregroundColor(observer.networkState.isCaptivePortalDetected ? .red : .secondary)
                    }

                    HStack {
                        Text("Low Data / Expensive")
                        Spacer()
                        Text(observer.networkState.isExpensive ? "Expensive" : "Normal")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Active Reachability Diagnostic")) {
                    Button(action: {
                        observer.runActiveDiagnostic()
                    }) {
                        HStack {
                            Text("Run Active Diagnostic")
                            Spacer()
                            if observer.isDiagnosing {
                                ProgressView()
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(observer.isDiagnosing)

                    if let result = observer.lastDiagnosticResult {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Reachable:")
                                    .bold()
                                Text(result.isReachable ? "YES" : "NO")
                                    .foregroundColor(result.isReachable ? .green : .red)
                            }
                            if let host = result.reachedHost {
                                Text("Reached Via: \(host)")
                                    .font(.subheadline)
                            }
                            Text("Stage: \(result.stage.description)")
                                .font(.subheadline)
                            Text("Duration: \(result.durationMs) ms")
                                .font(.subheadline)
                            if !result.attemptedHosts.isEmpty {
                                Text("Attempted Probes: \(result.attemptedHosts.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Connectivity iOS")
        }
    }
}

#if DEBUG
struct ConnectivityExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectivityExampleView()
    }
}
#endif
