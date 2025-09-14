//
//  XCStringEditorApp.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/20/24.
//

import SwiftUI

extension Notification.Name {
    static let findCommand = Notification.Name("findCommand")
}

@main
struct XCStringEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.controlActiveState) private var controlActiveState
    
    @State private var appModel: AppModel = AppModel()
    @State private var isDiscardConfirmVisible: Bool = false
    
    var body: some Scene {
        Window("XCStringsEditor", id: "main") {
            ContentView()
                .background(FileDropView { url in
                    openURL(url)
                })
                .environment(appModel)
                .environment(appDelegate.windowDelegate)
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
                    for document in appModel.documents {
                        if let url = document.settingsFileURL {
                            document.settings.save(to: url)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .receivedOpenURLsNotification), perform: { newValue in
                    guard let urls = newValue.userInfo?["urls"] as? [URL] else {
                        return
                    }
                    for url in urls {
                        openURL(url)
                    }
                })
                .confirmationDialog("Unsaved Changes Detected", isPresented: $isDiscardConfirmVisible) {
                    Button("Save and Open", role: .none) {
                        for document in appModel.documents {
                            guard let url = document.openingFileURL else {
                                return
                            }
                            document.save()
                            document.load(file: url)
                        }
                    }
                    
                    Button("Discard and Open", role: .destructive) {
                        for document in appModel.documents {
                            guard let url = document.openingFileURL else {
                                return
                            }
                            document.load(file: url)
                        }
                    }
                    
                    Button("Cancel", role: .cancel) {
                    }
                } message: {
                    Text("You have unsaved changes. Do you want to save your changes before opening a new file?")
                }

        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Divider()
                Button("Open") {
                    open()
                }
                .keyboardShortcut("o", modifiers: [.command]) // Cmd + O
                
                Menu("Open Recent") {
                    let recents = (UserDefaults.standard.array(forKey: "RecentFiles") as? [String])?.map { URL(filePath: $0) } ?? [URL]()
                    if recents.isEmpty == false {
                        ForEach(recents.reversed(), id: \.self) { url in
                            Button {
                                appModel.load(file: url)
                                
                                var recents = UserDefaults.standard.array(forKey: "RecentFiles") as? [String] ?? [String]()
                                if let index = recents.firstIndex(where: { $0 == url.path(percentEncoded: false) }) {
                                    recents.remove(at: index)
                                    recents.append(url.path(percentEncoded: false))
                                    UserDefaults.standard.set(recents, forKey: "RecentFiles")
                                }
                            } label: {
                                HStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                                    Text(verbatim: url.lastPathComponent)
                                }
                            }
                        }
                        Divider()
                        Button("Clear Menu") {
                            UserDefaults.standard.removeObject(forKey: "RecentFiles")
                        }
                    }
                }
                
                Divider()
                
                Button("Save") {
                    for document in appModel.documents {
                        document.save()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command]) // Cmd + S
//                .disabled(appModel.fileURL == nil)
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Source Text") {
                    for document in appModel.documents {
                        document.copySourceText()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .control]) // Cmd + Control + C
                .disabled(appModel.selected.isEmpty)
                
                Button("Copy Translation") {
                    for document in appModel.documents {
                        document.copyTranslationText()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .option]) // Cmd + Option + C
                .disabled(appModel.selected.isEmpty)

                Button("Copy Source and Translation Text") {
                    for document in appModel.documents {
                        document.copySourceAndTranslationText()
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .option, .control]) // Cmd + Option + Control + C
                .disabled(appModel.selected.isEmpty)

                Divider() // ------------------------
                
                Button("Clear Translation") {
                    for document in appModel.documents {
                        document.clearTranslation()
                    }
                }
                .keyboardShortcut("e", modifiers: [.command]) // Cmd + E
                .disabled(appModel.selected.isEmpty)
                
                Button("Copy from Source Text") {
                    for document in appModel.documents {
                        document.copyFromSourceText()
                    }
                }
                .keyboardShortcut("d", modifiers: [.command]) // Cmd + D
                .disabled(appModel.selected.isEmpty)
                
                Divider() // ------------------------
                
                Button("Mark for Review") {
                    for document in appModel.documents {
                        document.markNeedsReview()
                    }
                }
                .disabled(appModel.selected.isEmpty)
                Button("Mark as Reviewed") {
                    for document in appModel.documents {
                        document.reviewed()
                    }
                }
                .disabled(appModel.selected.isEmpty)

                if appModel.selected.isEmpty == false && appModel.documents.flatMap({ $0.items(with: Array(appModel.selected))}).allSatisfy({ $0.shouldTranslate == false }) {
                    Button("Mark for Translation") {
                        for document in appModel.documents {
                            document.setShouldTranslate(true)
                        }
                    }
                } else {
                    Button("Mark as \"Don't Translate\"") {
                        for document in appModel.documents {
                            document.setShouldTranslate(false)
                        }
                    }
                    .disabled(appModel.selected.isEmpty)
                }
                                
                Divider()
                
                Button("Mark for Translate Later") {
                    for document in appModel.documents {
                        document.markTranslateLater(value: true)
                    }
                }
                .keyboardShortcut("l", modifiers: [.command]) // Cmd + L
                .disabled(appModel.selected.isEmpty)
                
                Button("Unmark Translate Later") {
                    for document in appModel.documents {
                        document.markTranslateLater(value: false)
                    }
                }
                .keyboardShortcut("l", modifiers: [.shift, .command]) // Cmd + Shift + L
                .disabled(appModel.selected.isEmpty)
                
                Button("Mark for Needs Work") {
                    for document in appModel.documents {
                        document.markNeedsWork(value: true)
                    }
                }
                .keyboardShortcut("w", modifiers: [.control, .command]) // Cmd + Control + W
                .disabled(appModel.selected.isEmpty)

                Button("Mark for Needs Work for All Languages") {
                    for document in appModel.documents {
                        document.markNeedsWork(value: true, allLanguages: true)
                    }
                }
                .disabled(appModel.selected.isEmpty)
                .keyboardShortcut("w", modifiers: [.control, .option, .command]) // Cmd + Option + Control + W
                
                Button("Clear Needs Work for All Languages") {
                    for document in appModel.documents {
                        document.clearNeedsWork(allLanguages: true)
                    }
                }

                Button("Unmark Needs Work") {
                    for document in appModel.documents {
                        document.markNeedsWork(value: false)
                    }
                }
                .keyboardShortcut("w", modifiers: [.control, .shift, .command]) // Cmd + Shift + Control + W
                .disabled(appModel.selected.isEmpty)

                Divider() // ------------------------
                
                Button("Auto Translate") {
                    Task {
                        for document in appModel.documents {
                            await document.translate()
                        }
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .option]) // Cmd + Option + T
                .disabled(appModel.selected.isEmpty)

                Button("Reverse Translate") {
                    Task {
                        for document in appModel.documents {
                            await document.reverseTranslate()
                        }
                    }
                }
                .keyboardShortcut("t", modifiers: [.shift, .option, .command]) // Cmd + Option + Shift + T
                .disabled(appModel.selected.isEmpty)

                Button("Check Translation") {
                    for document in appModel.documents {
                        document.detectLanguage()
                    }
                }
                .disabled(true) //stringsModel.selected.isEmpty)
            }
            CommandGroup(after: .toolbar) {
                Button(appModel.staleItemsHidden ? "Show Stale Items" : "Hide Stale Items") {
                    appModel.staleItemsHidden.toggle()
                }
                Button(appModel.dontTranslateItemsHidden ? "Show \"Don't Translate\" Items" : "Hide \"Don't Translate\" Items") {
                    appModel.dontTranslateItemsHidden.toggle()
                }
                Button(appModel.translateLaterItemsHidden ? "Show Translate Later Items" : "Hide Translate Later Items") {
                    appModel.translateLaterItemsHidden.toggle()
                }
                Divider()
            }
            
            CommandGroup(replacing: .appInfo) {
                Button("About XCStringsEditor") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "https://github.com/xiles",
                                attributes: [
                                    NSAttributedString.Key.font: NSFont.boldSystemFont(
                                        ofSize: NSFont.smallSystemFontSize)
                                ]
                            )
                        ]
                    )
                }
            }
        } // commands
        
        if #available(macOS 15.0, *) {
            Window("Welcome", id: "welcome") {
                WelcomeView()
                    .environment(appModel)
            }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(.presented)
        }
        
        Settings {
            SettingsView()
                .environment(appModel)
        }
    }
}

extension XCStringEditorApp {
    func open() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let fileURL = panel.url {
                openURL(fileURL)
            }
        }
    }

    private func openURL(_ url: URL) {
        appModel.load(file: url)
    }
}
