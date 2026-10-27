#!/usr/bin/env python3
"""Compare same-scale, neutral-pose SCNRenderer exports with their source textures.

Usage: python3 scripts/compare-models.py docs/screenshots/v20/comparison
Requires Pillow and NumPy (available in the Codex bundled Python runtime).
"""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image


def measure(source, rendered):
    if source.shape != rendered.shape or source.shape[2] != 4:
        raise ValueError("Expected equally sized RGBA images")
    original = source[:, :, 3] > 64
    model = rendered[:, :, 3] > 64
    overlap = original & model
    if not original.any() or not model.any() or not overlap.any():
        raise ValueError("Empty or disjoint render; check the export camera and geometry")
    difference = np.abs(source[:, :, :3].astype(float) - rendered[:, :, :3])
    return {
        "silhouette_iou": round(float(overlap.sum() / (original | model).sum()), 4),
        "rgb_mae_on_overlap_0_255": round(float(difference[overlap].mean()), 2),
        "source_pixels": int(original.sum()),
        "render_pixels": int(model.sum()),
    }


def main(directory):
    result = {}
    sources = sorted(directory.glob("*-source.png"))
    if not sources:
        raise ValueError("No model comparison exports found")
    for path in sources:
        name = path.stem.removesuffix("-source")
        source = np.array(Image.open(path).convert("RGBA"))
        rendered = np.array(Image.open(directory / f"{name}-top.png").convert("RGBA"))
        assert measure(source, source)["silhouette_iou"] == 1
        result[name] = measure(source, rendered)
    output = json.dumps(result, indent=2) + "\n"
    (directory / "metrics.json").write_text(output)
    print(output, end="")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
