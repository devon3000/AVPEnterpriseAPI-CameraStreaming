//
//  AppModel.swift
//  avpenterprisetest
//
//  Created by Devon Copley on 12/3/24.
//

import SwiftUI

class AppModel: ObservableObject {
    @Published var immersiveSpaceState: ImmersiveSpaceState = .closed
    let immersiveSpaceID = "IDImmersiveSpace"
}

enum ImmersiveSpaceState {
    case open
    case closed
    case inTransition
}
