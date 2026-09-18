// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "AIQuota",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIQuotaCore", targets: ["AIQuotaCore"]),
        .executable(name: "aiquota-cli", targets: ["aiquota-cli"]),
        .executable(name: "AIQuota", targets: ["AIQuota"])
    ],
    targets: [
        .target(
            name: "AIQuotaCore",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "aiquota-cli",
            dependencies: ["AIQuotaCore"]
        ),
        .executableTarget(
            name: "AIQuota",
            dependencies: ["AIQuotaCore"],
            // As logos das IAs. O SwiftPM empacota isso num bundle separado
            // (AIQuota_AIQuota.bundle) que o scripts/build-app.sh precisa copiar para dentro do
            // .app — sem isso o app instalado roda sem as logos.
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "AIQuotaCoreTests",
            dependencies: ["AIQuotaCore"],
            swiftSettings: [
                // Nesta instalação (Command Line Tools sem Xcode completo), o SwiftPM não
                // localiza sozinho o plugin de macros do swift-testing (fica em
                // .../usr/lib/swift/host/plugins/testing, fora do caminho padrão). Sem isso,
                // `swift test` falha com "plugin for module 'TestingMacros' not found".
                .unsafeFlags([
                    "-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
                ])
            ]
        )
    ]
)
