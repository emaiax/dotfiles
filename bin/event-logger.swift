#!/usr/bin/env swift

import Foundation
import Cocoa

class SystemEventLogger {
    private var running = true

    private let distributedCenter = DistributedNotificationCenter.default()
    private let localCenter = NotificationCenter.default
    private let workspaceCenter = NSWorkspace.shared.notificationCenter

    struct MonitoredNotifications {
        var distributed: [String]
        var local: [String]
        var workspace: [String]
    }

    func startMonitoring(_ categories: MonitoredNotifications) {
        print("Starting system event monitoring...")
        print("(Press Ctrl+C to stop)\n")

        // Register distributed notifications
        categories.distributed.forEach { name in
            distributedCenter.addObserver(
                self,
                selector: #selector(handleDistributedNotification(_:)),
                name: NSNotification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
            print("📡 Registered distributed: \(name)")
        }

        // Register local notifications
        categories.local.forEach { name in
            localCenter.addObserver(
                self,
                selector: #selector(handleLocalNotification(_:)),
                name: NSNotification.Name(name),
                object: nil
            )
            print("🖥️ Registered local: \(name)")
        }

        // Register workspace notifications
        categories.workspace.forEach { name in
            workspaceCenter.addObserver(
                self,
                selector: #selector(handleWorkspaceNotification(_:)),
                name: NSNotification.Name(name),
                object: nil
            )
            print("💼 Registered workspace: \(name)")
        }

        // Handle graceful termination
        setupTerminationHandler()

        RunLoop.current.run()
    }

    private func setupTerminationHandler() {
        signal(SIGINT, { _ in
            NotificationCenter.default.post(name: NSNotification.Name("TerminateApp"), object: nil)
        })

        localCenter.addObserver(
            self,
            selector: #selector(terminate),
            name: NSNotification.Name("TerminateApp"),
            object: nil
        )
    }

    // MARK: - Notification Handlers

    @objc private func handleDistributedNotification(_ notification: Notification) {
        logNotification(notification, prefix: "📡 DISTRIBUTED")
    }

    @objc private func handleLocalNotification(_ notification: Notification) {
        logNotification(notification, prefix: "🖥 LOCAL")
    }

    @objc private func handleWorkspaceNotification(_ notification: Notification) {
        logNotification(notification, prefix: "💼 WORKSPACE")
    }

    private func logNotification(_ notification: Notification, prefix: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(prefix): \(notification.name.rawValue)")
        print("   - Object: \(notification.object ?? "nil")")
        if let userInfo = notification.userInfo {
            print("   - UserInfo: \(userInfo)")
        }
        print("----------------------------------------")
    }

    @objc private func terminate() {
        print("\nStopping monitor...")
        distributedCenter.removeObserver(self)
        localCenter.removeObserver(self)
        workspaceCenter.removeObserver(self)
        running = false
        exit(0)
    }
}

// Notification categories with common system events
let notificationsToMonitor = SystemEventLogger.MonitoredNotifications(
    distributed: [
        // System Preferences/Appearance
        "AppleInterfaceThemeChangedNotification",
        "AppleColorPreferencesChangedNotification",
        "AppleAquaColorVariantChanged",

        // Screen/Security
        "com.apple.screenIsLocked",
        "com.apple.screenIsUnlocked",
        "com.apple.sessionDidMoveOffConsole",

        // Hardware/Device
        "com.apple.accessibility.api",
        "com.apple.system.config.network_change",

        // Audio
        "com.apple.sound.settingsChanged"
    ],

    local: [
        // App Lifecycle
        "NSApplication.didBecomeActiveNotification",
        "NSApplication.willResignActiveNotification",
        "NSApplication.willTerminateNotification",

        // Window/View Events
        "NSWindow.didBecomeKeyNotification",
        "NSWindow.willCloseNotification",

        // Menu/UI
        "NSMenu.didBeginTrackingNotification",
        "NSMenu.didEndTrackingNotification"
    ],

    workspace: [
        // App Launch/Quit
        "NSWorkspace.didLaunchApplicationNotification",
        "NSWorkspace.didTerminateApplicationNotification",

        // File System/Devices
        "NSWorkspace.didMountNotification",
        "NSWorkspace.didUnmountNotification",
        "NSWorkspace.didRenameVolumeNotification",

        // Power/Sleep
        "NSWorkspace.willSleepNotification",
        "NSWorkspace.didWakeNotification",
        "NSWorkspace.screensDidSleepNotification",
        "NSWorkspace.screensDidWakeNotification"
    ]
)

// Start monitoring
SystemEventLogger().startMonitoring(notificationsToMonitor)