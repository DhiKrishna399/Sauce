//
//  MainWindowView.swift
//  CrackedSiri
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @State private var conversationHistory: [ConversationItem] = []
    @State private var currentItemId: UUID?
    @State private var queryText: String = ""
    @State private var isLoading = false
    @State private var isPollingCall = false
    @State private var showHighlights = false
    @State private var backendConnected = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var scrollTrigger: Int = 0
    
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
            if conversationHistory.isEmpty {
                emptyStateView
            } else {
                conversationHistoryView
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
    
    // MARK: - Conversation History View
    private var conversationHistoryView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(conversationHistory) { item in
                        ConversationItemView(
                            item: item,
                            isPollingCall: isPollingCall && item.id == currentItemId,
                            showHighlights: $showHighlights,
                            statusColors: statusColors,
                            statusIcon: statusIcon
                        )
                        .id(item.id)
                    }
                }
                .padding(14)
            }
            .onChange(of: conversationHistory.count) { _ in
                if let lastItem = conversationHistory.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: currentItemId) { newId in
                if let id = newId {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollTrigger) { _ in
                if let lastItem = conversationHistory.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
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
        ScrollView {
            VStack(spacing: 16) {
                // Icon based on action type
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: response.status == "success" ? 
                                    (response.isEmailAction ? [.blue, .cyan] : [.green, .mint]) : 
                                    [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: response.isEmailAction ? "envelope.fill" : 
                          (response.type == "executed" ? "phone.arrow.up.right.fill" : "phone.fill"))
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                .shadow(color: response.status == "success" ? 
                        (response.isEmailAction ? .blue.opacity(0.4) : .green.opacity(0.4)) : 
                        .orange.opacity(0.4), radius: 10)
                
                // Message
                Text(response.message ?? "Processing...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Email details if this is an email action
                if response.isEmailAction, let details = response.details {
                    VStack(alignment: .leading, spacing: 12) {
                        // Subject
                        if let subject = details.subject {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.alignleft")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("Subject")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                Text(subject)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Body
                        if let body = details.body {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("Message")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                Text(body)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .lineLimit(6)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                
                // Call ID if available (for phone calls)
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
                        Text(response.isEmailAction ? "Email sent" : "Call initiated")
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
    }
    
    // MARK: - State Views
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
        // Create a new conversation item
        let newItem = ConversationItem(query: query)
        let itemId = newItem.id
        
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                conversationHistory.append(newItem)
                currentItemId = itemId
                isLoading = true
            }
        }
        
        // Capture screenshot at submission time
        guard let imageBase64 = await captureScreenshotAtSubmissionTime() else {
            await MainActor.run {
                withAnimation {
                    if let index = conversationHistory.firstIndex(where: { $0.id == itemId }) {
                        conversationHistory[index].isLoading = false
                        conversationHistory[index].errorMessage = "Failed to capture screenshot"
                    }
                    isLoading = false
                    scrollTrigger += 1
                }
            }
            return
        }
        
        // Detect if this is an action request
        let mode = detectMode(for: query)
        
        // Cancel any existing polling
        pollingTask?.cancel()
        
        do {
            if mode == "action" {
                let actionResult = try await apiClient.analyzeAction(
                    imageBase64: imageBase64,
                    query: query
                )
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        if let index = conversationHistory.firstIndex(where: { $0.id == itemId }) {
                            conversationHistory[index].actionResponse = actionResult
                            conversationHistory[index].isLoading = false
                        }
                        isLoading = false
                        scrollTrigger += 1
                    }
                }
                
                // Start polling if we have a callId
                if let callId = actionResult.callId {
                    startPollingCallStatus(callId: callId, itemId: itemId)
                }
            } else {
                let response = try await apiClient.analyze(
                    imageBase64: imageBase64,
                    query: query,
                    mode: "guide"
                )
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        if let index = conversationHistory.firstIndex(where: { $0.id == itemId }) {
                            conversationHistory[index].guideResponse = response
                            conversationHistory[index].isLoading = false
                        }
                        isLoading = false
                        scrollTrigger += 1
                    }
                }
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    if let index = conversationHistory.firstIndex(where: { $0.id == itemId }) {
                        conversationHistory[index].errorMessage = error.localizedDescription
                        conversationHistory[index].isLoading = false
                    }
                    isLoading = false
                    scrollTrigger += 1
                }
            }
        }
    }
    
    private func startPollingCallStatus(callId: String, itemId: UUID) {
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
                            if let index = conversationHistory.firstIndex(where: { $0.id == itemId }) {
                                conversationHistory[index].callStatus = status
                                conversationHistory[index].actionResponse = nil
                            }
                            scrollTrigger += 1
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
        
        // Check for email addresses in query
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let _ = lowercased.range(of: emailPattern, options: .regularExpression) {
            return "action"
        }
        
        let actionKeywords = [
            // Email keywords
            "email", "e-mail", "send an email", "send email", "email them", "email him", "email her",
            // Phone keywords
            "call", "phone", "dial",
            // Reservation keywords
            "book", "reserve", "reservation", "make a reservation",
            "schedule", "appointment",
            // Purchase keywords
            "order", "purchase", "buy",
            // Message keywords
            "tell them", "tell her", "tell him",
            "leave a message", "send a message", "let them know",
            "remind", "notify", "inform",
            // SMS keywords
            "text", "sms"
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

// MARK: - Conversation Item View
struct ConversationItemView: View {
    let item: ConversationItem
    let isPollingCall: Bool
    @Binding var showHighlights: Bool
    let statusColors: (CallStatusResponse) -> [Color]
    let statusIcon: (CallStatusResponse) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question bubble with red border
            questionBubble
            
            // Response content
            if item.isLoading {
                loadingIndicator
            } else if let error = item.errorMessage {
                errorBubble(message: error)
            } else if let callStatus = item.callStatus {
                callStatusBubble(status: callStatus)
            } else if let actionResponse = item.actionResponse {
                actionResponseBubble(response: actionResponse)
            } else if let guideResponse = item.guideResponse {
                guideResponseBubble(response: guideResponse)
            }
        }
    }
    
    private var questionBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Text("Q")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(item.query)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.6), lineWidth: 2)
        )
    }
    
    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Analyzing your screen...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func errorBubble(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func guideResponseBubble(response: GuideResponse) -> some View {
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
            
            if response.isHowTo && !response.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(response.steps) { step in
                        StepRowCompact(step: step, totalSteps: response.steps.count)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
    
    private func actionResponseBubble(response: ActionResponse) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: response.status == "success" ?
                                    (response.isEmailAction ? [.blue, .cyan] : [.green, .mint]) :
                                    [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: response.isEmailAction ? "envelope.fill" :
                          (response.type == "executed" ? "phone.arrow.up.right.fill" : "phone.fill"))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(response.message ?? "Processing...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if response.type == "executed" {
                        Text(response.isEmailAction ? "Email sent" : "Call initiated")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            
            if response.isEmailAction, let details = response.details {
                if let subject = details.subject {
                    HStack(spacing: 6) {
                        Text("Subject:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(subject)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func callStatusBubble(status: CallStatusResponse) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: statusColors(status),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: statusIcon(status))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.status.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColors(status).first ?? .gray)
                    
                    Text(status.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if isPollingCall {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
            if let success = status.success {
                HStack(spacing: 6) {
                    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(success ? .green : .red)
                    Text(success ? "Completed successfully" : "Did not complete")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(success ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let transcript = status.transcript, !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(transcript)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.8))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Compact Step Row for History
struct StepRowCompact: View {
    let step: GuideStep
    let totalSteps: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(step.step)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                
                if !step.elementDescription.isEmpty {
                    Text(step.elementDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    MainWindowView()
        .frame(width: 420, height: 540)
}
