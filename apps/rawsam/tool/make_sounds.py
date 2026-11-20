#!/usr/bin/env python3
"""يولد أصوات الإشعارات المميزة لتطبيق روسم للتجميل (WAV أحادي 44.1kHz).

لاستبدال أي صوت بتسجيل حقيقي (مثلاً صوت بنت بلهجة عراقية «عدنا عرض جديد!»)
ضع ملف WAV بنفس الاسم في assets/sounds/ — مدته 2 إلى 6 ثواني (آيفون يقبل حتى 30 ثانية).
"""
import math, os, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds")


def note(freq, dur, vol=0.5, harmonics=((1, 1.0), (2, 0.35), (3, 0.15), (4.2, 0.08)), decay=5.0):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.008) * math.exp(-decay * t)
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(vol * env * s / 1.6)
    return out


def mix(parts, total):
    buf = [0.0] * int(RATE * total)
    for start, samples in parts:
        o = int(RATE * start)
        for i, v in enumerate(samples):
            if o + i < len(buf):
                buf[o + i] += v
    peak = max(1e-6, max(abs(v) for v in buf))
    return [v / peak * 0.85 for v in buf]


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))


C5, D5, E5, G5, A5, C6, E6, G6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5, 1568.0

# منشور جديد: ثلاث نغمات صاعدة ناعمة
save("rs_post", mix([(0, note(E5, 1.0)), (0.12, note(G5, 1.0)), (0.24, note(C6, 1.4))], 1.8))
# عرض: بريق سريع صاعد
save("rs_offer", mix([(i * 0.07, note(f, 0.9, decay=6)) for i, f in enumerate([C5, E5, G5, C6, E6, G6])], 1.6))
# هدية: نغمتان مع رنين جرس
save("rs_gift", mix([(0, note(G5, 1.2, harmonics=((1, 1), (2.76, 0.4), (5.4, 0.2)))), (0.18, note(C6, 1.6, harmonics=((1, 1), (2.76, 0.4), (5.4, 0.2))))], 2.0))
# رسالة: نقرتان قصيرتان
save("rs_msg", mix([(0, note(A5, 0.35, decay=12)), (0.13, note(E6, 0.45, decay=10))], 0.7))
# حجز: نغمة تأكيد
save("rs_booking", mix([(0, note(C5, 0.9)), (0.15, note(G5, 1.2))], 1.5))
print("✓ الأصوات في", OUT)
