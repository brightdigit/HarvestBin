# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HarvestBin** is a guest-side service for macOS virtual machines that enables remote access and system management from the Bushel host application. It runs inside virtual machines to provide SSH management, system information gathering, and command execution capabilities.

**Tech Stack:**
- Swift 6.1+ with Tuist for project generation
- macOS 12+ deployment target (supports iOS 15+, watchOS 8+, tvOS 15+, visionOS 1+, macCatalyst 15+)
- Async/await for all I/O operations
- Sendable types for thread safety
- Network framework for service discovery and communication

**Main Components:**
- **HarvestBin** (macOS App) - Menu bar application for guest VM services
- **HarvestBinKit** (Swift Package) - Core service framework
- **harvestbin** (CLI Executable) - Command-line interface to run the macOS app

## Dependencies

### BushelKit (Subrepo Branch)

**IMPORTANT:** This project **temporarily** depends on the **`subrepo`** branch of BushelKit, located at `../BushelKit`. This dependency will transition to the main branch once the harvest-related modules are merged.

```bash
# Ensure BushelKit is checked out to the subrepo branch
cd ../BushelKit
git checkout subrepo
cd ../HarvestBin
```

The project uses these BushelKit modules:
- **BushelFoundation** - Core abstractions, logging, and utilities
- **BushelGuestProfile** - Guest OS configuration and system profiler data types
- **BushelHarvestCore** - Harvest protocol definitions and shared types (in development)

The package reference in `Packages/HarvestBinKit/Package.swift`:
```swift
dependencies: [
  .package(path: "../../../BushelKit")
]
```

## Common Development Commands

### Project Management with Tuist

**CRITICAL:** This project uses **Tuist** for Xcode project generation. The `.xcodeproj` and `.xcworkspace` files are gitignored and generated on-demand.

```bash
# Generate Xcode project
tuist generate

# Clean generated files
tuist clean

# Edit project configuration
# Edit Project.swift, then regenerate with `tuist generate`
```

**Tuist Version:** Managed via `mise.toml`:
```toml
[tools]
tuist = "4.46.0"
```

Install via mise: `mise install`

### Building and Testing

```bash
# Build with Tuist (generates project first if needed)
tuist build

# Build specific targets
tuist build HarvestBin
tuist build HarvestBinTests

# Build the Swift Package directly (HarvestBinKit)
cd Packages/HarvestBinKit
swift build

# Run tests for the package
swift test
```

### Running the Application

```bash
# Generate and open in Xcode
tuist generate
open HarvestBin.xcworkspace

# Run from Xcode or build and run the app bundle
```

## High-Level Architecture

HarvestBin implements a **guest-side service architecture** for virtual machines, enabling host-guest communication and remote management.

### Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│              HarvestBin macOS App                       │
│          (Menu Bar UI, Service Lifecycle)               │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              HarvestBinService                          │
│        (Central service coordinator)                    │
│  • Manages all subsystems                               │
│  • Handles service lifecycle (start/stop)               │
│  • Coordinates command execution                        │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Discovery    │  │ Host Conn    │  │ Command      │
│ Service      │  │ Service      │  │ Executor     │
│              │  │              │  │              │
│ • Advertises │  │ • TCP Server │  │ • Validates  │
│   VM via     │  │ • Processes  │  │   commands   │
│   Bonjour    │  │   incoming   │  │ • Routes to  │
│ • Network    │  │   commands   │  │   executors  │
│   discovery  │  │ • Sends      │  │              │
│              │  │   responses  │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           ▼
                ┌──────────────────┐
                │ Remote Access    │
                │ Manager          │
                │                  │
                │ • SSH setup      │
                │ • Service status │
                │ • Monitoring     │
                └──────────────────┘
