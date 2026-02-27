import os
import re
import sys
from pbxproj import XcodeProject

def parse_swift_file(filepath, out_dir, project_path, target_name):
    if not os.path.exists(filepath):
        print(f"File {filepath} non trovato.")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    os.makedirs(out_dir, exist_ok=True)
    
    imports = []
    for line in content.split('\n'):
        if line.startswith('import '):
            if line not in imports:
                imports.append(line)
        elif line.strip() != '' and not line.startswith('//'):
            pass

    header = "\n".join(imports) + "\n\n"
    
    idx = 0
    length = len(content)
    blocks = []
    
    while True:
        match = re.search(r'(?:@[A-Za-z0-9_]+\s*)*(?:(?:public|internal|fileprivate|private)\s+)?(?:final\s+)?(?:@[A-Za-z0-9_]+\s*)*(?:struct|class|enum|extension|actor)\s+([A-Za-z0-9_]+)[^{]*\{', content[idx:], re.MULTILINE)
        if not match:
            break
            
        start_block = idx + match.start()
        name = match.group(1)
        first_brace = content.find('{', start_block)
        
        brace_count = 1
        end_idx = first_brace + 1
        
        in_string = False
        in_comment = False
        
        while brace_count > 0 and end_idx < length:
            char = content[end_idx]
            
            # Simple string skipping
            if char == '"' and not in_comment:
                if end_idx == 0 or content[end_idx-1] != '\\':
                    in_string = not in_string
            
            # Simple single-line comment skipping
            if char == '/' and end_idx + 1 < length and content[end_idx+1] == '/' and not in_string and not in_comment:
                in_comment = True
            
            if in_comment and char == '\n':
                in_comment = False
                
            if not in_string and not in_comment:
                if char == '{': brace_count += 1
                elif char == '}': brace_count -= 1
                
            end_idx += 1
            
        block_text = content[start_block:end_idx]
        blocks.append((name, block_text))
        idx = end_idx

    grouped_blocks = {}
    for name, text in blocks:
        if name not in grouped_blocks:
            grouped_blocks[name] = []
        grouped_blocks[name].append(text)
        
    generated_files = []
    for name, texts in grouped_blocks.items():
        out_file = os.path.join(out_dir, f"{name}.swift")
        with open(out_file, 'w', encoding='utf-8') as f:
            f.write(header)
            f.write("\n\n".join(texts) + "\n")
        generated_files.append(out_file)
        
    print(f"File diviso in {len(generated_files)} componenti.")
    
    try:
        project = XcodeProject.load(project_path)
        
        # 1. Rimuovi tutti i RailwayMapView.swift esistenti
        # Determina il nome originale del file
        original_basename = os.path.basename(filepath).replace('.bak', '')
        
        # 1. Rimuovi tutte le istanze del file originale dal progetto per evitare duplicati
        for file_id in project.get_files_by_name(original_basename):
            project.remove_file_by_id(file_id)

        # 2. Rimuovi tutti i precedenti che potrebbero essere stati generati per non avere duplicati
        for generated_file in generated_files:
            bname = os.path.basename(generated_file)
            if bname != original_basename: # Già rimosso
                for fid in project.get_files_by_name(bname):
                    project.remove_file_by_id(fid)

        # 3. Aggiungiamo i file nuovi generati
        for gen_file in generated_files:
            project.add_file(gen_file, force=False, target_name=target_name)
            
        project.save()
        print(f"Salvataggio xcodeproj completato. {len(generated_files)} file aggiunti.")
    except Exception as e:
        print(f"Errore nell'aggiornamento del progetto Xcode: {e}")

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Uso: python3 split_ui.py <filepath> <out_dir> <project_path> <target_name>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    out_dir = sys.argv[2]
    project_path = sys.argv[3]
    target_name = sys.argv[4]
    
    parse_swift_file(filepath, out_dir, project_path, target_name)
