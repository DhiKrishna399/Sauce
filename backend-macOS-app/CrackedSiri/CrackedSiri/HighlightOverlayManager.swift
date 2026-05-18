//
//  HighlightOverlayManager.swift
//  CrackedSiri
//
//  Manages a transparent fullscreen overlay window for displaying highlights

import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let highlightsDismissed = Notification.Name("highlightsDismissed")
}

class HighlightOverlayManager: ObservableObject {
    static let shared = HighlightOverlayManager()
    
    private var overlayWindow: NSWindow?
    @Published var activeHighlights: [Highlight] = []
    @Published var isVisible: Bool = false
    
    private init() {
        setupOverlayWindow()
    }
    
    private func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.overlayManager = self
        
        let hostingView = NSHostingView(rootView: HighlightOverlayView(manager: self))
        hostingView.frame = screen.frame
        window.contentView = hostingView
        
        self.overlayWindow = window
    }
    
    func showHighlight(_ highlight: Highlight, forStep stepNumber: Int? = nil) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.activeHighlights = [highlight]
            self.isVisible = true
            self.overlayWindow?.orderFront(nil)
            
            // Force view refresh
            if let hostingView = self.overlayWindow?.contentView as? NSHostingView<HighlightOverlayView> {
                hostingView.rootView = HighlightOverlayView(manager: self)
            }
        }
    }
    
    func showHighlights(_ highlights: [Highlight]) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.activeHighlights = highlights
            self.isVisible = true
            self.overlayWindow?.orderFront(nil)
        }
    }
    
    func hideAll() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.activeHighlights = []
            self.isVisible = false
            self.overlayWindow?.orderOut(nil)
            
            // Notify that highlights were dismissed
            NotificationCenter.default.post(name: .highlightsDismissed, object: nil)
        }
    }
    
    func toggleHighlight(_ highlight: Highlight) {
        if activeHighlights.contains(where: { $0.label == highlight.label }) {
            hideAll()
        } else {
            showHighlight(highlight)
        }
    }
    
    func showTestHighlight() {
        guard let screen = NSScreen.main else { return }
        
        // Place test highlight at ~1/3 from left, ~1/4 from top (in logical screen coordinates)
        let testX = Int(screen.frame.width * 0.3)
        let testY = Int(screen.frame.height * 0.25)
        
        let testHighlight = Highlight(
            type: "box",
            x: testX,
            y: testY,
            radius: nil,
            width: 150,
            height: 50,
            toX: nil,
            toY: nil,
            label: "Test Highlight",
            color: "#FF6B6B"
        )
        showHighlight(testHighlight)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.hideAll()
        }
    }
}

// Custom window that dismisses overlay when clicked
class OverlayWindow: NSWindow {
    weak var overlayManager: HighlightOverlayManager?
    
    override func mouseDown(with event: NSEvent) {
        overlayManager?.hideAll()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