```

### Core Services

**1. HarvestBinService** (`HarvestBinKit.swift`)
- Main coordinator for all guest services
- Manages lifecycle: `start()`, `stop()`, `getStatus()`
- Configuration via `HarvestBinConfiguration`
- Default port: 8080

**2. DiscoveryService** (`Discovery/DiscoveryService.swift`)
- Advertises the VM using Network framework's Bonjour (`_bushel-guest._tcp`)
- Broadcasts VM identifier and capabilities via TXT records
- Enables host machines to discover guest VMs on the local network
- Implementation: `NetworkDiscoveryService`

**3. HostConnectionService** (`HostConnection/HostConnectionService.swift`)
- TCP server for host-guest communication
- Accepts connections from Bushel host application
- Receives `HarvestCommand` objects (JSON-encoded)
- Sends `HarvestResponse` objects back to host
- Manages multiple concurrent connections

**4. CommandExecutor** (`CommandExecutor/CommandExecutor.swift`)
- Validates and executes commands from the host
- Security validation via `SecurityValidator`
- Routes commands to appropriate handlers:
  - **System commands**: ping, systemInfo
  - **Remote access commands**: SSH enable/disable, status
  - **Security commands**: validation and permission checks

**5. RemoteAccessManager** (`RemoteAccess/RemoteAccessManager.swift`)
- Manages SSH and other remote access services
- Enables/disables SSH via `systemsetup` command
- Monitors service status
- Delegates to `SSHManager` → `SystemSetupExecutor`

**6. SystemSetupExecutor** (`CommandExecutor/SystemSetupExecutor.swift`)
- Wrapper around macOS `/usr/sbin/systemsetup` command
- SSH operations: `-setremotelogin on/off`, `-getremotelogin`
- Requires elevated privileges (uses `sudo`)
- Process execution via `ProcessRunner`

### Service Communication Flow

```
Host (Bushel) ─────────────────────────────────────────────┐
                                                            │
1. Discovery:                                               │
   Bonjour Browser → finds "_bushel-guest._tcp"            │
   TXT Record → vmid, version, capabilities                │
                                                            │
2. Connection:                                              │
   TCP Connect → :8080                                      │
                                                            ▼
                                              ┌──────────────────────┐
3. Command:                                   │ HarvestBin Guest VM  │
   JSON: HarvestCommand { id, payload, ... } │                      │
                                              │  DiscoveryService    │
                                              │  HostConnectionSvc   │
4. Processing:                                │  CommandExecutor     │
   • Security validation                      │  RemoteAccessMgr     │
   • Route to executor                        │                      │
   • Execute (may call systemsetup)           └──────────────────────┘
                                                            │
5. Response:                                                │
   JSON: HarvestResponse { id, status, ... } ◄─────────────┘
```

### Command Protocol

Commands follow the `HarvestCommand` structure (defined in BushelHarvestCore):

```swift
struct HarvestCommand: Codable {
  let id: UUID
  let name: String
  let timestamp: Date
  let payload: CommandPayload
  let metadata: [String: String]?
}

enum CommandPayload {
  case system(SystemCommand)    // .ping, .systemInfo
  case remote(RemoteAccessCommand) // .ssh(.enable/.disable), .status
  case security(SecurityCommand)
}
```

Responses follow `HarvestResponse`:

```swift
struct HarvestResponse: Codable {
  let id: UUID
  let commandID: UUID
  let timestamp: Date
  let status: ResponseStatus  // .success, .error
  let payload: ResponsePayload
}

enum ResponsePayload {
  case systemInfo(SystemInfo)
  case remoteStatus(RemoteStatus)
  case error(HarvestErrorResponse)
}
```

### Key Design Patterns

**1. Protocol-Based Architecture**
```swift
protocol CommandExecutor: Sendable {
  func execute(_ command: HarvestCommand) async throws -> HarvestResponse
  func canExecute(_ command: HarvestCommand) -> Bool
}

protocol DiscoveryService: Sendable {
  func startAdvertising(vmIdentifier: String, capabilities: [String]) async throws
  func stopAdvertising() async
  var isAdvertising: Bool { get async }
}
```

**2. Dependency Injection**
```swift
// Default initialization with standard implementations
let service = HarvestBinService()

// Custom initialization for testing
let service = HarvestBinService(
  commandExecutor: MockCommandExecutor(),
  remoteAccessManager: MockRemoteAccessManager(),
  discoveryService: MockDiscoveryService(),
  hostConnectionService: MockHostConnectionService()
)
```

**3. Async/Await Throughout**
All I/O operations are async:
```swift
try await service.start(configuration: config)
let status = try await remoteAccessManager.status(for: .ssh)
let response = try await commandExecutor.execute(command)
```

**4. Logger Protocol**
```swift
protocol Logger: Sendable {
  func info(_ message: String)
  func error(_ message: String)
  func debug(_ message: String)
}

