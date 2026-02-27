import glob
import os
import sys

def fix_imports(directory):
    files = glob.glob(f'{directory}/*.swift')
    print(f"Fixing imports for {len(files)} files in {directory}...")
    for file in files:
        with open(file, 'r') as f:
            content = f.read()
            
        modified = False
        if 'import AppKit' in content and '#if canImport(AppKit)' not in content:
            content = content.replace('import AppKit', '#if canImport(AppKit)\nimport AppKit\n#endif')
            modified = True
        if 'import UIKit' in content and '#if canImport(UIKit)' not in content:
            content = content.replace('import UIKit', '#if canImport(UIKit)\nimport UIKit\n#endif')
            modified = True
            
        if modified:
            with open(file, 'w') as f:
                f.write(content)
            print(f"  Fixed: {os.path.basename(file)}")
            
    print("Fix imports completato")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python3 fix_imports.py <directory>")
        sys.exit(1)
    fix_imports(sys.argv[1])
