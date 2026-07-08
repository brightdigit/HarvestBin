//
// SettingsView.swift
// HarvestBin
//
// Copyright (c) 2025 BrightDigit.
//

import SwiftUI
import HarvestBinKit

struct SettingsView: View {
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    TabView {
      GeneralSettingsView(appState: appState)
        .tabItem {
          Label("General", systemImage: "gear")
        }

      ServiceSettingsView(appState: appState)
        .tabItem {
          Label("Service", systemImage: "server.rack")
        }

      AboutView()
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
    }
    .frame(width: 500, height: 400)
  }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
  @ObservedObject var appState: HarvestBinAppState
  @AppStorage("autoStartService") private var autoStartService = true
  @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

  var body: some View {
    Form {
      Section {
        Toggle("Auto-start service at login", isOn: $autoStartService)
        Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
      } header: {
        Text("Preferences")
      }

      Section {
        Toggle("Enable debug logging", isOn: .constant(false))
          .disabled(true)
      } header: {
        Text("Logging")
      } footer: {
        Text("Debug logging is currently disabled.")
          .font(.caption)
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

// MARK: - Service Settings

struct ServiceSettingsView: View {
  @ObservedObject var appState: HarvestBinAppState

  var body: some View {
    Form {
      if let status = appState.serviceStatus {
        Section {
          LabeledContent("Status") {
            HStack {
              Circle()
                .fill(status.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
              Text(status.isRunning ? "Running" : "Stopped")
                .foregroundStyle(.secondary)
            }
          }

          LabeledContent("VM Identifier") {
            Text(status.vmIdentifier)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }

          LabeledContent("Connection Type") {
            Text("VirtioSocket")
              .foregroundStyle(.secondary)
          }

          LabeledContent("Port") {
            Text("8080 (AF_VSOCK)")
              .foregroundStyle(.secondary)
          }

          LabeledContent("Capabilities") {
            Text(status.capabilities.joined(separator: ", "))
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Service Information")
        }

        Section {
          LabeledContent("Connection Count") {
            Text("\(status.connectionService.connectionCount)")
              .foregroundStyle(.secondary)
          }

          LabeledContent("Advertising") {
            Text(status.connectionService.isAdvertising ? "Yes" : "No")
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Connection Details")
        }
      } else {
        Section {
          Text("Service is not running")
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .padding()
    .task {
      await appState.refreshStatus()
    }
  }
}

// MARK: - About

struct AboutView: View {
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.blue)

      VStack(spacing: 4) {
        Text("HarvestBin")
          .font(.title)
          .fontWeight(.bold)

        Text("Version 1.0.0")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 2) {
        Text("Guest Service for Bushel VMs")
          .font(.caption)

        Text("Copyright © 2025 BrightDigit LLC")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