// Implementation: ConsoleLogger (prints to stdout/stderr)
```

**5. Process Execution Abstraction**
```swift
protocol ProcessRunner: Sendable {
  func run(executable: String, arguments: [String], requiresElevation: Bool) async throws -> ProcessResult
}

// Handles sudo elevation, pipe management, and async process execution
```

## Project Structure

```
HarvestBin/
├── HarvestBin/                    # macOS App
│   ├── Sources/
│   │   ├── HarvestBinApp.swift   # SwiftUI App entry point
│   │   └── ContentView.swift     # UI (minimal menu bar app)
│   ├── Resources/                # App resources (icons, etc.)
│   └── Tests/
│       └── HarvestBinTests.swift # App tests
│
├── Packages/
│   └── HarvestBinKit/            # Swift Package (core framework)
│       ├── Package.swift         # Package manifest
│       └── Sources/
│           ├── harvestbin/       # CLI executable
│           │   └── HarvestBinKit.swift
│           └── HarvestBinKit/    # Library target
│               ├── HarvestBinKit.swift       # Main service
│               ├── CommandExecutor/
│               │   ├── CommandExecutor.swift
│               │   └── SystemSetupExecutor.swift
│               ├── Discovery/
│               │   └── DiscoveryService.swift
│               ├── HostConnection/
│               │   └── HostConnectionService.swift
│               └── RemoteAccess/
│                   └── RemoteAccessManager.swift
│
├── Project.swift                 # Tuist project definition
├── Tuist.swift                   # Tuist configuration
├── Tuist/                        # Tuist helpers
│   └── Package.swift
├── mise.toml                     # Tool version management
└── macos-defaults-commands.md    # Reference for macOS defaults/systemsetup
```

## Module Responsibilities

### HarvestBinKit Library Modules

**CommandExecutor/**
- Command validation and security checks
- Command routing and execution
- Integration with system tools (systemsetup, launchctl)

**Discovery/**
- Bonjour/mDNS service advertising
- Network framework integration
- TXT record management for VM metadata

**HostConnection/**
- TCP server for host communication
- Connection lifecycle management
- JSON serialization/deserialization
- Command/response handling

**RemoteAccess/**
- SSH service management
- Remote access status monitoring
- Service enable/disable operations
- Integration with systemsetup and launchctl

## Important Implementation Details

### SSH Management

SSH is managed through macOS's `systemsetup` command:

```swift
// Enable SSH
await processRunner.run(
  executable: "/usr/sbin/systemsetup",
  arguments: ["-setremotelogin", "on"],
  requiresElevation: true  // Uses sudo
)

// Get status
let result = await processRunner.run(
  executable: "/usr/sbin/systemsetup",
  arguments: ["-getremotelogin"],
  requiresElevation: false
)
// Output: "Remote Login: On" or "Remote Login: Off"
```

**IMPORTANT:** SSH operations require elevated privileges. The process runner automatically uses `sudo` when `requiresElevation: true`.

### Service Discovery (Bonjour)

Uses Apple's Network framework for mDNS advertising:

```swift
let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(8080))
listener.service = NWListener.Service(
  name: vmIdentifier,           // e.g., "MacVM-abc123"
  type: "_bushel-guest._tcp",   // Service type
  txtRecord: NWTXTRecord([
    "vmid": vmIdentifier,
    "version": "1.0.0",
    "capabilities": "ssh,systeminfo",
    "ssh": "enabled",
    "timestamp": ISO8601DateFormatter().string(from: Date())
  ])
)
```

### Error Handling

The framework uses typed errors for different subsystems:

```swift
enum HarvestBinError: Error {
  case startupFailed(underlying: Error)
  case serviceUnavailable(String)
  case remoteAccessFailed(underlying: Error)
  case configurationInvalid(String)
}

