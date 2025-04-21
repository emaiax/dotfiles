#!/usr/bin/env swift

// == How it works ==
//
// You can set the accent colour using a `defaults write` command,
// e.g. to change your accent colour to pink:
//
//      $ defaults write -g AppleAccentColor -int 6
//
// But this doesn't take effect immediately -- we have to send notifications
// AppleColorPreferencesChangedNotification and
// AppleAquaColorVariantChanged to tell apps they should update their UIs.
//
// == Attribution ==
//
// Based on code/ideas by Henrik Helmers, Garth Mortensen, and Robert Sesek.
//
// See https://alexwlchan.net/2022/11/changing-the-macos-accent-colour/

import Foundation

let notifications = [
    "ApplePrivateInterfaceThemeChangedNotification",   // FinderSyncExt
    "AppleColorPreferencesChangedNotification",        // accent color changes
    "AppleInterfaceThemeChangedNotification",          // dark/light mode changes
    "AppleAquaColorVariantChanged"                     // color variant changes
]

for eventName in notifications {
    let notificationName = Notification.Name(eventName)

    // Method 1: Try distributed notification
    do {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // Method 2: Fallback to local notification
    do {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }

    // Method 3: Ultimate fallback to system command
    do {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "display notification \"Event \(eventName) sent\" with title \"System Event\""]
        try task.run()
        task.waitUntilExit()
    }
}