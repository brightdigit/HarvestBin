//
// DiscoveryService.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import Foundation

/// Service advertising for VM discovery using Network framework
///
/// Advertises the HarvestBin service to allow host machines to discover this guest VM.
public protocol DiscoveryService: Sendable {
  /// Starts advertising the HarvestBin service
  /// - Parameters:
  ///   - vmIdentifier: Unique identifier for this VM
  ///   - capabilities: List of capabilities this VM supports
  /// - Throws: DiscoveryError on failure
  func startAdvertising(vmIdentifier: String, capabilities: [String]) async throws

  /// Stops advertising the service
  func stopAdvertising() async

  /// Updates the advertised capabilities
  /// - Parameter capabilities: New list of capabilities
  /// - Throws: DiscoveryError on failure
  func updateCapabilities(_ capabilities: [String]) async throws

  /// Gets the current advertising status
  /// - Returns: True if currently advertising
  var isAdvertising: Bool { get async }
}

/// Service discovery utilities
public final class DiscoveryUtils {
  /// Gets a unique VM identifier for this machine
  /// - Returns: A unique string identifier
  public static func generateVMIdentifier() -> String {
    // Use a combination of hostname and UUID for uniqueness
    let hostname = ProcessInfo.processInfo.hostName
    let uuid = UUID().uuidString.prefix(8)
    return "\(hostname)-\(uuid)"
  }

  /// Gets the current system's capabilities
  /// - Returns: Array of capability strings
  public static func getSystemCapabilities() async -> [String] {
    var capabilities: [String] = ["ssh", "systeminfo"]

    // Add SSH capability if available
    do {
      let executor = DefaultSystemSetupExecutor()
      _ = try await executor.getSSHStatus()
      if !capabilities.contains("ssh") {
        capabilities.append("ssh")
      }
    } catch {
      // SSH not available
      capabilities.removeAll { $0 == "ssh" }
    }

    return capabilities
  }
}

/// Service discovery configuration
public struct DiscoveryConfiguration: Sendable {
  public let serviceName: String
  public let port: UInt16
  public let vmIdentifier: String
  public let capabilities: [String]

  public init(
    serviceName: String = "_bushel-guest._tcp",
    port: UInt16 = 8080,
    vmIdentifier: String = DiscoveryUtils.generateVMIdentifier(),
    capabilities: [String] = ["ssh", "systeminfo"]
  ) {
    self.serviceName = serviceName
    self.port = port
    self.vmIdentifier = vmIdentifier
    self.capabilities = capabilities
  }
}

/// Discovery service errors
public enum DiscoveryError: Error, Sendable {
  case advertisingFailed(underlying: Error)
  case notAdvertising
  case listenerCreationFailed
  case listenerFailed(Error)
  case listenerCancelled
  case missingVMIdentifier
  case invalidConfiguration(String)
  case networkUnavailable

  public var localizedDescription: String {
    switch self {
    case .advertisingFailed(let error):
      return "Service advertising failed: \(error.localizedDescription)"
    case .notAdvertising:
      return "Service is not currently advertising"
    case .listenerCreationFailed:
      return "Failed to create network listener"
    case .listenerFailed(let error):
      return "Network listener failed: \(error.localizedDescription)"
    case .listenerCancelled:
      return "Network listener was cancelled"
    case .missingVMIdentifier:
      return "VM identifier is required for service advertising"
    case .invalidConfiguration(let reason):
      return "Invalid discovery configuration: \(reason)"
    case .networkUnavailable:
      return "Network is not available for service advertising"
    }
  }
}

