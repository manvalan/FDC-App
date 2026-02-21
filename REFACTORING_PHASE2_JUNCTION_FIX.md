# ✅ Junction Creation in Altitude Profile - Fixed

## User Request
> "quando aggiungo un junction con un tap nella finestra altimetrica devi legarlo alle stazioni che lo precedono e lo seguono e porlo al km corretto"

**Translation**: When adding a junction with a tap in the altitude window, you must link it to the stations that precede and follow it and place it at the correct km.

## Problem Identified

The `handleSegmentTap()` function had a critical limitation:

```swift
// BEFORE (line 1545):
guard p1.isStation && p2.isStation,  // ❌ Only stations allowed!
```

**Issues**:
1. **Too restrictive**: Only allowed creating junctions between stations, but now the path includes junction nodes
2. **Edge finding limitation**: Used `findEdge()` which could fail with bidirectional edges
3. **Not future-proof**: After creating first junction, couldn't create another junction between station and junction

## Solution Implemented

### Key Changes in EditorModeView.swift (lines 1543-1623)

**1. Removed station-only restriction**:
```swift
// AFTER (line 1545):
guard let nodeId1 = p1.nodeId,  // ✅ ANY consecutive nodes
      let nodeId2 = p2.nodeId,
```

**2. Use InfrastructureService for bidirectional edge finding**:
```swift
// Use InfrastructureService to find edge (handles bidirectional)
let service = InfrastructureService(network: appState.railroad.network)
guard let edgeDistance = service.calculateDistance(from: nodeId1, to: nodeId2) else {
    return
}
```

**3. Try both edge directions**:
```swift
// Find the actual edge (try both directions)
var edge: Edge?
if let e = appState.railroad.network.findEdge(from: nodeId1, to: nodeId2) {
    edge = e
} else if let e = appState.railroad.network.findEdge(from: nodeId2, to: nodeId1) {
    edge = e
}
```

**4. Use calculated distance from InfrastructureService**:
```swift
// Calculate distances using the actual edge distance
let totalDist = edgeDistance  // From InfrastructureService, not just edge.distance
let distToJunction = totalDist * Double(relativeX)
let distFromJunction = totalDist - distToJunction
```

## Benefits

### 1. Flexibility
- ✅ Can create junction between **station ↔ station**
- ✅ Can create junction between **station ↔ junction**
- ✅ Can create junction between **junction ↔ junction**

### 2. Correctness
- ✅ Uses bidirectional BFS from InfrastructureService
- ✅ Handles edges in both directions
- ✅ Calculates correct km position based on tap location

### 3. Consistency
- ✅ Uses same InfrastructureService as rest of the code
- ✅ Follows "Code That Fits in Your Head" principles
- ✅ No duplicate logic

## How It Works

1. **User taps** on altitude profile between two consecutive points (p1, p2)
2. **Function extracts** nodeId1 and nodeId2 from PointData
3. **InfrastructureService** calculates distance (handles bidirectional)
4. **Edge lookup** tries both directions (A→B or B→A)
5. **Position calculation**:
   - X position → relative position along edge (0 to 1)
   - Y position → altitude at tap location
6. **Junction creation**:
   - Geographic coordinates: linear interpolation between node1 and node2
   - Distance to junction: `edgeDistance × relativeX`
   - Distance from junction: `edgeDistance - distToJunction`
7. **Edge splitting**:
   - Remove old edges: A↔B (both directions)
   - Create new edges: A↔Junction and Junction↔B (all bidirectional)

## Build Status

✅ **Build Successful** - No compilation errors
✅ **No Breaking Changes** - Function signature unchanged
✅ **Ready for Testing** - Can now create junctions anywhere in altitude profile

## Testing Scenarios

To verify this fix works correctly, test:

1. **Station to Station**: Create junction between two consecutive stations
2. **Station to Junction**: Create junction between a station and an existing junction
3. **Bidirectional Edges**: Ensure works when edge direction is reversed
4. **Correct km Position**: Verify junction appears at exact tap location
5. **Altitude Interpolation**: Verify altitude matches Y position of tap

## Relation to Phase 2 Refactoring

This fix builds on the Phase 2 refactoring work:
- Uses `InfrastructureService.calculateDistance()` (bidirectional BFS)
- Consistent with treating junctions as special stations
- Follows Single Responsibility Principle (service handles logic, view handles UI)

## Files Modified

- **EditorModeView.swift**: Function `handleSegmentTap()` (lines 1543-1623)
  - Removed station-only restriction
  - Added InfrastructureService usage
  - Added bidirectional edge finding
  - Total change: ~80 lines modified

## Code Committable

```bash
git add "FdC Railway Manager/EditorModeView.swift"
git commit -m "fix: allow junction creation between any consecutive nodes in altitude profile

- Removed restriction requiring both nodes to be stations
- Use InfrastructureService.calculateDistance() for bidirectional edge finding
- Try both edge directions when finding connecting edge
- Use calculated distance instead of assuming edge direction
- Enables creating junctions between station↔junction and junction↔junction
- Maintains correct km positioning based on tap location

Resolves user request: 'quando aggiungo un junction con un tap nella
finestra altimetrica devi legarlo alle stazioni che lo precedono e lo
seguono e porlo al km corretto'"
```

## Next Steps (Optional)

If further improvements are needed:

1. **Visual feedback**: Show preview of where junction will be created before tap
2. **Validation**: Prevent creating junction too close to existing nodes
3. **Undo/Redo**: Ensure junction creation is properly tracked in checkpoint system (already implemented via `createCheckpoint()`)
4. **Unit tests**: Test junction creation logic in isolation
