//
//  AppDelegate.swift
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 06/11/2021.
//

import Cocoa
import assimp

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window = NSWindow(contentRect: NSMakeRect(0, 0, 1200,  800),
                          styleMask: [.miniaturizable, .closable, .resizable, .titled],
                          backing: .buffered,
                          defer: false)
        window?.title = "MetalMeshViewer"
        window?.contentViewController = AppViewController()
        window?.makeKeyAndOrderFront(nil)
 }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @objc func load_file() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        var asset_url: URL
        if panel.runModal() == .OK {
            asset_url = panel.url!
            let view_ctrl = window!.contentViewController as! AppViewController
            if view_ctrl.load_file(url: asset_url) {
                NSDocumentController.shared.noteNewRecentDocumentURL(asset_url)
                menu.redo_recent_menu()
            }
        }
    }
    
    @objc func clear_recent_files() {
        NSDocumentController.shared.clearRecentDocuments(self)
        menu.redo_recent_menu()
    }
    
    @objc func load_recent_file(sender: NSMenuItem) {
        // This function is called when the user chooses an item in the Open Recent menu.
        // The sender gets passed along and now we have to go through the list of files
        // in the NSDocumentController until we find the file where the actual file name
        // i.e. lastPathComponent matches the title of the menu entry that was selected.
        // The corresponding URL is then loaded.
        for asset_url in NSDocumentController.shared.recentDocumentURLs {
            if asset_url.lastPathComponent == sender.title {
                let view_ctrl = window!.contentViewController as! AppViewController
                view_ctrl.load_file(url: asset_url)
            }
        }
    }
    
}
