//
//  ContentView.swift
//  Cadence
//
//  Created by S. Mason Lavinder on 3/14/26.
//

import SwiftUI
import SwiftData

/// Root navigation view with tab-based navigation
struct ContentView: View {
    var body: some View {
        TabView {
            // Workout Library Tab
            NavigationStack {
                WorkoutsView()
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell")
            }

            // Exercise Catalog Tab
            NavigationStack {
                ExerciseCatalogView()
            }
            .tabItem {
                Label("Movements", systemImage: "figure.strengthtraining.traditional")
            }

            // Insights Tab
            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar.fill")
            }

            // Coach Tab
            if FeatureFlags.coachTab {
                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.text.bubble.right")
                }
            }

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
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
