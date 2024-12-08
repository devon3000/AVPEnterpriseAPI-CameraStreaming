//
//  ToggleImmersiveSpaceButton.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/3/24.
//

import SwiftUI

struct ToggleImmersiveSpaceButton: View {

    @EnvironmentObject private var appModel: AppModel // Link to your shared app state

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button {
            print("Button tapped!") // Add this to confirm the button is responding
            Task { @MainActor in
                switch appModel.immersiveSpaceState {
                case .open:
                    print("Attempting to dismiss immersive space...")
                    appModel.immersiveSpaceState = .inTransition
                    await dismissImmersiveSpace() // This triggers Vision Pro to close the immersive space
                    print("Immersive space dismissed.")

                case .closed:
                    print("Attempting to open immersive space...")
                    appModel.immersiveSpaceState = .inTransition
                    let result = await openImmersiveSpace(id: appModel.immersiveSpaceID) // This triggers Vision Pro to open the immersive space
                    switch result {
                    case .opened:
                        print("Immersive space successfully opened.")
                        break // Lifecycle hooks (e.g., onAppear) will finalize state

                    case .userCancelled, .error:
                        print("Failed to open immersive space: \(result).")
                        appModel.immersiveSpaceState = .closed

                    @unknown default:
                        print("Unexpected result from openImmersiveSpace.")
                        appModel.immersiveSpaceState = .closed
                    }

                case .inTransition:
                    print("Transition in progress. Button action ignored.")
                }
            }
        } label: {
            Text(appModel.immersiveSpaceState == .open ? "Hide Immersive Space" : "Show Immersive Space")
        }
        .disabled(appModel.immersiveSpaceState == .inTransition) // Prevent interaction during transitions
        .fontWeight(.semibold)
    }
}
