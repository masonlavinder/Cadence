import SwiftUI

// TODO Phase 5: Implement timer ring visualization
struct TimerRingView: View {
    @Environment(\.dsTheme) private var theme

    var body: some View {
        Circle()
            .stroke(theme.primary, lineWidth: 8)
            .frame(width: 100, height: 100)
        // TODO: Implement in Phase 5
    }
}

// TODO Phase 4: Implement muscle group picker
struct MuscleGroupPicker: View {
    var body: some View {
        Text("Muscle Group Picker")
        // TODO: Implement in Phase 4
    }
}
