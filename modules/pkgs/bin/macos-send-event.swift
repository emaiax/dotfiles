#!/usr/bin/env swift

/**
    Robust event sender for macOS Sequoia
    Usage: ./send-event EVENT_NAME
*/

import Foundation

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("Error: Missing event name\n".data(using: .utf8)!)
    FileHandle.standardError.write("Usage: \(CommandLine.arguments[0]) EVENT_NAME\n".data(using: .utf8)!)
    exit(1)
}

let eventName = CommandLine.arguments[1]
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