//
// SystemSetupExecutor.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import Foundation

/// Executor for systemsetup command operations
///
/// Provides a wrapper around macOS systemsetup command for SSH management.
public protocol SystemSetupExecutor: Sendable {
  /// Enables SSH remote login
  /// - Throws: SystemSetupError on failure
  func enableSSH() async throws

  /// Disables SSH remote login
  /// - Throws: SystemSetupError on failure
  func disableSSH() async throws

  /// Gets the current SSH status
  /// - Returns: True if SSH is enabled
  /// - Throws: SystemSetupError on failure
  func getSSHStatus() async throws -> Bool
}

/// Default implementation of SystemSetupExecutor
public final class DefaultSystemSetupExecutor: SystemSetupExecutor {
  private let processRunner: ProcessRunner
  private let logger: Logger

  /// Initializes the system setup executor
  /// - Parameters:
  ///   - processRunner: Process execution service
  ///   - logger: Logging service
  public init(
    processRunner: ProcessRunner = DefaultProcessRunner(),
    logger: Logger = ConsoleLogger()
  ) {
    self.processRunner = processRunner
    self.logger = logger
  }

  public func enableSSH() async throws {
    logger.info("Enabling SSH remote login")

    let result = try await processRunner.run(
      executable: "/usr/sbin/systemsetup",
      arguments: ["-setremotelogin", "on"],
      requiresElevation: true
    )

    guard result.exitCode == 0 else {
      logger.error("Failed to enable SSH: \(result.stderr)")
      throw SystemSetupError.commandFailed(
        "enable SSH", exitCode: result.exitCode, output: result.stderr)
    }

    logger.info("SSH remote login enabled successfully")
  }

  public func disableSSH() async throws {
    logger.info("Disabling SSH remote login")

    let result = try await processRunner.run(
      executable: "/usr/sbin/systemsetup",
      arguments: ["-setremotelogin", "off"],
      requiresElevation: true
    )

    guard result.exitCode == 0 else {
      logger.error("Failed to disable SSH: \(result.stderr)")
      throw SystemSetupError.commandFailed(
        "disable SSH", exitCode: result.exitCode, output: result.stderr)
    }

    logger.info("SSH remote login disabled successfully")
  }

  public func getSSHStatus() async throws -> Bool {
    logger.info("Getting SSH remote login status")

    let result = try await processRunner.run(
      executable: "/usr/sbin/systemsetup",
      arguments: ["-getremotelogin"],
      requiresElevation: false
    )

    guard result.exitCode == 0 else {
      logger.error("Failed to get SSH status: \(result.stderr)")
      throw SystemSetupError.commandFailed(
        "get SSH status", exitCode: result.exitCode, output: result.stderr)
    }

    // Parse the output to determine SSH status
    // Expected output: "Remote Login: On" or "Remote Login: Off"
    let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let isEnabled = output.contains("Remote Login: On")

    logger.info("SSH remote login status: \(isEnabled ? "enabled" : "disabled")")
    return isEnabled
  }
}

/// Process execution service
public protocol ProcessRunner: Sendable {
  func run(
    executable: String,
    arguments: [String],
    requiresElevation: Bool
  ) async throws -> ProcessResult
}

/// Default process runner implementation
public final class DefaultProcessRunner: ProcessRunner {
  public init() {}

  public func run(
    executable: String,
    arguments: [String],
    requiresElevation: Bool
  ) async throws -> ProcessResult {

    return try await withCheckedThrowingContinuation { continuation in
      let process = Process()

      // Set up process
      if requiresElevation {
        // Use sudo for elevated commands
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [executable] + arguments
      } else {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
      }

      // Set up pipes for output capture
      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()

      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      // Handle process completion
      process.terminationHandler = { proc in
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let result = ProcessResult(
          exitCode: Int(proc.terminationStatus),
          stdout: stdout,
          stderr: stderr
        )

        continuation.resume(returning: result)
      }

      // Start the process
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: SystemSetupError.processStartFailed(error))
      }
    }
  }
}

/// Result of process execution
public struct ProcessResult: Sendable {
  public let exitCode: Int
  public let stdout: String
  public let stderr: String

  public init(exitCode: Int, stdout: String, stderr: String) {
    self.exitCode = exitCode
    self.stdout = stdout
    self.stderr = stderr
  }
}

/// Errors that can occur during system setup operations
public enum SystemSetupError: Error, Sendable {
  case commandFailed(String, exitCode: Int, output: String)
  case processStartFailed(Error)
  case permissionDenied(String)
  case invalidOutput(String)

  public var localizedDescription: String {
    switch self {
    case .commandFailed(let command, let exitCode, let output):
      return "Command '\(command)' failed with exit code \(exitCode): \(output)"
    case .processStartFailed(let error):
      return "Failed to start process: \(error.localizedDescription)"
    case .permissionDenied(let command):
      return "Permission denied for command: \(command)"
    case .invalidOutput(let output):
      return "Invalid command output: \(output)"
    }
  }
}
