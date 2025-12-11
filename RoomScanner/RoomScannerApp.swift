//
//  RoomScannerApp.swift
//  RoomScanner
//
//  Created by Abhishek trezi on 10/12/25.
//

/*
 RoomScannerApp.swift
 Purpose: Main app entry point for the RoomScanner iOS application.
 Sets up environment objects and app-wide configuration.
 
 Created: December 2025
 */

import SwiftUI

@available(iOS 16.0, *)
@main
struct RoomScannerApp: App {
    @StateObject private var manager = RoomCaptureManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
    }
}
