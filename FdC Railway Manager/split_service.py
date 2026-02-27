import os

def split_file(filename, output_dir, class_name):
    if os.path.exists(output_dir):
        import shutil
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    with open(filename, 'r') as f:
        lines = f.readlines()

    # (StartLine, FileNameSuffix) - verified closing brace before
    marks = [
        (107, "Auth"),
        (249, "Optimization"),
        (632, "Admin"),
        (724, "Training"),
        (790, "WebSocket"),
    ]

    # Core file
    core_end = marks[0][0] - 1
    with open(os.path.join(output_dir, f"{class_name}.swift"), "w") as f:
        f.writelines(lines[:core_end])
        f.write("\n}\n")

    for i in range(len(marks)):
        start = marks[i][0]
        end = marks[i+1][0] - 1 if i+1 < len(marks) else len(lines)
        suffix = marks[i][1]
        
        with open(os.path.join(output_dir, f"{class_name}+{suffix}.swift"), "w") as f:
            f.write("import Foundation\nimport SwiftUI\nimport Combine\n\n")
            f.write(f"extension {class_name} {{\n")
            f.writelines(lines[start-1:end])
            if i < len(marks) - 1:
                f.write("\n}\n")

split_file("RailwayAIService.swift.bak", "RailwayAIService", "RailwayAIService")
