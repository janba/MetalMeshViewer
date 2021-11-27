//
//  AppMenu.swift
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 08/11/2021.
//

import Cocoa

class AppMenu: NSMenu {
    private lazy var applicationName = ProcessInfo.processInfo.processName
    var recent_menu: NSMenu?
    
    override init(title: String) {
        // The menu is created programmatically since we do not use a storyboard for this app.
        // One complication is that we have to deal with the Open Recent Menu in a very explicit
        // manual way. However, the NSDocumentController can still be used as a persistent data
        // base for recently opened files - it is just turning this data base into menu items
        // that is now manual.
        super.init(title: title)
        let menuItemOne = NSMenuItem()
        menuItemOne.submenu = NSMenu(title: "menuItemOne")
        menuItemOne.submenu?.items = [NSMenuItem(title: "Quit \(applicationName)",
                                                 action: #selector(NSApplication.terminate(_:)),
                                                 keyEquivalent: "q")]
        let delegate = NSApplication.shared.delegate as? AppDelegate
        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: "File")
        fileMenu.submenu?.items = [
            NSMenuItem(title: "Open", action: #selector(delegate?.load_file), keyEquivalent: "o"),
            NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "") ]
        recent_menu = NSMenu(title: "recent")
        fileMenu.submenu?.items[1].submenu = recent_menu
        redo_recent_menu()
        items = [menuItemOne, fileMenu]
    }
    
    func redo_recent_menu() {
        // We have to recreate the open recent file menu every time a new mesh is loaded.
        // The NSDocumentController keeps track of our files, so below, URLs are simply copied
        // from the controller to the menu.
        let delegate = NSApplication.shared.delegate as? AppDelegate
        recent_menu?.items.removeAll()
        for asset_url in NSDocumentController.shared.recentDocumentURLs {
            recent_menu?.items.append(contentsOf: [NSMenuItem(title: asset_url.lastPathComponent,
                                                              action: #selector(delegate?.load_recent_file),
                                                              keyEquivalent: "")])
        }
        recent_menu?.items.append(contentsOf: [NSMenuItem.separator(), NSMenuItem(title: "clear", action: #selector(delegate?.clear_recent_files), keyEquivalent: "")])
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
}
