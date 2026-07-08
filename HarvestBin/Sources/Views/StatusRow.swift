//
// StatusRow.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI

struct StatusRow: View {
  let icon: String
  let iconColor: Color
  let title: String
  let subtitle: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .foregroundStyle(iconColor)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption)
          .fontWeight(.medium)
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }
}
