//
//  MainWindowView.swift
//  CrackedSiri
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @State private var response: GuideResponse?
    @State private var actionResponse: ActionResponse?
    @State private var callStatus: CallStatusResponse?
    @State private var currentQuery: String?
    @State private var queryText: String = ""
    @State private var isLoading = false
    @State private var isPollingCall = false
    @State private var showHighlights = false
    @State private var errorMessage: String?
    @State private var backendConnected = false
    @State private var currentMode: String = "guide"
    @State private var pollingTask: Task<Void, Never>?
    
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
            } else if let callStatus = callStatus {
                callStatusView(status: callStatus)
            } else if let actionResponse = actionResponse {
                actionResultView(response: actionResponse)
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
    
    // MARK: - Call Status View
    private func callStatusView(status: CallStatusResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: statusColors(for: status),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: statusIcon(for: status))
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .shadow(color: statusColors(for: status).first?.opacity(0.4) ?? .clear, radius: 10)
                
                // Status Badge
                Text(status.status.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(statusColors(for: status).first ?? .gray, in: Capsule())
                
                // Message
                Text(status.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Success/Failure indicator
                if let success = status.success {
                    HStack(spacing: 8) {
                        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(success ? .green : .red)
                        Text(success ? "Completed successfully" : "Did not complete")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(success ? .green : .red)
                    }
                    .padding(.top, 4)
                }
                
                // Transcript
                if let transcript = status.transcript, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.quote")
                                .foregroundColor(.secondary)
                            Text("Call Transcript")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(transcript)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Polling indicator
                if isPollingCall {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Updating...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private func statusColors(for status: CallStatusResponse) -> [Color] {
        switch status.status {
        case "completed":
            return status.success == true ? [.green, .mint] : [.orange, .yellow]
        case "in-progress":
            return [.blue, .cyan]
        case "ringing":
            return [.purple, .pink]
        case "queued":
            return [.gray, .secondary]
        case "failed", "no-answer":
            return [.red, .orange]
        default:
            return [.gray, .secondary]
        }
    }
    
    private func statusIcon(for status: CallStatusResponse) -> String {
        switch status.status {
        case "completed":
            return status.success == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        case "in-progress":
            return "phone.fill"
        case "ringing":
            return "phone.arrow.up.right.fill"
        case "queued":
            return "phone.badge.clock.fill"
        case "failed":
            return "phone.down.fill"
        case "no-answer":
            return "phone.fill.badge.xmark"
        default:
            return "phone.fill"
        }
    }
    
    // MARK: - Action Result View
    private func actionResultView(response: ActionResponse) -> some View {
        VStack(spacing: 16) {
            // Icon based on status
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: response.status == "success" ? [.green, .mint] : [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: response.type == "executed" ? "phone.arrow.up.right.fill" : "phone.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .shadow(color: response.status == "success" ? .green.opacity(0.4) : .orange.opacity(0.4), radius: 10)
            
            // Message
            Text(response.message ?? "Processing...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Call ID if available
            if let callId = response.callId {
                HStack(spacing: 6) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Call ID: \(callId)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            // Status indicator
            if response.type == "executed" {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Call initiated")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            } else if response.type == "error" {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Action failed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 24)
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
        
        // Detect if this is an action request
        let mode = detectMode(for: query)
        
        // Cancel any existing polling
        pollingTask?.cancel()
        
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                isLoading = true
                errorMessage = nil
                currentQuery = query
                currentMode = mode
                isPollingCall = false
                callStatus = nil
                // Clear previous responses
                if mode == "action" {
                    self.response = nil
                } else {
                    self.actionResponse = nil
                }
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
            if mode == "action" {
                let actionResult = try await apiClient.analyzeAction(
                    imageBase64: imageBase64,
                    query: query
                )
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        self.actionResponse = actionResult
                        self.callStatus = nil
                    }
                }
                
                // Start polling if we have a callId
                if let callId = actionResult.callId {
                    startPollingCallStatus(callId: callId)
                }
            } else {
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
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startPollingCallStatus(callId: String) {
        // Cancel any existing polling
        pollingTask?.cancel()
        
        pollingTask = Task {
            await MainActor.run {
                isPollingCall = true
            }
            
            var attempts = 0
            let maxAttempts = 60 // Poll for up to 2 minutes (2s intervals)
            
            while !Task.isCancelled && attempts < maxAttempts {
                do {
                    let status = try await apiClient.getCallStatus(callId: callId)
                    
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3)) {
                            self.callStatus = status
                            self.actionResponse = nil // Clear action response, show status instead
                        }
                    }
                    
                    // Stop polling if call is complete
                    if status.status == "completed" || status.status == "failed" || status.status == "no-answer" {
                        break
                    }
                } catch {
                    // Silently continue polling on error
                }
                
                attempts += 1
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            await MainActor.run {
                isPollingCall = false
            }
        }
    }
    
    private func detectMode(for query: String) -> String {
        let lowercased = query.lowercased()
        
        // Check for phone numbers in query (personal calls)
        let phonePattern = #"\+?1?\d{10,11}|\(\d{3}\)\s?\d{3}[-.]?\d{4}|\d{3}[-.]?\d{3}[-.]?\d{4}"#
        if let _ = lowercased.range(of: phonePattern, options: .regularExpression) {
            return "action"
        }
        
        let actionKeywords = [
            "call", "phone", "dial",
            "book", "reserve", "reservation", "make a reservation",
            "schedule", "appointment",
            "order", "purchase", "buy",
            "tell them", "tell her", "tell him",
            "leave a message", "send a message", "let them know",
            "remind", "notify", "inform"
        ]
        
        for keyword in actionKeywords {
            if lowercased.contains(keyword) {
                return "action"
            }
        }
        return "guide"
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
