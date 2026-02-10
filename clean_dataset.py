import json
import argparse
import sys
import copy
from math import radians, cos, sin, asin, sqrt

def haversine(lon1, lat1, lon2, lat2):
    """Calcola la distanza in km tra due punti (lat/lon decimali)."""
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    r = 6371 # Raggio terra in km
    return c * r

def clean_dataset(input_file, output_file):
    print(f"🚄 Apertura file dataset: {input_file}")
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Errore apertura file: {e}")
        return

    # Detection struttura (Root vs Network wrapper)
    is_wrapped = False
    
    if 'network' in data and isinstance(data['network'], dict):
        print("   📂 Rilevata struttura nidificata 'network'")
        network_root = data['network']
        is_wrapped = True
    else:
        network_root = data

    nodes = network_root.get('nodes', [])
    edges = network_root.get('edges', [])
    # Lines a volte sono fuori da network nelle versioni vecchie FDC
    lines = network_root.get('lines', []) or data.get('lines', [])
    
    print(f"📊 Statistiche Iniziali: {len(nodes)} nodi, {len(edges)} archi, {len(lines)} linee.")
    
    # 1. Mappa Nodi per accesso rapido e Validazione Coordinate
    node_map = {n['id']: n for n in nodes}
    valid_node_ids = set()
    cleaned_nodes = []
    
    for n in nodes:
        # Correzione coordinate nulle
        if n.get('latitude') is None: n['latitude'] = 0.0
        if n.get('longitude') is None: n['longitude'] = 0.0
        
        # Correzione capacità minime stazioni
        if n.get('type') == 'station' or n.get('type') == 'interchange':
            if n.get('capacity', 0) < 2:
                n['capacity'] = 2
                
        valid_node_ids.add(n['id'])
        cleaned_nodes.append(n)
        
    # 2. Pulizia Archi (Edges)
    cleaned_edges = []
    seen_edges = set()
    
    # Mappa per verificare bidirezionalità
    adjacency = {} # "A--B" -> [edge]
    
    corrections = {
        'duplicates': 0,
        'orphans': 0,
        'capacity_fixed': 0,
        'bidirectional_added': 0,
        'distance_fixed': 0
    }
    
    for e in edges:
        u, v = e.get('from'), e.get('to')
        
        # Rimuovi archi verso nodi inesistenti
        if u not in valid_node_ids or v not in valid_node_ids:
            corrections['orphans'] += 1
            # print(f"   ⚠️ Rimossso arco orfano {u} -> {v}")
            continue
            
        # Rimuovi auto-anelli
        if u == v:
            continue
            
        # Chiave univoca per duplicati esatti (direzione conta)
        edge_key = f"{u}_{v}_{e.get('trackType')}"
        if edge_key in seen_edges:
            corrections['duplicates'] += 1
            continue
        seen_edges.add(edge_key)
        
        # Normalizzazione Capacità basata su Tipo Binario
        t_type = e.get('trackType', 'single')
        current_cap = e.get('capacity', 1)
        new_cap = current_cap
        
        if t_type == 'single':
            new_cap = 1
        elif t_type == 'double':
            new_cap = 2
        elif t_type == 'highSpeed':
            new_cap = 2 # Almeno 2 per AV
            
        if new_cap != current_cap:
            e['capacity'] = new_cap
            corrections['capacity_fixed'] += 1
            
        # Ricalcolo distanza se mancante o <= 0
        dist = e.get('distance', 0)
        if dist <= 0.001:
            n1, n2 = node_map[u], node_map[v]
            calc_dist = haversine(n1['longitude'], n1['latitude'], n2['longitude'], n2['latitude'])
            e['distance'] = round(max(calc_dist, 1.0), 3) # Minimo 1km per stabilità
            corrections['distance_fixed'] += 1
            
        cleaned_edges.append(e)
        
        # Registra per controllo bidirezionalità
        pair_key = tuple(sorted((u, v)))
        if pair_key not in adjacency: adjacency[pair_key] = []
        adjacency[pair_key].append(e)

    # 3. Verifica Bidirezionalità (Per ogni binario fisico deve esserci andata e ritorno)
    final_edges = list(cleaned_edges)
    
    for (u, v), arc_list in adjacency.items():
        has_forward = any(e['from'] == u and e['to'] == v for e in arc_list)
        has_backward = any(e['from'] == v and e['to'] == u for e in arc_list)
        
        if has_forward and not has_backward:
            # Crea backward mancante copiando il forward
            ref = next(e for e in arc_list if e['from'] == u)
            new_edge = copy.deepcopy(ref)
            new_edge['id'] = str(hash(f"{v}_{u}_{ref['id']}")) # ID temporaneo
            new_edge['from'] = v
            new_edge['to'] = u
            final_edges.append(new_edge)
            corrections['bidirectional_added'] += 1
            
        elif has_backward and not has_forward:
            # Crea forward mancante
            ref = next(e for e in arc_list if e['from'] == v)
            new_edge = copy.deepcopy(ref)
            new_edge['id'] = str(hash(f"{u}_{v}_{ref['id']}"))
            new_edge['from'] = u
            new_edge['to'] = v
            final_edges.append(new_edge)
            corrections['bidirectional_added'] += 1

    # 4. Pulizia Linee (Rimuovi stazioni non più esistenti)
    cleaned_lines = []
    for line in lines:
        original_stops = line.get('stations', [])
        valid_stops = [s for s in original_stops if s in valid_node_ids]
        if len(valid_stops) >= 2:
            line['stations'] = valid_stops
            cleaned_lines.append(line)

    # 5. Aggiorna Struttura Dati (DOPO calcolo)
    if is_wrapped:
        data['network']['nodes'] = cleaned_nodes
        data['network']['edges'] = final_edges
        # Se le linee erano dentro network, aggiornale lì
        if 'lines' in data['network']:
             data['network']['lines'] = cleaned_lines
        elif 'lines' in data: # Se erano fuori, tienile fuori
             data['lines'] = cleaned_lines
        else: # Default dentro network per il futuro
             data['network']['lines'] = cleaned_lines
    else:
        data['nodes'] = cleaned_nodes
        data['edges'] = final_edges
        data['lines'] = cleaned_lines
    
    print("-" * 40)
    print(f"✅ Pulizia Completata:")
    print(f"   - Archi Duplicati Rimossi: {corrections['duplicates']}")
    print(f"   - Archi Orfani Rimossi:    {corrections['orphans']}")
    print(f"   - Capacità Corrette:       {corrections['capacity_fixed']}")
    print(f"   - Distanze Ricalcolate:    {corrections['distance_fixed']}")
    print(f"   - Archi Ritorno Creati:    {corrections['bidirectional_added']}")
    print("-" * 40)
    print(f"📊 Statistiche Finali: {len(cleaned_nodes)} nodi, {len(final_edges)} archi, {len(cleaned_lines)} linee.")
    
    # Salvataggio
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"💾 File salvato con successo: {output_file}")
    except Exception as e:
        print(f"❌ Errore salvataggio: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FdC Railway Network Cleaner")
    parser.add_argument("input", help="Percorso del file .rail/.json/.fdc da pulire")
    parser.add_argument("--output", "-o", help="Percorso file di output (default: input_cleaned.json)")
    
    args = parser.parse_args()
    
    out_path = args.output
    if not out_path:
        parts = args.input.rsplit('.', 1)
        if len(parts) > 1:
            out_path = f"{parts[0]}_cleaned.{parts[1]}"
        else:
            out_path = f"{args.input}_cleaned.json"
            
    clean_dataset(args.input, out_path)
