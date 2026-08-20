import UIKit
import ConnectivityAndInternetAccess

/// UIKit Example UIViewController showing lifecycle-aware passive observation + active diagnostic.
public class ConnectivityViewController: UIViewController {

    private var networkToken: NetworkObserverToken?
    private let statusLabel = UILabel()
    private let diagnoseButton = UIButton(type: .system)
    private let diagnosticResultLabel = UILabel()

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Start passive observation when view appears
        networkToken = ConnectivityAndInternetAccess.observeNetwork { [weak self] state in
            self?.updateStatusLabel(state: state)
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Close passive observer when view disappears
        networkToken?.close()
        networkToken = nil
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)

        diagnoseButton.setTitle("Run Active Diagnostic Probe", for: .normal)
        diagnoseButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        diagnoseButton.addTarget(self, action: #selector(didTapDiagnose), for: .touchUpInside)

        diagnosticResultLabel.numberOfLines = 0
        diagnosticResultLabel.textAlignment = .center
        diagnosticResultLabel.font = .systemFont(ofSize: 14)
        diagnosticResultLabel.textColor = .secondaryLabel

        let stackView = UIStackView(arrangedSubviews: [statusLabel, diagnoseButton, diagnosticResultLabel])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func updateStatusLabel(state: NetworkState) {
        statusLabel.text = """
        Passive Network State:
        Connected: \(state.isConnected ? "Yes" : "No")
        Interface: \(state.interfaceType.description)
        Validated: \(state.isInternetValidated ? "Yes" : "No")
        Captive Portal: \(state.isCaptivePortalDetected ? "Yes" : "No")
        """
    }

    @objc private func didTapDiagnose() {
        diagnosticResultLabel.text = "Diagnosing reachability..."
        diagnoseButton.isEnabled = false

        ConnectivityAndInternetAccess.checkInternetAsyncDefault { [weak self] result in
            self?.diagnoseButton.isEnabled = true
            self?.diagnosticResultLabel.text = """
            Diagnostic Result:
            Reachable: \(result.isReachable ? "YES" : "NO")
            Via: \(result.reachedHost ?? "N/A")
            Stage: \(result.stage.description)
            Duration: \(result.durationMs)ms
            """
        }
    }
}
