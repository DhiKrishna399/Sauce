//
//  QueryInputView.swift
//  CrackedSiri
//

import SwiftUI

struct QueryInputView: View {
    @State private var query: String = ""
    var onSubmit: (String) -> Void
    var isLoading: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("What would you like to do?", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(isLoading)
            
            Button(action: {
                if !query.isEmpty {
                    onSubmit(query)
                    query = ""
                }
            }) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                } else {
                    Text("Ask")
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 12)
            .disabled(query.isEmpty || isLoading)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    QueryInputView(onSubmit: { _ in })
}
