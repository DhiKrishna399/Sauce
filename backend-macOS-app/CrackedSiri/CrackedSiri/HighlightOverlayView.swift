//
//  HighlightOverlayView.swift
//  CrackedSiri
//
//  SwiftUI view that renders highlight overlays on screen

import SwiftUI

struct HighlightOverlayView: View {
    @ObservedObject var manager: HighlightOverlayManager
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Invisible background to fill the screen
            Color.clear
            
            ForEach(Array(manager.activeHighlights.enumerated()), id: \.offset) { index, highlight in
                HighlightShape(highlight: highlight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

struct HighlightShape: View {
    let highlight: Highlight
    
    private var highlightColor: Color {
        if let colorHex = highlight.color {
            return Color(hex: colorHex) ?? .red
        }
        return .red
    }
    
    // Coordinates from AI - try different scale factors
    // The screenshot is captured at 2x retina but encoded to PNG which may be at logical size
    private static let scaleFactor: CGFloat = 1.0  // Try 1.0 first, change to 2.0 if needed
    
    private var scaledX: CGFloat {
        CGFloat(highlight.x) / Self.scaleFactor
    }
    
    private var scaledY: CGFloat {
        CGFloat(highlight.y) / Self.scaleFactor
    }
    
    private var scaledWidth: CGFloat {
        CGFloat(highlight.width ?? 100) / Self.scaleFactor
    }
    
    private var scaledHeight: CGFloat {
        CGFloat(highlight.height ?? 40) / Self.scaleFactor
    }
    
    private var scaledRadius: CGFloat {
        CGFloat(highlight.radius ?? 30) / Self.scaleFactor
    }
    
    var body: some View {
        // Debug: print the coordinates
        let _ = print("🎯 Highlight: x=\(highlight.x), y=\(highlight.y), w=\(highlight.width ?? 0), h=\(highlight.height ?? 0) → scaled: x=\(scaledX), y=\(scaledY)")
        
        switch highlight.type {
        case "circle":
            circleHighlight
        default:
            boxHighlight
        }
    }
    
    private var boxHighlight: some View {
        // Add padding to make highlight more forgiving of imprecise AI coordinates
        let padding: CGFloat = 20
        let adjustedWidth = max(scaledWidth, 80) + padding * 2
        let adjustedHeight = max(scaledHeight, 50) + padding * 2
        // Offset adjustment to center the padded highlight over the target
        let adjustedX = scaledX - padding
        let adjustedY = scaledY - padding
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(highlightColor.opacity(0.15))
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlightColor, lineWidth: 4)
            
            // Only show label if it's meaningful (not empty, not just dots/ellipsis)
            if !highlight.label.isEmpty && !highlight.label.hasPrefix("...") && highlight.label != "Step" {
                VStack {
                    Text(highlight.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(highlightColor)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                    Spacer()
                }
                .offset(y: -35)
            }
        }
        .frame(width: adjustedWidth, height: adjustedHeight)
        .offset(x: adjustedX, y: adjustedY)
        .pulsingAnimation()
    }
    
    private var circleHighlight: some View {
        let adjustedRadius = max(scaledRadius, 30) + 10
        
        return ZStack {
            Circle()
                .fill(highlightColor.opacity(0.15))
            
            Circle()
                .stroke(highlightColor, lineWidth: 4)
            
            // Only show label if meaningful
            if !highlight.label.isEmpty && !highlight.label.hasPrefix("...") && highlight.label != "Step" {
                VStack {
                    Text(highlight.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(highlightColor)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                    Spacer()
                }
                .offset(y: -adjustedRadius - 20)
            }
        }
        .frame(width: adjustedRadius * 2, height: adjustedRadius * 2)
        .offset(x: scaledX - adjustedRadius, y: scaledY - adjustedRadius)
        .pulsingAnimation()
    }
}

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.85)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulsingAnimation() -> some View {
        modifier(PulsingModifier())
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
