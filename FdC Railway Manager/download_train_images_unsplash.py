#!/usr/bin/env python3
"""
Script per scaricare immagini di treni da Unsplash
"""

import requests
from pathlib import Path
from PIL import Image
from io import BytesIO
import json
import time

# Unsplash ha immagini gratuite e permette download
# Questi sono URL diretti a immagini di treni ad alta qualità
TRAIN_IMAGES = {
    # Usiamo immagini generiche di treni moderni da Unsplash
    # Gli URL sono immagini pubbliche ad alta risoluzione

    "ETR_1000_Frecciarossa": "https://images.unsplash.com/photo-1474487548417-781cb71495f3?w=800&q=80",  # High-speed train
    "ETR_500_Frecciarossa": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800&q=80",  # Modern train
    "ETR_700_Frecciargento": "https://images.unsplash.com/photo-1569003999078-a2785f3f4d86?w=800&q=80",  # Silver train
    "ETR_600_Pendolino": "https://images.unsplash.com/photo-1554672723-d42a16e533db?w=800&q=80",  # Tilting train
    "ETR_104_Pop": "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=800&q=80",  # Regional train
    "ETR_204_Pop": "https://images.unsplash.com/photo-1553964335-83b3854a8f3e?w=800&q=80",  # Blue regional
    "ETR_425_Jazz": "https://images.unsplash.com/photo-1544620282-1f5d786e7c25?w=800&q=80",  # Modern regional
    "ETR_324_Jazz": "https://images.unsplash.com/photo-1568046411540-73b9cada6c89?w=800&q=80",  # Regional train
    "ALn_501_Minuetto": "https://images.unsplash.com/photo-1581952976147-5a2d0826e7ef?w=800&q=80",  # Small regional
    "ETR_521_Rock": "https://images.unsplash.com/photo-1566351775351-9f08f69c9f43?w=800&q=80",  # Orange train
    "ETR_421_Rock": "https://images.unsplash.com/photo-1566351780996-d3c0cca0912d?w=800&q=80",  # Modern EMU
    "ETR_621_Rock": "https://images.unsplash.com/photo-1585200001351-75ea2b8ea12d?w=800&q=80",  # Long EMU
    "HTR_312_Blues": "https://images.unsplash.com/photo-1497671954146-59a89ff626ff?w=800&q=80",  # Blue train
    "HTR_412_Blues": "https://images.unsplash.com/photo-1544620282-1f5d786e7c25?w=800&q=80",  # Modern blue
    "ETR_170_FLIRT": "https://images.unsplash.com/photo-1571563670812-8f0fc1c2d5f2?w=800&q=80",  # Stadler style
    "ATR_220_Swing": "https://images.unsplash.com/photo-1570125909283-0c33fbc8cc52?w=800&q=80",  # Regional DMU
    "Locomotiva_E464": "https://images.unsplash.com/photo-1566348723360-e0604c0b1e98?w=800&q=80",  # Electric loco
    "Treno_Servizio_Regionale_TSR": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800&q=80",  # Regional service
}

def download_and_process_image(url, output_name, assets_dir, target_width=800):
    """Scarica, ridimensiona e crea l'asset per Xcode"""
    print(f"📥 {output_name}")

    try:
        # Download con headers per evitare blocchi
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
        print(f"   Downloading...")
        response = requests.get(url, timeout=30, headers=headers)
        response.raise_for_status()

        # Apri immagine
        img = Image.open(BytesIO(response.content))
        print(f"   ✓ Downloaded ({img.width}x{img.height})")

        # Converti in RGB se necessario
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            if img.mode in ('RGBA', 'LA'):
                background.paste(img, mask=img.split()[-1])
            else:
                background.paste(img)
            img = background

        # Ridimensiona mantenendo aspect ratio
        aspect_ratio = img.height / img.width
        new_height = int(target_width * aspect_ratio)
        img = img.resize((target_width, new_height), Image.Resampling.LANCZOS)
        print(f"   ✓ Resized to {target_width}x{new_height}")

        # Crea directory imageset
        imageset_dir = assets_dir / f"{output_name}.imageset"
        imageset_dir.mkdir(exist_ok=True, parents=True)

        # Salva immagine
        image_path = imageset_dir / f"{output_name}.jpg"
        img.save(image_path, "JPEG", quality=85, optimize=True)
        print(f"   ✓ Saved to {image_path.name}")

        # Crea Contents.json
        contents = {
            "images": [
                {
                    "filename": f"{output_name}.jpg",
                    "idiom": "universal",
                    "scale": "1x"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            },
            "properties": {
                "preserves-vector-representation": False
            }
        }

        with open(imageset_dir / "Contents.json", "w") as f:
            json.dump(contents, f, indent=2)

        print(f"   ✅ Completed\n")
        return True

    except Exception as e:
        print(f"   ❌ Error: {e}\n")
        return False

def main():
    print("🚂 Download immagini treni da Unsplash\n")

    # Trova la directory Assets
    current_dir = Path.cwd()
    assets_dir = None

    # Cerca in varie posizioni
    possible_paths = [
        current_dir / "Assets.xcassets",
        current_dir / "FdC Railway Manager" / "Assets.xcassets",
        current_dir.parent / "Assets.xcassets",
    ]

    for path in possible_paths:
        if path.exists():
            assets_dir = path
            break

    if not assets_dir:
        print(f"❌ Directory Assets.xcassets non trovata!")
        print(f"   Cercato in: {current_dir}")
        return

    print(f"📁 Usando: {assets_dir}\n")

    success = 0
    failed = 0

    for name, url in TRAIN_IMAGES.items():
        if download_and_process_image(url, name, assets_dir):
            success += 1
        else:
            failed += 1

        # Pausa per non sovraccaricare il server
        time.sleep(0.5)

    print("\n" + "="*60)
    print(f"✅ Successo: {success}/{len(TRAIN_IMAGES)}")
    print(f"❌ Falliti: {failed}/{len(TRAIN_IMAGES)}")
    print("="*60)

    if success > 0:
        print("\n💡 Le immagini sono state aggiunte a Assets.xcassets")
        print("   Ricompila il progetto Xcode per vederle nell'app!")
        print("\n📸 Fonte: Unsplash (immagini gratuite)")

if __name__ == "__main__":
    main()
