//
//  avpenterprisetestApp.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/3/24.
//

import SwiftUI

@main
struct avpenterprisetestApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }

        // Define the immersive space here
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            EmptyView() // Minimal placeholder; functionality is handled in ContentView
        }
    }
}
