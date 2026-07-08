//
// HarvestBinApp.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

@MainActor
final class HarvestBinAppState: ObservableObject {
  @Published var service: HarvestBinService?
  @Published var serviceStatus: HarvestBinStatus?
  @Published var isStarting: Bool = false
  @Published var startupError: String?

  func startService() async {
    guard service == nil else { return }

    isStarting = true
    startupError = nil

    do {
      let newService = HarvestBinService()
      try await newService.start()
      service = newService
      serviceStatus = await newService.getStatus()
    } catch {
      startupError = "Failed to start: \(error.localizedDescription)"
      print("[ERROR] \(startupError!)")
    }

    isStarting = false
  }

  func stopService() async {
    guard let service = service else { return }
    await service.stop()
    self.service = nil
    self.serviceStatus = nil
  }

  func refreshStatus() async {
    guard let service = service else { return }
    serviceStatus = await service.getStatus()
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillTerminate(_ notification: Notification) {
    // Service cleanup handled by app shutdown
  }
}

@main
struct HarvestBinApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate

  @StateObject private var appState = HarvestBinAppState()

  var body: some Scene {
    MenuBarExtra("HarvestBin", systemImage: connectionStatusIcon) {
      MenuBarContentView(appState: appState)
    }

    Settings {
      SettingsView(appState: appState)
    }
  }

  private var connectionStatusIcon: String {
    guard let status = appState.serviceStatus else {
      return "antenna.radiowaves.left.and.right.slash"
    }
    return status.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
  }
}
