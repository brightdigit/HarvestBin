//
// HeaderSection.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI

struct HeaderSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("HarvestBin")
        .font(.headline)
      Text("Guest Service")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}
