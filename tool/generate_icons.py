#!/usr/bin/env python3
"""IBRA BOOKING — يولد كل أيقونات أندرويد و iOS وشاشة البداية من ملف واحد.

المصدر: assets/icon/source.png (مربع، يفضل 1024 أو أكبر).
لتغيير الأيقونة: بدّل الملف بنفس الاسم وأعد البناء.

الاستخدام:
  python3 tool/generate_icons.py            # يولد assets/images/* فقط
  python3 tool/generate_icons.py --platforms  # + android/ و ios/ (بعد flutter create)
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "icon", "source_general.png" if "--general" in sys.argv else "source.png")
BG = (11, 16, 38)  # كحلي داكن للخلفيات


def load_master():
    im = Image.open(SRC).convert("RGB")
    # قص الحواف السوداء الخارجية إن وجدت (بلاطة بزوايا سوداء)
    gray = im.convert("L").point(lambda v: 255 if v > 22 else 0)
    bbox = gray.getbbox() or (0, 0, im.width, im.height)
    l, t, r, b = bbox
    side = max(r - l, b - t)
    cx, cy = (l + r) // 2, (t + b) // 2
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    tile = im.crop(box).resize((1024, 1024), Image.LANCZOS)
    return tile


def rounded_mask(size, radius_ratio):
    s = size * 4
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * radius_ratio), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def rounded(img, ratio=0.2):
    out = img.convert("RGBA")
    out.putalpha(rounded_mask(img.width, ratio))
    return out


def inner(tile, inset=0.06):
    p = int(tile.width * inset)
    return tile.crop((p, p, tile.width - p, tile.height - p)).resize((1024, 1024), Image.LANCZOS)


def save(img, path, size, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if mode:
        out = out.convert(mode)
    out.save(path, optimize=True)


def notification_crescent(size=512):
    s = size * 4
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    r = s * 0.42
    cx, cy = s * 0.5, s * 0.5
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    off = r * 0.45
    r2 = r * 0.82
    d.ellipse([cx - r2 + off, cy - r2, cx + r2 + off, cy + r2], fill=0)
    out = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    out.putalpha(m)
    return out.resize((size, size), Image.LANCZOS)


def gen_assets(tile):
    logo = rounded(inner(tile, 0.0), 0.2)
    name = "logo_general.png" if "--general" in sys.argv else "logo.png"
    save(logo, os.path.join(ROOT, "assets", "images", name), 512)
    save(tile, os.path.join(ROOT, "dist_assets", "play_store_icon_512.png"), 512, "RGB")


def gen_android(tile):
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    if not os.path.isdir(res):
        print("android/ غير موجود — تخطي")
        return
    legacy = rounded(tile, 0.2)
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    # الطبقة الأمامية للأيقونة المتكيفة
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    art = rounded(inner(tile, 0.07), 0.22).resize((720, 720), Image.LANCZOS)
    fg.paste(art, (152, 152), art)
    for d, k in dens.items():
        save(legacy, os.path.join(res, f"mipmap-{d}", "ic_launcher.png"), int(48 * k))
        save(legacy, os.path.join(res, f"mipmap-{d}", "ic_launcher_round.png"), int(48 * k))
        save(fg, os.path.join(res, f"mipmap-{d}", "ic_launcher_foreground.png"), int(108 * k))
    os.makedirs(os.path.join(res, "mipmap-anydpi-v26"), exist_ok=True)
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    for n in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(res, "mipmap-anydpi-v26", n), "w") as f:
            f.write(adaptive)
    os.makedirs(os.path.join(res, "values"), exist_ok=True)
    with open(os.path.join(res, "values", "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#0B1026</color>\n</resources>\n')
    # شعار شاشة البداية
    splash = rounded(inner(tile, 0.0), 0.22)
    save(splash, os.path.join(res, "drawable-nodpi", "splash_logo.png"), 384)
    # أيقونة الإشعار الصغيرة: هلال أبيض على خلفية شفافة
    stat = notification_crescent()
    for d, k in dens.items():
        save(stat, os.path.join(res, f"drawable-{d}", "ic_stat_ibra.png"), int(24 * k))
    print("✓ أيقونات أندرويد")


IOS_ICONS = [
    ("20x20", "iphone", "2x"), ("20x20", "iphone", "3x"),
    ("29x29", "iphone", "1x"), ("29x29", "iphone", "2x"), ("29x29", "iphone", "3x"),
    ("40x40", "iphone", "2x"), ("40x40", "iphone", "3x"),
    ("60x60", "iphone", "2x"), ("60x60", "iphone", "3x"),
    ("20x20", "ipad", "1x"), ("20x20", "ipad", "2x"),
    ("29x29", "ipad", "1x"), ("29x29", "ipad", "2x"),
    ("40x40", "ipad", "1x"), ("40x40", "ipad", "2x"),
    ("76x76", "ipad", "1x"), ("76x76", "ipad", "2x"),
    ("83.5x83.5", "ipad", "2x"),
    ("1024x1024", "ios-marketing", "1x"),
]


def gen_ios(tile):
    assets = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")
    if not os.path.isdir(assets):
        print("ios/ غير موجود — تخطي")
        return
    full = inner(tile, 0.04).convert("RGB")  # iOS يرفض الشفافية ويقص الزوايا بنفسه
    d = os.path.join(assets, "AppIcon.appiconset")
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    images = []
    for size, idiom, scale in IOS_ICONS:
        base = float(size.split("x")[0])
        px = int(round(base * int(scale[0])))
        name = f"Icon-App-{size}@{scale}.png"
        save(full, os.path.join(d, name), px, "RGB")
        images.append({"size": size, "idiom": idiom, "filename": name, "scale": scale})
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"version": 1, "author": "xcode"}}, f, indent=2)
    # صورة شاشة الإطلاق
    li = os.path.join(assets, "LaunchImage.imageset")
    os.makedirs(li, exist_ok=True)
    logo = rounded(inner(tile, 0.0), 0.22)
    for n, s in (("LaunchImage.png", 160), ("LaunchImage@2x.png", 320), ("LaunchImage@3x.png", 480)):
        save(logo, os.path.join(li, n), s)
    with open(os.path.join(li, "Contents.json"), "w") as f:
        json.dump({"images": [
            {"idiom": "universal", "filename": "LaunchImage.png", "scale": "1x"},
            {"idiom": "universal", "filename": "LaunchImage@2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": "LaunchImage@3x.png", "scale": "3x"}],
            "info": {"version": 1, "author": "xcode"}}, f, indent=2)
    print("✓ أيقونات iOS")


if __name__ == "__main__":
    t = load_master()
    gen_assets(t)
    if "--platforms" in sys.argv:
        gen_android(t)
        gen_ios(t)
    print("تم.")
