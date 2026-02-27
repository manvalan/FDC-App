from pbxproj import XcodeProject

project_path = 'FdC Railway Manager.xcodeproj/project.pbxproj'
project = XcodeProject.load(project_path)

# Troviamo e rimuoviamo l'istanza di RailwayMapView.swift che non ha il prefisso UI/Views
for file_id in project.get_files_by_name('RailwayMapView.swift'):
    file_ref = project.objects[file_id]
    
    # In pbxproj, gli attributi si assettano come dizionario se non sono proprietà dirette
    path = file_ref.get('path', '')
    
    if 'UI/Views/RailwayMap' not in path and path != 'FdC Railway Manager/UI/Views/RailwayMap/RailwayMapView.swift':
        print(f"Rimuovo file_id: {file_id} con path {path}")
        project.remove_file_by_id(file_id)

project.save()
print("Pulizia terminata.")
