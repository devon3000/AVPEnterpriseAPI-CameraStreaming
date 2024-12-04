//
//  avpenterprisetestApp.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/3/24.
//

import SwiftUI

@main
struct avpenterprisetestApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.progressive), in: .progressive)
    }
}
