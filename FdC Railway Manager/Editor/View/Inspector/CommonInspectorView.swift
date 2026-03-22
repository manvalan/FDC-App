import SwiftUI

// MARK: - Common Inspector Architecture
// Componente generico per l'inspector destro, riutilizzabile per tutte le entità

struct InspectorView<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let onBack: (() -> Void)?
    let onClose: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(
                title: title,
                icon: icon,
                iconColor: iconColor,
                onBack: onBack,
                onClose: onClose
            )
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding()
            }
        }
        .background(Color.white)
    }
}

// MARK: - Inspector Header
private struct InspectorHeader: View {
    let title: String
    let icon: String
    let iconColor: Color
    let onBack: (() -> Void)?
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Circle().fill(Color.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.headline)
            
            Text(title)
                .font(.system(.headline, design: .rounded))
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Inspector Section
struct InspectorSection<Content: View>: View {
    let title: String?
    let icon: String?
    let iconColor: Color?
    @ViewBuilder let content: Content
    
    init(
        title: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(iconColor ?? .blue)
                    }
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
            }
            
            content
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Inspector Field Wrappers
struct InspectorTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct InspectorNumberField: View {
    let label: String
    @Binding var value: Double
    let unit: String
    var range: ClosedRange<Double>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                if let range = range {
                    Stepper(value: $value, in: range) {
                        Text("\(Int(value))")
                            .foregroundColor(.primary)
                    }
                } else {
                    TextField(label, value: $value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InspectorPicker<T: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: T
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Picker(label, selection: $selection) {
                content()
            }
        }
    }
}

// MARK: - Inspector Info Banner
struct InspectorInfoBanner: View {
    enum BannerType {
        case info, warning, error, success
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
    
    let type: BannerType
    let title: String?
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            VStack(alignment: .leading, spacing: 2) {
                if let title = title {
                    Text(title)
                        .font(.subheadline.bold())
                }
                Text(message)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Inspector Delete Button
struct InspectorDeleteButton: View {
    let label: String
    let onDelete: () -> Void
    @State private var showConfirmation = false
    
    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
        .alert("confirm_deletion".localized, isPresented: $showConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive, action: onDelete)
        } message: {
            Text("delete_confirm".localized)
        }
    }
}

// MARK: - Editing Mode Banner
struct EditingModeBanner: View {
    @Binding var isEditingEnabled: Bool
    @EnvironmentObject var appState: AppState
    
    // Lo stato è "sbloccato" se l'utente ha forzato l'editing O se siamo in modalità design globale
    private var isCurrentlyUnlocked: Bool {
        isEditingEnabled || appState.currentMode == .design
    }
    
    var body: some View {
        HStack {
            Image(systemName: isCurrentlyUnlocked ? "pencil.circle.fill" : "lock.fill")
                .foregroundColor(isCurrentlyUnlocked ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentlyUnlocked ? "editing_mode_active".localized : "read_only_mode".localized)
                    .font(.subheadline.bold())
                
                if !isCurrentlyUnlocked {
                    Text("long_press_to_edit".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if appState.currentMode == .design {
                    Text("Sbloccato automaticamente (Modalità Design)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background((isCurrentlyUnlocked ? Color.green : Color.orange).opacity(0.1))
        .cornerRadius(8)
    }
}
