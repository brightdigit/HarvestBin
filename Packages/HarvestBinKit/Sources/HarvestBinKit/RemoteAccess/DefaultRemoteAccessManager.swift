//
// DefaultRemoteAccessManager.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import Foundation

#if os(macOS)

  /// Default implementation of RemoteAccessManager
  public actor DefaultRemoteAccessManager: RemoteAccessManager {
    private let sshManager: SSHManager
    private let logger: Logger
    private var monitors: [UUID: RemoteAccessMonitor] = [:]

    /// Initializes the remote access manager
    /// - Parameters:
    ///   - sshManager: SSH service management
    ///   - logger: Logging service
    public init(
      sshManager: SSHManager = DefaultSSHManager(),
      logger: Logger = ConsoleLogger()
    ) {
      self.sshManager = sshManager
      self.logger = logger
    }

    public func enable(_ type: RemoteAccessType) async throws {
      logger.info("Enabling remote access: \(type)")

      switch type {
      case .ssh:
        try await sshManager.enable()
      }

      logger.info("Remote access enabled: \(type)")
    }

    public func disable(_ type: RemoteAccessType) async throws {
      logger.info("Disabling remote access: \(type)")

      switch type {
      case .ssh:
        try await sshManager.disable()
      }

      logger.info("Remote access disabled: \(type)")
    }

    public func status(for type: RemoteAccessType) async throws -> RemoteAccessStatus {
      switch type {
      case .ssh:
        let sshStatus = try await sshManager.status()
        return .ssh(sshStatus)
      }
    }

    public func validateConfiguration() async -> Bool {
      // Validate SSH configuration
      return await sshManager.validateConfiguration()
    }

    public func monitorServices(
      _ callback: @escaping @Sendable (RemoteAccessType, RemoteAccessStatus) -> Void
    ) async -> UUID {
      let monitorID = UUID()
      let monitor = RemoteAccessMonitor(
        id: monitorID,
        callback: callback,
        sshManager: sshManager,
        logger: logger
      )

      monitors[monitorID] = monitor

      await monitor.start()

      logger.info("Started monitoring remote access services: \(monitorID)")
      return monitorID
    }

    public func stopMonitoring(_ monitorID: UUID) async {
      let monitor = monitors.removeValue(forKey: monitorID)

      await monitor?.stop()
      logger.info("Stopped monitoring remote access services: \(monitorID)")
    }
  }

  /// Default SSH manager implementation
  public final class DefaultSSHManager: SSHManager {
    private let systemSetupExecutor: SystemSetupExecutor
    private let sshDaemonManager: SSHDaemonManager
    private let logger: Logger

    public init(
      systemSetupExecutor: SystemSetupExecutor = DefaultSystemSetupExecutor(),
      sshDaemonManager: SSHDaemonManager = DefaultSSHDaemonManager(),
      logger: Logger = ConsoleLogger()
    ) {
      self.systemSetupExecutor = systemSetupExecutor
      self.sshDaemonManager = sshDaemonManager
      self.logger = logger
    }

    public func enable() async throws {
      logger.info("Enabling SSH service")

      // Enable SSH via systemsetup
      try await systemSetupExecutor.enableSSH()

      // Verify SSH daemon is running
      let isRunning = await sshDaemonManager.isRunning()
      if !isRunning {
        logger.info("SSH daemon not running, attempting to start")
        try await sshDaemonManager.start()
      }

      logger.info("SSH service enabled successfully")
    }

    public func disable() async throws {
      logger.info("Disabling SSH service")

      // Stop SSH daemon first
      if await sshDaemonManager.isRunning() {
        try await sshDaemonManager.stop()
      }

      // Disable SSH via systemsetup
      try await systemSetupExecutor.disableSSH()

      logger.info("SSH service disabled successfully")
    }

    public func status() async throws -> SSHServiceStatus {
      let isEnabled = try await systemSetupExecutor.getSSHStatus()
      let isRunning = await sshDaemonManager.isRunning()
      let connectionDetails = await sshDaemonManager.connectionDetails()

      return SSHServiceStatus(
        isEnabled: isEnabled,
        isRunning: isRunning,
        port: isEnabled ? 22 : nil,
        connectionCount: connectionDetails.connectionCount,
        lastStartTime: connectionDetails.startTime
      )
    }

    public func validateConfiguration() async -> Bool {
      // Basic SSH configuration validation
      do {
        _ = try await systemSetupExecutor.getSSHStatus()
        return true
      } catch {
        logger.error("SSH configuration validation failed: \(error)")
        return false
      }
    }
  }

  /// Default SSH daemon manager
  public final class DefaultSSHDaemonManager: SSHDaemonManager {
    private let processRunner: ProcessRunner
    private let logger: Logger

    public init(
      processRunner: ProcessRunner = DefaultProcessRunner(),
      logger: Logger = ConsoleLogger()
    ) {
      self.processRunner = processRunner
      self.logger = logger
    }

    public func isRunning() async -> Bool {
      do {
        let result = try await processRunner.run(
          executable: "/bin/launchctl",
          arguments: ["print", "system/com.openssh.sshd"],
          requiresElevation: false
        )

        // If the service is loaded and running, launchctl print will succeed
        return result.exitCode == 0 && result.stdout.contains("state = running")
      } catch {
        logger.debug("Failed to check SSH daemon status: \(error)")
        return false
      }
    }

    public func start() async throws {
      logger.info("Starting SSH daemon")

      let result = try await processRunner.run(
        executable: "/bin/launchctl",
        arguments: ["load", "/System/Library/LaunchDaemons/com.openssh.sshd.plist"],
        requiresElevation: true
      )

      guard result.exitCode == 0 else {
        throw RemoteAccessError.serviceStartFailed("sshd", output: result.stderr)
      }

      logger.info("SSH daemon started successfully")
    }

    public func stop() async throws {
      logger.info("Stopping SSH daemon")

      let result = try await processRunner.run(
        executable: "/bin/launchctl",
        arguments: ["unload", "/System/Library/LaunchDaemons/com.openssh.sshd.plist"],
        requiresElevation: true
      )

      guard result.exitCode == 0 else {
        throw RemoteAccessError.serviceStopFailed("sshd", output: result.stderr)
      }

      logger.info("SSH daemon stopped successfully")
    }

    public func connectionDetails() async -> SSHConnectionDetails {
      // For Phase 1, return basic details
      // In a full implementation, this would parse actual SSH connection info
      return SSHConnectionDetails()
    }
  }

  /// Remote access monitoring
  private actor RemoteAccessMonitor {
    let id: UUID
    private let callback: @Sendable (RemoteAccessType, RemoteAccessStatus) -> Void
    private let sshManager: SSHManager
    private let logger: Logger
    private var isRunning: Bool = false
    private var monitorTask: Task<Void, Never>?

    init(
      id: UUID,
      callback: @escaping @Sendable (RemoteAccessType, RemoteAccessStatus) -> Void,
      sshManager: SSHManager,
      logger: Logger
    ) {
      self.id = id
      self.callback = callback
      self.sshManager = sshManager
      self.logger = logger
    }

    func start() {
      isRunning = true
      monitorTask = Task { [weak self] in
        while await self?.isRunning == true {
          do {
            guard let self = self else { break }
            let sshStatus = try await self.sshManager.status()
            self.callback(.ssh, .ssh(sshStatus))
          } catch {
            await self?.logger.error("Failed to get SSH status during monitoring: \(error)")
          }

          // Check every 30 seconds
          try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
      }
    }

    func stop() {
      isRunning = false
      monitorTask?.cancel()
    }
  }

#else

  /// Stub implementation for non-macOS platforms
  public final class DefaultRemoteAccessManager: RemoteAccessManager {
    public init(
      sshManager: SSHManager = DefaultSSHManager(),
      logger: Logger = ConsoleLogger()
    ) {}

    public func enable(_ type: RemoteAccessType) async throws {
      throw RemoteAccessError.unsupportedType(type)
    }

    public func disable(_ type: RemoteAccessType) async throws {
      throw RemoteAccessError.unsupportedType(type)
    }

    public func status(for type: RemoteAccessType) async throws -> RemoteAccessStatus {
      throw RemoteAccessError.unsupportedType(type)
    }

    public func validateConfiguration() async -> Bool { false }

    public func monitorServices(
      _ callback: @escaping @Sendable (RemoteAccessType, RemoteAccessStatus) -> Void
    ) async -> UUID {
      UUID()
    }

    public func stopMonitoring(_ monitorID: UUID) async {}
  }

  /// Stub SSH manager for non-macOS platforms
  public final class DefaultSSHManager: SSHManager {
    public init(
      systemSetupExecutor: SystemSetupExecutor = DefaultSystemSetupExecutor(),
      sshDaemonManager: SSHDaemonManager = DefaultSSHDaemonManager(),
      logger: Logger = ConsoleLogger()
    ) {}

    public func enable() async throws {
      throw RemoteAccessError.serviceStartFailed("ssh", output: "Platform not supported")
    }

    public func disable() async throws {
      throw RemoteAccessError.serviceStopFailed("ssh", output: "Platform not supported")
    }

    public func status() async throws -> SSHServiceStatus {
      throw RemoteAccessError.statusCheckFailed(
        "ssh",
        underlying: NSError(domain: "UnsupportedPlatform", code: -1))
    }

    public func validateConfiguration() async -> Bool { false }
  }

  /// Stub SSH daemon manager for non-macOS platforms
  public final class DefaultSSHDaemonManager: SSHDaemonManager {
    public init(
      processRunner: ProcessRunner = DefaultProcessRunner(),
      logger: Logger = ConsoleLogger()
    ) {}

    public func isRunning() async -> Bool { false }

    public func start() async throws {
      throw RemoteAccessError.serviceStartFailed("sshd", output: "Platform not supported")
    }

    public func stop() async throws {
      throw RemoteAccessError.serviceStopFailed("sshd", output: "Platform not supported")
    }

    public func connectionDetails() async -> SSHConnectionDetails {
      SSHConnectionDetails()
    }
  }

#endif