enum SystemSetupError: Error {
  case commandFailed(String, exitCode: Int, output: String)
  case processStartFailed(Error)
  case permissionDenied(String)
  case invalidOutput(String)
}

enum DiscoveryError: Error {
  case advertisingFailed(underlying: Error)
  case notAdvertising
  case listenerCreationFailed
  case missingVMIdentifier
}
```

## Configuration

Default configuration:

```swift
HarvestBinConfiguration(
  port: 8080,                                     // TCP server port
  vmIdentifier: DiscoveryUtils.generateVMIdentifier(), // "hostname-uuid"
  capabilities: ["ssh", "systeminfo"],            // Advertised capabilities
  autoStartRemoteAccess: false                    // Auto-enable SSH on start
)
```

VM Identifier generation:
```swift
// Combines hostname + UUID for uniqueness
let hostname = ProcessInfo.processInfo.hostName
let uuid = UUID().uuidString.prefix(8)
return "\(hostname)-\(uuid)"  // e.g., "macOS-VM-a1b2c3d4"
```

## Security Considerations

1. **Command Validation** - All commands pass through `SecurityValidator` before execution
2. **Elevated Privileges** - SSH operations require sudo (user must have admin privileges)
3. **Network Security** - Service discovery limited to local network (peer-to-peer mode)
4. **Input Validation** - All command payloads validated before processing
5. **Error Handling** - Detailed errors without exposing system internals

## Testing Strategy

The architecture is designed for testability:

1. **Protocol-based design** - All services have protocol interfaces
2. **Dependency injection** - Services can be mocked for testing
3. **Async testing** - All tests use async/await test methods
4. **Process mocking** - `ProcessRunner` protocol allows mocking system commands

Example test setup:
```swift
final class HarvestBinTests: XCTestCase {
  func testServiceStartup() async throws {
    let mockExecutor = MockCommandExecutor()
    let mockDiscovery = MockDiscoveryService()
    let service = HarvestBinService(
      commandExecutor: mockExecutor,
      discoveryService: mockDiscovery,
      // ... other mocks
    )
    try await service.start()
    // Verify expectations
  }
}
```

## Development Workflow

### Making Changes to the App

1. Edit `Project.swift` for project configuration changes
2. Edit source files in `HarvestBin/Sources/` or `Packages/HarvestBinKit/Sources/`
3. Regenerate Xcode project: `tuist generate`
4. Build and test in Xcode

### Making Changes to the Package

```bash
cd Packages/HarvestBinKit
# Edit Swift files
swift build
swift test
```

### Adding New Capabilities

To add a new capability:

1. Define command type in `BushelHarvestCore` (if protocol extension needed)
2. Add executor logic in `CommandExecutor/`
3. Update `HarvestBinConfiguration.capabilities` array
4. Add to `DiscoveryService` TXT record capabilities
5. Update tests

### Debugging

**Enable verbose logging:**
```swift
// ConsoleLogger outputs to stdout/stderr
[INFO] 2025-01-31 12:00:00: Starting HarvestBin services
[ERROR] 2025-01-31 12:00:01: Failed to enable SSH: permission denied
```

**Check service status:**
```bash
# SSH status
sudo systemsetup -getremotelogin

# SSH daemon status
sudo launchctl print system/com.openssh.sshd

# Network listener
lsof -i :8080
```

## BushelKit Integration

When BushelKit's `BushelHarvestCore` module is available, it will provide:

- `HarvestCommand` and `HarvestResponse` protocol definitions
- Shared command payload types
- Common error codes
- Serialization helpers

Currently, these types are defined locally in HarvestBinKit and will migrate to BushelHarvestCore.

## Known Limitations

1. **macOS Only** - While the package supports iOS/tvOS/watchOS, the functionality is macOS-specific (systemsetup, SSH)
2. **Admin Privileges Required** - SSH management requires sudo access
3. **Local Network Only** - Service discovery limited to local network
4. **Single Service Port** - Currently hardcoded to port 8080

## Future Enhancements

Based on the architecture, potential additions:

- Screen sharing management (VNC/ARD)
- File transfer capabilities
- System configuration management
- Performance monitoring
- Log aggregation
- Multiple service types beyond SSH
