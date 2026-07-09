//
// VirtioSocketHostConnectionService.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import BushelHarvestCore
import Foundation

#if os(macOS)
  /// VirtioSocket-based implementation of HostConnectionService
  ///
  /// Uses VirtioSocket for direct host-guest communication without requiring
  /// VM networking configuration. The guest initiates the connection to the host.
  public actor VirtioSocketHostConnectionService: HostConnectionService {
    private let virtioClient: VirtioSocketClient
    private let logger: Logger
    private var commandHandler: (@Sendable (HarvestCommand) async throws -> HarvestResponse)?
    private var isRunning: Bool = false
    private var receiveTask: Task<Void, Never>?

    public init(
      virtioClient: VirtioSocketClient,
      logger: Logger = ConsoleLogger()
    ) {
      self.virtioClient = virtioClient
      self.logger = logger
    }

    public func start(configuration: ConnectionConfiguration) async throws {
      logger.info("Starting VirtioSocket connection service")

      // Connect to host via VirtioSocket
      do {
        try await virtioClient.connect()
      } catch {
        logger.error("Failed to connect to host: \(error)")
        throw error
      }

      isRunning = true

      // Start receiving messages in background
      receiveTask = Task {
        await receiveLoop()
      }

      logger.info("VirtioSocket connection established")
    }

    public func stop() async {
      logger.info("Stopping VirtioSocket connection service")

      isRunning = false

      // Cancel receive task
      receiveTask?.cancel()
      receiveTask = nil

      // Disconnect from host
      await virtioClient.disconnect()

      logger.info("VirtioSocket connection service stopped")
    }

    public var status: ConnectionServiceStatus {
      get async {
        ConnectionServiceStatus(
          isRunning: isRunning,
          connectionCount: isRunning ? 1 : 0,
          isAdvertising: false  // VirtioSocket doesn't use Bonjour
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

    /// Continuously receives and processes commands from the host
    private func receiveLoop() async {
      while isRunning {
        do {
          let data = try await virtioClient.receive()
          await processReceivedData(data)
        } catch {
          if isRunning {
            logger.error("Error receiving data: \(error)")
          }
          break
        }
      }
      logger.debug("Receive loop ended")
    }

    /// Processes received command data from the host
    /// - Parameter data: The received command data
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

    /// Sends a response back to the host
    /// - Parameter response: The response to send
    /// - Throws: HostConnectionError if send fails
    private func sendResponse(_ response: HarvestResponse) async throws {
      let encoder = JSONEncoder()
      let data = try encoder.encode(response)
      try await virtioClient.send(data)
      logger.debug("Sent response for request \(response.requestId)")
    }
  }
#endif
