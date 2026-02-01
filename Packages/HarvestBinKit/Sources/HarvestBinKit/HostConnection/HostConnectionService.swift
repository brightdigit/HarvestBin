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
    port: UInt16 = 8080,
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

#if canImport(Network)
  import Network

  /// Default implementation of HostConnectionService
  public actor DefaultHostConnectionService: HostConnectionService {
    private let discoveryService: DiscoveryService
    private let logger: Logger

    private var listener: NWListener?
    private var activeConnections: Set<HostConnection> = []
    private var commandHandler: (@Sendable (HarvestCommand) async throws -> HarvestResponse)?
    private var isRunning: Bool = false

    /// Initializes the host connection service
    /// - Parameters:
    ///   - discoveryService: Service discovery for advertising
    ///   - logger: Logging service
    public init(
      discoveryService: DiscoveryService = NetworkDiscoveryService(),
      logger: Logger = ConsoleLogger()
    ) {
      self.discoveryService = discoveryService
      self.logger = logger
    }

    public func start(configuration: ConnectionConfiguration) async throws {
      logger.info("Starting host connection service on port \(configuration.port)")

      // Stop any existing service
      await stop()

      // Start the network listener
      try await startListener(port: configuration.port)

      // Start service discovery advertising
      try await discoveryService.startAdvertising(
        vmIdentifier: configuration.vmIdentifier,
        capabilities: configuration.capabilities
      )

      isRunning = true
      logger.info("Host connection service started successfully")
    }

    public func stop() async {
      logger.info("Stopping host connection service")

      isRunning = false

      // Cancel the listener
      listener?.cancel()
      listener = nil

      // Close all active connections
      let connections = activeConnections
      activeConnections.removeAll()

      for connection in connections {
        await connection.close()
      }

      // Stop service advertising
      await discoveryService.stopAdvertising()

      logger.info("Host connection service stopped")
    }

    public var status: ConnectionServiceStatus {
      get async {
        return ConnectionServiceStatus(
          isRunning: isRunning,
          connectionCount: activeConnections.count,
          isAdvertising: await discoveryService.isAdvertising
        )
      }
    }

    public func setCommandHandler(
      _ handler: @escaping @Sendable (HarvestCommand) async throws -> HarvestResponse
    ) async {
      self.commandHandler = handler
      logger.info("Command handler set")
    }

    // MARK: - Private Methods

    private func startListener(port: UInt16) async throws {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true

      listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

      guard let listener = listener else {
        throw HostConnectionError.listenerCreationFailed
      }

      // Set up connection handler
      listener.newConnectionHandler = { [weak self] connection in
        Task {
          await self?.handleNewConnection(connection)
        }
      }

      // Start the listener
      return try await withCheckedThrowingContinuation { continuation in
        final class ResumeState: @unchecked Sendable {
          var hasResumed = false
          let lock = NSLock()

          func checkAndResume(_ action: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            if !hasResumed {
              hasResumed = true
              action()
            }
          }
        }

        let resumeState = ResumeState()

        listener.stateUpdateHandler = { state in
          switch state {
          case .ready:
            resumeState.checkAndResume {
              continuation.resume()
            }
          case .failed(let error):
            resumeState.checkAndResume {
              continuation.resume(throwing: HostConnectionError.listenerFailed(error))
            }
          case .cancelled:
            resumeState.checkAndResume {
              continuation.resume(throwing: HostConnectionError.listenerCancelled)
            }
          default:
            break
          }
        }

        listener.start(queue: .main)
      }
    }

    private func handleNewConnection(_ nwConnection: NWConnection) async {
      logger.info("New connection from: \(nwConnection.endpoint)")

      let connection = HostConnection(
        nwConnection: nwConnection,
        commandHandler: commandHandler,
        logger: logger
      )

      // Add to active connections
      activeConnections.insert(connection)

      // Handle connection lifecycle
      Task { [weak self] in
        await connection.start()

        // Remove from active connections when done
        await self?.removeConnection(connection)
        self?.logger.info("Connection closed: \(nwConnection.endpoint)")
      }
    }

    private func removeConnection(_ connection: HostConnection) {
      activeConnections.remove(connection)
    }
  }

  /// Individual host connection handler
  private final class HostConnection: Hashable, Sendable {
    private let nwConnection: NWConnection
    private let commandHandler: (@Sendable (HarvestCommand) async throws -> HarvestResponse)?
    private let logger: Logger
    private let id: UUID = UUID()

    init(
      nwConnection: NWConnection,
      commandHandler: (@Sendable (HarvestCommand) async throws -> HarvestResponse)?,
      logger: Logger
    ) {
      self.nwConnection = nwConnection
      self.commandHandler = commandHandler
      self.logger = logger
    }

    func start() async {
      nwConnection.stateUpdateHandler = { [weak self] state in
        self?.logger.debug("Connection state: \(state)")
      }

      nwConnection.start(queue: .main)

      // Handle incoming data
      await receiveLoop()
    }

    func close() async {
      nwConnection.cancel()
    }

    private func receiveLoop() async {
      while nwConnection.state == .ready {
        do {
          let data = try await receiveData()
          guard !data.isEmpty else { break }

          await processReceivedData(data)
        } catch {
          logger.error("Error receiving data: \(error)")
          break
        }
      }
    }

    private func receiveData() async throws -> Data {
      return try await withCheckedThrowingContinuation { continuation in
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
          data, _, _, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let data = data {
            continuation.resume(returning: data)
          } else {
            continuation.resume(returning: Data())
          }
        }
      }
    }

    private func processReceivedData(_ data: Data) async {
      do {
        // Deserialize command
        let decoder = JSONDecoder()
        let command = try decoder.decode(HarvestCommand.self, from: data)

        logger.info("Received command: \(command.name)")

        // Process command
        let response: HarvestResponse
        if let handler = commandHandler {
          response = try await handler(command)
        } else {
          response = HarvestResponse(
            requestId: command.id,
            timestamp: Date(),
            success: false,
            payload: .error("No command handler available")
          )
        }

        // Send response
        try await sendResponse(response)

      } catch {
        logger.error("Failed to process command: \(error)")

        // Send error response
        let errorResponse = HarvestResponse(
          requestId: UUID(),  // Unknown command ID
          timestamp: Date(),
          success: false,
          payload: .error("Processing error: \(error.localizedDescription)")
        )

        do {
          try await sendResponse(errorResponse)
        } catch {
          logger.error("Failed to send error response: \(error)")
        }
      }
    }

    private func sendResponse(_ response: HarvestResponse) async throws {
      let encoder = JSONEncoder()
      let data = try encoder.encode(response)

      return try await withCheckedThrowingContinuation { continuation in
        nwConnection.send(
          content: data,
          completion: .contentProcessed { error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume()
            }
          })
      }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    static func == (lhs: HostConnection, rhs: HostConnection) -> Bool {
      lhs.id == rhs.id
    }
  }

#else

  /// Stub implementation for non-Network platforms
  public final class DefaultHostConnectionService: HostConnectionService {
    private let logger: Logger

    public init(
      discoveryService: DiscoveryService = NetworkDiscoveryService(),
      logger: Logger = ConsoleLogger()
    ) {
      self.logger = logger
    }

    public func start(configuration: ConnectionConfiguration) async throws {
      logger.error("Network framework not available on this platform")
      throw HostConnectionError.listenerCreationFailed
    }

    public func stop() async {}

    public var status: ConnectionServiceStatus {
      get async {
        ConnectionServiceStatus(isRunning: false, connectionCount: 0, isAdvertising: false)
      }
    }

    public func setCommandHandler(
      _ handler: @escaping @Sendable (HarvestCommand) async throws -> HarvestResponse
    ) async {}
  }

#endif
