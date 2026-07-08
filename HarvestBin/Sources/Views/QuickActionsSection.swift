//
// QuickActionsSection.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct QuickActionsSection: View {
  @ObservedObject var appState: HarvestBinAppState
  let openSettings: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Button {
        Task {
          await appState.refreshStatus()
        }
      } label: {
        Label("Refresh Status", systemImage: "arrow.clockwise")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      .padding(.vertical, 6)

      if appState.service != nil {
        Button {
          Task {
            await appState.stopService()
            await appState.startService()
          }
        } label: {
          Label("Restart Service", systemImage: "arrow.triangle.2.circlepath")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 6)
      }

      Button {
        openSettings()
      } label: {
        Label("Settings", systemImage: "gear")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      .padding(.vertical, 6)

      Divider()

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Label("Quit HarvestBin", systemImage: "power")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .padding(.horizontal)
      .padding(.vertical, 6)
    }
  }
}
