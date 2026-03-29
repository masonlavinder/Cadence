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
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                WorkoutsTabView()
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell.fill")
            }
            .tag(AppTab.workouts)

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar.fill")
            }
            .tag(AppTab.insights)
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
