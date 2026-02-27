# Piano di Refactoring UI - FdC Railway Manager

## Obiettivo
Ristrutturare iterativamente i file della sezione **UI (Interfaccia Utente)** analizzati, applicando rigide regole di Ingegneria del Software per migliorare manutenibilità, leggibilità e testabilità, senza interrompere mai la build del progetto.

## Le 6 Regole d'Oro di Refactoring

### 1. Complessità e Logica
- **Complessità Ciclomatica**: MAX `6` per ogni metodo/funzione. Estrazione logica in funzioni più piccole se superata.
- **Livelli di Indentazione**: MAX `2` per metodo. Utilizzo pervasivo di `guard` per early returns e happy paths.
- **Stato Immutabile**: Priorità a `let`. Eliminazione stati mutabili globali o eccessivamente condivisi.

### 2. Dimensioni File/Metodi
- **Righe per Metodo**: MAX `15` righe di codice effettivo.
- **Righe per File**: MAX `200-250` righe. Se superate, smembramento logico in nuovi file.
- **Parametri Funzione**: MAX `3`. Altrimenti introduzione di una struct (Parameter Object).

### 3. Struttura Tipi
- **Single Responsibility (SRP)**: Massimo un tipo/struttura di grandi dimensioni per file.
- **Extension**: Utilizzo di extension per adozione di Protocolli (es. equatable) separate dalla definizione base.
- **Inizializzatori Semplici**: Nessuna logica complessa negli `init`; uso di factory if needed.

### 4. Naming e Semantica
- Nomi totalmente autoesplicativi, zero commenti necessari per spiegare "il cosa fa".
- Honest Types per evitare "primitive obsession".

### 5. Costanti e Stringhe
- Magic numbers estratti in un modulo "Costanti".
- Stringhe hardcoded migrate nel sistema multilíngua usando chiavi univoche.

---

## Processo Iterativo (Safe Step-by-Step)

Per ogni singolo file UI problematico individuato (inizieremo con quelli palesemente oltre le 250 righe, come le viste di Inspector, Editor, List views):

1. **Isolamento**: Rinomina del file target originale `NomeFile.swift` in `NomeFile.swift.bak`.
2. **Ricostruzione**: Creazione del nuovo `NomeFile.swift` e degli eventuali sotto-componenti necessari (se il file superava 250 righe verranno creati i nuovi file per i componenti estratti).
3. **Verifica Checklist**: 
   - [ ] Niente scrolling essenziale per leggere le funzioni?
   - [ ] Funzioni puramente testabili?
   - [ ] Nessun costrutto mentale di $>7$ elementi richiesto al lettore?
   - [ ] Complessità $<7$?
4. **Validazione**: Compilazione build locale (su iOS Simulator target).
5. **Finalizzazione**: Se la build va a buon fine, rimozione di `NomeFile.swift.bak`.
6. **Deploy**: Esecuzione di `git add`, `git commit -m "refactor: ..."` e `git push`.

Ripetizione per il prossimo file richiesto finché il livello qualitativo generale della directory UI non risulta ottimale. 

---

## ⚠️ Lista Bug / Comportamenti da Rispettare (To-Do)
- [ ] **Menu Laterale (FloatingSideMenu)**: Il pulsante "Rete" attualmente apre l'Inspector "Relazioni" anziché l'Inspector di "Rete" (quello delle Stazioni/Binari/Linee). *Rilevato: 26/02/2026 - da sistemare al termine dei refactoring strutturali grandi.*
