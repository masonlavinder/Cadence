import SwiftUI

// MARK: - AIGeneratorView

struct AIGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var category: WorkoutCategory = .strength
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var duration: Double = 30
    @State private var difficulty: Difficulty = .intermediate
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var additionalNotes: String = ""
    
    var body: some View {
        Form {
            Section {
                Text("AI Workout Generator")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Coming in Phase 6! For now, use the manual workout editor.")
                    .foregroundStyle(.secondary)
            }
            
            Section("Configuration (Preview)") {
                Picker("Category", selection: $category) {
                    ForEach(WorkoutCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized)
                    }
                }
                
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        Text(diff.rawValue.capitalized)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(duration)) minutes")
                    Slider(value: $duration, in: 15...90, step: 15)
                }
            }
            
            Section("Muscle Groups") {
                Text("Select target muscles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(MuscleGroup.allCases.prefix(10), id: \.self) { muscle in
                        MuscleChip(
                            muscle: muscle,
                            isSelected: selectedMuscles.contains(muscle)
                        ) {
                            if selectedMuscles.contains(muscle) {
                                selectedMuscles.remove(muscle)
                            } else {
                                selectedMuscles.insert(muscle)
                            }
                        }
                    }
                }
            }
            
            Section("Equipment") {
                Text("Available equipment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach([Equipment.none, .barbell, .dumbbell, .kettlebell, .resistanceBand, .yogaMat], id: \.self) { equip in
                        EquipmentChip(
                            equipment: equip,
                            isSelected: selectedEquipment.contains(equip)
                        ) {
                            if selectedEquipment.contains(equip) {
                                selectedEquipment.remove(equip)
                            } else {
                                selectedEquipment.insert(equip)
                            }
                        }
                    }
                }
            }
            
            Section("Additional Notes") {
                TextField("Any special requests?", text: $additionalNotes, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("Generate Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate") {
                    // TODO: Phase 6 - LLM integration
                    dismiss()
                }
                .disabled(true) // Disabled until Phase 6
            }
        }
    }
}

// MARK: - MuscleChip

struct MuscleChip: View {
    let muscle: MuscleGroup
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(muscle.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EquipmentChip

struct EquipmentChip: View {
    let equipment: Equipment
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "dumbbell")
                    .font(.caption2)
                Text(equipment.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AIGeneratorView()
    }
}
