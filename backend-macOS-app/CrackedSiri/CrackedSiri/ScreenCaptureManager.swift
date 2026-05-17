//
//  ScreenCaptureManager.swift
//  CrackedSiri
//

import AppKit
import Foundation
import ScreenCaptureKit

class ScreenCaptureManager {
    
    /// Captures screen while excluding our app's windows (no flashing)
    static func captureScreenWithoutAppWindows(completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                let image = try await captureExcludingOurWindows()
                await MainActor.run {
                    completion(image)
                }
            } catch {
                print("Screenshot failed: \(error)")
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }
    
    /// Capture screen excluding our app's windows using ScreenCaptureKit
    private static func captureExcludingOurWindows() async throws -> NSImage? {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first else {
            return nil
        }
        
        // Get our app's bundle identifier to filter out our windows
        let ourBundleID = Bundle.main.bundleIdentifier ?? "com.dhivakrishna.CrackedSiri"
        
        // Filter out our app's windows
        let excludedWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ourBundleID
        }
        
        // Create a content filter that excludes our windows
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        
        // Configure the capture
        let config = SCStreamConfiguration()
        config.width = Int(display.width) * 2  // Retina
        config.height = Int(display.height) * 2
        config.scalesToFit = false
        config.showsCursor = false
        
        // Capture the screenshot
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        return NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))
    }
    
    /// Synchronous capture (legacy - includes app windows)
    static func captureScreen() -> NSImage? {
        var result: NSImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    semaphore.signal()
                    return
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width) * 2
                config.height = Int(display.height) * 2
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                result = NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))
            } catch {
                print("Screenshot failed: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
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
