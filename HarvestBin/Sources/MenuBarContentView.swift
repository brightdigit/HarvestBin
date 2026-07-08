//
// MenuBarContentView.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit
import BushelHarvestCore

struct MenuBarContentView: View {
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    if #available(macOS 14, *) {
      MenuBarContentViewBody14(appState: appState)
    } else {
      MenuBarContentViewBodyLegacy(appState: appState)
    }
  }
}

@available(macOS 14, *)
private struct MenuBarContentViewBody14: View {
  @ObservedObject var appState: HarvestBinAppState
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    MenuBarContentViewCore(appState: appState, openSettings: { openSettings() })
  }
}

private struct MenuBarContentViewBodyLegacy: View {
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    MenuBarContentViewCore(appState: appState) {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }
}

private struct MenuBarContentViewCore: View {
  @ObservedObject var appState: HarvestBinAppState
  let openSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderSection()
      Divider()

      if appState.isStarting {
        LoadingSection()
      } else if let error = appState.startupError {
        ErrorSection(error: error, appState: appState)
      } else if let status = appState.serviceStatus {
        ConnectionStatusSection(status: status)
        Divider()
        StopServiceButton(appState: appState)
        Divider()
      } else {
        StartServiceButton(appState: appState)
      }

      QuickActionsSection(appState: appState, openSettings: openSettings)
    }
    .frame(width: 280)
    .task {
      if appState.service == nil && !appState.isStarting {
        await appState.startService()
      }
    }
  }
}
