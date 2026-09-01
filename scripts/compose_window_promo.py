#!/usr/bin/env python3
"""창만 남긴 녹화를 랜딩 배경 위에 올려 MP4로 만든다.

색은 site/styles.css :root, 배치은 site/promo-layout.json에서 읽는다.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Protocol

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"


class PromoLayout(Protocol):
    """캔버스와 창 배치. 픽셀·비율은 promo-layout.json이 출처."""

    canvas_w: int
    canvas_h: int
    window_height_ratio: float
    corner_radius_px: int
    shadow_blur: int
    shadow_offset_y: int
    shadow_opacity: float


def parse_css_vars(css: str) -> dict[str, str]:
    """`:root { --name: value; }` 블록만 읽는다."""
    match = re.search(r":root\s*\{([^}]+)\}", css)
    if not match:
        raise ValueError("styles.css에 :root 변수가 없습니다.")
    found = re.findall(r"--([a-z0-9-]+)\s*:\s*([^;]+);", match.group(1))
    return {name: value.strip() for name, value in found}


def parse_hex(color: str) -> tuple[int, int, int]:
    text = color.strip().lstrip("#")
    if len(text) != 6:
        raise ValueError(f"hex 색이 아닙니다: {color}")
    return int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16)


def even(n: int) -> int:
    return n if n % 2 == 0 else n - 1


def window_box(src_w: int, src_h: int, layout: dict) -> tuple[int, int, int, int]:
    """창을 캔버스 높이에 맞추고 가운데 둔다. (x, y, w, h) 모두 짝수."""
    canvas_w = int(layout["canvasWidth"])
    canvas_h = int(layout["canvasHeight"])
    win_h = even(int(canvas_h * float(layout["windowHeightRatio"])))
    win_w = even(int(win_h * (src_w / src_h)))
    if win_w > canvas_w - 48:
        win_w = even(canvas_w - 48)
        win_h = even(int(win_w * (src_h / src_w)))
    x = even((canvas_w - win_w) // 2)
    y = even((canvas_h - win_h) // 2)
    return x, y, win_w, win_h


def render_background(width: int, height: int, colors: dict[str, str]) -> Image.Image:
    bg = parse_hex(colors["bg"])
    glow = parse_hex(colors.get("glow", colors["bg"]))
    accent = parse_hex(colors["accent"])
    img = Image.new("RGBA", (width, height), (*bg, 255))
    img = _radial(img, (int(width * 0.80), int(-height * 0.10)), int(width * 0.72), glow, 170)
    img = _radial(img, (int(width * 0.12), int(height * 1.08)), int(width * 0.58), accent, 80)
    return img.convert("RGB")


def _radial(
    base: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    peak_alpha: int,
) -> Image.Image:
    """부드러운 radial glow. 원 스택 후 블러로 밴딩을 죽인다."""
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx, cy = center
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        r = int(radius * t)
        alpha = int(peak_alpha * (1 - t) ** 2)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, alpha))
    overlay = overlay.filter(ImageFilter.GaussianBlur(48))
    return Image.alpha_composite(base, overlay)


def render_shadow(
    canvas: tuple[int, int],
    box: tuple[int, int, int, int],
    radius: int,
    blur: int,
    offset_y: int,
    opacity: float,
) -> Image.Image:
    layer = Image.new("RGBA", canvas, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y, w, h = box
    pad = blur * 2
    shadow = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    alpha = max(0, min(255, int(255 * opacity)))
    sdraw.rounded_rectangle(
        (pad, pad, pad + w, pad + h),
        radius=radius,
        fill=(0, 0, 0, alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    layer.alpha_composite(shadow, (x - pad, y - pad + offset_y))
    return layer


def render_mask(width: int, height: int, radius: int) -> Image.Image:
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    return mask


def ffprobe_size(path: Path) -> tuple[int, int]:
    out = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height",
            "-of",
            "csv=p=0",
            str(path),
        ],
        text=True,
    ).strip()
    w, h = out.split(",")
    return int(w), int(h)


def compose_window_promo(
    source: Path,
    out_mp4: Path,
    out_poster: Path,
    styles: Path,
    layout_path: Path,
    duration_s: float = 12.0,
) -> None:
    """창 녹화 `source`를 배경 위에 합성해 `out_mp4` / `out_poster`를 쓴다."""
    colors = parse_css_vars(styles.read_text(encoding="utf-8"))
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    src_w, src_h = ffprobe_size(source)
    x, y, win_w, win_h = window_box(src_w, src_h, layout)
    canvas_w = int(layout["canvasWidth"])
    canvas_h = int(layout["canvasHeight"])
    radius = int(layout["cornerRadiusPx"])

    with tempfile.TemporaryDirectory(prefix="alog-promo-") as tmp:
        tmp_path = Path(tmp)
        bg_path = tmp_path / "bg.png"
        shadow_path = tmp_path / "shadow.png"
        mask_path = tmp_path / "mask.png"
        render_background(canvas_w, canvas_h, colors).save(bg_path)
        render_shadow(
            (canvas_w, canvas_h),
            (x, y, win_w, win_h),
            radius,
            int(layout["shadowBlur"]),
            int(layout["shadowOffsetY"]),
            float(layout["shadowOpacity"]),
        ).save(shadow_path)
        render_mask(win_w, win_h, radius).save(mask_path)

        filter_complex = (
            f"[0:v]setpts=PTS-STARTPTS,fps=30,scale={win_w}:{win_h},format=rgba[win];"
            f"[3:v]format=gray,scale={win_w}:{win_h}[mask];"
            f"[win][mask]alphamerge[round];"
            f"[1:v][2:v]overlay=0:0[stage];"
            f"[stage][round]overlay={x}:{y}:format=auto,fps=30,format=yuv420p"
        )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(source),
                "-loop",
                "1",
                "-i",
                str(bg_path),
                "-loop",
                "1",
                "-i",
                str(shadow_path),
                "-loop",
                "1",
                "-i",
                str(mask_path),
                "-filter_complex",
                filter_complex,
                "-t",
                str(duration_s),
                "-an",
                "-r",
                "30",
                "-c:v",
                "libx264",
                "-crf",
                "20",
                "-movflags",
                "+faststart",
                str(out_mp4),
            ],
            check=True,
        )

    poster_t = min(9.0, max(1.0, duration_s * 0.75))
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            str(poster_t),
            "-i",
            str(out_mp4),
            "-frames:v",
            "1",
            "-update",
            "1",
            "-q:v",
            "3",
            str(out_poster),
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="창 녹화를 랜딩 배경 위에 합성한다.")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=SITE / "promo.mp4")
    parser.add_argument("--poster", type=Path, default=SITE / "promo-poster.jpg")
    parser.add_argument("--styles", type=Path, default=SITE / "styles.css")
    parser.add_argument("--layout", type=Path, default=SITE / "promo-layout.json")
    parser.add_argument("--duration", type=float, default=12.0)
    args = parser.parse_args()
    compose_window_promo(
        source=args.source,
        out_mp4=args.out,
        out_poster=args.poster,
        styles=args.styles,
        layout_path=args.layout,
        duration_s=args.duration,
    )
    print("wrote", args.out, args.poster)


if __name__ == "__main__":
    main()
