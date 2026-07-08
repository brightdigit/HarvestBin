//
// StopServiceButton.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct StopServiceButton: View {
  @ObservedObject var appState: HarvestBinAppState
  @State private var isStopping = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        Task {
          isStopping = true
          await appState.stopService()
          isStopping = false
        }
      } label: {
        Label(
          isStopping ? "Stopping Service..." : "Stop Service",
          systemImage: "stop.circle.fill"
        )
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.borderedProminent)
      .tint(.red)
      .disabled(isStopping)
      .padding(.horizontal)
    }
    .padding(.vertical, 8)
  }
}
