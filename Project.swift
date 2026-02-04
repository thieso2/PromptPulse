import ProjectDescription

let project = Project(
    name: "PromptPulse",
    organizationName: "com.promptpulse",
    options: .options(
        developmentRegion: "en"
    ),
    packages: [
        .local(path: "./PromptPulseLib")
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
                "CFBundleShortVersionString": "0.3.0",
                "CFBundleVersion": "1",
                "NSHumanReadableCopyright": "Copyright 2025",
                "LSMinimumSystemVersion": "15.0"
            ]),
            sources: ["PromptPulse/**/*.swift"],
            resources: [
                "PromptPulse/Resources/**"
            ],
            dependencies: [
                .package(product: "PromptWatchKit")
            ],
            settings: .settings(
                base: [
                    "MACOSX_DEPLOYMENT_TARGET": "15.0",
                    "SWIFT_VERSION": "6.0",
                    "CODE_SIGN_IDENTITY": "-",
                    "PRODUCT_NAME": "PromptPulse"
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"
                    ]),
                    .release(name: "Release", settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                        "SWIFT_OPTIMIZATION_LEVEL": "-O"
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
