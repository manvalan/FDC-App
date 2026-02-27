from pbxproj import XcodeProject

project_path = 'FdC Railway Manager.xcodeproj/project.pbxproj'
project = XcodeProject.load(project_path)

# Trova e rimuovi il vecchio RailwayMapView.swift che si trova nella root di FdC Railway Manager, 
# non quello appena aggiunto in UI/Views/RailwayMap
for file_id in project.get_files_by_name('RailwayMapView.swift'):
    file_ref = project.objects[file_id]
    # stampiamo per debug
    print(f"Trovato: {file_id}, {getattr(file_ref, 'path', 'No path')}")
    # se non contiene 'UI/Views', allora è quello vecchio
    path = getattr(file_ref, 'path', '')
    if 'UI/Views' not in path and path == 'RailwayMapView.swift':
        print(f"Rimuovo {file_id}")
        project.remove_file_by_id(file_id)

project.save()
print("Salvataggio completato.")
