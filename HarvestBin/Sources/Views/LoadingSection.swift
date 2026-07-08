//
// LoadingSection.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI

struct LoadingSection: View {
  var body: some View {
    VStack(spacing: 12) {
      ProgressView()
        .controlSize(.small)
      Text("Starting service...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
}
