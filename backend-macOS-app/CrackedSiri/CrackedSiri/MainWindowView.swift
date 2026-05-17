//
//  MainWindowView.swift
//  CrackedSiri
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @State private var response: GuideResponse?
    @State private var currentQuery: String?
    @State private var queryText: String = ""
    @State private var isLoading = false
    @State private var showHighlights = false
    @State private var errorMessage: String?
    @State private var backendConnected = false
    
    let apiClient = APIClient()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing for window controls (traffic lights)
            Color.clear.frame(height: 28)
            
            // Header
            headerView
            
            // Query input
            queryInputSection
            
            // Results
            resultsSection
        }
        .background(.regularMaterial)
        .onAppear {
            checkBackendConnection()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // App icon and title
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Sauce")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.9))
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(backendConnected ? Color.green : Color.red.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .shadow(color: backendConnected ? .green.opacity(0.5) : .red.opacity(0.5), radius: 3)
                
                Text(backendConnected ? "Ready" : "Offline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
    
    // MARK: - Query Input
    private var queryInputSection: some View {
        HStack(spacing: 10) {
            // Text field with glass effect
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                TextField("Ask anything about your screen...", text: $queryText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .disabled(isLoading)
                    .onSubmit {
                        submitQuery()
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Submit button
            Button(action: submitQuery) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                queryText.isEmpty ? 
                                    AnyShapeStyle(Color.secondary.opacity(0.5)) :
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                    }
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(queryText.isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(spacing: 0) {
            if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if isLoading {
                loadingView
            } else if let response = response {
                GuideModeView(response: response, query: currentQuery, showHighlights: $showHighlights)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial.opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    // MARK: - State Views
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Dismiss") {
                withAnimation(.spring(response: 0.3)) {
                    self.errorMessage = nil
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.blue)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            
            Text("Analyzing your screen...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Need some Sauce to assist? Just Ask")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary.opacity(0.8))
            
            Text("Ask me anything about what's on your screen")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding()
    }
    
    // MARK: - Actions
    private func submitQuery() {
        guard !queryText.isEmpty else { return }
        let query = queryText
        queryText = ""
        Task {
            await handleQuery(query)
        }
    }
    
    private func handleQuery(_ query: String) async {
        // Capture screenshot at submission time
        guard let imageBase64 = await captureScreenshotAtSubmissionTime() else {
            await MainActor.run {
                withAnimation { self.errorMessage = "Failed to capture screenshot" }
            }
            return
        }
        
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                isLoading = true
                errorMessage = nil
                currentQuery = query
            }
        }
        
        defer {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3)) {
                    self.isLoading = false
                }
            }
        }
        
        do {
            let response = try await apiClient.analyze(
                imageBase64: imageBase64,
                query: query,
                mode: "guide"
            )
            await MainActor.run {
                withAnimation(.spring(response: 0.4)) {
                    self.response = response
                }
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func captureScreenshotAtSubmissionTime() async -> String? {
        return await withCheckedContinuation { continuation in
            ScreenCaptureManager.captureScreenWithoutAppWindows { image in
                if let image = image, let base64 = ScreenCaptureManager.imageToBase64(image) {
                    continuation.resume(returning: base64)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func checkBackendConnection() {
        Task {
            do {
                let connected = try await apiClient.healthCheck()
                await MainActor.run {
                    withAnimation { self.backendConnected = connected }
                }
            } catch {
                await MainActor.run {
                    withAnimation { self.backendConnected = false }
                }
            }
        }
    }
    
}

#Preview {
    MainWindowView()
        .frame(width: 420, height: 540)
}
