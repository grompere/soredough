import SwiftUI
import SwiftData
import Charts

// MARK: - Data Types

/// Identifies a unique exercise variant (name + tag combination).
struct ExerciseIdentity: Hashable, Identifiable {
    let name: String
    let tags: [String]

    var id: String {
        let tagPart = tags.sorted().joined(separator: ",")
        return "\(name.lowercased().trimmingCharacters(in: .whitespaces))|\(tagPart)"
    }

    var displayLabel: String {
        if tags.isEmpty {
            return name
        }
        return "\(name) · \(tags.sorted().joined(separator: ", "))"
    }
}

/// A single data point for a chart line.
struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let repCount: Int
}

// MARK: - Jelly Merge Modifier

struct JellyMergeModifier: ViewModifier {
    let isSource: Bool
    let isTarget: Bool
    let jellyPhase: CGFloat  // 0 = idle, 1 = full jelly
    let sourceCollapsed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: isTarget ? 1 + 0.10 * jellyPhase : (isSource && sourceCollapsed ? 0.01 : 1),
                y: isTarget ? 1 + 0.05 * jellyPhase : (isSource && sourceCollapsed ? 0.01 : 1)
            )
            .opacity(isSource && sourceCollapsed ? 0 : 1)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.orange.opacity((isSource || isTarget) ? 0.12 * jellyPhase : 0))
                    .padding(.horizontal, -8)
                    .padding(.vertical, -2)
            )
    }
}

// MARK: - Progress List View

