//
// StartServiceButton.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct StartServiceButton: View {
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    VStack(spacing: 12) {
      Text("Service not running")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button("Start Service") {
        Task {
          await appState.startService()
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
}
