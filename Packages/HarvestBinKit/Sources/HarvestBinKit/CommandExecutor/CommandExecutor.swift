//
// CommandExecutor.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import BushelFoundation
import BushelHarvestCore
import Foundation

/// Main command execution interface for guest-side command processing
///
/// Validates commands, performs security checks, and routes to appropriate executors.
public protocol CommandExecutor: Sendable {
  /// Executes a harvest command and returns the response
  /// - Parameter command: The harvest command to execute
  /// - Returns: The command response
  /// - Throws: CommandExecutorError on execution failure
  func execute(_ command: HarvestCommand) async throws -> HarvestResponse

  /// Validates if a command can be executed
  /// - Parameter command: The command to validate
  /// - Returns: True if the command can be executed
  func canExecute(_ command: HarvestCommand) -> Bool
}

/// Default implementation of CommandExecutor
public final class DefaultCommandExecutor: CommandExecutor {
  private let systemSetupExecutor: SystemSetupExecutor
  private let securityValidator: SecurityValidator
  private let logger: Logger

  /// Initializes the command executor
  /// - Parameters:
  ///   - systemSetupExecutor: Executor for systemsetup commands
  ///   - securityValidator: Security validation service
  ///   - logger: Logging service
  public init(
    systemSetupExecutor: SystemSetupExecutor = DefaultSystemSetupExecutor(),
    securityValidator: SecurityValidator = DefaultSecurityValidator(),
    logger: Logger = ConsoleLogger()
  ) {
    self.systemSetupExecutor = systemSetupExecutor
    self.securityValidator = securityValidator
    self.logger = logger
  }

  public func execute(_ command: HarvestCommand) async throws -> HarvestResponse {
    logger.info("Executing command: \(command.name)")

    // Security validation
    guard securityValidator.validate(command) else {
      logger.error("Security validation failed for command: \(command.name)")
      throw CommandExecutorError.securityValidationFailed(command.name)
    }

    // Check if we can execute the command
    guard canExecute(command) else {
      logger.error("Cannot execute command: \(command.name)")
      throw CommandExecutorError.unsupportedCommand(command.name)
    }

    // Route command to appropriate executor
    do {
      let response = try await executeCommand(command)
      logger.info("Command completed successfully: \(command.name)")
      return response
    } catch {
      logger.error("Command execution failed: \(command.name) - \(error)")
      throw CommandExecutorError.executionFailed(command.name, underlying: error)
    }
  }

  public func canExecute(_ command: HarvestCommand) -> Bool {
    switch command.payload {
    case .system(let systemCommand):
      return canExecuteSystemCommand(systemCommand)
    case .remote(let remoteCommand):
      return canExecuteRemoteCommand(remoteCommand)
    case .security:
      // Security commands are handled by security validator
      return true
    @unknown default:
      return false
    }
  }

  // MARK: - Private Methods

  private func executeCommand(_ command: HarvestCommand) async throws -> HarvestResponse {
    switch command.payload {
    case .system(let systemCommand):
      return try await executeSystemCommand(systemCommand, from: command)
    case .remote(let remoteCommand):
      return try await executeRemoteCommand(remoteCommand, from: command)
    case .security(let securityCommand):
      return try await executeSecurityCommand(securityCommand, from: command)
    @unknown default:
      throw CommandExecutorError.unsupportedCommand("Unknown command type")
    }
  }

