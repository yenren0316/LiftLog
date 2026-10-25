//
//  LiftLogWidgetsLiveActivity.swift
//  LiftLogWidgets
//
//  Created by 侯彥任 on 2026/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiftLogWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiftLogWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiftLogWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiftLogWidgetsAttributes {
    fileprivate static var preview: LiftLogWidgetsAttributes {
        LiftLogWidgetsAttributes(name: "World")
    }
}

extension LiftLogWidgetsAttributes.ContentState {
    fileprivate static var smiley: LiftLogWidgetsAttributes.ContentState {
        LiftLogWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiftLogWidgetsAttributes.ContentState {
         LiftLogWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiftLogWidgetsAttributes.preview) {
   LiftLogWidgetsLiveActivity()
} contentStates: {
    LiftLogWidgetsAttributes.ContentState.smiley
    LiftLogWidgetsAttributes.ContentState.starEyes
}
