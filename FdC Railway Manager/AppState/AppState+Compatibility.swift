import Foundation
import SwiftUI
import Combine

// Forwarding computed properties so existing call sites (appState.X) continue
// to work without modification while the underlying storage lives in the
// specialized sub-objects.  This file will shrink as call sites are migrated.

// MARK: - Settings forwarding (pre-existing)

extension AppState {
    var globalLineWidth: Double {
        get { uiSettings.globalLineWidth }
        set { uiSettings.globalLineWidth = newValue }
    }

    var globalFontSize: Double {
        get { uiSettings.globalFontSize }
        set { uiSettings.globalFontSize = newValue }
    }

    var showGrid: Bool {
        get { uiSettings.showGrid }
        set { uiSettings.showGrid = newValue }
    }

    var trackWidthSingle: Double {
        get { trackSettings.widthSingle }
        set { trackSettings.widthSingle = newValue }
    }

    var trackWidthDouble: Double {
        get { trackSettings.widthDouble }
        set { trackSettings.widthDouble = newValue }
    }

    var trackWidthRegional: Double {
        get { trackSettings.widthRegional }
        set { trackSettings.widthRegional = newValue }
    }

    var trackWidthHighSpeed: Double {
        get { trackSettings.widthHighSpeed }
        set { trackSettings.widthHighSpeed = newValue }
    }

    var regionalMaxSpeed: Double {
        get { trainPhysics.regionalMaxSpeed }
        set { trainPhysics.regionalMaxSpeed = newValue }
    }

    var regionalAcceleration: Double {
        get { trainPhysics.regionalAcceleration }
        set { trainPhysics.regionalAcceleration = newValue }
    }

    var regionalDeceleration: Double {
        get { trainPhysics.regionalDeceleration }
        set { trainPhysics.regionalDeceleration = newValue }
    }

    var regionalPriority: Double {
        get { trainPhysics.regionalPriority }
        set { trainPhysics.regionalPriority = newValue }
    }

    var intercityMaxSpeed: Double {
        get { trainPhysics.intercityMaxSpeed }
        set { trainPhysics.intercityMaxSpeed = newValue }
    }

    var intercityAcceleration: Double {
        get { trainPhysics.intercityAcceleration }
        set { trainPhysics.intercityAcceleration = newValue }
    }

    var intercityDeceleration: Double {
        get { trainPhysics.intercityDeceleration }
        set { trainPhysics.intercityDeceleration = newValue }
    }

    var intercityPriority: Double {
        get { trainPhysics.intercityPriority }
        set { trainPhysics.intercityPriority = newValue }
    }

    var highSpeedMaxSpeed: Double {
        get { trainPhysics.highSpeedMaxSpeed }
        set { trainPhysics.highSpeedMaxSpeed = newValue }
    }

    var highSpeedAcceleration: Double {
        get { trainPhysics.highSpeedAcceleration }
        set { trainPhysics.highSpeedAcceleration = newValue }
    }

    var highSpeedDeceleration: Double {
        get { trainPhysics.highSpeedDeceleration }
        set { trainPhysics.highSpeedDeceleration = newValue }
    }

    var highSpeedPriority: Double {
        get { trainPhysics.highSpeedPriority }
        set { trainPhysics.highSpeedPriority = newValue }
    }

    var singleTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedSingle }
        set { trackSettings.maxSpeedSingle = newValue }
    }

    var doubleTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedDouble }
        set { trackSettings.maxSpeedDouble = newValue }
    }

    var regionalTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedRegional }
        set { trackSettings.maxSpeedRegional = newValue }
    }

    var highSpeedTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedHighSpeed }
        set { trackSettings.maxSpeedHighSpeed = newValue }
    }

    var aiEndpoint: String {
        get { aiCredentials.endpoint }
        set { aiCredentials.endpoint = newValue }
    }

    var aiUsername: String {
        get { aiCredentials.username }
        set { aiCredentials.username = newValue }
    }

    var aiPassword: String {
        get { aiCredentials.password }
        set { aiCredentials.password = newValue }
    }

    var aiApiKey: String {
        get { aiCredentials.apiKey }
        set { aiCredentials.apiKey = newValue }
    }

    var useCloudAI: Bool {
        get { aiCredentials.useCloudAI }
        set { aiCredentials.useCloudAI = newValue }
    }
}

// MARK: - NavigationState forwarding

extension AppState {
    var sidebarSelection: SidebarItem? {
        get { navigation.sidebarSelection }
        set { navigation.sidebarSelection = newValue }
    }

    var jumpToTrainId: UUID? {
        get { navigation.jumpToTrainId }
        set { navigation.jumpToTrainId = newValue }
    }

