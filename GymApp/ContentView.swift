//
//  ContentView.swift
//  GymApp
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
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "list.bullet.rectangle.portrait")
            }
            
            // Exercise Catalog Tab
            NavigationStack {
                ExerciseCatalogView()
            }
            .tabItem {
                Label("Exercises", systemImage: "figure.strengthtraining.traditional")
            }
            
            // History Tab
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

// MARK: - History View (Placeholder)

struct HistoryView: View {
    @Environment(SessionStore.self) private var sessionStore
    
    var body: some View {
        List {
            ForEach(sessionStore.recentSessions(limit: 50)) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.workoutName)
                        .font(.headline)
                    
                    HStack {
                        Text(session.formattedDuration)
                        Text("•")
                        Text("\(Int(session.completionPercentage * 100))% complete")
                        Text("•")
                        Text(session.startedAt, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("History")
        .overlay {
            if sessionStore.recentSessions().isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your completed workouts will appear here")
                )
            }
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
