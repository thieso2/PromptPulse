import ProjectDescription

let project = Project(
    name: "PromptPulse",
    organizationName: "com.promptpulse",
    options: .options(
        developmentRegion: "en"
    ),
    packages: [
        .local(path: "./PromptPulseLib"),
        .remote(url: "https://github.com/sparkle-project/Sparkle", requirement: .upToNextMajor(from: "2.7.0"))
    ],
    targets: [
        .target(
            name: "PromptPulse",
            destinations: [.mac],
            product: .app,
            bundleId: "com.promptpulse.app",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
                "CFBundleIconFile": "AppIcon",
                "CFBundleDisplayName": "PromptPulse",
                "CFBundleShortVersionString": "0.3.7",
                "CFBundleVersion": "0.3.7",
                "NSHumanReadableCopyright": "Copyright (c) 2026 Thies C. Arntzen (thieso@gmail.com)",
                "LSMinimumSystemVersion": "15.0",
                "SUFeedURL": "https://thieso2.github.io/PromptPulse/appcast.xml",
                "SUPublicEDKey": "E5BFoa/g1Sd/vKtouHqmBjic17zqasPPZLl7QKFvhIM=",
                "SUEnableAutomaticChecks": true
            ]),
            sources: ["PromptPulse/**/*.swift"],
            resources: [
                "PromptPulse/Resources/**"
            ],
            entitlements: .file(path: "PromptPulse/Resources/PromptPulse.entitlements"),
            dependencies: [
                .package(product: "PromptWatchKit"),
                .package(product: "Sparkle")
            ],
            settings: .settings(
                base: [
                    "MACOSX_DEPLOYMENT_TARGET": "15.0",
                    "SWIFT_VERSION": "6.0",
                    "CODE_SIGN_IDENTITY": "-",
                    "PRODUCT_NAME": "PromptPulse",
                    "ENABLE_HARDENED_RUNTIME": "YES"
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"
                    ]),
                    .release(name: "Release", settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                        "SWIFT_OPTIMIZATION_LEVEL": "-O",
                        "ENABLE_HARDENED_RUNTIME": "YES"
                    ])
                ]
            )
        ),
        .target(
            name: "PromptPulseTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "com.promptpulse.tests",
            deploymentTargets: .macOS("15.0"),
            sources: ["PromptPulseTests/**/*.swift"],
            dependencies: [
                .target(name: "PromptPulse")
            ]
        )
    ]
)
