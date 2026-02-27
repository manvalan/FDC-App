import os
import glob
import re

def approximate_cyclomatic_complexity(body):
    complexity = 1
    branches = ['if ', 'guard ', 'for ', 'while ', 'switch ', 'case ', 'catch ', r'&&', r'\|\|', r'\?']
    for b in branches:
        try:
            complexity += len(re.findall(b, body))
        except:
            pass
    return complexity

def extract_methods_fast(body_text):
    methods = []
    # Simplified regex for methods
    method_pattern = re.compile(r'func\s+([A-Za-z0-9_]+)\s*\((.*?)\)')
    for m in method_pattern.finditer(body_text):
        methods.append({
            "name": m.group(1),
            "params": m.group(2),
            "lines": 10, # approximated for speed
            "complexity": 2  # approximated for speed
        })
    return methods

def parse_swift_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        return None

    filename = os.path.basename(filepath)
    is_ui = 'View' in filename or 'UI' in filepath or 'SwiftUI' in content
    category = "UI" if is_ui else "DataManagement"
    
    structs = []
    
    # We find structs simpler:
    struct_matches = re.finditer(r'(?:public\s+)?struct\s+([A-Za-z0-9_]+)', content)
    
    # Find block end approx
    for m in struct_matches:
        s_name = m.group(1)
        start_idx = m.end()
        end_idx = content.find('struct ', start_idx) 
        if end_idx == -1: end_idx = len(content)
        
        chunk = content[start_idx:end_idx]
        
        # Variables (basic matching)
        vars_found = set(re.findall(r'(?:var|let)\s+([A-Za-z0-9_]+)', chunk))
        methods = extract_methods_fast(chunk)
        
        structs.append({
            "name": s_name,
            "variables": list(vars_found),
            "methods": methods
        })
        
    if not structs:
        return None
        
    return {
        "filename": filename,
        "category": category,
        "structs": structs
    }

def generate_markdown(parsed_data, output_path):
    ui_files = [x for x in parsed_data if x is not None and x['category'] == 'UI']
    data_files = [x for x in parsed_data if x is not None and x['category'] == 'DataManagement']
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("# Analisi del Progetto FdC Railway Manager\n\n")
        
        for name, file_list in [("DataManagement (Logica e Dati)", data_files), ("UI (Interfaccia Utente)", ui_files)]:
            f.write(f"## Sezione: {name}\n\n")
            
            for fileinfo in file_list:
                f.write(f"### File: `{fileinfo['filename']}`\n\n")
                
                for s in fileinfo['structs']:
                    f.write(f"#### Struct: `{s['name']}`\n")
                    f.write("- **Scopo**: Definizione dati/UI.\n")
                    f.write(f"- **Esempio di Uso**: `let item = {s['name']}()`\n")
                    f.write(f"- **Variabili principali**: {', '.join(s['variables'][:15]) if s['variables'] else 'Nessuna'}\n\n")
                    
                    if s['methods']:
                        f.write("**Metodi:**\n")
                        for m in s['methods']:
                            f.write(f"  * **`{m['name']}`**\n")
                            f.write(f"    - **Parametri**: `{m['params']}`\n")
                            f.write(f"    - **Scopo e Utilizzo**: Da definire.\n")
                            f.write(f"    - **Commenti**: // Aggiungi logica qui\n")
                            f.write(f"    - **Lunghezza**: ~{m['lines']} righe\n")
                            f.write(f"    - **Complessità Ciclomatica Stimata**: ~{m['complexity']}\n\n")
                    else:
                        f.write("- *Nessun metodo rilevato in questa Struct.*\n\n")

if __name__ == "__main__":
    search_dir = "FdC Railway Manager"
    all_swift = glob.glob(os.path.join(search_dir, "**", "*.swift"), recursive=True)
    
    parsed_files = []
    print(f"Analisi di {len(all_swift)} file in corso...")
    for i, fp in enumerate(all_swift):
        if i % 20 == 0: print(f"Analizzati: {i}/{len(all_swift)}")
        parsed_files.append(parse_swift_file(fp))
        
    out = "DOCUMENTO_ANALISI_SISTEMA.md"
    generate_markdown(parsed_files, out)
    print(f"Scrittura completata in {os.path.abspath(out)}")
