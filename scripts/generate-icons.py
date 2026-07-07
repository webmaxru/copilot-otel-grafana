#!/usr/bin/env python3
"""Generate favicons and PWA icons for the copilot-otel-grafana promo site.

Renders the brand "tickline" mark (a small prompt-cache hit/miss bar chart:
two green bars = cache hits, one amber = a miss) on a navy tile, matching the
inline SVG favicon and the landing page. Pre-generates raster files so the
build/CI needs no image toolchain at deploy time. Re-run after changing the
mark: `python scripts/generate-icons.py`.
"""
from PIL import Image, ImageDraw
import os

NAVY = (10, 14, 26, 255)      # #0a0e1a
GREEN = (115, 191, 105, 255)  # #73bf69  (cache hit)
AMBER = (255, 152, 48, 255)   # #ff9830  (cache miss)
GRID = 16.0
# bars on a 16-unit grid, sharing a baseline: (x, y, w, h, color)
BARS = [(3, 7, 2.4, 6, GREEN), (6.8, 4, 2.4, 9, GREEN), (10.6, 9, 2.4, 4, AMBER)]

DOCS = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "docs"))


def draw_icon(size, radius_ratio=0.19, content_scale=1.0, opaque=False):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(size * radius_ratio)
    if r > 0:
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=NAVY)
    else:
        d.rectangle([0, 0, size, size], fill=NAVY)
    k = size / GRID
    cx = cy = GRID / 2.0
    for (x, y, w, h, color) in BARS:
        nx = cx + (x - cx) * content_scale
        ny = cy + (y - cy) * content_scale
        nw, nh = w * content_scale, h * content_scale
        rr = max(1, int(1 * content_scale * k * 0.9))
        d.rounded_rectangle([nx * k, ny * k, (nx + nw) * k, (ny + nh) * k],
                            radius=rr, fill=color)
    return img.convert("RGB") if opaque else img


def main():
    # favicon.ico — legacy 16/32/48, rounded tile
    draw_icon(48, 0.19, 1.0).save(os.path.join(DOCS, "favicon.ico"),
                                  sizes=[(16, 16), (32, 32), (48, 48)])
    # apple-touch — 180x180, full-bleed square, no transparency (iOS masks corners)
    draw_icon(180, 0.0, 1.0, opaque=True).save(os.path.join(DOCS, "apple-touch-icon.png"))
    # PWA "any" icons — rounded tile
    draw_icon(192, 0.19, 1.0).save(os.path.join(DOCS, "icon-192.png"))
    draw_icon(512, 0.19, 1.0).save(os.path.join(DOCS, "icon-512.png"))
    # PWA maskable — full-bleed navy, content kept inside the safe zone
    draw_icon(512, 0.0, 0.80, opaque=True).save(os.path.join(DOCS, "icon-512-maskable.png"))
    print("Wrote favicon.ico, apple-touch-icon.png, icon-192.png, icon-512.png, "
          "icon-512-maskable.png ->", DOCS)


if __name__ == "__main__":
    main()
