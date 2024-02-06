import SwiftUI

public extension View {
  func onGeometry(_ action: @escaping (GeometryProxy) -> Void) -> some View {
    self.overlay {
      GeometryReader(content: { geometry in
        Color.clear.onAppear(perform: {
          action(geometry)
        })
      })
    }
  }
}

class StatusBarManager {
    let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var popover = NSPopover()

    init() {
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
            button.action = #selector(togglePopover(_:))
          button.target = self
        }

      let rootView = StatusBarItemView { size in
        //self.popover.contentSize = size
      }
      let controller = NSHostingController(rootView: rootView)
      popover.contentViewController = controller
      
      
    }

  @objc func togglePopover(_ sender: AnyObject?) {
          if popover.isShown {
              popover.performClose(sender)
          } else {
              if let button = statusBarItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
              }
          }
      }
}

struct StatusBarItemView: View {
  @State var appeared = false
  internal init(onSize: @escaping (CGSize) -> Void) {
    self.onSize = onSize
  }
  
  let onSize : (CGSize) -> Void
    var body: some View {
      HStack{
        Spacer()
        VStack{
          Spacer()
          Text("Status Bar Item")
          Text("Status Bar Item")
          Text("Status Bar Item")
          Text("Status Bar Item")
          Spacer()
        }
        Spacer()
      }.onGeometry { proxy in
        if appeared {
          dump(proxy.size)
          onSize(proxy.size)
        }
      }.onAppear(perform: {
        appeared = true
      })
    }
}

@main
struct YourApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
          EmptyView().hidden()
        }
        .commands {
            CommandMenu("Application") {
                Button("Quit", action: {
                    NSApplication.shared.terminate(nil)
                })
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager()
    }
}
