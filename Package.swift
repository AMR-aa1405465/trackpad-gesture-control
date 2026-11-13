// swift-tools-version:5.9
import PackageDescription

// Layered architecture. Dependencies only point DOWN this list:
//   TrackpadGestureControl (executable, composition root)
//     -> GestureCLI -> GestureConfig -> GestureActions -> GestureCore
//     -> GestureEngine (recognizers + OS input) -> GestureCore
let package = Package(
    name: "TrackpadGestureControl",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "trackpad-gestures", targets: ["TrackpadGestureControl"])
    ],
    targets: [
        // Domain layer: pure models + protocols. No OS imports beyond Foundation.
        .target(name: "GestureCore"),

        // Recognition layer: turns touch frames into gestures; OS touch input adapters.
        .target(name: "GestureEngine", dependencies: ["GestureCore"]),

        // Action layer: things that can be triggered (launch app, key press, click).
        .target(name: "GestureActions", dependencies: ["GestureCore"]),

        // Config layer: JSON <-> bindings (gesture trigger -> action).
        .target(name: "GestureConfig", dependencies: ["GestureCore", "GestureActions"]),

        // Tiny C wrapper around libedit: line editing, history and Tab completion for the menu.
        .target(name: "CEditline", linkerSettings: [.linkedLibrary("edit")]),

        // CLI layer: command engine (router + commands). No UI; everything is terminal-driven.
        .target(
            name: "GestureCLI",
            dependencies: ["GestureCore", "GestureEngine", "GestureActions", "GestureConfig", "CEditline"]
        ),

        // Composition root: wires everything together. Contains no business logic.
        .executableTarget(
            name: "TrackpadGestureControl",
            dependencies: ["GestureCLI"]
        ),

        .testTarget(
            name: "GestureEngineTests",
            dependencies: ["GestureCore", "GestureEngine"]
        ),
        .testTarget(
            name: "GestureConfigTests",
            dependencies: ["GestureCore", "GestureActions", "GestureConfig"]
        ),
    ]
)
