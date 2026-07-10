//
// RemoteAccessManager.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import Foundation

/// Remote access coordinator for managing SSH and other remote access services
///
/// Coordinates SSH service management, status monitoring, and configuration validation.
public protocol RemoteAccessManager: Sendable {
  /// Enables remote access services
  /// - Parameter type: The type of remote access to enable
  /// - Throws: RemoteAccessError on failure
  func enable(_ type: RemoteAccessType) async throws

  /// Disables remote access services
  /// - Parameter type: The type of remote access to disable
  /// - Throws: RemoteAccessError on failure
  func disable(_ type: RemoteAccessType) async throws

  /// Gets the status of a remote access service
  /// - Parameter type: The type of remote access to check
  /// - Returns: The current status
  /// - Throws: RemoteAccessError on failure
  func status(for type: RemoteAccessType) async throws -> RemoteAccessStatus

  /// Validates the configuration of remote access services
  /// - Returns: True if configuration is valid
  func validateConfiguration() async -> Bool

  /// Monitors remote access services and reports status changes
  /// - Parameter callback: Called when status changes
  /// - Returns: A cancellation token
  func monitorServices(
    _ callback: @escaping @Sendable (RemoteAccessType, RemoteAccessStatus) -> Void
  ) async -> UUID

  /// Stops monitoring a service
  /// - Parameter monitorID: The monitoring session ID
  func stopMonitoring(_ monitorID: UUID) async
}

/// Types of remote access
public enum RemoteAccessType: String, Sendable, CaseIterable {
  case ssh
}

/// Status of remote access services
public enum RemoteAccessStatus: Sendable {
  case ssh(SSHServiceStatus)
}

/// SSH service status
public struct SSHServiceStatus: Sendable {
  public let isEnabled: Bool
  public let isRunning: Bool
  public let port: Int?
  public let connectionCount: Int
  public let lastStartTime: Date?

  public init(
    isEnabled: Bool,
    isRunning: Bool,
    port: Int? = nil,
    connectionCount: Int = 0,
    lastStartTime: Date? = nil
  ) {
    self.isEnabled = isEnabled
    self.isRunning = isRunning
    self.port = port
    self.connectionCount = connectionCount
    self.lastStartTime = lastStartTime
  }
}

/// SSH service manager
public protocol SSHManager: Sendable {
  func enable() async throws
  func disable() async throws
  func status() async throws -> SSHServiceStatus
  func validateConfiguration() async -> Bool
}

/// SSH daemon management
public protocol SSHDaemonManager: Sendable {
  func isRunning() async -> Bool
  func start() async throws
  func stop() async throws
  func connectionDetails() async -> SSHConnectionDetails
}

/// SSH connection details
public struct SSHConnectionDetails: Sendable {
  public let connectionCount: Int
  public let startTime: Date?

  public init(connectionCount: Int = 0, startTime: Date? = nil) {
    self.connectionCount = connectionCount
    self.startTime = startTime
  }
}

/// Errors that can occur during remote access operations
public enum RemoteAccessError: Error, Sendable {
  case unsupportedType(RemoteAccessType)
  case serviceStartFailed(String, output: String)
  case serviceStopFailed(String, output: String)
  case configurationInvalid(String)
  case statusCheckFailed(String, underlying: Error)

  public var localizedDescription: String {
    switch self {
    case .unsupportedType(let type):
      return "Unsupported remote access type: \(type)"
    case .serviceStartFailed(let service, let output):
      return "Failed to start service '\(service)': \(output)"
    case .serviceStopFailed(let service, let output):
      return "Failed to stop service '\(service)': \(output)"
    case .configurationInvalid(let reason):
      return "Invalid configuration: \(reason)"
    case .statusCheckFailed(let service, let error):
      return "Failed to check status of '\(service)': \(error.localizedDescription)"
    }
  }
}