  private func executeSystemCommand(
    _ systemCommand: SystemCommand, from originalCommand: HarvestCommand
  ) async throws -> HarvestResponse {
    switch systemCommand {
    case .ping:
      // Simple ping response
      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: true,
        payload: .systemStatus("pong")
      )
    case .status:
      // Return system status information
      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: true,
        payload: .systemStatus("HarvestBin v1.0.0 - running")
      )
    @unknown default:
      // Handle unknown system commands
      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: false,
        payload: .error("Unknown system command")
      )
    }
  }

  private func executeRemoteCommand(
    _ remoteCommand: RemoteAccessCommand, from originalCommand: HarvestCommand
  ) async throws -> HarvestResponse {
    switch remoteCommand {
    case .ssh(let sshCommand):
      return try await executeSSHCommand(sshCommand, from: originalCommand)
    case .status:
      return try await getRemoteStatus(from: originalCommand)
    }
  }

  private func executeSSHCommand(_ sshCommand: SSHCommand, from originalCommand: HarvestCommand)
    async throws -> HarvestResponse {
    switch sshCommand {
    case .enable:
      try await systemSetupExecutor.enableSSH()

      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: true,
        payload: .remoteStatus(
          RemoteStatusData(
            access: RemoteAccess(
              ssh: SSHStatus(isEnabled: true, port: 22)
            )
          )
        )
      )

    case .disable:
      try await systemSetupExecutor.disableSSH()

      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: true,
        payload: .remoteStatus(
          RemoteStatusData(
            access: RemoteAccess(
              ssh: SSHStatus(isEnabled: false, port: nil)
            )
          )
        )
      )

    case .status:
      return try await getRemoteStatus(from: originalCommand)

    @unknown default:
      return HarvestResponse(
        requestId: originalCommand.id,
        timestamp: Date(),
        success: false,
        payload: .error("Unknown SSH command")
      )
    }
  }

  private func getRemoteStatus(from originalCommand: HarvestCommand) async throws -> HarvestResponse {
    let isSSHEnabled = try await systemSetupExecutor.getSSHStatus()

    return HarvestResponse(
      requestId: originalCommand.id,
      timestamp: Date(),
      success: true,
      payload: .remoteStatus(
        RemoteStatusData(
          access: RemoteAccess(
            ssh: SSHStatus(
              isEnabled: isSSHEnabled,
              port: isSSHEnabled ? 22 : nil
            )
          )
        )
      )
    )
  }

  private func executeSecurityCommand(
    _ securityCommand: SecurityCommand, from originalCommand: HarvestCommand
  ) async throws -> HarvestResponse {
    // Security commands implementation
    // For Phase 1, return a basic response
    return HarvestResponse(
      requestId: originalCommand.id,
      timestamp: Date(),
      success: true,
      payload: .securityStatus("authorized")
    )
  }

  private func canExecuteSystemCommand(_ command: SystemCommand) -> Bool {
    // All system commands are currently supported
    return true
  }

  private func canExecuteRemoteCommand(_ command: RemoteAccessCommand) -> Bool {
    // All remote commands are currently supported
    return true
  }
}

/// Security validation service
public protocol SecurityValidator: Sendable {
  func validate(_ command: HarvestCommand) -> Bool
}

/// Default security validator
public struct DefaultSecurityValidator: SecurityValidator {
  public init() {}

  public func validate(_ command: HarvestCommand) -> Bool {
    // Basic security validation
    // Check if command requires elevation
    let requiresElevation = command.metadata?["requiresElevation"] == "true"

    if requiresElevation {
      // For Phase 1, assume we have necessary privileges
      // In production, this would check actual privileges
      return true
    }

    return true
  }
}

/// Simple logging protocol
public protocol Logger: Sendable {
  func info(_ message: String)
  func error(_ message: String)
  func debug(_ message: String)
}

/// Console logger implementation
public struct ConsoleLogger: Logger {
  public init() {}

  public func info(_ message: String) {
    print("[INFO] \(Date()): \(message)")
  }

  public func error(_ message: String) {
    print("[ERROR] \(Date()): \(message)")
  }

  public func debug(_ message: String) {
    print("[DEBUG] \(Date()): \(message)")
  }
}

/// Errors that can occur during command execution
public enum CommandExecutorError: Error, Sendable {
  case unsupportedCommand(String)
  case securityValidationFailed(String)
  case executionFailed(String, underlying: Error)
  case missingDependency(String)

  public var localizedDescription: String {
    switch self {
    case .unsupportedCommand(let command):
      return "Unsupported command: \(command)"
    case .securityValidationFailed(let command):
      return "Security validation failed for command: \(command)"
    case .executionFailed(let command, let error):
      return "Execution failed for command '\(command)': \(error.localizedDescription)"
    case .missingDependency(let dependency):
      return "Missing dependency: \(dependency)"
    }
  }
}
