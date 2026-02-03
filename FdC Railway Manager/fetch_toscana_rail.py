import json
import urllib.request
import urllib.parse
import math
import sys
import uuid
import time

# Configurazione
# Configurazione
FILENAME = "Toscana.rail"
OVERPASS_URL = "https://lz4.overpass-api.de/api/interpreter"

# Queries separate per evitare timeout
QUERIES = [
    # 1. Toscana (Espande a La Spezia/Roma tramite relazioni)
    """
    [out:json][timeout:300];
    area(3600041977)->.searchArea;
    relation["route"="train"](area.searchArea)->.rels;
    .rels out;
    node(r.rels)->.nodesOfRels;
    node.nodesOfRels["railway"~"station|halt|stop"]->.stations;
    .stations out;
    """
]

def scarica_dati_overpass(query_str):
    print("  -> Invio richiesta Overpass...")
    try:
        data = urllib.parse.urlencode({'data': query_str}).encode('utf-8')
        req = urllib.request.Request(OVERPASS_URL, data=data)
        with urllib.request.urlopen(req, timeout=300) as response:
            return json.load(response)
    except Exception as e:
        print(f"  -> Errore Overpass: {e}")
        return None

def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def main():
    print("Elaborazione dati per formato FDC (Multi-Region)...")
    
    all_elements = []
    seen_ids = set()
    
    for i, q in enumerate(QUERIES):
        print(f"Scaricando blocco {i+1}/{len(QUERIES)}...")
        res = scarica_dati_overpass(q)
        if res and 'elements' in res:
            count = 0
            for el in res['elements']:
                if el['id'] not in seen_ids:
                    all_elements.append(el)
                    seen_ids.add(el['id'])
                    count += 1
            print(f"  -> Aggiunti {count} elementi.")
        else:
            print("  -> Nessun dato o errore.")
            if i == 0: # Se fallisce il blocco principale
                print("Impossibile procedere senza il blocco principale.")
                sys.exit(1)
        time.sleep(2)

    nodes_db = {}
    relations = []
    
    for el in all_elements:
        if el['type'] == 'node':
            nodes_db[el['id']] = el
        elif el['type'] == 'relation':
            relations.append(el)

    print(f"Totale Dataset: {len(nodes_db)} nodi, {len(relations)} relazioni.")

    # 1. Stazioni (FDCNodeData)
    fdc_nodes = {} 
    
    def make_node(el):
        tags = el.get('tags', {})
        nid = str(el['id'])
        name = tags.get('name', tags.get('ref', f"Stop {nid}"))
        name = name.replace("Stazione di ", "").replace("Stazione ", "")
        
        ntype = "station"
        # Logica semplice per identificare nodi importanti
        if any(x in name for x in ["Centrale", "S.M.N.", "P.P.", "Porta", "Bologna", "Genova", "Pisa", "Firenze"]): 
            ntype = "interchange"
        
        return {
            "id": nid,
            "name": name,
            "type": ntype,
            "latitude": el['lat'],
            "longitude": el['lon'],
            "platform_count": 10 if ntype == "interchange" else 2,
            "capacity": 20 if ntype == "interchange" else 5
        }

    for nid, el in nodes_db.items():
        tags = el.get('tags', {})
        if 'railway' in tags and tags['railway'] in ['station', 'halt', 'stop']:
            fdc_nodes[str(nid)] = make_node(el)

    # 2. Linee (FDCLineData) e Edges (FDCEdgeData)
    
    output_edges = [] 
    output_lines = [] 
    existing_edges = set()
    
    for rel in relations:
        tags = rel.get('tags', {})
        route_name = tags.get('name', tags.get('ref', 'Linea'))
        
        members = rel.get('members', [])
        current_stops = []
        
        for m in members:
            if m['type'] == 'node':
                mid = str(m['ref'])
                if mid in fdc_nodes:
                    current_stops.append(mid)
                elif mid in nodes_db:
                    el = nodes_db[int(mid)]
                    # Se è un nodo che fa parte della relazione ma non taggato come stazione esplicitamente,
                    # lo promuoviamo se ha un nome o ruolo 'stop'
                    if 'name' in el.get('tags', {}) or m.get('role') in ['stop', 'platform', 'station']:
                         new = make_node(el)
                         fdc_nodes[mid] = new
                         current_stops.append(mid)
        
        if not current_stops: continue
        
        # Filtra duplicati consecutivi
        unique = [current_stops[0]]
        for s in current_stops[1:]:
            if s != unique[-1]: unique.append(s)
        
        if len(unique) < 2: continue
        
        # Create FDC Line
        color = "#0000FF"
        if "Frec" in route_name: color = "#FF0000"
        elif "IC" in route_name: color = "#FFA500"
        
        output_lines.append({
            "id": f"L_{rel['id']}",
            "name": route_name,
            "color": color,
            "stops": [{"stationId": s, "minDwellTime": 3} for s in unique]
        })
        
        # Create Edges
        for i in range(len(unique) - 1):
            u, v = unique[i], unique[i+1]
            k = tuple(sorted((u, v)))
            if k in existing_edges: continue
            existing_edges.add(k)
            
            if int(u) not in nodes_db or int(v) not in nodes_db: continue
            
            n1 = nodes_db[int(u)]
            n2 = nodes_db[int(v)]
            dist = haversine_km(n1['lat'], n1['lon'], n2['lat'], n2['lon']) * 1.25 # Fattore correzione binario curvo
            
            ttype = "single"
            max_s = 140.0
            
            if "Frec" in route_name:
                ttype = "highSpeed"
                max_s = 250.0
            elif "IC" in route_name or "Direttissima" in route_name:
                ttype = "double"
                max_s = 180.0
            elif "Tirrenica" in route_name:
                ttype = "double"
            
            output_edges.append({
                "from": u,
                "to": v,
                "distance": max(0.5, round(dist, 2)),
                "trackType": ttype,
                "maxSpeed": int(max_s),
                "capacity": 10
            })

    print(f"Risultato: {len(output_lines)} linee, {len(output_edges)} segmenti, {len(fdc_nodes)} stazioni.")
    
    # Root Structure (RailwayNetworkDTO for .rail)
    final_output = {
        "name": "Toscana",
        "nodes": list(fdc_nodes.values()),
        "edges": output_edges,
        "lines": output_lines,
        "trains": []
    }
    
    with open(FILENAME, 'w') as f:
        json.dump(final_output, f, indent=2)
    print(f"Salvato in {FILENAME} (Formato FDC Compatibile)")

if __name__ == "__main__":
    main()
