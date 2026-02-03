import json
import urllib.request
import urllib.parse
import math
import sys
import uuid
import time

# Configurazione
FILENAME = "ToscanaLiguria_Completa.rail"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Query
QUERY = """
[out:json][timeout:180];
(area(3600041977);area(3600041854);)->.searchArea;
relation["route"~"train|railway"](area.searchArea)->.rels;
.rels out;
node(r.rels)->.nodesOfRels;
.nodesOfRels out;
node["railway"~"station|halt|stop"](area.searchArea);
out;
"""

def scarica_dati_overpass():
    print("Interrogazione Overpass API in corso (attendere)...")
    try:
        data = urllib.parse.urlencode({'data': QUERY}).encode('utf-8')
        req = urllib.request.Request(OVERPASS_URL, data=data)
        with urllib.request.urlopen(req) as response:
            return json.load(response)
    except Exception as e:
        print(f"Errore Overpass: {e}")
        sys.exit(1)

def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def main():
    print("Elaborazione dati per formato FDC Parse (Snake Case)...")
    osm_data = scarica_dati_overpass()
    elements = osm_data.get('elements', [])
    
    nodes_db = {}
    relations = []
    
    for el in elements:
        if el['type'] == 'node':
            nodes_db[el['id']] = el
        elif el['type'] == 'relation':
            relations.append(el)

    print(f"Dataset: {len(nodes_db)} nodi, {len(relations)} relazioni.")

    # 1. Stazioni (FDCNodeData)
    # id, name, type, latitude, longitude, platform_count, capacity
    fdc_nodes = {} 
    
    def make_node(el):
        tags = el.get('tags', {})
        nid = str(el['id'])
        name = tags.get('name', tags.get('ref', f"Stop {nid}"))
        name = name.replace("Stazione di ", "").replace("Stazione ", "")
        
        ntype = "station"
        if any(x in name for x in ["Centrale", "S.M.N.", "P.P.", "Porta"]): ntype = "interchange"
        
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
    # FDCLineData: id, name, color, stations
    # FDCEdgeData: from_node, to_node, distance, track_type, max_speed, bidirectional
    
    output_edges = [] # List of FDCEdgeData dicts
    output_lines = [] # List of FDCLineData dicts
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
                    if 'name' in el.get('tags', {}) or m.get('role') in ['stop', 'platform', 'station']:
                         new = make_node(el)
                         fdc_nodes[mid] = new
                         current_stops.append(mid)
        
        if not current_stops: continue
        
        unique = [current_stops[0]]
        for s in current_stops[1:]:
            if s != unique[-1]: unique.append(s)
        
        if len(unique) < 2: continue
        
        # Create FDC Line
        output_lines.append({
            "id": f"L_{rel['id']}",
            "name": route_name,
            "color": "#FF0000" if "Frec" in route_name else "#0000FF",
            "stations": unique
        })
        
        # Create Edges
        for i in range(len(unique) - 1):
            u, v = unique[i], unique[i+1]
            k = tuple(sorted((u, v)))
            if k in existing_edges: continue
            existing_edges.add(k)
            
            n1 = nodes_db[int(u)]
            n2 = nodes_db[int(v)]
            dist = haversine_km(n1['lat'], n1['lon'], n2['lat'], n2['lon']) * 1.2
            
            ttype = "double" if "Frec" in route_name or "IC" in route_name else "single"
            max_s = 250.0 if "Frec" in route_name else 140.0
            
            output_edges.append({
                "from_node": u,
                "to_node": v,
                "distance": max(0.5, round(dist, 2)),
                "track_type": ttype,
                "max_speed": max_s,
                "bidirectional": True,
                "capacity": 10
            })

    print(f"Risultato: {len(output_lines)} linee, {len(output_edges)} segmenti, {len(fdc_nodes)} stazioni.")
    
    # Root Structure (FDCFileRoot)
    final_output = {
        "network": {
            "nodes": list(fdc_nodes.values()),
            "edges": output_edges
        },
        "trains": [],   # FDCTrainData
        "lines": output_lines,
        "schedules": [] # FDCScheduleData
    }
    
    with open(FILENAME, 'w') as f:
        json.dump(final_output, f, indent=2)
    print(f"Salvato in {FILENAME} (Formato FDC Compatibile)")

if __name__ == "__main__":
    main()
