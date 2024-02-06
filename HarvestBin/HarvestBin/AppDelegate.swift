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
            keyEquivalent: menuItem.actualKeyEquivalent
        )
        
        nsMenuItem.image = menuItem.image
        
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
    var keyEquivalent : String? { get }
    var image : NSImage? { get }
}

extension MenuItem {
    var image : NSImage? {
        return nil
    }
    
    var actualKeyEquivalent : String {
        self.keyEquivalent ?? ""
    }
}

extension NSMenu {
    @discardableResult
    func menuItem (_ menuItem: MenuItem) -> NSMenuItem {
        let holder = MenuItemHolder(menuItem: menuItem)
        let item = holder.createMenuItem()
        self.addItem(item)
        return item
    }
}

struct SecondMenuItem : MenuItem {
    let title: String = "Second Menu Item"
    
    let keyEquivalent: String? = nil
    
    var image: NSImage? = NSImage(systemSymbolName: "2.circle", accessibilityDescription: nil)
    
    
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
        
        let menu = NSMenu()
        menu.menuItem(SecondMenuItem())
        self.statusItem.menu = menu
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

