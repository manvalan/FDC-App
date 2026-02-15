#!/usr/bin/env python3
"""
Script per scaricare immagini dei treni italiani da Wikimedia Commons
"""

import requests
import json
from pathlib import Path
from PIL import Image
from io import BytesIO
import time

# Mapping dei modelli di treno alle ricerche su Wikimedia
TRAIN_MODELS = {
    # Alstom Pop
    "ETR_103_Pop": "ETR 103 Alstom Coradia Meridian",
    "ETR_104_Pop": "ETR 104 Alstom Coradia",
    "ETR_204_Pop": "ETR 204 Alstom Pop",
    "ETR_255_Pop": "ETR 255 Alstom Pop",

    # Alstom Jazz
    "ETR_425_Jazz": "ETR 425 Jazz Alstom",
    "ETR_324_Jazz": "ETR 324 Jazz Alstom",

    # Alstom Minuetto
    "ALn_501_Minuetto": "ALn 501 Minuetto Alstom",

    # Alstom Pendolino
    "ETR_600_Pendolino": "ETR 600 Pendolino",
    "ETR_485_Pendolino": "ETR 485 Pendolino Cisalpino",

    # Hitachi Frecciarossa
    "ETR_1000_Frecciarossa": "ETR 1000 Frecciarossa",
    "ETR_500_Frecciarossa": "ETR 500 Frecciarossa",

    # Hitachi Frecciargento
    "ETR_700_Frecciargento": "ETR 700 Frecciargento",

    # Hitachi Rock
    "ETR_421_Rock": "ETR 421 Rock Hitachi",
    "ETR_521_Rock": "ETR 521 Rock Hitachi",
    "ETR_621_Rock": "ETR 621 Rock Hitachi",

    # Hitachi Blues
    "HTR_312_Blues": "HTR 312 Blues",
    "HTR_412_Blues": "HTR 412 Blues",

    # Stadler
    "ETR_170_FLIRT": "ETR 170 FLIRT Stadler",
    "ATR_803_Colleoni": "ATR 803 Stadler Colleoni",

    # Pesa
    "ATR_220_Swing": "ATR 220 Pesa Swing",

    # Locomotive
    "Locomotiva_E464": "E.464 locomotiva elettrica",

    # TSR
    "Treno_Servizio_Regionale_TSR": "TSR Hitachi treno regionale",
}

def search_wikimedia_commons(search_term):
    """Cerca un'immagine su Wikimedia Commons"""
    api_url = "https://commons.wikimedia.org/w/api.php"

    params = {
        "action": "query",
        "format": "json",
        "list": "search",
        "srsearch": search_term,
        "srnamespace": "6",  # File namespace
        "srlimit": "5"
    }

    try:
        response = requests.get(api_url, params=params, timeout=10)
        data = response.json()

        if "query" in data and "search" in data["query"]:
            results = data["query"]["search"]
            if results:
                return results[0]["title"]
    except Exception as e:
        print(f"  ⚠️  Errore nella ricerca: {e}")

    return None

def get_image_url(file_title):
    """Ottieni l'URL dell'immagine da Wikimedia Commons"""
    api_url = "https://commons.wikimedia.org/w/api.php"

    params = {
        "action": "query",
        "format": "json",
        "prop": "imageinfo",
        "titles": file_title,
        "iiprop": "url",
        "iiurlwidth": "800"  # Larghezza ottimale per l'app
    }

    try:
        response = requests.get(api_url, params=params, timeout=10)
        data = response.json()

        pages = data.get("query", {}).get("pages", {})
        for page_id, page_data in pages.items():
            if "imageinfo" in page_data:
                return page_data["imageinfo"][0].get("thumburl") or page_data["imageinfo"][0].get("url")
    except Exception as e:
        print(f"  ⚠️  Errore nel recupero URL: {e}")

    return None

def download_and_resize_image(url, output_path, target_width=800):
    """Scarica e ridimensiona l'immagine"""
    try:
        response = requests.get(url, timeout=15)
        img = Image.open(BytesIO(response.content))

        # Converti in RGB se necessario
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            background.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
            img = background

        # Ridimensiona mantenendo l'aspect ratio
        aspect_ratio = img.height / img.width
        new_height = int(target_width * aspect_ratio)
        img = img.resize((target_width, new_height), Image.Resampling.LANCZOS)

        # Salva come JPEG
        img.save(output_path, "JPEG", quality=85, optimize=True)
        return True
    except Exception as e:
        print(f"  ⚠️  Errore nel download/resize: {e}")
        return False

def create_asset_catalog(image_name, image_path, assets_dir):
    """Crea l'imageset per Xcode Asset Catalog"""
    imageset_dir = assets_dir / f"{image_name}.imageset"
    imageset_dir.mkdir(exist_ok=True)

    # Copia l'immagine nell'imageset
    import shutil
    dest_path = imageset_dir / f"{image_name}.jpg"
    shutil.copy(image_path, dest_path)

    # Crea Contents.json
    contents = {
        "images": [
            {
                "filename": f"{image_name}.jpg",
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

def main():
    print("🚂 Download immagini treni da Wikimedia Commons\n")

    # Directory di output
    temp_dir = Path("/tmp/train_images")
    temp_dir.mkdir(exist_ok=True)

    assets_dir = Path("FdC Railway Manager/Assets.xcassets")

    success_count = 0
    failed_count = 0

    for image_name, search_term in TRAIN_MODELS.items():
        print(f"📥 {image_name}")
        print(f"   Ricerca: {search_term}")

        # Cerca l'immagine
        file_title = search_wikimedia_commons(search_term)
        if not file_title:
            print(f"   ❌ Nessuna immagine trovata\n")
            failed_count += 1
            continue

        print(f"   ✓ Trovato: {file_title}")

        # Ottieni URL
        image_url = get_image_url(file_title)
        if not image_url:
            print(f"   ❌ Impossibile ottenere URL\n")
            failed_count += 1
            continue

        print(f"   ✓ URL ottenuto")

        # Scarica e ridimensiona
        temp_image = temp_dir / f"{image_name}.jpg"
        if download_and_resize_image(image_url, temp_image):
            print(f"   ✓ Download completato")

            # Crea asset catalog
            create_asset_catalog(image_name, temp_image, assets_dir)
            print(f"   ✓ Asset creato")
            print(f"   ✅ Completato\n")
            success_count += 1
        else:
            print(f"   ❌ Errore nel download\n")
            failed_count += 1

        # Pausa per non sovraccaricare i server
        time.sleep(1)

    print("\n" + "="*50)
    print(f"✅ Successo: {success_count}/{len(TRAIN_MODELS)}")
    print(f"❌ Falliti: {failed_count}/{len(TRAIN_MODELS)}")
    print("="*50)

if __name__ == "__main__":
    main()
