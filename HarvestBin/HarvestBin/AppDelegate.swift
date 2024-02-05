//
//  AppDelegate.swift
//  HarvestBin
//
//  Created by Leo Dion on 2/5/24.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    //private var window: NSWindow!
    private var statusItem: NSStatusItem!
    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
//        window = NSWindow(
//            contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
//            styleMask: [.miniaturizable, .closable, .resizable, .titled],
//            backing: .buffered, defer: false)
//        window.center()
//        window.title = "No Storyboard Window"
//        window.makeKeyAndOrderFront(nil)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 3
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "1.circle", accessibilityDescription: "1")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

