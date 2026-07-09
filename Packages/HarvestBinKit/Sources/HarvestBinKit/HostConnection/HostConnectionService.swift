//
// HostConnectionService.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import BushelHarvestCore
import Foundation

/// Service for handling host-guest communication
///
/// Manages connections from the host machine and processes incoming commands.
public protocol HostConnectionService: Sendable {
  /// Starts the connection service
  /// - Parameter configuration: Service configuration
  /// - Throws: HostConnectionError on failure
  func start(configuration: ConnectionConfiguration) async throws

  /// Stops the connection service
  func stop() async

  /// Gets the current service status
  /// - Returns: Service status information
  var status: ConnectionServiceStatus { get async }

  /// Sets the command handler for processing incoming commands
  /// - Parameter handler: Command processing handler
  func setCommandHandler(
    _ handler: @escaping @Sendable (HarvestCommand) async throws -> HarvestResponse) async
}

/// Connection service configuration
public struct ConnectionConfiguration: Sendable {
  public let port: UInt16
  public let vmIdentifier: String
  public let capabilities: [String]

  public init(
    port: UInt16 = UInt16(HarvestConfiguration.defaultPort),
    vmIdentifier: String = DiscoveryUtils.generateVMIdentifier(),
    capabilities: [String] = ["ssh", "systeminfo"]
  ) {
    self.port = port
    self.vmIdentifier = vmIdentifier
    self.capabilities = capabilities
  }
}

/// Connection service status
public struct ConnectionServiceStatus: Sendable {
  public let isRunning: Bool
  public let connectionCount: Int
  public let isAdvertising: Bool

  public init(isRunning: Bool, connectionCount: Int, isAdvertising: Bool) {
    self.isRunning = isRunning
    self.connectionCount = connectionCount
    self.isAdvertising = isAdvertising
  }
}

/// Host connection errors
public enum HostConnectionError: Error, Sendable {
  case listenerCreationFailed
  case listenerFailed(Error)
  case listenerCancelled
  case connectionFailed(Error)
  case serializationError(Error)
  case noCommandHandler

  public var localizedDescription: String {
    switch self {
    case .listenerCreationFailed:
      return "Failed to create network listener"
    case .listenerFailed(let error):
      return "Network listener failed: \(error.localizedDescription)"
    case .listenerCancelled:
      return "Network listener was cancelled"
    case .connectionFailed(let error):
      return "Connection failed: \(error.localizedDescription)"
    case .serializationError(let error):
      return "Serialization error: \(error.localizedDescription)"
    case .noCommandHandler:
      return "No command handler is configured"
    }
  }
}
