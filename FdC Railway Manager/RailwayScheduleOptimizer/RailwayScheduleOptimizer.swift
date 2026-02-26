import Foundation
import SwiftUI
import Combine // Required for Publisher bridge

/// 🚂 **RailwayScheduleOptimizer**
///
/// Questa classe gestisce la pipeline completa di generazione e ottimizzazione degli orari ferroviari.
/// Segue un processo rigoroso a 7 step per garantire la massima stabilità e il minimo numero di conflitti
/// prima ancora di interpellare l'AI o l'utente.
///
/// **Pipeline Logic:**
/// 1. Ottimizzazione Orari Partenza (Shift Temporale)
/// 2. Generazione Orario Base
/// 3. Analisi Criticità (Hotspot Detection)
/// 4. Risoluzione Conflitti CTC
/// 5. Hybrid Cloud AI
/// 6. Genetic Algorithm Refinement
final class RailwayScheduleOptimizer {
    
    // Singleton pattern per accesso facile, ma può essere istanziato
    static let shared = RailwayScheduleOptimizer()
    
    let conflictManager = ConflictManager()
    let aiService = RailwayAIService.shared
    let geneticOptimizer = GeneticOptimizer() // Assumendo che sia adattabile o stateless
    let returnStartNumber = 1
    
    /// Esegue l'intera pipeline di ottimizzazione.
    /// - Parameters:
    ///   - newTrains: I treni appena generati (Andata + Ritorno)
    ///   - existingTrains: I treni già presenti nel sistema (immutabili)
    ///   - network: La rete ferroviaria
    ///   - useAI: Flag per abilitare l'AI Cloud
    /// - Returns: La lista di treni ottimizzati pronti per l'inserimento
    /// Esegue l'intera pipeline di ottimizzazione.
    /// - Parameters:
    ///   - newTrains: I treni appena generati (Andata + Ritorno)
    ///   - existingTrains: I treni già presenti nel sistema (immutabili)
    ///   - network: La rete ferroviaria
    ///   - useAI: Flag per abilitare l'AI Cloud
    ///   - geneticOptimizer: Opzionale. Se passato, viene usato questo oggetto (utile per aggiornare la UI progress).
    /// - Returns: La lista di treni ottimizzati pronti per l'inserimento
    func executePipeline(
        newTrains: [RailwayTrain],
        existingTrains: [RailwayTrain],
        nodes: [RailwayNode],
        edges: [Edge],
        useAI: Bool = true,
        useGA: Bool = true,
        geneticOptimizer: GeneticOptimizer? = nil,
        preferredTaktNodeId: String? = nil
    ) async -> [RailwayTrain] {
        if Task.isCancelled { 
            print("⚠️ [PIPELINE] Task cancellata all'avvio!")
            return newTrains 
        }
        var localPathCache: [String: [Edge]] = [:] 
        let hasTaktRequired = nodes.contains(where: { (node: RailwayNode) in node.taktMinutes != nil })
        
        // 🛡️ BLINDATURA TAKT: forza GA=false quando Takt è attivo.
        // Nessuna ottimizzazione genetica deve alterare gli orari cadenzati.
        let effectiveUseGA: Bool
        if hasTaktRequired {
            effectiveUseGA = false
            if useGA {
                print("🛡️ [PIPELINE] BLINDATURA TAKT: GA forzatamente disabilitato (hasTaktRequired=true)")
            }
        } else {
            effectiveUseGA = useGA
        }
        
        logPipelineInit(newTrains: newTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, useAI: useAI, useGA: effectiveUseGA)

        // --- STEP 1: Time Optimization ---
        var workingTrains = await runStep1_TimeOptimization(
            newTrains: newTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useGA: effectiveUseGA, 
            hasTaktRequired: hasTaktRequired, 
            pathCache: &localPathCache
        )
        
        // --- STEP 2: Physical Refresh ---
        workingTrains = await runStep2_PhysicalRefresh(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            preferredTaktNodeId: preferredTaktNodeId,
            pathCache: &localPathCache
        )
        
        // --- STEP 3-5: Optimization & Takt Alignment ---
        workingTrains = await runStep3_5_Alignment(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            hasTaktRequired: hasTaktRequired, 
            preferredTaktNodeId: preferredTaktNodeId, 
            pathCache: &localPathCache
        )
        
        // --- STEP 6: AI Cloud Optimization ---
        workingTrains = await runStep6_AIOptimization(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useAI: useAI, 
            hasTaktRequired: hasTaktRequired, 
            preferredTaktNodeId: preferredTaktNodeId,
            pathCache: &localPathCache
        )
        
        // --- STEP 7: Genetic Refinement ---
        var finalTrains = await runStep7_GeneticRefinement(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useGA: effectiveUseGA, 
            hasTaktRequired: hasTaktRequired, 
            preferredTaktNodeId: preferredTaktNodeId,
            pathCache: &localPathCache,
            geneticOptimizer: geneticOptimizer
        )
        
        // --- STEP 8: Final Verification & Reporting ---
        return await runStep8_FinalVerification(
            finalTrains: finalTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            hasTaktRequired: hasTaktRequired, 
            preferredTaktNodeId: preferredTaktNodeId,
            pathCache: &localPathCache
        )
    }


}
