import SwiftUI

/// Sistema per assegnare automaticamente colori alle linee ferroviarie
/// Assegna colori simili a linee con caratteristiche simili
class LineColorAssigner {
    
    /// Palette di colori distinti per linee
    static let distinctColors: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink,
        .yellow, .cyan, .mint, .indigo, .teal, .brown
    ]
    
    /// Palette di colori per linee ad alta velocità (tonalità rosse)
    static let highSpeedColors: [Color] = [
        Color(hex: "#DC143C")!, // Crimson
        Color(hex: "#FF1744")!, // Red Accent
        Color(hex: "#D32F2F")!, // Dark Red
        Color(hex: "#C62828")!, // Darker Red
        Color(hex: "#B71C1C")!, // Deep Red
    ]
    
    /// Palette di colori per linee dirette/interregionali (tonalità arancioni)
    static let directColors: [Color] = [
        Color(hex: "#FF6F00")!, // Dark Orange
        Color(hex: "#FF8F00")!, // Orange
        Color(hex: "#F57C00")!, // Deep Orange
        Color(hex: "#E65100")!, // Darker Orange
        Color(hex: "#FF5722")!, // Orange Red
    ]
    
    /// Palette di colori per linee regionali (tonalità verdi/blu)
    static let regionalColors: [Color] = [
        Color(hex: "#2E7D32")!, // Green
        Color(hex: "#388E3C")!, // Light Green
        Color(hex: "#43A047")!, // Lighter Green
        Color(hex: "#1976D2")!, // Blue
        Color(hex: "#1565C0")!, // Dark Blue
        Color(hex: "#0D47A1")!, // Deeper Blue
        Color(hex: "#00838F")!, // Cyan
        Color(hex: "#006064")!, // Dark Cyan
    ]
    
    /// Palette di colori per linee merci (tonalità marroni/grigie)
    static let freightColors: [Color] = [
        Color(hex: "#5D4037")!, // Brown
        Color(hex: "#4E342E")!, // Dark Brown
        Color(hex: "#3E2723")!, // Darker Brown
        Color(hex: "#616161")!, // Grey
        Color(hex: "#424242")!, // Dark Grey
    ]
    
    /// Assegna automaticamente colori a tutte le linee
    /// - Parameter lines: Array di linee da colorare
    /// - Returns: Array di linee con colori assegnati
    static func assignColors(to lines: [RailwayLine]) -> [RailwayLine] {
        var updatedLines = lines
        
        // Raggruppa linee per tipologia (basandosi sul nome o sul prefisso)
        let highSpeedLines = lines.filter { isHighSpeed($0) }
        let directLines = lines.filter { isDirect($0) }
        let regionalLines = lines.filter { isRegional($0) }
        let freightLines = lines.filter { isFreight($0) }
        let otherLines = lines.filter { !isHighSpeed($0) && !isDirect($0) && !isRegional($0) && !isFreight($0) }
        
        // Assegna colori per ogni gruppo
        assignColorsToGroup(&updatedLines, lines: highSpeedLines, colors: highSpeedColors)
        assignColorsToGroup(&updatedLines, lines: directLines, colors: directColors)
        assignColorsToGroup(&updatedLines, lines: regionalLines, colors: regionalColors)
        assignColorsToGroup(&updatedLines, lines: freightLines, colors: freightColors)
        assignColorsToGroup(&updatedLines, lines: otherLines, colors: distinctColors)
        
        return updatedLines
    }
    
    /// Assegna colori a un gruppo di linee
    private static func assignColorsToGroup(_ allLines: inout [RailwayLine], lines: [RailwayLine], colors: [Color]) {
        for (index, line) in lines.enumerated() {
            guard let lineIndex = allLines.firstIndex(where: { $0.id == line.id }) else { continue }
            
            let colorIndex = index % colors.count
            let color = colors[colorIndex]
            
            // Converti il colore in formato hex
            if let hexColor = color.toHex() {
                allLines[lineIndex].color = hexColor
            }
        }
    }
    
    /// Determina se una linea è ad alta velocità
    private static func isHighSpeed(_ line: RailwayLine) -> Bool {
        let name = line.name.lowercased()
        let code = line.codePrefix?.lowercased() ?? ""
        
        return name.contains("av") ||
               name.contains("alta velocità") ||
               name.contains("alta velocita") ||
               name.contains("frecciarossa") ||
               name.contains("freccia rossa") ||
               code.contains("av") ||
               code.contains("fr")
    }
    
    /// Determina se una linea è diretta/interregionale
    private static func isDirect(_ line: RailwayLine) -> Bool {
        let name = line.name.lowercased()
        let code = line.codePrefix?.lowercased() ?? ""
        
        return name.contains("intercity") ||
               name.contains("ic") ||
               name.contains("diretto") ||
               name.contains("dirett") ||
               name.contains("frecciargento") ||
               name.contains("freccia argento") ||
               name.contains("interregionale") ||
               code.contains("ic") ||
               code.contains("ir") ||
               code.contains("fa")
    }
    
    /// Determina se una linea è regionale
    private static func isRegional(_ line: RailwayLine) -> Bool {
        let name = line.name.lowercased()
        let code = line.codePrefix?.lowercased() ?? ""
        
        return name.contains("regional") ||
               name.contains("regionale") ||
               name.contains("metropolitana") ||
               name.contains("suburbana") ||
               name.contains("locale") ||
               code.contains("r") ||
               code.contains("rv") ||
               code.contains("re") ||
               code.contains("s") // S-Bahn style
    }
    
    /// Determina se una linea è merci
    private static func isFreight(_ line: RailwayLine) -> Bool {
        let name = line.name.lowercased()
        let code = line.codePrefix?.lowercased() ?? ""
        
        return name.contains("merci") ||
               name.contains("cargo") ||
               name.contains("freight") ||
               code.contains("m") ||
               code.contains("cargo")
    }
    
    /// Genera una variazione di colore per linee simili
    /// - Parameters:
    ///   - baseColor: Colore base
    ///   - variation: Indice di variazione (0, 1, 2...)
    /// - Returns: Colore variato
    static func varyColor(_ baseColor: Color, variation: Int) -> Color {
        guard let components = UIColor(baseColor).cgColor.components, components.count >= 3 else {
            return baseColor
        }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Applica una leggera variazione basata sull'indice
        let factor = 1.0 + (Double(variation) * 0.1) // 10% di variazione per ogni step
        let newR = min(1.0, r * factor)
        let newG = min(1.0, g * factor)
        let newB = min(1.0, b * factor)
        
        return Color(red: newR, green: newG, blue: newB)
    }
    
    /// Assegna colori distinguibili quando ci sono troppe linee dello stesso tipo
    static func assignDistinguishableColors(to lines: [RailwayLine], existingColors: Set<String>) -> [RailwayLine] {
        var updatedLines = lines
        var usedColors = existingColors
        
        for index in 0..<updatedLines.count {
            // Cerca un colore non ancora usato
            for color in distinctColors {
                if let hexColor = color.toHex(), !usedColors.contains(hexColor) {
                    updatedLines[index].color = hexColor
                    usedColors.insert(hexColor)
                    break
                }
            }
        }
        
        return updatedLines
    }
}
