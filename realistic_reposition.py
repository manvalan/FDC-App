import json
import math

# Using the constant from the user's project to ensure visual consistency
DEGREES_TO_KM = 111.0 

def reposition_network():
    path = "/Users/michelebigi/Documents/FdC/Rete FdC.rail"
    with open(path, 'r') as f:
        data = json.load(f)

    nodes = data['network']['nodes']
    edges = data['network']['edges']

    node_map = {n['id']: n for n in nodes}
    
    adj = {}
    for edge in edges:
        u, v = edge['from'], edge['to']
        d = edge.get('distance', 1.0)
        if u not in adj: adj[u] = []
        if v not in adj: adj[v] = []
        adj[u].append((v, d))
        adj[v].append((u, d))

    # Reference: Bywater
    start_anchor_id = "STATION_012"
    if start_anchor_id not in node_map:
        start_anchor_id = nodes[0]['id']

    # New coordinates (Arezzo-ish)
    start_lat = 43.463
    start_lon = 11.878

    new_coords = {}
    visited = set()
    all_node_ids = set(node_map.keys())
    global_offset = None

    while visited < all_node_ids:
        remaining = all_node_ids - visited
        if not visited:
            seed_id = start_anchor_id
            seed_lat, seed_lon = start_lat, start_lon
        else:
            seed_id = list(remaining)[0]
            if global_offset:
                # Maintain relative position from original grid for disconnected parts
                seed_lat = node_map[seed_id]['latitude'] + global_offset[0]
                seed_lon = node_map[seed_id]['longitude'] + global_offset[1]
            else:
                seed_lat, seed_lon = start_lat, start_lon

        new_coords[seed_id] = (seed_lat, seed_lon)
        visited.add(seed_id)
        queue = [seed_id]

        while queue:
            u_id = queue.pop(0)
            u_lat, u_lon = new_coords[u_id]
            u_grid_lat = node_map[u_id]['latitude']
            u_grid_lon = node_map[u_id]['longitude']

            if global_offset is None:
                global_offset = (u_lat - u_grid_lat, u_lon - u_grid_lon)

            if u_id not in adj: continue
            for v_id, d_km in adj[u_id]:
                if v_id in visited: continue
                
                v_grid_lat = node_map[v_id]['latitude']
                v_grid_lon = node_map[v_id]['longitude']

                # Get direction in the original grid
                dx_grid = v_grid_lon - u_grid_lon
                dy_grid = v_grid_lat - u_grid_lat
                
                mag = math.sqrt(dx_grid**2 + dy_grid**2)
                if mag == 0: 
                    ux, uy = 1.0, 0.0
                else: 
                    ux, uy = dx_grid / mag, dy_grid / mag

                # Distance to apply (exactly d_km)
                d_km_x = ux * d_km
                d_km_y = uy * d_km

                # Convert to degrees using the app's internal constant (no cosine compression)
                # This ensures that a square in KM looks like a square in the app's visualization
                delta_lat = d_km_y / DEGREES_TO_KM
                delta_lon = d_km_x / DEGREES_TO_KM

                new_v_lat = u_lat + delta_lat
                new_v_lon = u_lon + delta_lon

                new_coords[v_id] = (new_v_lat, new_v_lon)
                visited.add(v_id)
                queue.append(v_id)

    # Apply back to nodes
    for n in nodes:
        if n['id'] in new_coords:
            n['latitude'], n['longitude'] = new_coords[n['id']]

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"Repositioned {len(new_coords)} nodes using 1deg = {DEGREES_TO_KM}km factor.")

if __name__ == "__main__":
    reposition_network()
