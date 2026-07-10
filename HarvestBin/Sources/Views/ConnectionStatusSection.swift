//
// ConnectionStatusSection.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct ConnectionStatusSection: View {
  let status: HarvestBinStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      StatusRow(
        icon: status.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill",
        iconColor: status.isRunning ? .green : .red,
        title: status.isRunning ? "Connected to Host" : "Disconnected",
        subtitle: "VirtioSocket connection"
      )

      StatusRow(
        icon: "number",
        iconColor: .blue,
        title: "VM Identifier",
        subtitle: status.vmIdentifier
      )

      if !status.capabilities.isEmpty {
        StatusRow(
          icon: "star.fill",
          iconColor: .orange,
          title: "Capabilities",
          subtitle: status.capabilities.joined(separator: ", ")
        )
      }
    }
    .padding()
  }
}
