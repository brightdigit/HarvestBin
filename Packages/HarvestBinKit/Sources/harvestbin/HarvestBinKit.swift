// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct HarvestBinApp: App {
    var body: some Scene {
      WindowGroup {
        Text("Hello World")
      }
    }
  }
#else
  @main
  struct HarvestBinCLI {
    static func main() {
      print("Error: The harvestbin command is not supported on this platform.")
      print("HarvestBin requires macOS 12.0 or later with SwiftUI support.")
    }
  }
#endif
