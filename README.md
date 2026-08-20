# ConnectivityAndInternetAccess-iOS-mobile

[![CI & Automated Testing](https://github.com/rodrigosambadesaa/ConnectivityAndInternetAccess-iOS-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/rodrigosambadesaa/ConnectivityAndInternetAccess-iOS-mobile/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%2013%2B%20%7C%20macOS%2011%2B%20%7C%20tvOS%2013%2B%20%7C%20watchOS%206%2B-blue.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Reimplementación completa y modernizada en Swift para iOS / macOS / tvOS / watchOS del gist de conectividad y acceso a Internet para Android:
👉 **Gist de referencia (Android Java/Kotlin):** [rodrigosambadesaa/729cca29a031fef4e2f15751863b655f](https://gist.github.com/rodrigosambadesaa/729cca29a031fef4e2f15751863b655f)

---

## 🇪🇸 Descripción en Español

Esta librería proporciona un sistema de diagnóstico de conectividad de dos capas optimizado para iOS:

1. **Observación Pasiva de Red (`NetworkObserver`):**
   - Utiliza `NWPathMonitor` de Apple para monitorizar cambios de red de forma eficiente sin generar tráfico DNS ni HTTP.
   - Devuelve snapshots `NetworkState` con estado de conexión, tipo de interfaz (Wi-Fi, Cellular, Ethernet, VPN), validación del sistema y detección de portales cautivos.
   - Soporta callbacks de cierre (`NetworkObserverToken`), **Combine Publishers** (`AnyPublisher<NetworkState, Never>`), **Swift AsyncSequence** (`AsyncStream<NetworkState>`) e integración reactiva con **SwiftUI** (`ConnectivityObserver`).

2. **Diagnóstico Activo Multietapa (`checkInternetAsync` / `checkInternetBlocking`):**
   - Pipeline de diagnóstico con límite de tiempo global estricto (deadline por defecto de 2.0s):
     - **Etapa 1: Preflight DNS de Sistema** (presupuesto ~350ms): Resolución mediante el resolver DNS configurado en el dispositivo (`getaddrinfo`).
     - **Etapa 2: Consultas DNS UDP Directas en Paralelo** (presupuesto ~700ms total DNS): Envío paralelo de paquetes de consulta DNS A sobre UDP a servidores públicos (Cloudflare `1.1.1.1`, Google `8.8.8.8`, Quad9 `9.9.9.9`, OpenDNS `208.67.222.222`).
     - **Etapa 3: Sondas HTTP/HTTPS en Paralelo** (tiempo restante): Peticiones ligeras HEAD/GET a endpoints confiables (`generate_204`, Apple, Cloudflare, Amazon, Facebook).
   - El primer resultado exitoso cancela inmediatamente las sondas restantes.

3. **Modo Estricto Portal Cautivo (`strictCaptivePortalBuilder`):**
   - Desactiva las etapas DNS y realiza peticiones HTTP a endpoints `generate_204` rechazando redirecciones y exigiendo código de estado 204 No Content (o 200 OK verificado).

---

## 🇬🇧 English Summary

A modern, zero-dependency Swift package bringing the 2-tier Android connectivity diagnostic architecture to iOS, macOS, tvOS, and watchOS.

- **Passive Observation (`NWPathMonitor`):** Cheap, event-driven network path tracking with zero probe traffic. Supports closures, Combine, AsyncSequence, and SwiftUI bindings.
- **Active Multi-Stage Diagnostics:** Bounded global deadline engine (System DNS preflight -> Parallel Direct UDP DNS -> Parallel HTTP/HTTPS probes).
- **Strict Captive Portal Mode:** Verifies HTTP 204 response without following redirects.
- **Fluent Builder API:** Fully customizable hosts, DNS resolvers, and probe strategies.

---

## 🚀 Instalación con Swift Package Manager (SPM)

Agrega la dependencia a tu archivo `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rodrigosambadesaa/ConnectivityAndInternetAccess-iOS-mobile.git", from: "1.0.0")
]
```

O en Xcode: `File > Add Package Dependencies...` e ingresa la URL del repositorio.

---

## 💻 Ejemplos de Uso

### 1. Observación Pasiva (Recomendado para el flujo normal)

```swift
import ConnectivityAndInternetAccess

class ViewController: UIViewController {
    private var token: NetworkObserverToken?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        token = ConnectivityAndInternetAccess.observeNetwork { state in
            print("Conectado: \(state.isConnected)")
            print("Interfaz: \(state.interfaceType)")
            print("Validado por SO: \(state.isInternetValidated)")
            print("Portal Cautivo: \(state.isCaptivePortalDetected)")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        token?.close()
    }
}
```

### 2. Diagnóstico Activo de Alcance a Internet

```swift
// Diagnóstico asíncrono con callback
let request = ConnectivityAndInternetAccess.checkInternetAsyncDefault { result in
    print("Internet Alcanzable: \(result.isReachable)")
    print("Endpoint: \(result.reachedHost ?? "N/A")")
    print("Etapa Exitosa: \(result.stage)")
    print("Duración: \(result.durationMs) ms")
}

// O usando Swift Concurrency (async/await)
Task {
    let connectivity = ConnectivityAndInternetAccess()
    let result = await connectivity.checkInternetAsync()
    print("Resultado: \(result)")
}
```

### 3. Integración Directa en SwiftUI

```swift
import SwiftUI
import ConnectivityAndInternetAccess

struct ContentView: View {
    @StateObject private var observer = ConnectivityObserver()

    var body: some View {
        VStack(spacing: 16) {
            Text(observer.networkState.isConnected ? "🟢 En línea" : "🔴 Sin conexión")
                .font(.title)

            Text("Tipo de red: \(observer.networkState.interfaceType.description)")

            Button("Diagnosticar Alcance Real") {
                observer.runActiveDiagnostic()
            }

            if let result = observer.lastDiagnosticResult {
                Text("Alcance verificado vía \(result.reachedHost ?? "desconocido") (\(result.durationMs)ms)")
                    .font(.caption)
            }
        }
    }
}
```

### 4. Modo Estricto para Portales Cautivos

```swift
let strictConnectivity = ConnectivityAndInternetAccess.strictCaptivePortalBuilder().build()

strictConnectivity.checkInternetAsync { result in
    if result.isReachable {
        print("Acceso transparente a Internet verificado")
    } else {
        print("Sin conexión o bloqueado tras un portal cautivo")
    }
}
```

---

## ⚙️ CI & Pruebas Automatizadas en GitHub Actions

El repositorio incluye un workflow completo de integración continua en `.github/workflows/ci.yml` configurado para ejecutarse en entornos **macOS 14** con Xcode 15.4 / 16.0:

```bash
# Ejecutar pruebas unitarias de forma paralela con cobertura de código
swift test --enable-code-coverage --parallel
```

---

## 📜 Licencia

MIT License. Copyright (c) 2013 Emil Davtyan, 2017 str4d, 2026 Rodrigo Sambade Saa y colaboradores. Consulta el archivo [LICENSE](LICENSE) para más detalles.
