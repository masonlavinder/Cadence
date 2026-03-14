import Foundation
import SwiftData

/// Standalone exercise catalog entity
/// This is the master library of all exercises the user can add to workouts
@Model
final class Exercise: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Core Properties
    var name: String
    var exerciseDescription: String  // "description" is reserved
    var instructions: String
    var exerciseType: ExerciseType
    
    // MARK: - Muscle Groups
    var primaryMuscleGroups: [MuscleGroup]
    var secondaryMuscleGroups: [MuscleGroup]
    
    // MARK: - Equipment & Difficulty
    var equipment: Equipment
    var movementPattern: MovementPattern?
    
    // MARK: - Default Configuration
    var defaultBlockType: BlockType
    var defaultSets: Int
    var defaultRepCount: Int?           // For rep-based exercises
    var defaultDurationSeconds: Int?    // For timed exercises
    var defaultRestBetweenSetsSeconds: Int
    var defaultRestAfterSeconds: Int
    
    // MARK: - Yoga/Flow-Specific
    var defaultHoldSeconds: Int?
    var defaultTransitionStyle: TransitionStyle?
    var defaultFlowStyle: FlowStyle?
    
    // MARK: - User Preferences
    var isFavorite: Bool
    var timesUsed: Int  // Increment each time added to a workout
    
    // MARK: - Media (Future)
    var thumbnailURL: String?
    var videoURL: String?
    var cueText: String?  // Custom TTS instructions
    
    // MARK: - Provenance
    var isCustom: Bool  // user-created vs. from built-in library
    var externalReferenceId: String?
    
    // MARK: - Initialization
    init(
        name: String,
        description: String = "",
        instructions: String = "",
        exerciseType: ExerciseType,
        primaryMuscleGroups: [MuscleGroup] = [],
        secondaryMuscleGroups: [MuscleGroup] = [],
        equipment: Equipment = .none,
        movementPattern: MovementPattern? = nil,
        defaultBlockType: BlockType = .repBased,
        defaultSets: Int = 3,
        defaultRepCount: Int? = 10,
        defaultDurationSeconds: Int? = nil,
        defaultRestBetweenSetsSeconds: Int = 60,
        defaultRestAfterSeconds: Int = 90,
        defaultHoldSeconds: Int? = nil,
        defaultTransitionStyle: TransitionStyle? = nil,
        defaultFlowStyle: FlowStyle? = nil,
        isFavorite: Bool = false,
        isCustom: Bool = true,
        thumbnailURL: String? = nil,
        videoURL: String? = nil,
        cueText: String? = nil
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.name = name
        self.exerciseDescription = description
        self.instructions = instructions
        self.exerciseType = exerciseType
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.movementPattern = movementPattern
        self.defaultBlockType = defaultBlockType
        self.defaultSets = defaultSets
        self.defaultRepCount = defaultRepCount
        self.defaultDurationSeconds = defaultDurationSeconds
        self.defaultRestBetweenSetsSeconds = defaultRestBetweenSetsSeconds
        self.defaultRestAfterSeconds = defaultRestAfterSeconds
        self.defaultHoldSeconds = defaultHoldSeconds
        self.defaultTransitionStyle = defaultTransitionStyle
        self.defaultFlowStyle = defaultFlowStyle
        self.isFavorite = isFavorite
        self.timesUsed = 0
        self.isCustom = isCustom
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.cueText = cueText
        self.externalReferenceId = nil
    }
}
