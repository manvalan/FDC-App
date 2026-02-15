import json

def restore_geometry():
    ref_path = "/Users/michelebigi/Documents/FdC/FDC.rail"
    target_path = "/Users/michelebigi/Documents/FdC/Rete FdC.rail"
    
    print(f"Reading reference geometry from {ref_path}")
    with open(ref_path, 'r') as f:
        ref_data = json.load(f)
    
    print(f"Reading target file to repair: {target_path}")
    with open(target_path, 'r') as f:
        target_data = json.load(f)
    
    # Map node IDs to coordinates from reference
    coord_map = {}
    for node in ref_data['network']['nodes']:
        coord_map[node['id']] = {
            'lat': node.get('latitude'),
            'lon': node.get('longitude')
        }
    
    # Update target nodes
    updated_count = 0
    for node in target_data['network']['nodes']:
        node_id = node['id']
        if node_id in coord_map:
            node['latitude'] = coord_map[node_id]['lat']
            node['longitude'] = coord_map[node_id]['lon']
            updated_count += 1
        else:
            print(f"Warning: Node {node_id} not found in reference geometry.")
    
    print(f"Updated coordinates for {updated_count} nodes.")
    
    # Save back
    with open(target_path, 'w') as f:
        json.dump(target_data, f, indent=2)
    
    print("Restore complete.")

if __name__ == "__main__":
    restore_geometry()
