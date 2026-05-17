//
//  ScreenCaptureManager.swift
//  CrackedSiri
//

import AppKit
import Foundation

class ScreenCaptureManager {
    
    /// Captures screen after hiding all app windows to avoid including the GuideBot UI
    static func captureScreenWithoutAppWindows(completion: @escaping (NSImage?) -> Void) {
        // Store references to visible windows and their original states
        let appWindows = NSApp.windows.filter { $0.isVisible }
        
        // Hide all app windows
        for window in appWindows {
            window.orderOut(nil)
        }
        
        // Wait a moment for windows to fully hide, then capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let screenshot = captureScreenInternal()
            
            // Restore windows
            for window in appWindows {
                window.orderFront(nil)
            }
            
            // Re-activate the app so the window comes back to focus
            NSApp.activate(ignoringOtherApps: true)
            
            completion(screenshot)
        }
    }
    
    /// Internal capture method - does the actual screenshot
    private static func captureScreenInternal() -> NSImage? {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", "-t", "png", "/tmp/guidebot_screenshot.png"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if let imageData = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/guidebot_screenshot.png")),
               let image = NSImage(data: imageData) {
                try? FileManager.default.removeItem(atPath: "/tmp/guidebot_screenshot.png")
                return image
            }
        } catch {
            print("Screenshot failed: \(error)")
        }
        
        return nil
    }
    
    /// Synchronous capture (legacy - includes app windows)
    static func captureScreen() -> NSImage? {
        return captureScreenInternal()
    }
    
    static func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }
    
    static func captureAndEncode() -> String? {
        guard let screenshot = captureScreen() else { return nil }
        return imageToBase64(screenshot)
    }
}