#if canImport(Network)
  import Network

  /// Network framework-based service advertising
  public actor NetworkDiscoveryService: DiscoveryService {
    private let serviceName: String = "_bushel-guest._tcp"
    private let servicePort: UInt16 = 8080

    private var listener: NWListener?
    private var vmIdentifier: String?
    private var currentCapabilities: [String] = []
    private let logger: Logger

    /// Initializes the discovery service
    /// - Parameter logger: Logging service
    public init(logger: Logger = ConsoleLogger()) {
      self.logger = logger
    }

    public func startAdvertising(vmIdentifier: String, capabilities: [String]) async throws {
      logger.info("Starting service advertising for VM: \(vmIdentifier)")

      // Stop any existing advertising
      await stopAdvertising()

      self.vmIdentifier = vmIdentifier
      self.currentCapabilities = capabilities

      do {
        try await startListener()
        logger.info("Successfully started advertising service \(serviceName)")
      } catch {
        logger.error("Failed to start advertising: \(error)")
        throw DiscoveryError.advertisingFailed(underlying: error)
      }
    }

    public func stopAdvertising() async {
      guard let listener = listener else { return }

      logger.info("Stopping service advertising")

      listener.cancel()
      self.listener = nil

      logger.info("Service advertising stopped")
    }

    public func updateCapabilities(_ capabilities: [String]) async throws {
      guard await isAdvertising else {
        throw DiscoveryError.notAdvertising
      }

      logger.info("Updating advertised capabilities: \(capabilities)")

      self.currentCapabilities = capabilities

      // Restart advertising with new capabilities
      if let vmIdentifier = vmIdentifier {
        try await startAdvertising(vmIdentifier: vmIdentifier, capabilities: capabilities)
      }
    }

    public var isAdvertising: Bool {
      get async {
        return listener?.state == .ready
      }
    }

    // MARK: - Private Methods

    private func startListener() async throws {
      let parameters = NWParameters.tcp

      // Enable peer-to-peer for local network discovery
      parameters.includePeerToPeer = true

      // Create the listener
      listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: servicePort)!)

      guard let listener = listener else {
        throw DiscoveryError.listenerCreationFailed
      }

      // Configure service advertising
      listener.service = try createServiceConfiguration()

      // Set up state update handler
      listener.stateUpdateHandler = { [weak self] state in
        Task { await self?.handleStateUpdate(state) }
      }

      // Set up new connection handler
      listener.newConnectionHandler = { [weak self] connection in
        Task { await self?.handleNewConnection(connection) }
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
              continuation.resume(throwing: DiscoveryError.listenerFailed(error))
            }
          case .cancelled:
            resumeState.checkAndResume {
              continuation.resume(throwing: DiscoveryError.listenerCancelled)
            }
          default:
            break
          }
        }

        listener.start(queue: .main)
      }
    }

    private func createServiceConfiguration() throws -> NWListener.Service {
      guard let vmIdentifier = vmIdentifier else {
        throw DiscoveryError.missingVMIdentifier
      }

      // Create TXT record with VM metadata
      let txtRecord = createTXTRecord()

      return NWListener.Service(
        name: vmIdentifier,
        type: serviceName,
        txtRecord: txtRecord
      )
    }

    private func createTXTRecord() -> NWTXTRecord {
      var txtData: [String: String] = [:]

      // Add VM identifier
      if let vmIdentifier = vmIdentifier {
        txtData["vmid"] = vmIdentifier
      }

      // Add HarvestBin version
      txtData["version"] = "1.0.0"

      // Add capabilities
      txtData["capabilities"] = currentCapabilities.joined(separator: ",")

      // Add SSH status if SSH is a capability
      if currentCapabilities.contains("ssh") {
        txtData["ssh"] = "enabled"
      }

      // Add timestamp
      txtData["timestamp"] = ISO8601DateFormatter().string(from: Date())

      return NWTXTRecord(txtData)
    }

    private func handleStateUpdate(_ state: NWListener.State) {
      switch state {
      case .ready:
        logger.info("Network listener is ready")
      case .failed(let error):
        logger.error("Network listener failed: \(error)")
      case .cancelled:
        logger.info("Network listener cancelled")
      default:
        logger.debug("Network listener state: \(state)")
      }
    }

    private func handleNewConnection(_ connection: NWConnection) {
      logger.info("New connection received from: \(connection.endpoint)")

      // Set up connection handlers
      connection.stateUpdateHandler = { [weak self] state in
        self?.logger.debug("Connection state: \(state)")
      }

      // Start the connection
      connection.start(queue: .main)

      // For Phase 1, we'll just accept connections but not handle data yet
      // Full command processing will be implemented in HostConnectionService
    }
  }

#else

  /// Stub implementation for non-Network platforms
  public final class NetworkDiscoveryService: DiscoveryService {
    private let logger: Logger

    public init(logger: Logger = ConsoleLogger()) {
      self.logger = logger
    }

    public func startAdvertising(vmIdentifier: String, capabilities: [String]) async throws {
      logger.error("Network framework not available on this platform")
      throw DiscoveryError.networkUnavailable
    }

    public func stopAdvertising() async {}

    public func updateCapabilities(_ capabilities: [String]) async throws {
      throw DiscoveryError.networkUnavailable
    }

    public var isAdvertising: Bool {
      get async { false }
    }
  }

#endif
