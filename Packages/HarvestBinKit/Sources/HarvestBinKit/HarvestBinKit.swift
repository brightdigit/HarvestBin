//
// HarvestBinService.swift
// HarvestBinService
//
// Copyright (c) 2025 BrightDigit.
//

import BushelHarvestCore
import Foundation

/// Main HarvestBin service for guest-side VM functionality
///
/// Coordinates all HarvestBin services including command execution, remote access, and host communication.
public actor HarvestBinService {
  private let commandExecutor: CommandExecutor
  private let remoteAccessManager: RemoteAccessManager
  private let discoveryService: DiscoveryService
  private let hostConnectionService: HostConnectionService
  private let logger: Logger

  private var isRunning: Bool = false

  /// Initializes HarvestBinService with default components
  public init() {
    let logger = ConsoleLogger()

    self.commandExecutor = DefaultCommandExecutor(logger: logger)
    self.remoteAccessManager = DefaultRemoteAccessManager(logger: logger)
    self.discoveryService = NetworkDiscoveryService(logger: logger)
    self.hostConnectionService = DefaultHostConnectionService(
      discoveryService: discoveryService,
      logger: logger
    )
    self.logger = logger
  }

  /// Initializes HarvestBinService with custom components
  /// - Parameters:
  ///   - commandExecutor: Command execution service
  ///   - remoteAccessManager: Remote access management
  ///   - discoveryService: Service discovery
  ///   - hostConnectionService: Host communication
  ///   - logger: Logging service
  public init(
    commandExecutor: CommandExecutor,
    remoteAccessManager: RemoteAccessManager,
    discoveryService: DiscoveryService,
    hostConnectionService: HostConnectionService,
    logger: Logger = ConsoleLogger()
  ) {
    self.commandExecutor = commandExecutor
    self.remoteAccessManager = remoteAccessManager
    self.discoveryService = discoveryService
    self.hostConnectionService = hostConnectionService
    self.logger = logger
  }

  /// Starts all HarvestBin services
  /// - Parameter configuration: Service configuration
  /// - Throws: HarvestBinError on startup failure
  public func start(configuration: HarvestBinConfiguration = HarvestBinConfiguration()) async throws {
    guard !isRunning else {
      logger.info("HarvestBin services are already running")
      return
    }

    logger.info("Starting HarvestBin services")

    do {
      // Set up command handler for host connections
      await hostConnectionService.setCommandHandler { [weak self] command in
        guard let self = self else {
          throw HarvestBinError.serviceUnavailable("HarvestBin")
        }
        return try await self.commandExecutor.execute(command)
      }

      // Start host connection service
      let connectionConfig = ConnectionConfiguration(
        port: configuration.port,
        vmIdentifier: configuration.vmIdentifier,
        capabilities: configuration.capabilities
      )
      try await hostConnectionService.start(configuration: connectionConfig)

      isRunning = true
      logger.info("HarvestBin services started successfully")

      // Log service status
      await logServiceStatus()

    } catch {
      logger.error("Failed to start HarvestBin services: \(error)")
      throw HarvestBinError.startupFailed(underlying: error)
    }
  }

  /// Stops all HarvestBin services
  public func stop() async {
    guard isRunning else {
      logger.info("HarvestBin services are not running")
      return
    }

    logger.info("Stopping HarvestBin services")

    // Stop host connection service
    await hostConnectionService.stop()

    isRunning = false
    logger.info("HarvestBin services stopped")
  }

  /// Gets the current status of all services
  /// - Returns: Service status information
  public func getStatus() async -> HarvestBinStatus {
    let connectionStatus = await hostConnectionService.status

    return HarvestBinStatus(
      isRunning: isRunning,
      connectionService: connectionStatus,
      vmIdentifier: await getVMIdentifier(),
      capabilities: await getCapabilities()
    )
  }

  /// Executes a command directly (for testing)
  /// - Parameter command: The command to execute
  /// - Returns: The command response
  /// - Throws: HarvestBinError on execution failure
  public func executeCommand(_ command: HarvestCommand) async throws -> HarvestResponse {
    return try await commandExecutor.execute(command)
  }

  /// Enables remote access service
  /// - Parameter type: The type of remote access to enable
  /// - Throws: HarvestBinError on failure
  public func enableRemoteAccess(_ type: RemoteAccessType) async throws {
    do {
      try await remoteAccessManager.enable(type)
      logger.info("Remote access enabled: \(type)")
    } catch {
      logger.error("Failed to enable remote access \(type): \(error)")
      throw HarvestBinError.remoteAccessFailed(underlying: error)
    }
  }

  /// Disables remote access service
  /// - Parameter type: The type of remote access to disable
  /// - Throws: HarvestBinError on failure
  public func disableRemoteAccess(_ type: RemoteAccessType) async throws {
    do {
      try await remoteAccessManager.disable(type)
      logger.info("Remote access disabled: \(type)")
    } catch {
      logger.error("Failed to disable remote access \(type): \(error)")
      throw HarvestBinError.remoteAccessFailed(underlying: error)
    }
  }

  // MARK: - Private Methods

  private func logServiceStatus() async {
    let status = await getStatus()

    logger.info("Service Status:")
    logger.info("  Running: \(status.isRunning)")
    logger.info("  VM ID: \(status.vmIdentifier)")
    logger.info("  Capabilities: \(status.capabilities.joined(separator: ", "))")
    logger.info("  Connections: \(status.connectionService.connectionCount)")
    logger.info("  Advertising: \(status.connectionService.isAdvertising)")
  }

  private func getVMIdentifier() async -> String {
    return DiscoveryUtils.generateVMIdentifier()
  }

  private func getCapabilities() async -> [String] {
    return await DiscoveryUtils.getSystemCapabilities()
  }
}

/// HarvestBin service configuration
public struct HarvestBinConfiguration: Sendable {
  public let port: UInt16
  public let vmIdentifier: String
  public let capabilities: [String]
  public let autoStartRemoteAccess: Bool

  public init(
    port: UInt16 = 8080,
    vmIdentifier: String = DiscoveryUtils.generateVMIdentifier(),
    capabilities: [String] = ["ssh", "systeminfo"],
    autoStartRemoteAccess: Bool = false
  ) {
    self.port = port
    self.vmIdentifier = vmIdentifier
    self.capabilities = capabilities
    self.autoStartRemoteAccess = autoStartRemoteAccess
  }
}

/// HarvestBin service status
public struct HarvestBinStatus: Sendable {
  public let isRunning: Bool
  public let connectionService: ConnectionServiceStatus
  public let vmIdentifier: String
  public let capabilities: [String]

  public init(
    isRunning: Bool,
    connectionService: ConnectionServiceStatus,
    vmIdentifier: String,
    capabilities: [String]
  ) {
    self.isRunning = isRunning
    self.connectionService = connectionService
    self.vmIdentifier = vmIdentifier
    self.capabilities = capabilities
  }
}

/// HarvestBin errors
public enum HarvestBinError: Error, Sendable {
  case startupFailed(underlying: Error)
  case serviceUnavailable(String)
  case remoteAccessFailed(underlying: Error)
  case configurationInvalid(String)

  public var localizedDescription: String {
    switch self {
    case .startupFailed(let error):
      return "HarvestBin startup failed: \(error.localizedDescription)"
    case .serviceUnavailable(let service):
      return "Service unavailable: \(service)"
    case .remoteAccessFailed(let error):
      return "Remote access operation failed: \(error.localizedDescription)"
    case .configurationInvalid(let reason):
      return "Invalid configuration: \(reason)"
    }
  }
}
