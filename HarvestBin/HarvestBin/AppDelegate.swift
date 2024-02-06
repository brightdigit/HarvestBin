//
//  AppDelegate.swift
//  HarvestBin
//
//  Created by Leo Dion on 2/5/24.
//

import Cocoa

@objc
class MenuItemHolder : NSObject {
    internal init(menuItem: MenuItem) {
        self.menuItem = menuItem
    }
    
    @objc
    func action(_ sender: NSMenuItem) {
        guard let menuItem = self.menuItem as? ActionMenuItem else {
            assertionFailure()
            return
        }
        menuItem.action(sender)
    }
    
    let menuItem: MenuItem
    
    func createMenuItem () -> NSMenuItem {
        
        let nsMenuItem = NSMenuItem(
            title: menuItem.title,
            action: nil,
            keyEquivalent: menuItem.keyEquivalent
        )
        
        if menuItem is ActionMenuItem {
            nsMenuItem.action = #selector(self.action(_:))
            nsMenuItem.target = self
        }
        return nsMenuItem
    }
}

protocol ActionMenuItem {
    func action(_ sender: NSMenuItem)
}
protocol MenuItem {
    var title : String { get }
    var keyEquivalent : String { get }
    
}

extension NSMenu {
    @discardableResult
    func menuItem (_ menuItem: MenuItem) -> NSMenuItem {
        let holder = MenuItemHolder(menuItem: menuItem)
        let item = NSMenuItem(title: menuItem.title, action: #selector(holder.action(_:)), keyEquivalent: menuItem.keyEquivalent)
        item.target = holder
        self.addItem(item)
        return item
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    //private var window: NSWindow!
    private var statusItem: NSStatusItem!
    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
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

