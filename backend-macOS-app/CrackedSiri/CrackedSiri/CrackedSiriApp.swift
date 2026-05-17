//
//  CrackedSiriApp.swift
//  CrackedSiri
//
//  Created by Dhiva Krishna on 5/17/26.
//

import SwiftUI

@main
struct CrackedSiriApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra("GuideBot", systemImage: "sparkles") {
            MainWindowView()
                .frame(width: 420, height: 540)
        }
        .menuBarExtraStyle(.window)
    }
}
