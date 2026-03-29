//
//  ContentView.swift
//  Cadence
//
//  Created by S. Mason Lavinder on 3/14/26.
//

import SwiftUI
import SwiftData

/// Root navigation view
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, Workout.self], inMemory: true)
        .environment(ExerciseStore(modelContext:
            try! ModelContainer(for: Exercise.self, Workout.self).mainContext))
        .environment(WorkoutStore(modelContext:
            try! ModelContainer(for: Exercise.self, Workout.self).mainContext))
        .environment(SessionStore(modelContext:
            try! ModelContainer(for: Exercise.self, Workout.self).mainContext))
}