struct ProgressListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var completedSessions: [Session]

    @State private var aggregateAcrossTags = true

    // Rename state
    @State private var renamingIdentity: ExerciseIdentity?
    @State private var renameText = ""

    // Merge animation state
    @State private var animatingIdentities: [ExerciseIdentity]?
    @State private var mergingSourceId: String?
    @State private var mergingTargetId: String?
    @State private var jellyPhase: CGFloat = 0
    @State private var sourceCollapsed = false

    private var exerciseIdentities: [ExerciseIdentity] {
        var seen = Set<String>()
        var result: [ExerciseIdentity] = []

        for session in completedSessions {
            for exercise in session.exercises {
                let identity: ExerciseIdentity
                if aggregateAcrossTags {
                    identity = ExerciseIdentity(name: exercise.name, tags: [])
                } else {
                    identity = ExerciseIdentity(name: exercise.name, tags: exercise.tags)
                }
                if seen.insert(identity.id).inserted {
                    result.append(identity)
                }
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var displayIdentities: [ExerciseIdentity] {
        animatingIdentities ?? exerciseIdentities
    }

    /// Find the existing identity that a rename would merge into
    private func findMergeTarget(newName: String, from source: ExerciseIdentity) -> ExerciseIdentity? {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let hypothetical = ExerciseIdentity(
            name: trimmed,
            tags: aggregateAcrossTags ? [] : source.tags
        )
        guard hypothetical.id != source.id else { return nil }
        return exerciseIdentities.first { $0.id == hypothetical.id }
    }

    var body: some View {
        Group {
            if displayIdentities.isEmpty {
                ContentUnavailableView {
                    Label("No Progress Yet", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Complete some workouts to see your progress here.")
                }
            } else {
                List {
                    Section {
                        Toggle(isOn: $aggregateAcrossTags.animation()) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.slash")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                Text("Aggregate across tags")
                                    .font(.subheadline)
                            }
                        }
                        .tint(.orange)
                    }

                    Section("Exercises") {
                        ForEach(displayIdentities) { identity in
                            NavigationLink {
                                ExerciseProgressChartView(
                                    identity: identity,
                                    sessions: completedSessions,
                                    aggregateAcrossTags: aggregateAcrossTags
                                )
                            } label: {
                                HStack {
                                    exerciseRow(identity)
                                    Spacer()
                                    Button {
                                        renameText = identity.name
                                        renamingIdentity = identity
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(6)
                                            .background(.quaternary, in: Circle())
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .modifier(JellyMergeModifier(
                                isSource: mergingSourceId == identity.id,
                                isTarget: mergingTargetId == identity.id,
                                jellyPhase: jellyPhase,
                                sourceCollapsed: sourceCollapsed
                            ))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renamingIdentity) { identity in
            renameSheet(for: identity)
        }
    }

    // MARK: - Row

    private func exerciseRow(_ identity: ExerciseIdentity) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(identity.name)
                .font(.subheadline)
                .fontWeight(.medium)
            if !identity.tags.isEmpty {
                TagFlowView(tags: identity.tags, compact: true)
            }
        }
    }

    // MARK: - Rename Sheet

    @ViewBuilder
    private func renameSheet(for identity: ExerciseIdentity) -> some View {
        let target = findMergeTarget(newName: renameText, from: identity)
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        let canSubmit = !trimmed.isEmpty && trimmed.lowercased() != identity.name.lowercased()

        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(identity.name)
                        .font(.body)
                        .foregroundStyle(target != nil ? .secondary : .primary)
                        .strikethrough(target != nil, color: .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("New name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Exercise name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let target {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Will merge with **\(target.displayLabel)**")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Rename Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { renamingIdentity = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target != nil ? "Merge" : "Rename") {
                        let capturedTarget = findMergeTarget(newName: renameText, from: identity)
                        renamingIdentity = nil
                        performRename(from: identity, to: renameText, mergeTarget: capturedTarget)
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: target?.id)
        }
        .presentationDetents([.height(target != nil ? 310 : 250)])
        .interactiveDismissDisabled()
    }

    // MARK: - Rename & Merge

    private func performRename(from source: ExerciseIdentity, to newName: String, mergeTarget target: ExerciseIdentity?) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let target {
            performMerge(source: source, target: target, newName: trimmed)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                renameExercisesInDB(oldName: source.name, newName: trimmed)
            }
        }
    }

    private func performMerge(source: ExerciseIdentity, target: ExerciseIdentity, newName: String) {
        // Phase 0: Snapshot the list so we control the animation
        var snapshot = exerciseIdentities
        animatingIdentities = snapshot

        // Rename in DB immediately (hidden behind our snapshot)
        renameExercisesInDB(oldName: source.name, newName: newName)

        // Phase 1: Slide source next to target
        guard let sourceIdx = snapshot.firstIndex(where: { $0.id == source.id }),
              let targetIdx = snapshot.firstIndex(where: { $0.id == target.id }) else {
            animatingIdentities = nil
            return
        }

        let sourceItem = snapshot.remove(at: sourceIdx)
        let adjustedTargetIdx = snapshot.firstIndex(where: { $0.id == target.id }) ?? 0
        let insertIdx = sourceIdx < targetIdx ? adjustedTargetIdx + 1 : adjustedTargetIdx
        snapshot.insert(sourceItem, at: insertIdx)

        mergingSourceId = source.id
        mergingTargetId = target.id

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            animatingIdentities = snapshot
        }

        // Phase 2: Jelly wobble — both items pulse together
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                jellyPhase = 1
            }
        }

        // Phase 3: Source collapses into target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                sourceCollapsed = true
            }
        }

        // Phase 4: Remove source from list, target absorbs with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            snapshot.removeAll { $0.id == source.id }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                animatingIdentities = snapshot
                jellyPhase = 0.6 // brief re-pulse for absorption feel
            }
        }

        // Phase 5: Settle — hand control back to real data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                jellyPhase = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animatingIdentities = nil
                mergingSourceId = nil
                mergingTargetId = nil
                sourceCollapsed = false
            }
        }
    }

    private func renameExercisesInDB(oldName: String, newName: String) {
        let descriptor = FetchDescriptor<Exercise>()
        guard let allExercises = try? modelContext.fetch(descriptor) else { return }

        for exercise in allExercises {
            if exercise.name.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
                exercise.name = newName
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Chart View

struct ExerciseProgressChartView: View {
    let identity: ExerciseIdentity
    let sessions: [Session]
    let aggregateAcrossTags: Bool

    private var dataPoints: [ProgressPoint] {
        var points: [ProgressPoint] = []

        for session in sessions {
            let matchingExercises = session.exercises.filter { exercise in
                if aggregateAcrossTags {
                    return exercise.name.localizedCaseInsensitiveCompare(identity.name) == .orderedSame
                } else {
                    return exercise.name.localizedCaseInsensitiveCompare(identity.name) == .orderedSame
                        && Set(exercise.tags) == Set(identity.tags)
                }
            }

            var sessionMax1RME: Double? = nil

            for exercise in matchingExercises {
                // Group sets by rep count and find max weight per rep count
                var maxByRep: [Int: Double] = [:]
                for set in exercise.sets where set.isCompleted && set.weight > 0 {
                    let current = maxByRep[set.repCount] ?? 0
                    if set.weight > current {
                        maxByRep[set.repCount] = set.weight
                    }

                    if set.repCount > 0 {
                        let estimated1RM = set.weight * (1.0 + Double(set.repCount) / 30.0)
                        if estimated1RM > (sessionMax1RME ?? 0) {
                            sessionMax1RME = estimated1RM
                        }
                    }
                }

                for (repCount, maxWeight) in maxByRep {
                    points.append(ProgressPoint(
                        date: session.startedAt,
                        maxWeight: maxWeight,
                        repCount: repCount
                    ))
                }
            }

            if let max1RME = sessionMax1RME {
                points.append(ProgressPoint(
                    date: session.startedAt,
                    maxWeight: max1RME,
                    repCount: 0
                ))
            }
        }

        return points.sorted { $0.date < $1.date }
    }

    private var repCounts: [Int] {
        Array(Set(dataPoints.map(\.repCount))).sorted()
    }

    // Curated chart line colors
    private let lineColors: [Color] = [
        .orange, .blue, .green, .purple, .pink,
        .teal, .red, .cyan, .indigo, .mint
    ]

    @State private var selectedPoint: ProgressPoint?
    @State private var hiddenReps: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(identity.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    if !identity.tags.isEmpty {
                        TagFlowView(tags: identity.tags)
                    }
                }
                .padding(.horizontal, 20)

                if dataPoints.isEmpty {
                    ContentUnavailableView {
                        Label("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("Complete sets with weight to see progress.")
                    }
                    .frame(height: 300)
                } else {
                    // Chart
                    chartView
                        .frame(height: 280)
                        .padding(.horizontal, 16)

                    // Legend
                    legendView
                        .padding(.horizontal, 20)

                    // Summary cards
                    summaryCards
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let seriesLabels = repCounts.map { seriesLabel(for: $0) }
        let seriesColors = repCounts.map { colorForRep($0) }
        let visibleRepCounts = repCounts.filter { !hiddenReps.contains($0) }

        Chart {
            ForEach(visibleRepCounts, id: \.self) { repCount in
                let seriesLabelStr = seriesLabel(for: repCount)
                let repPoints = dataPoints.filter { $0.repCount == repCount }
                ForEach(repPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.maxWeight),
                        series: .value("Reps", seriesLabelStr)
                    )
                    .foregroundStyle(by: .value("Reps", seriesLabelStr))
                    .lineStyle(StrokeStyle(lineWidth: repCount == 0 ? 2.5 : 2.0, dash: repCount == 0 ? [6, 4] : []))
                    .symbol {
                        Circle()
                            .fill(colorForRep(repCount))
                            .frame(width: repCount == 0 ? 5 : 6, height: repCount == 0 ? 5 : 6)
                    }
                    .interpolationMethod(.catmullRom)
                }
            }

            if let selected = selectedPoint, !hiddenReps.contains(selected.repCount) {
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Weight", selected.maxWeight)
                )
                .foregroundStyle(colorForRep(selected.repCount))
                .symbolSize(80)
                .annotation(position: .top, spacing: 6) {
                    Text("\(formatWeight(selected.maxWeight)) lbs · \(seriesLabel(for: selected.repCount)) · \(selected.date.formatted(.dateTime.month(.defaultDigits).day()))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorForRep(selected.repCount),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
            }
        }
        .chartForegroundStyleScale(domain: seriesLabels, range: seriesColors)
        .chartLegend(.hidden)
        .chartYAxisLabel("lbs")
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                            .font(.caption2)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geometry[plotFrame].origin
                        let tapX = location.x - origin.x
                        let tapY = location.y - origin.y

                        // Find nearest data point from visible series only
                        var nearest: ProgressPoint?
                        var nearestDistance: CGFloat = .infinity

                        for point in dataPoints {
                            // Skip hidden series
                            guard !hiddenReps.contains(point.repCount) else { continue }

                            guard let px: CGFloat = proxy.position(forX: point.date),
                                  let py: CGFloat = proxy.position(forY: point.maxWeight) else { continue }
                            let dist = hypot(tapX - px, tapY - py)
                            if dist < nearestDistance {
                                nearestDistance = dist
                                nearest = point
                            }
                        }

                        withAnimation(.easeOut(duration: 0.15)) {
                            if nearestDistance < 40, let nearest {
                                if selectedPoint?.id == nearest.id {
                                    selectedPoint = nil
                                } else {
                                    selectedPoint = nearest
                                }
                            } else {
                                selectedPoint = nil
                            }
                        }
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        FlowLayout(spacing: 8) {
            ForEach(repCounts, id: \.self) { repCount in
                let isHidden = hiddenReps.contains(repCount)
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForRep(repCount))
                        .frame(width: 8, height: 8)
                    Text(seriesLabel(for: repCount))
                        .font(.caption)
                        .strikethrough(isHidden)
                }
                .foregroundStyle(isHidden ? .secondary : .primary)
                .opacity(isHidden ? 0.4 : 1.0)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    let otherReps = repCounts.filter { $0 != repCount }
                    if hiddenReps == Set(otherReps) {
                        hiddenReps.removeAll()
                    } else {
                        hiddenReps = Set(otherReps)
                        if let selected = selectedPoint, selected.repCount != repCount {
                            selectedPoint = nil
                        }
                    }
                }
                .onTapGesture {
                    if hiddenReps.contains(repCount) {
                        hiddenReps.remove(repCount)
                    } else {
                        hiddenReps.insert(repCount)
                        if selectedPoint?.repCount == repCount {
                            selectedPoint = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let actualDataPoints = dataPoints.filter { $0.repCount != 0 }
        let allTimeMax = actualDataPoints.max(by: { $0.maxWeight < $1.maxWeight })
        let recentPoints = actualDataPoints.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: Date())! }
        let recentMax = recentPoints.max(by: { $0.maxWeight < $1.maxWeight })

        return HStack(spacing: 12) {
            summaryCard(
                title: "All-Time Max",
                value: allTimeMax.map { "\(formatWeight($0.maxWeight)) lbs" } ?? "—",
                subtitle: allTimeMax.map { "@ \($0.repCount) reps" } ?? "",
                icon: "trophy.fill",
                color: .orange
            )
            summaryCard(
                title: "30-Day Max",
                value: recentMax.map { "\(formatWeight($0.maxWeight)) lbs" } ?? "—",
                subtitle: recentMax.map { "@ \($0.repCount) reps" } ?? "",
                icon: "flame.fill",
                color: .red
            )
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private func seriesLabel(for repCount: Int) -> String {
        if repCount == 0 {
            return "1RME"
        } else {
            return "\(repCount) rep\(repCount == 1 ? "" : "s")"
        }
    }

    private func colorForRep(_ repCount: Int) -> Color {
        if repCount == 0 {
            return Color(red: 0.95, green: 0.72, blue: 0.15) // Sleek gold color for 1RME
        }
        let nonZeroReps = repCounts.filter { $0 != 0 }
        let index = nonZeroReps.firstIndex(of: repCount) ?? 0
        return lineColors[index % lineColors.count]
    }

    private func formatWeight(_ weight: Double) -> String {
        weight == weight.rounded() ? String(format: "%.0f", weight) : String(format: "%.1f", weight)
    }
}

#Preview {
    NavigationStack {
        ProgressListView()
    }
    .modelContainer(for: Session.self, inMemory: true)
}
