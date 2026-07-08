//
// VirtioSocketClient.swift
// HarvestBinKit
//
// Copyright (c) 2025 BrightDigit.
//

import BushelHarvestCore
import Foundation

#if os(macOS)
  /// Client for VirtioSocket communication with the host (guest-side)
  ///
  /// Connects to the host machine using AF_VSOCK sockets and handles
  /// message framing for command/response communication using file descriptors.
  ///
  /// Note: This is for use inside macOS VMs. The guest connects to the host
  /// using the AF_VSOCK socket family with VMADDR_CID_HOST (2).
  public actor VirtioSocketClient {
    private var socketFD: Int32 = -1
    private let port: UInt32 = UInt32(HarvestConfiguration.defaultPort)
    private let hostCID: UInt32 = 2  // VMADDR_CID_HOST
    private let ioQueue = DispatchQueue(
      label: "com.brightdigit.harvestbin.virtio-io",
      qos: .userInitiated
    )

    public init() {}

    /// Connects to the host via VirtioSocket (AF_VSOCK)
    /// - Throws: HostConnectionError if connection fails
    public func connect() async throws {
      // Create AF_VSOCK socket
      let sock = Darwin.socket(AF_VSOCK, SOCK_STREAM, 0)
      guard sock >= 0 else {
        throw HostConnectionError.connectionFailed(
          POSIXError(POSIXErrorCode(rawValue: errno) ?? .ECONNREFUSED)
        )
      }

      // Prepare sockaddr_vm structure
      var addr = sockaddr_vm(
        svm_len: UInt8(MemoryLayout<sockaddr_vm>.size),
        svm_family: sa_family_t(AF_VSOCK),
        svm_reserved1: 0,
        svm_port: port,
        svm_cid: hostCID
      )

      // Connect to host
      let result = withUnsafePointer(to: &addr) { addrPtr in
        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
          Darwin.connect(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_vm>.size))
        }
      }

      if result < 0 {
        Darwin.close(sock)
        throw HostConnectionError.connectionFailed(
          POSIXError(POSIXErrorCode(rawValue: errno) ?? .ECONNREFUSED)
        )
      }

      // Bound blocking read/write so a stalled host can't park the I/O queue.
      HarvestMessageFraming.configureTimeouts(
        descriptor: sock, seconds: HarvestConfiguration.ioTimeoutSeconds
      )

      socketFD = sock
    }

    /// Sends data to the host with length-prefix framing
    /// - Parameter data: The data to send
    /// - Throws: HostConnectionError if not connected or send fails
    public func send(_ data: Data) async throws {
      guard socketFD >= 0 else {
        throw HostConnectionError.connectionFailed(POSIXError(.ENOTCONN))
      }

      let fd = socketFD

      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        ioQueue.async {
          do {
            try HarvestMessageFraming.writeMessage(descriptor: fd, data: data)
            continuation.resume()
          } catch {
            continuation.resume(throwing: Self.connectionError(from: error))
          }
        }
      }
    }

    /// Receives data from the host with length-prefix framing
    /// - Returns: The received data
    /// - Throws: HostConnectionError if not connected or receive fails
    public func receive() async throws -> Data {
      guard socketFD >= 0 else {
        throw HostConnectionError.connectionFailed(POSIXError(.ENOTCONN))
      }

      let fd = socketFD

      return try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Data, Error>) in
        ioQueue.async {
          do {
            let data = try HarvestMessageFraming.readMessage(
              descriptor: fd, maxLength: HarvestConfiguration.maxMessageLength
            )
            continuation.resume(returning: data)
          } catch {
            continuation.resume(throwing: Self.connectionError(from: error))
          }
        }
      }
    }

    /// Disconnects from the host
    public func disconnect() {
      let fd = socketFD
      guard fd >= 0 else {
        return
      }
      // Invalidate synchronously so new send/receive calls fail the guard, then
      // close on the serial queue so the close runs after any in-flight syscall.
      socketFD = -1
      ioQueue.async {
        Darwin.close(fd)
      }
    }

    /// Maps a framing error onto the guest connection error domain.
    private static func connectionError(from error: Error) -> HostConnectionError {
      guard let framingError = error as? HarvestFramingError else {
        return .connectionFailed(error)
      }
      switch framingError {
      case .connectionClosed:
        return .connectionFailed(POSIXError(.ECONNRESET))
      case .messageTooLarge:
        return .connectionFailed(POSIXError(.EMSGSIZE))
      case .posix(let posixError):
        return .connectionFailed(posixError)
      }
    }
  }

  // sockaddr_vm structure for AF_VSOCK (from sys/vsock.h)
  private struct sockaddr_vm {
    var svm_len: UInt8
    var svm_family: sa_family_t
    var svm_reserved1: UInt16
    var svm_port: UInt32
    var svm_cid: UInt32
  }

  // Constants from sys/vsock.h
  private let AF_VSOCK: Int32 = 40
  private let SOCK_STREAM: Int32 = 1
#endif
