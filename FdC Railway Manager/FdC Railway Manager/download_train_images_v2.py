#!/usr/bin/env python3
"""
Script per scaricare immagini dei treni italiani da URL diretti
"""

import requests
from pathlib import Path
from PIL import Image
from io import BytesIO
import json
import shutil

# URL diretti alle immagini su Wikimedia Commons
# Questi sono link diretti a immagini di alta qualità con licenze libere
TRAIN_IMAGES = {
    "ETR_1000_Frecciarossa": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/ETR_1000_Frecciarossa_1000.jpg/1280px-ETR_1000_Frecciarossa_1000.jpg",
    "ETR_500_Frecciarossa": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/ETR_500_Frecciarossa.jpg/1280px-ETR_500_Frecciarossa.jpg",
    "ETR_700_Frecciargento": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/ETR_700_Frecciargento.jpg/1280px-ETR_700_Frecciargento.jpg",
    "ETR_600_Pendolino": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/ETR_610_Pendolino.jpg/1280px-ETR_610_Pendolino.jpg",
    "ETR_104_Pop": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/ALe_426_Roma.jpg/1280px-ALe_426_Roma.jpg",
    "ETR_425_Jazz": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/ALe_426_Jazz.jpg/1280px-ALe_426_Jazz.jpg",
    "ALn_501_Minuetto": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/ALn_501_Minuetto.jpg/1280px-ALn_501_Minuetto.jpg",
    "ETR_521_Rock": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/ETR_521_Rock.jpg/1280px-ETR_521_Rock.jpg",
    "ETR_170_FLIRT": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Stadler_FLIRT.jpg/1280px-Stadler_FLIRT.jpg",
    "Locomotiva_E464": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/E_464_locomotive.jpg/1280px-E_464_locomotive.jpg",
}

def download_and_process_image(url, output_name, assets_dir, target_width=800):
    """Scarica, ridimensiona e crea l'asset per Xcode"""
    print(f"📥 {output_name}")

    try:
        # Download
        print(f"   Downloading from {url[:50]}...")
        response = requests.get(url, timeout=30, headers={'User-Agent': 'TrainImageDownloader/1.0'})
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

        # Ridimensiona
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
                    "idiom": "universal"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
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
    print("🚂 Download immagini treni\n")

    assets_dir = Path("Assets.xcassets")
    if not assets_dir.exists():
        print(f"❌ Directory {assets_dir} non trovata!")
        return

    success = 0
    failed = 0

    for name, url in TRAIN_IMAGES.items():
        if download_and_process_image(url, name, assets_dir):
            success += 1
        else:
            failed += 1

    print("\n" + "="*60)
    print(f"✅ Successo: {success}/{len(TRAIN_IMAGES)}")
    print(f"❌ Falliti: {failed}/{len(TRAIN_IMAGES)}")
    print("="*60)
    print("\n💡 Le immagini sono state aggiunte a Assets.xcassets")
    print("   Ricompila il progetto per vederle nell'app!")

if __name__ == "__main__":
    main()
