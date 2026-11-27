import SwiftUI
import AppKit
import HP12CCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: CalculatorViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.saveState()
    }
}

@main
struct HP12CApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = CalculatorViewModel()

    var body: some Scene {
        WindowGroup("HP 12C") {
            CalculatorView(viewModel: viewModel)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first {
                            window.contentAspectRatio = NSSize(width: 940, height: 620)
                        }
                    }
                }
        }
        .defaultSize(width: 940, height: 620)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .pasteboard) {
                Button("Copiar X") {
                    let text = viewModel.copyXString()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Colar em X") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        viewModel.pasteFromString(text)
                    }
                }
                .keyboardShortcut("v", modifiers: .command)
            }

            CommandMenu("Calculadora") {
                Button("Alternar separador decimal (ON + .)") {
                    viewModel.toggleSeparator()
                }
                Button("Reset da memória contínua (ON + −)") {
                    viewModel.resetContinuousMemory()
                }
            }

            CommandGroup(replacing: .help) {
                Button("Atalhos de teclado") {
                    viewModel.showingShortcuts = true
                }
            }
        }
    }
}
