//
//  GuideModeView.swift
//  CrackedSiri
//

import SwiftUI

struct GuideModeView: View {
    let response: GuideResponse
    let query: String?
    @Binding var showHighlights: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User's question
                if let query = query {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                            
                            Text("Q")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(query)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineSpacing(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Answer/Explanation
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: response.isHowTo ? "list.bullet.clipboard" : "lightbulb.min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: response.isHowTo ? [.orange, .yellow] : [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(response.isHowTo ? "Instructions" : "Answer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Text(response.explanation)
                        .font(.system(size: 13))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                
                // Steps (only show section if this is a how-to question with steps)
                if response.isHowTo && !response.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(response.steps) { step in
                            StepRow(step: step, totalSteps: response.steps.count)
                        }
                    }
                }
                
                // Toggle highlights (only if there are highlights)
                if !response.highlights.isEmpty {
                    HStack {
                        Toggle(isOn: $showHighlights) {
                            HStack(spacing: 6) {
                                Image(systemName: showHighlights ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 11))
                                Text("Show highlights on screen")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
    }
}

struct StepRow: View {
    let step: GuideStep
    let totalSteps: Int
    
    private var progressColor: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number with progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .trim(from: 0, to: CGFloat(step.step) / CGFloat(totalSteps))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                
                Text("\(step.step)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.instruction)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                if !step.elementDescription.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 9))
                        Text(step.elementDescription)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview("How-to Question") {
    let dummyResponse = GuideResponse(
        mode: "guide",
        answerType: "howto",
        explanation: "To change the view in Google Calendar, follow these steps:",
        steps: [
            GuideStep(step: 1, instruction: "Click the gear icon in the top right corner", elementDescription: "Settings button"),
            GuideStep(step: 2, instruction: "Select 'Settings' from the dropdown menu", elementDescription: "Menu item"),
            GuideStep(step: 3, instruction: "Navigate to 'View options'", elementDescription: "Left sidebar")
        ],
        highlights: []
    )
    
    GuideModeView(response: dummyResponse, query: "How do I change the calendar view?", showHighlights: .constant(false))
        .frame(width: 400, height: 500)
        .background(Color.gray.opacity(0.1))
}

#Preview("Informational Question") {
    let infoResponse = GuideResponse(
        mode: "guide",
        answerType: "informational",
        explanation: "The cheapest item on screen is the 'Basic Plan' at $9.99/month. It's highlighted in the pricing table on the left side of the page.",
        steps: [],
        highlights: []
    )
    
    GuideModeView(response: infoResponse, query: "What is the cheapest option?", showHighlights: .constant(false))
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.1))
}
