import SwiftUI

/// Sistema per assegnare automaticamente colori alle linee ferroviarie
/// Assegna colori simili a linee con caratteristiche simili
class LineColorAssigner {
    
    /// Palette di colori distinti ottimizzata per massima leggibilità
    /// Colori scelti per essere ben distinguibili anche quando sovrapposti
    static let distinctColors: [Color] = [
        Color(hex: "#E53935")!,  // Rosso intenso
        Color(hex: "#1E88E5")!,  // Blu oceano
        Color(hex: "#43A047")!,  // Verde bosco
        Color(hex: "#FB8C00")!,  // Arancione
        Color(hex: "#8E24AA")!,  // Viola
        Color(hex: "#00ACC1")!,  // Ciano
        Color(hex: "#D81B60")!,  // Rosa fucsia
        Color(hex: "#FDD835")!,  // Giallo oro
        Color(hex: "#3949AB")!,  // Indaco
        Color(hex: "#00897B")!,  // Verde acqua (teal)
        Color(hex: "#F4511E")!,  // Rosso arancio
        Color(hex: "#6D4C41")!,  // Marrone
        Color(hex: "#5E35B1")!,  // Viola profondo
        Color(hex: "#C0CA33")!,  // Verde lime
        Color(hex: "#00BFA5")!,  // Turchese
        Color(hex: "#FF6F00")!,  // Arancione scuro
        Color(hex: "#7CB342")!,  // Verde chiaro
        Color(hex: "#1565C0")!,  // Blu profondo
        Color(hex: "#AD1457")!,  // Magenta
        Color(hex: "#FFB300")!   // Ambra
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

    /// Assegna colori intelligentemente evitando colori simili per linee che si incrociano
    /// - Parameters:
    ///   - lines: Array di linee da colorare
    ///   - network: Network model per analizzare le intersezioni
    /// - Returns: Array di linee con colori ottimizzati
    static func assignSmartColors(to lines: [RailwayLine], in network: RailwayNetwork) -> [RailwayLine] {
        guard !lines.isEmpty else { return lines }

        var updatedLines = lines
        var lineColorMap: [String: Color] = [:]

        // Crea grafo di adiacenza (linee che condividono stazioni)
        var adjacencyMap: [String: Set<String>] = [:]
        for line in lines {
            adjacencyMap[line.id] = Set<String>()
        }

        // Trova linee adiacenti (che condividono almeno una stazione)
        for i in 0..<lines.count {
            for j in (i+1)..<lines.count {
                let line1 = lines[i]
                let line2 = lines[j]

                let stations1 = Set(line1.stops.map { $0.stationId })
                let stations2 = Set(line2.stops.map { $0.stationId })

                if !stations1.intersection(stations2).isEmpty {
                    adjacencyMap[line1.id]?.insert(line2.id)
                    adjacencyMap[line2.id]?.insert(line1.id)
                }
            }
        }

        // Ordina linee per numero di adiacenze (linee più connesse per prime)
        let sortedLines = lines.sorted { line1, line2 in
            let adj1 = adjacencyMap[line1.id]?.count ?? 0
            let adj2 = adjacencyMap[line2.id]?.count ?? 0
            return adj1 > adj2
        }

        // Assegna colori usando algoritmo greedy con massimo contrasto
        for line in sortedLines {
            let adjacentLineIds = adjacencyMap[line.id] ?? Set<String>()
            let adjacentColors = adjacentLineIds.compactMap { lineColorMap[$0] }

            // Trova il colore con massima distanza dai colori adiacenti
            let bestColor = findBestColor(avoiding: adjacentColors, from: distinctColors)
            lineColorMap[line.id] = bestColor

            // Applica il colore alla linea
            if let index = updatedLines.firstIndex(where: { $0.id == line.id }),
               let hexColor = bestColor.toHex() {
                updatedLines[index].color = hexColor
            }
        }

        return updatedLines
    }

    /// Trova il miglior colore che massimizza la distanza dai colori da evitare
    private static func findBestColor(avoiding colorsToAvoid: [Color], from palette: [Color]) -> Color {
        guard !colorsToAvoid.isEmpty else {
            return palette.first ?? .blue
        }

        var bestColor = palette[0]
        var maxMinDistance = 0.0

        for candidateColor in palette {
            // Calcola la distanza minima da tutti i colori da evitare
            var minDistance = Double.infinity

            for avoidColor in colorsToAvoid {
                let distance = colorDistance(candidateColor, avoidColor)
                minDistance = min(minDistance, distance)
            }

            // Scegli il colore con la massima distanza minima
            if minDistance > maxMinDistance {
                maxMinDistance = minDistance
                bestColor = candidateColor
            }
        }

        return bestColor
    }

    /// Calcola la distanza euclidea tra due colori nello spazio RGB
    private static func colorDistance(_ color1: Color, _ color2: Color) -> Double {
        guard let components1 = UIColor(color1).cgColor.components,
              let components2 = UIColor(color2).cgColor.components,
              components1.count >= 3,
              components2.count >= 3 else {
            return 0.0
        }

        let r1 = components1[0]
        let g1 = components1[1]
        let b1 = components1[2]

        let r2 = components2[0]
        let g2 = components2[1]
        let b2 = components2[2]

        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2

        return sqrt(dr*dr + dg*dg + db*db)
    }
}
