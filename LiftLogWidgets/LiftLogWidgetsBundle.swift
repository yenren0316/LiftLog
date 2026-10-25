//
//  LiftLogWidgetsBundle.swift
//  LiftLogWidgets
//
//  Created by 侯彥任 on 2026/10/25.
//

import WidgetKit
import SwiftUI

@main
struct LiftLogWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LiftLogWidgets()
        LiftLogWidgetsControl()
        LiftLogWidgetsLiveActivity()
    }
}
