import SwiftUI

struct LogEntryView: View {
    var exercise: Exercise

    var body: some View {
        Text(exercise.name)
            .navigationTitle(exercise.name)
    }
}
