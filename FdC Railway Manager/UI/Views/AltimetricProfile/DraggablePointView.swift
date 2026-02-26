import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

struct DraggablePointView: View {
    let point: CGPoint
    let station: Node
    let altRange: Double
    let geoHeight: Double
    var isLocked: Bool = false
    var isEditing: Bool = false
    @Binding var editText: String
    var onUpdate: (Double) -> Void
    var onLongPress: () -> Void
    var onCommitEdit: () -> Void
    var onCancelEdit: () -> Void
    var onToggleLock: () -> Void
    
    @State private var isDragging: Bool = false
    @State private var startAlt: Double = 0
    
    var body: some View {
        ZStack {
            // The draggable point
            Circle()
                .fill(isEditing ? Color.yellow : (isLocked ? Color.red : (station.type == .junction ? Color.black : Color.white)))
                .frame(width: station.type == .junction ? 8 : 16, height: station.type == .junction ? 8 : 16)
                .overlay(Circle().stroke(isEditing ? Color.orange : (station.type == .junction ? Color.gray : Color.blue), lineWidth: station.type == .junction ? 1 : 2))
                .overlay(
                    ZStack {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                    }
                )
                .contentShape(Circle().inset(by: -10))
                .shadow(color: isEditing ? .orange.opacity(0.5) : .black.opacity(0.2), radius: isEditing ? 4 : 1)
                .position(point)
                .onTapGesture(count: 2) {
                    onLongPress()
                }
                .onLongPressGesture {
                    onLongPress()
                }
                .gesture(
                    isLocked ? nil : DragGesture(minimumDistance: 2)
                        .onChanged { val in
                            if !isDragging {
                                isDragging = true
                                startAlt = station.altitude ?? 0
                            }
                            
                            let effectiveH = geoHeight * 0.8
                            let deltaAlt = -(val.translation.height / effectiveH) * altRange
                            let newAlt = startAlt + deltaAlt
                            onUpdate(newAlt)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            
            // Altitude Editor Popover
            if isEditing {
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text(station.name.isEmpty ? (station.type == .junction ? "Bivio" : "Nodo") : station.name)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: onCancelEdit) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Altitude input
                    HStack(spacing: 4) {
                        TextField("Quota", text: $editText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Actions
                    HStack(spacing: 8) {
                        Button(action: onToggleLock) {
                            Label(
                                isLocked ? "Sblocca" : "Blocca",
                                systemImage: isLocked ? "lock.open.fill" : "lock.fill"
                            )
                            .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(isLocked ? .green : .orange)
                        
                        Spacer()
                        
                        Button(action: onCommitEdit) {
                            Text("Applica")
                                .font(.caption2.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .frame(width: 180)
                .position(x: point.x, y: point.y - 75)
            }
        }
    }
}
