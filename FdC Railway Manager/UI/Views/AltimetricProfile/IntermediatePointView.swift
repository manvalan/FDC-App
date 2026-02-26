import Foundation
import Combine
import SwiftUI
import MapKit
import CoreLocation

struct IntermediatePointView: View {
    let point: CGPoint
    let segment: TrackSegment
    let edge: Edge
    let altRange: Double
    let geoHeight: Double
    var isEditing: Bool = false
    @Binding var editText: String
    var onUpdate: (Double) -> Void
    var onLongPress: () -> Void
    var onCommitEdit: () -> Void
    var onCancelEdit: () -> Void
    var onDelete: () -> Void
    
    @State private var isDragging: Bool = false
    @State private var startAlt: Double = 0
    
    var body: some View {
        ZStack {
            // The draggable point - diamond shape for intermediate points
            Rectangle()
                .fill(isEditing ? Color.yellow : Color.green.opacity(0.8))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .overlay(
                    Rectangle()
                        .stroke(isEditing ? Color.orange : Color.green, lineWidth: 2)
                        .rotationEffect(.degrees(45))
                )
                .shadow(color: isEditing ? .orange.opacity(0.5) : .black.opacity(0.3), radius: isEditing ? 4 : 2)
                .position(point)
                .onLongPressGesture {
                    onLongPress()
                }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { val in
                            if !isDragging {
                                isDragging = true
                                startAlt = segment.altitude ?? 0
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
                        Text("Punto Intermedio")
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
                        Button(action: onCommitEdit) {
                            Label("Applica", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        
                        Button(action: onDelete) {
                            Label("Elimina", systemImage: "trash.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button(action: onCancelEdit) {
                            Label("Annulla", systemImage: "xmark.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .position(x: point.x, y: point.y - 60)
            }
        }
    }
}
