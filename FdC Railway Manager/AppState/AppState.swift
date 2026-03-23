import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Specialized state aggregates (Strangler pattern)

    @Published var navigation = NavigationState()
    @Published var editorMode = EditorModeState()
    @Published var schedulePreview = SchedulePreviewState()

    // MARK: - App-level state

    @Published var theme = FdCTheme()
    @Published var showAI: Bool = false
    var aiNetwork: NetworkModel? = nil
    let aiService = RailwayAIService.shared
    @Published var didAutoImport: Bool = false
    @Published var importMessage: String? = nil
    @Published var simulator = FDCSimulator()
    @Published var liveSim = LiveSimulationManager()

    // MARK: - Selection state (still centralized — touches navigation boundary)

    @Published var selectedRouteId: String? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var selectedNodeId: String? = nil {
        didSet {
            syncNodeSetFromSingleId()
            updateInspectorVisibilityForSelection()
        }
    }
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedNodeIds: Set<String> = []
    @Published var selectedNodeIdsOrder: [String] = []
    @Published var brushStrokePoints: [CGPoint] = []
    @Published var isEraserActive: Bool = false
    @Published var selectedEdgeId: String? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var selectedInfraLineId: String? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var selectedTrainIds: Set<UUID> = [] {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var selectedVehicleId: UUID? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var isShowingSettings: Bool = false {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var isInspectorEditingMode: Bool = false
    @Published var lastVehicleAssignmentRouteId: String? = nil

    // MARK: - Creation & I/O state

    @Published var creationRouteId: String? = nil {
        didSet { if creationRouteId != nil { navigation.showPanel(.inspector) } }
    }
    @Published var ioImportMode: IOImportMode? = nil

    // MARK: - Vehicle defaults

    @Published var lastVehicleName: String = ""
    @Published var lastVehicleModel: String = ""
    @Published var lastVehicleLength: Double = 200
    @Published var lastVehicleMaxSpeed: Double = 160

    // MARK: - Domain aggregate root

    @Published var railroad = RailroadNetwork()

    // MARK: - Settings aggregates

    @Published var uiSettings = UISettings()
    @Published var trackSettings = TrackSettings()
    @Published var trainPhysics = TrainPhysicsSettings()
    @Published var aiCredentials = AICredentials()

    @Published var currentLanguage: AppLanguage {
        didSet { LocalizationManager.shared.currentLanguage = currentLanguage }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        self.currentLanguage = LocalizationManager.shared.currentLanguage
        initializeAIService()
        setupBindings()
    }

    // MARK: - Derived accessors

    var selectedInfraLine: RailwayLine? {
        guard let id = selectedInfraLineId else { return nil }
        return railroad.network.lines.first(where: { $0.id == id })
    }

    var selectedRoute: TrainRoute? {
        railroad.lines.routes.first { $0.id == selectedRouteId }
    }

    /// Legacy alias — prefer `selectedRoute`.
    var selectedLine: TrainRoute? { selectedRoute }

    var selectedNode: RailwayNode? {
        railroad.network.nodes.first { $0.id == selectedNodeId }
    }

    var selectedVehicle: RailwayVehicle? {
        railroad.lines.vehicles.first { $0.id == selectedVehicleId }
    }

    var isSomethingSelected: Bool {
        selectedRouteId != nil || selectedNodeId != nil
            || selectedEdgeId != nil || !selectedTrainIds.isEmpty
    }

    // MARK: - Mutation methods

    func toggleNodeSelection(_ id: String) {
        if selectedNodeIds.contains(id) {
            selectedNodeIds.remove(id)
            selectedNodeIdsOrder.removeAll(where: { $0 == id })
        } else {
            selectedNodeIds.insert(id)
            selectedNodeIdsOrder.append(id)
        }
        selectedNodeId = selectedNodeIds.count == 1 ? selectedNodeIds.first : nil
    }

    func selectTrain(_ id: UUID) {
        selectedTrainIds = [id]
        selectedNodeId = nil
        selectedEdgeId = nil
    }

    func selectLine(_ route: TrainRoute) {
        selectedRouteId = route.id
        selectedNodeId = nil
        selectedEdgeId = nil
        selectedTrainIds = []
    }

    func clearSelection() {
        selectedRouteId = nil
        selectedNodeId = nil
        selectedEdgeId = nil
        isShowingSettings = false
        let keepInspectorOpen = editorMode.isCreatingLine
            || creationRouteId != nil
            || !selectedTrainIds.isEmpty
            || selectedVehicleId != nil
        if navigation.activePanel == .inspector && !keepInspectorOpen {
            navigation.activePanel = .none
        }
    }

    func showSettings() {
        clearSelection()
        isShowingSettings = true
        navigation.showPanel(.inspector)
    }

    func startTrainCreation(routeId: String) {
        creationRouteId = routeId
        selectedRouteId = routeId
        selectedTrainIds = []
        selectedNodeId = nil
        selectedEdgeId = nil
        navigation.showPanel(.inspector)
    }

    func getPhysics(
        for category: TrainCategory
    ) -> (acceleration: Double, deceleration: Double) {
        let params = trainPhysics.getParameters(for: category)
        return (params.acceleration, params.deceleration)
    }

    // MARK: - Private helpers

    private func syncNodeSetFromSingleId() {
        if let id = selectedNodeId, !isMultiSelectMode {
            selectedNodeIds = [id]
        } else if !isMultiSelectMode {
            selectedNodeIds = []
        }
    }

    private func initializeAIService() {
        aiService.syncCredentials(
            endpoint: aiCredentials.endpoint,
            apiKey: aiCredentials.apiKey,
            token: nil
        )
        aiService.verifyConnection()
    }

    private func setupBindings() {
        forwardObjectWillChange(from: navigation)
        forwardObjectWillChange(from: editorMode)
        forwardObjectWillChange(from: schedulePreview)
        forwardObjectWillChange(from: liveSim)
        railroad.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        railroad.lines.onSchedulesChanged = { [weak self] in
            guard let self else { return }
            simulator.schedules = railroad.lines.generateSchedulesPreview()
        }
        bindEditorModeToInspector()
    }

    private func bindEditorModeToInspector() {
        editorMode.$isDraggingNode
            .dropFirst()
            .sink { [weak self] _ in self?.updateInspectorVisibilityForSelection() }
            .store(in: &cancellables)
        editorMode.$mapEditMode
            .dropFirst()
            .sink { [weak self] _ in self?.updateInspectorVisibilityForSelection() }
            .store(in: &cancellables)
    }

    private func forwardObjectWillChange<T: ObservableObject>(from object: T) {
        object.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func updateInspectorVisibilityForSelection() {
        withAnimation {
            if shouldShowInspectorForSelection() {
                navigation.activePanel = .inspector
            } else if shouldHideInspectorForSelection() {
                navigation.activePanel = .none
            }
        }
    }

    private func shouldShowInspectorForSelection() -> Bool {
        if editorMode.isDraggingNode { return false }
        if editorMode.mapEditMode == .addTrack { return false }
        if editorMode.mapEditMode == .addStation { return false }
        return selectedRouteId != nil || selectedNodeId != nil
            || selectedEdgeId != nil || selectedInfraLineId != nil
            || !selectedTrainIds.isEmpty || isInspectorEditingMode
    }

    private func shouldHideInspectorForSelection() -> Bool { false }
}
