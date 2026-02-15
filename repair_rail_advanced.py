import json
import numpy as np
import math

def repair_with_compression():
    path = "/Users/michelebigi/Documents/FdC/Rete FdC.rail"
    with open(path, 'r') as f:
        data = json.load(f)

    nodes = data['network']['nodes']
    edges = data['network']['edges']
    
    # Constants for 43 degrees North
    LAT_REF = 43.0
    # 1 degree of latitude is always about 111.12 km
    KM_PER_DEG_LAT = 111.12
    # 1 degree of longitude depends on latitude: 111.32 * cos(lat)
    KM_PER_DEG_LON = 111.321 * math.cos(math.radians(LAT_REF))
    
    print(f"Using scale: 1deg Lat = {KM_PER_DEG_LAT:.2f} km, 1deg Lon = {KM_PER_DEG_LON:.2f} km (at {LAT_REF}N)")

    node_ids = [n['id'] for n in nodes]
    id_to_idx = {id: i for i, id in enumerate(node_ids)}
    
    # Initialize positions
    pos = np.zeros((len(nodes), 2))
    for i, n in enumerate(nodes):
        # Prefer existing valid coordinates if they aren't NaN
        if n.get('longitude') is not None and not np.isnan(n['longitude']) and n['longitude'] != 0:
            pos[i] = [n['longitude'], n['latitude']]
        else:
            # Fallback to a starting grid or random
            pos[i] = [11.0 + np.random.uniform(-0.5, 0.5), 43.0 + np.random.uniform(-0.5, 0.5)]

    # Constraints
    edge_constraints = []
    for e in edges:
        u = id_to_idx.get(e['from'])
        v = id_to_idx.get(e['to'])
        d_target = e.get('distance', 0)
        if u is not None and v is not None and u != v and d_target > 0:
            edge_constraints.append((u, v, d_target))

    # Optimizer (Force-directed with ellipsoidal geometry)
    lr = 0.0005
    for epoch in range(15000):
        grad = np.zeros_like(pos)
        mse = 0
        for u, v, d_target in edge_constraints:
            # Vector in degrees
            diff_deg = pos[u] - pos[v]
            # Vector in KM (applying compression to Lon)
            diff_km = diff_deg * np.array([KM_PER_DEG_LON, KM_PER_DEG_LAT])
            
            dist_km = np.linalg.norm(diff_km)
            
            if dist_km > 1e-9:
                error = dist_km - d_target
                mse += error**2
                
                # Gradient component (delta_dist / delta_coord)
                # We need to pull/push based on the KM error but update the degree coordinates
                force_km = (error / dist_km) * diff_km
                # Translate KM force back to Degree gradient
                grad_deg = force_km * np.array([KM_PER_DEG_LON, KM_PER_DEG_LAT])
                
                grad[u] += grad_deg
                grad[v] -= grad_deg
            else:
                grad[u] += np.random.randn(2) * 0.001
        
        # Clip
        gnorm = np.linalg.norm(grad)
        if gnorm > 10.0:
            grad = (grad / gnorm) * 10.0
            
        pos -= lr * grad
        if epoch % 3000 == 0:
            rmse_km = np.sqrt(mse / len(edge_constraints))
            print(f"Epoch {epoch:5d} | RMSE: {rmse_km:.6f} km")

    # Final update
    for i, n in enumerate(nodes):
        n['longitude'] = round(float(pos[i, 0]), 8)
        n['latitude'] = round(float(pos[i, 1]), 8)

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print("Optimization complete with longitude compression at 43N.")

if __name__ == "__main__":
    repair_with_compression()
