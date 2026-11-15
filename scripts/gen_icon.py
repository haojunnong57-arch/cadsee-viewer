"""生成 CadSee App 图标（1024x1024，苹果风格等轴测线框立方体）。"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "CadSee", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

SS = 4                      # 超采样倍数（抗锯齿）
S = 1024 * SS

# ---------- 背景：对角渐变（亮蓝 -> 深海军蓝）----------
top = np.array([0x2E, 0x6B, 0xFF], dtype=float)
bottom = np.array([0x0A, 0x24, 0x7A], dtype=float)
yy = np.linspace(0, 1, S)[:, None]
xx = np.linspace(0, 1, S)[None, :]
t = 0.72 * yy + 0.28 * xx
bg = np.empty((S, S, 3), dtype=np.float64)
for c in range(3):
    bg[:, :, c] = np.interp(t.ravel(), [0, 1], [top[c], bottom[c]]).reshape(S, S)

# 左上角柔光
d = np.sqrt((xx - 0.18) ** 2 + (yy - 0.12) ** 2)
glow = np.exp(-(d ** 2) / (2 * 0.75 ** 2))[..., None]
bg = np.clip(bg + glow * 26, 0, 255)

img = Image.fromarray(bg.astype(np.uint8), "RGB")
draw = ImageDraw.Draw(img, "RGBA")

# ---------- 等轴测立方体 ----------
s = 230 * SS
cx, oy = 512 * SS, 620 * SS
axis1 = (0.866, 0.5)    # 右下
axis2 = (-0.866, 0.5)   # 左下
axis3 = (0.0, -1.0)     # 上

def v(ax1, ax2=0.0, ax3=0.0):
    return (
        cx + axis1[0] * s * ax1 + axis2[0] * s * ax2 + axis3[0] * s * ax3,
        oy + axis1[1] * s * ax1 + axis2[1] * s * ax2 + axis3[1] * s * ax3,
    )

T = v(0, 0, 1)          # 顶部前角
TR = v(1, 0, 1)         # 顶部右角
TL = v(0, 1, 1)         # 顶部左角
O = v(0, 0, 0)          # 前下角
R = v(1, 0, 0)          # 右下角
L = v(0, 1, 0)          # 左下角
B = v(1, 1, 0)          # 底后角

# 面填充（白色，不同透明度区分受光面）
draw.polygon([T, TR, O, TL], fill=(255, 255, 255, 64))
draw.polygon([T, TR, R, O], fill=(255, 255, 255, 40))
draw.polygon([T, TL, L, O], fill=(255, 255, 255, 26))

# 棱边
edges = [(T, O), (O, R), (O, L), (R, B), (L, B), (T, TR), (T, TL), (TR, R), (TL, L)]
ew = 15 * SS
for a, b in edges:
    draw.line([a, b], fill=(255, 255, 255, 240), width=ew)
    draw.ellipse([a[0] - ew / 2, a[1] - ew / 2, a[0] + ew / 2, a[1] + ew / 2], fill=(255, 255, 255, 240))
    draw.ellipse([b[0] - ew / 2, b[1] - ew / 2, b[0] + ew / 2, b[1] + ew / 2], fill=(255, 255, 255, 240))

# 顶部顶点高光节点（青绿色）
r = 20 * SS
halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
hd = ImageDraw.Draw(halo)
hd.ellipse([T[0] - 4 * r, T[1] - 4 * r, T[0] + 4 * r, T[1] + 4 * r], fill=(77, 227, 255, 90))
halo = halo.filter(ImageFilter.GaussianBlur(3 * SS))
img = Image.alpha_composite(img.convert("RGBA"), halo)
draw = ImageDraw.Draw(img)
draw.ellipse([T[0] - r, T[1] - r, T[0] + r, T[1] + r], fill=(160, 242, 255, 255))

# 底部轻微压暗，增加层次
arr = np.asarray(img).astype(np.float64)
fade = np.clip((yy - 0.68) / 0.32, 0, 1)
arr *= (1 - 0.30 * fade)[..., None]
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

# ---------- 输出 ----------
final = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")
final.save(OUT, "PNG")
print("icon written:", OUT, final.size)
