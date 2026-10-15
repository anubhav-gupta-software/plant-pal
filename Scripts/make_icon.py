#!/usr/bin/env python3
"""Paint the Plant Pal app icon. No image library, just a PNG."""

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
pixels = [[(0, 0, 0) for _ in range(SIZE)] for _ in range(SIZE)]


def blend(dst, src, alpha):
    if alpha <= 0:
        return dst
    if alpha >= 1:
        return src
    return tuple(int(dst[i] * (1 - alpha) + src[i] * alpha) for i in range(3))


def paint(x, y, color, alpha=1.0):
    if 0 <= x < SIZE and 0 <= y < SIZE and alpha > 0:
        pixels[y][x] = blend(pixels[y][x], color, alpha)


def gradient():
    top = (186, 214, 190)
    bottom = (251, 243, 228)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(SIZE):
            pixels[y][x] = color


def disc(cx, cy, radius, color):
    x0 = max(0, int(cx - radius - 2))
    x1 = min(SIZE - 1, int(cx + radius + 2))
    y0 = max(0, int(cy - radius - 2))
    y1 = min(SIZE - 1, int(cy + radius + 2))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            distance = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            alpha = max(0.0, min(1.0, radius + 0.6 - distance))
            paint(x, y, color, alpha)


def ellipse(cx, cy, rx, ry, rotation, color):
    cos_a = math.cos(rotation)
    sin_a = math.sin(rotation)
    reach = max(rx, ry) + 2
    x0 = max(0, int(cx - reach))
    x1 = min(SIZE - 1, int(cx + reach))
    y0 = max(0, int(cy - reach))
    y1 = min(SIZE - 1, int(cy + reach))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            local_x = dx * cos_a + dy * sin_a
            local_y = -dx * sin_a + dy * cos_a
            distance = math.hypot(local_x / rx, local_y / ry)
            alpha = max(0.0, min(1.0, (1 - distance) * min(rx, ry)))
            paint(x, y, color, alpha)


def polygon(points, color):
    ys = [point[1] for point in points]
    for y in range(max(0, int(min(ys))), min(SIZE - 1, int(max(ys))) + 1):
        hits = []
        for index, (x1, y1) in enumerate(points):
            x2, y2 = points[(index + 1) % len(points)]
            if (y1 <= y < y2) or (y2 <= y < y1):
                if y2 != y1:
                    t = (y + 0.5 - y1) / (y2 - y1)
                    hits.append(x1 + t * (x2 - x1))
        hits.sort()
        for index in range(0, len(hits) - 1, 2):
            start = int(math.floor(hits[index]))
            end = int(math.ceil(hits[index + 1]))
            for x in range(max(0, start), min(SIZE, end + 1)):
                paint(x, y, color, 1)


def write_png(path):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)
        for x in range(SIZE):
            red, green, blue = pixels[y][x]
            raw.extend((red, green, blue, 255))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main():
    gradient()
    disc(780, 180, 150, (245, 214, 130))
    disc(512, 470, 230, (243, 198, 186))
    ellipse(512, 900, 190, 28, 0, (90, 70, 48))
    polygon([(300, 690), (724, 690), (650, 900), (374, 900)], (206, 112, 72))
    polygon([(560, 700), (710, 690), (648, 890), (520, 890)], (176, 86, 54))
    ellipse(512, 688, 230, 42, 0, (222, 138, 94))
    ellipse(512, 676, 190, 26, 0, (92, 58, 36))
    polygon([(496, 520), (528, 520), (528, 690), (496, 690)], (36, 110, 68))
    ellipse(390, 590, 36, 78, -0.8, (70, 158, 92))
    ellipse(640, 575, 34, 74, 0.7, (42, 122, 70))
    ellipse(430, 500, 30, 64, -0.35, (86, 176, 104))
    ellipse(600, 490, 28, 60, 0.4, (48, 132, 74))
    center_x, center_y = 512, 430
    for index in range(6):
        angle = -math.pi / 2 + index * (math.pi / 3)
        petal = (245, 198, 86) if index % 2 == 0 else (230, 156, 58)
        ellipse(
            center_x + math.cos(angle) * 72,
            center_y + math.sin(angle) * 72,
            34,
            64,
            angle - math.pi / 2,
            petal,
        )
    disc(center_x, center_y, 48, (236, 126, 68))
    disc(center_x - 16, center_y - 6, 7, (48, 36, 24))
    disc(center_x + 16, center_y - 6, 7, (48, 36, 24))
    disc(center_x - 34, center_y + 14, 11, (236, 150, 140))
    disc(center_x + 34, center_y + 14, 11, (236, 150, 140))
    for index in range(-4, 5):
        disc(center_x + index * 6, center_y + 18 + abs(index) * 1.3, 3.2, (48, 36, 24))
    destination = Path(__file__).resolve().parents[1] / "PlantPal" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    write_png(destination)
    print(destination)


if __name__ == "__main__":
    main()
