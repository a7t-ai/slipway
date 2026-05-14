#!/usr/bin/env python3
"""Generate streaming-app-style App Store marketing screenshots.

Reads captured screenshots from ../screenshots/{locale}/ and title.strings,
composites each onto a themed gradient canvas with a tilted iPhone mockup
and bold headline, and writes results to output/{locale}/.
"""
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = Path(__file__).parent
CONFIG = json.loads((HERE / "config.json").read_text())

CANVAS_W = CONFIG["canvas"]["width"]
CANVAS_H = CONFIG["canvas"]["height"]
FONT_PATH = CONFIG["font"]

TITLE_RE = re.compile(r'^"([^"]+)"\s*=\s*"([^"]*)"\s*;\s*$')


def parse_title_strings(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = TITLE_RE.match(line.strip())
        if m:
            out[m.group(1)] = m.group(2)
    return out


def gradient_bg(w: int, h: int, top_hex: str, bot_hex: str) -> Image.Image:
    top = tuple(int(top_hex[i : i + 2], 16) for i in (1, 3, 5))
    bot = tuple(int(bot_hex[i : i + 2], 16) for i in (1, 3, 5))
    base = Image.new("RGB", (w, h), top)
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return base


def fit_text(draw: ImageDraw.ImageDraw, text: str, font_path: str,
             max_w: int, max_h: int, start_size: int, min_size: int = 40) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """Word-wrap text to fit (max_w, max_h); shrink font if needed."""
    size = start_size
    while size >= min_size:
        font = ImageFont.truetype(font_path, size)
        words = text.split()
        lines, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            tw = draw.textbbox((0, 0), trial, font=font)[2]
            if tw <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        # Measure total block height
        line_h = font.getbbox("Ag")[3] - font.getbbox("Ag")[1]
        total_h = int(line_h * len(lines) * 1.05)
        widest = max((draw.textbbox((0, 0), ln, font=font)[2] for ln in lines), default=0)
        if widest <= max_w and total_h <= max_h:
            return font, lines
        size -= 6
    return font, lines  # best effort


def draw_keyword(canvas: Image.Image, text: str, color: str, top: int) -> int:
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_PATH, 58)
    # uppercase, tracked spacing via wide letter-spacing emulation
    display = " ".join(list(text.upper()))
    bbox = draw.textbbox((0, 0), display, font=font)
    tw = bbox[2] - bbox[0]
    x = (CANVAS_W - tw) // 2
    draw.text((x, top), display, fill=color, font=font)
    return top + (bbox[3] - bbox[1]) + 24


def draw_headline(canvas: Image.Image, text: str, color: str, top: int, max_h: int) -> int:
    draw = ImageDraw.Draw(canvas)
    max_w = CANVAS_W - 160
    font, lines = fit_text(draw, text, FONT_PATH, max_w, max_h, start_size=150, min_size=70)
    line_h = font.getbbox("Ag")[3] - font.getbbox("Ag")[1]
    step = int(line_h * 1.05)
    y = top
    for ln in lines:
        bbox = draw.textbbox((0, 0), ln, font=font)
        x = (CANVAS_W - (bbox[2] - bbox[0])) // 2
        draw.text((x, y), ln, fill=color, font=font)
        y += step
    return y


def place_device(canvas: Image.Image, device: Image.Image, rot_deg: float, top_y: int) -> None:
    frame_w, frame_h = device.size
    # Scale device so it fits nicely below the headline
    target_h = CANVAS_H - top_y - 40  # small bottom padding
    scale = target_h / frame_h
    new_w = int(frame_w * scale)
    new_h = int(frame_h * scale)
    d = device.resize((new_w, new_h), Image.LANCZOS)
    # Soft drop shadow
    shadow = Image.new("RGBA", (new_w + 120, new_h + 120), (0, 0, 0, 0))
    sh_alpha = d.split()[-1]
    shadow.paste((0, 0, 0, 180), (60, 80), sh_alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    # Rotate both
    d_rot = d.rotate(rot_deg, resample=Image.BICUBIC, expand=True)
    sh_rot = shadow.rotate(rot_deg, resample=Image.BICUBIC, expand=True)
    x_d = (CANVAS_W - d_rot.size[0]) // 2
    y_d = top_y
    x_s = (CANVAS_W - sh_rot.size[0]) // 2
    y_s = top_y - 40
    canvas.alpha_composite(sh_rot, (x_s, y_s))
    canvas.alpha_composite(d_rot, (x_d, y_d))


def render_slide(locale: str, slide: dict, titles: dict[str, str]) -> Image.Image:
    key = slide["key"]
    headline = titles.get(key, "")
    bg = gradient_bg(CANVAS_W, CANVAS_H, slide["gradient"][0], slide["gradient"][1]).convert("RGBA")

    shot_path = HERE / CONFIG["screenshot_pattern"].format(locale=locale, key=key)
    if not shot_path.exists():
        raise FileNotFoundError(shot_path)
    device = Image.open(shot_path).convert("RGBA")

    top_margin = 160
    y = draw_headline(bg, headline, slide["headline_color"], top_margin, max_h=560)
    place_device(bg, device, slide["rotation_deg"], y + 60)
    return bg


def main() -> None:
    for locale in CONFIG["locales"]:
        locale_dir = HERE / ".." / "screenshots" / locale
        titles = parse_title_strings(locale_dir / "title.strings")
        out_dir = locale_dir / "uploadable"
        out_dir.mkdir(exist_ok=True)
        for slide in CONFIG["slides"]:
            img = render_slide(locale, slide, titles)
            out = out_dir / f"{slide['key']}.png"
            img.convert("RGB").save(out, "PNG", optimize=True)
            print(f"✓ {locale}/uploadable/{slide['key']}.png")


if __name__ == "__main__":
    main()
