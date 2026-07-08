//
// ErrorSection.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct ErrorSection: View {
  let error: String
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Service Error", systemImage: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.red)

      Text(error)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(3)

      Button("Retry") {
        Task {
          await appState.startService()
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding()
  }
}
