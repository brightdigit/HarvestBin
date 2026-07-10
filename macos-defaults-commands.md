# macOS Defaults Commands Reference

## Overview

The `defaults` command in macOS is a powerful command-line utility for reading, writing, and deleting macOS user defaults. It allows you to customize system behavior and application settings that are often not exposed through the standard GUI.

**Important**: There is no single comprehensive official list from Apple. These are hidden settings that vary by:
- Installed applications and services
- macOS version
- System configuration

## Basic Syntax

```bash
# Read a preference
defaults read [domain] [key]

# Write a preference
defaults write [domain] [key] [type] [value]

# Delete a preference
defaults delete [domain] [key]

# List all domains
defaults domains

# Search for a keyword
defaults find [word]

# Read the type of a preference
defaults read-type [domain] [key]
```

## Common Defaults Commands by Category

### Dock

```bash
# Show only active apps in Dock
defaults write com.apple.dock static-only -bool true

# Set Dock position (left, bottom, right)
defaults write com.apple.dock orientation -string "left"

# Change minimize effect (genie, scale, suck)
defaults write com.apple.dock mineffect -string "scale"

# Auto-hide Dock
defaults write com.apple.dock autohide -bool true

# Show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Set icon size
defaults write com.apple.dock tilesize -int 48

# Enable highlight hover effect for the grid view of a stack
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# Restart Dock to apply changes
killall Dock
```

### Finder

```bash
# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Set default Finder location to home folder
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show full POSIX path in window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Restart Finder
killall Finder
```

### Screenshots

```bash
# Set screenshot location
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# Change screenshot format (png, jpg, gif, pdf)
defaults write com.apple.screencapture type -string "jpg"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Include date in screenshot filename
defaults write com.apple.screencapture include-date -bool true

# Show mouse pointer in screenshots
defaults write com.apple.screencapture showsCursor -bool true

# Restart SystemUIServer
killall SystemUIServer
```

### Safari

```bash
# Enable Developer menu
defaults write com.apple.Safari IncludeDevelopMenu -bool true

# Show full URL in address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable Debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Show status bar
defaults write com.apple.Safari ShowStatusBar -bool true

# Don't send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true
```

### Desktop & UI

```bash
# Show icons for hard drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

# Show icons for external drives on desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true

# Show icons for mounted servers on desktop
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

# Disable menu bar transparency
defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false

# Always show scrollbars
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"
```

### Mouse & Trackpad

```bash
# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Enable three finger drag
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# Set tracking speed (0-3)
defaults write NSGlobalDomain com.apple.mouse.scaling -float 2.5

# Natural scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true
```

### Mission Control

```bash
# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Group windows by application
defaults write com.apple.dock expose-group-by-app -bool true
```

### Time Machine

```bash
# Don't offer new disks for Time Machine backup
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable local Time Machine backups
hash tmutil &> /dev/null && sudo tmutil disablelocal
```

### Miscellaneous

```bash
# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable full keyboard access for all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Set a fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
```

## Developer & System Administration

### Xcode

```bash
# Enable remote debugging
defaults write com.apple.dt.Xcode IDEDebuggerFeatureSetting 12
```

### Remote Access & Sharing

```bash
# Enable SSH (Remote Login)
sudo systemsetup -setremotelogin on

# Enable Screen Sharing
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

# Enable Remote Management with VNC access
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -clientopts -setvnclegacy -vnclegacy yes \
  -clientopts -setvncpw -vncpw yourpassword \
  -restart -agent -privs -all

# Enable Remote Management for all users (no password)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -restart -agent -privs -all

# Enable Remote Apple Events
sudo systemsetup -setremoteappleevents on

# Disable SSH
sudo systemsetup -setremotelogin off

# Disable Remote Management
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate
```

### Clear Dock Icons

```bash
# Remove all apps from Dock (complete reset)
defaults delete com.apple.dock; killall Dock

# Remove only persistent apps (keep folders/recent apps)
defaults delete com.apple.dock persistent-apps; killall Dock

# Remove folders and files from Dock
defaults delete com.apple.dock persistent-others; killall Dock

# Remove recent apps section (macOS Mojave+)
defaults delete com.apple.dock recent-apps; killall Dock

# Show only running apps (hide all persistent icons)
defaults write com.apple.dock static-only -bool true; killall Dock

# Restore normal Dock behavior
defaults write com.apple.dock static-only -bool false; killall Dock
```

### Full Disk Access

**Important**: Full disk access for applications like Terminal and sshd **cannot be granted via defaults write** or any command-line method. This is a security feature by design.

**Manual method only**:
1. System Preferences > Security & Privacy > Privacy tab
2. Select "Full Disk Access" from the list
3. Click the lock and authenticate
4. Add applications manually:
   - `/Applications/Utilities/Terminal.app`
   - `/usr/libexec/sshd-keygen-wrapper` (for SSH access)

**MDM method**: Use Mobile Device Management with PPPC (Privacy Preferences Policy Control) configuration profiles for enterprise deployment.

## Discovering New Defaults

### List all domains
```bash
defaults domains
```

### Read all defaults for a domain
```bash
defaults read com.apple.finder
```

### Search for specific settings
```bash
defaults find "screenshot"
```

### Monitor changes in real-time
Use third-party tools like `plistwatch` to monitor preference changes as you make them in System Preferences.

## Safety Tips

1. **Always backup current values** before changing:
   ```bash
   defaults read [domain] [key] > backup.txt
   ```

2. **Test changes carefully** - Some can harm your system

3. **Restart relevant services** after changes:
   - Dock: `killall Dock`
   - Finder: `killall Finder`
   - SystemUIServer: `killall SystemUIServer`
   - Or logout/restart for system-wide changes

4. **Delete preferences to restore defaults**:
   ```bash
   defaults delete [domain] [key]
   ```

5. **Note**: Running applications might not see changes immediately and could overwrite them

## Resources

### Community Collections
- [macos-defaults.com](https://macos-defaults.com/) - Interactive demos and categorized commands
- [defaults-write.com](https://www.defaults-write.com/) - Collection of hidden features
- [SS64.com macOS defaults](https://ss64.com/mac/syntax-defaults.html) - Extensive preference listings

### Tools
- `plistwatch` - Monitor preference changes in real-time
- `defaults` man page: `man defaults`

### Finding More
- Search GitHub for "macOS defaults" or "dotfiles"
- Check application bundles for preference keys
- Use `strings` command on binaries to find hidden preferences

## Common Domains

- `NSGlobalDomain` - System-wide preferences
- `com.apple.finder` - Finder
- `com.apple.dock` - Dock
- `com.apple.Safari` - Safari
- `com.apple.screencapture` - Screenshots
- `com.apple.desktopservices` - Desktop services
- `com.apple.driver.AppleBluetoothMultitouch.trackpad` - Trackpad

Remember: These hidden preferences can change between macOS versions, so always verify commands work on your system before relying on them.