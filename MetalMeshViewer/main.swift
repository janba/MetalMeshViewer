//
//  main.swift
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 08/11/2021.
//
// Following advice from Ryan Theodore which was written up in the Medium article:
// "Creating macOS apps without a storyboard or .xib file with Swift 5",
// we are making this app without any .xib files or storyboard. It is simply so
// complicated to figure out the interactions between the visual representation of the
// interface and the code that it is better to do without. However, it means that we
// need to create a few globals manually below.

import Foundation
import Cocoa
let delegate = AppDelegate()
let menu = AppMenu()
NSApplication.shared.delegate = delegate
NSApplication.shared.mainMenu = menu
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
