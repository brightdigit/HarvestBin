import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  
}
@main
struct HarvestBinApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
  
  var body: some Scene {
    Settings{
      Button("Hello World") {
        print("Hello!")
      }
    }
  }
}
