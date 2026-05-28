#!/usr/bin/env python3
"""Generate the macOS AppIcon.appiconset from the curated 1024px master icon."""
from pathlib import Path
from PIL import Image
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MASTER_ICON = ROOT / "scripts" / "assets" / "datameter-icon-master.png"
ICONSET = ROOT / "DataMeterApp" / "App" / "Assets.xcassets" / "AppIcon.appiconset"
ICONSET.mkdir(parents=True, exist_ok=True)

ENTRIES = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]


def main() -> None:
    if not MASTER_ICON.exists():
        raise FileNotFoundError(f"Missing master icon: {MASTER_ICON}")

    master = Image.open(MASTER_ICON).convert("RGBA")
    if master.size != (1024, 1024):
        raise ValueError(f"Master icon must be 1024x1024, got {master.size}")

    contents = {"images": [], "info": {"author": "xcode", "version": 1}}
    for points, scale_factor in ENTRIES:
        pixels = points * scale_factor
        filename = f"AppIcon-{points}x{points}@{scale_factor}x.png"
        out = master.resize((pixels, pixels), Image.Resampling.LANCZOS)
        out.save(ICONSET / filename)
        contents["images"].append({
            "idiom": "mac",
            "size": f"{points}x{points}",
            "scale": f"{scale_factor}x",
            "filename": filename,
        })

    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    # Xcode's generated AppIcon.icns can omit the largest representations in some
    # local builds. Build a complete .icns ourselves so Finder/Dock/Command-Tab
    # can choose the same full-resolution variants as native macOS apps.
    manual_icns = ROOT / "scripts" / "assets" / "AppIcon.icns"
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        mapping = {
            "icon_16x16.png": "AppIcon-16x16@1x.png",
            "icon_16x16@2x.png": "AppIcon-16x16@2x.png",
            "icon_32x32.png": "AppIcon-32x32@1x.png",
            "icon_32x32@2x.png": "AppIcon-32x32@2x.png",
            "icon_128x128.png": "AppIcon-128x128@1x.png",
            "icon_128x128@2x.png": "AppIcon-128x128@2x.png",
            "icon_256x256.png": "AppIcon-256x256@1x.png",
            "icon_256x256@2x.png": "AppIcon-256x256@2x.png",
            "icon_512x512.png": "AppIcon-512x512@1x.png",
            "icon_512x512@2x.png": "AppIcon-512x512@2x.png",
        }
        for icns_name, png_name in mapping.items():
            shutil.copyfile(ICONSET / png_name, iconset / icns_name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(manual_icns)], check=True)

    print(f"Generated macOS app icon set at {ICONSET}")
    print(f"Generated complete icns at {manual_icns}")


if __name__ == "__main__":
    main()
