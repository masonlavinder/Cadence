import SwiftUI
import SwiftData

@main
struct GymApp: App {
    // SwiftData model container with all model types registered
    let modelContainer: ModelContainer
    
    // Stores initialized with the model context
    let exerciseStore: ExerciseStore
    let workoutStore: WorkoutStore
    let sessionStore: SessionStore
    
    init() {
        // Register all @Model types
        let schema = Schema([
            Exercise.self,
            Workout.self,
            WorkoutEntry.self,
            WorkoutSession.self,
            EntrySessionLog.self,
            Share.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Initialize stores with the main context
        let context = modelContainer.mainContext
        exerciseStore = ExerciseStore(modelContext: context)
        workoutStore = WorkoutStore(modelContext: context)
        sessionStore = SessionStore(modelContext: context)
        
        // TODO Phase 7: Check for first launch and seed exercises
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(exerciseStore)
                .environment(workoutStore)
                .environment(sessionStore)
        }
        .modelContainer(modelContainer)
    }
}