    var activePanel: ActivePanel {
        get { navigation.activePanel }
        set { navigation.activePanel = newValue }
    }

    var lineInspectorMode: LineInspectorMode {
        get { navigation.lineInspectorMode }
        set { navigation.lineInspectorMode = newValue }
    }

    var isSideMenuVisible: Bool { navigation.isSideMenuVisible }
    var isInspectorVisible: Bool { navigation.isInspectorVisible }
    var isModeBarVisible: Bool { navigation.isModeBarVisible }

    var isWidePanelVisible: Bool {
        navigation.sidebarSelection == .lines
            && navigation.lineInspectorMode == .schedule
            && selectedRouteId != nil
    }

    func showPanel(_ panel: ActivePanel) { navigation.showPanel(panel) }
    func togglePanel(_ panel: ActivePanel) { navigation.togglePanel(panel) }
}

// MARK: - EditorModeState forwarding

extension AppState {
    var currentMode: AppMode {
        get { editorMode.currentMode }
        set { editorMode.currentMode = newValue }
    }

    var mapVisualizationMode: MapVisualizationMode {
        get { editorMode.mapVisualizationMode }
        set { editorMode.mapVisualizationMode = newValue }
    }

    var isDraggingNode: Bool {
        get { editorMode.isDraggingNode }
        set { editorMode.isDraggingNode = newValue }
    }

    var mapZoomLevel: CGFloat {
        get { editorMode.mapZoomLevel }
        set { editorMode.mapZoomLevel = newValue }
    }

    var mapEditMode: MapEditMode {
        get { editorMode.mapEditMode }
        set { editorMode.mapEditMode = newValue }
    }

    var isLineEditing: Bool {
        get { editorMode.isLineEditing }
        set { editorMode.isLineEditing = newValue }
    }

    var isScheduleGeneratorVisible: Bool {
        get { editorMode.isScheduleGeneratorVisible }
        set { editorMode.isScheduleGeneratorVisible = newValue }
    }

    var isVehicleManagementVisible: Bool {
        get { editorMode.isVehicleManagementVisible }
        set { editorMode.isVehicleManagementVisible = newValue }
    }

    var isCreatingTrack: Bool {
        get { editorMode.isCreatingTrack }
        set { editorMode.isCreatingTrack = newValue }
    }

    var isWaitingForStationPlacement: Bool {
        get { editorMode.isWaitingForStationPlacement }
        set { editorMode.isWaitingForStationPlacement = newValue }
    }

    var stationPickingCallback: ((String) -> Void)? {
        get { editorMode.stationPickingCallback }
        set { editorMode.stationPickingCallback = newValue }
    }

    var lineDraftStations: [String] {
        get { editorMode.lineDraftStations }
        set { editorMode.lineDraftStations = newValue }
    }

    var trackDraftFromId: String? {
        get { editorMode.trackDraftFromId }
        set { editorMode.trackDraftFromId = newValue }
    }

    var trackDraftToId: String? {
        get { editorMode.trackDraftToId }
        set { editorMode.trackDraftToId = newValue }
    }

    var isCreatingLine: Bool {
        get { editorMode.isCreatingLine }
        set { editorMode.isCreatingLine = newValue }
    }
}

// MARK: - SchedulePreviewState forwarding

extension AppState {
    var schedulePreviewTrains: [RailwayTrain]? {
        get { schedulePreview.trains }
        set { schedulePreview.trains = newValue }
    }

    var schedulePreviewRoute: TrainRoute? {
        get { schedulePreview.route }
        set { schedulePreview.route = newValue }
    }

    var schedulePreviewMode: ScheduleMode {
        get { schedulePreview.mode }
        set { schedulePreview.mode = newValue }
    }

    var schedulePreviewSelectedModel: TrainModel? {
        get { schedulePreview.selectedModel }
        set { schedulePreview.selectedModel = newValue }
    }

    var schedulePreviewOptimizeVehicles: Bool {
        get { schedulePreview.optimizeVehicles }
        set { schedulePreview.optimizeVehicles = newValue }
    }

    var schedulePreviewMinTurnaroundTime: Int {
        get { schedulePreview.minTurnaroundTime }
        set { schedulePreview.minTurnaroundTime = newValue }
    }

    var optimizedTimesPreviewData: SchedulePreviewState.OptimizedTimesPreviewData? {
        get { schedulePreview.optimizedTimesData }
        set { schedulePreview.optimizedTimesData = newValue }
    }

    var optimizedTimesConfirmed: Bool {
        get { schedulePreview.optimizedTimesConfirmed }
        set { schedulePreview.optimizedTimesConfirmed = newValue }
    }

    var scheduleCreationViewRefreshId: Int {
        get { schedulePreview.refreshId }
        set { schedulePreview.refreshId = newValue }
    }
}
