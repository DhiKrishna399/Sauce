//
//  ScreenshotPreview.swift
//  CrackedSiri
//

import SwiftUI

struct ScreenshotPreview: View {
    let image: NSImage
    let highlights: [Highlight]
    let showHighlights: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Screenshot
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(Color.gray.opacity(0.2))
            
            // Overlays as overlay views instead of Canvas
            if showHighlights {
                ForEach(highlights.indices, id: \.self) { index in
                    HighlightView(highlight: highlights[index])
                }
            }
        }
    }
}

struct HighlightView: View {
    let highlight: Highlight
    
    var body: some View {
        ZStack(alignment: .center) {
            switch highlight.type {
            case "circle":
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: CGFloat(highlight.radius ?? 40), height: CGFloat(highlight.radius ?? 40))
                    .position(x: CGFloat(highlight.x), y: CGFloat(highlight.y))
                
            case "box":
                Rectangle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(
                        width: CGFloat(highlight.width ?? 50),
                        height: CGFloat(highlight.height ?? 50)
                    )
                    .position(x: CGFloat(highlight.x) + CGFloat(highlight.width ?? 50) / 2,
                             y: CGFloat(highlight.y) + CGFloat(highlight.height ?? 50) / 2)
                
            case "arrow":
                // For now, skip arrow rendering to avoid Canvas issues
                EmptyView()
                
            default:
                EmptyView()
            }
            
            // Label
            Text(highlight.label)
                .font(.caption2)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .padding(4)
                .background(Color.blue)
                .cornerRadius(3)
                .position(x: CGFloat(highlight.x), y: CGFloat(highlight.y) - 20)
        }
    }
}

#Preview {
    let dummyImage = NSImage(systemSymbolName: "rectangle.fill", accessibilityDescription: nil)!
    let dummyHighlights: [Highlight] = [
        Highlight(type: "circle", x: 100, y: 100, radius: 30, width: nil, height: nil, toX: nil, toY: nil, label: "Step 1", color: nil)
    ]
    
    ScreenshotPreview(image: dummyImage, highlights: dummyHighlights, showHighlights: true)
}
