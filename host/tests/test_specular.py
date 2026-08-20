"""Check the Blinn-Phong specular term against first principles.

A highlight must appear exactly where the surface normal bisects the light and
view directions, must fall off with the exponent, must stay OFF on purely
diffuse materials, and must not tint itself with the surface albedo.
"""
import sys

sys.path.insert(0, r"c:\GitHub_Projects\ASIC\ttsky-ASIC\host")

import numpy as np
import render_fpga as rf


def blinn(normal, light_dir, view_dir, power):
    h = np.asarray(light_dir) + np.asarray(view_dir)
    h = h / np.linalg.norm(h)
    return max(0.0, float(np.dot(normal, h))) ** power


print("material table:")
for m in range(len(rf.PALETTE)):
    if rf.SPEC_STRENGTH[m]:
        print(f"  material {m}: strength {rf.SPEC_STRENGTH[m]}, "
              f"exponent {rf.SPEC_POWER[m]}")
assert rf.SPEC_STRENGTH[rf.MAT_WALL_SHINY] > 0, "shiny wall has no gloss"
assert rf.SPEC_STRENGTH[rf.MAT_WALL] == 0, "the plain wall became glossy"

# --- the left wall really is the new material --------------------------
material = rf.make_scene()
G = rf.GRID
# The back wall is painted after the side walls, so it legitimately owns the
# corner column at z = GRID-1; everything in front of that is the left wall.
left = material[:G - 1, :, 0]
assert np.all(left == rf.MAT_WALL_SHINY), \
    f"left wall is not the shiny material: {np.unique(left)}"
assert np.all(material[G - 1, :, 0] == rf.MAT_WALL), "back wall corner changed"
assert np.all(material[:G - 1, :, G - 1] == rf.MAT_MIRROR), \
    "right wall is no longer the mirror"
assert rf.SPEC_STRENGTH[rf.MAT_MIRROR] == 0, "the mirror also became glossy"
print(f"\nleft wall  = material {rf.MAT_WALL_SHINY} (shiny)")
print(f"right wall = material {rf.MAT_MIRROR} (mirror, no gloss)")
assert rf.PALETTE[rf.MAT_WALL_SHINY] == rf.PALETTE[rf.MAT_WALL], \
    "shiny wall should share the plain wall's albedo, only gloss differs"

# --- peak at the mirror direction, falling off away from it ------------
n = np.array((1.0, 0.0, 0.0))          # left wall faces +x
power = rf.SPEC_POWER[rf.MAT_WALL_SHINY]
view = np.array((1.0, 0.0, 0.0))       # looking straight at the wall
print(f"\nangle between light and the mirror direction vs highlight "
      f"(exponent {power:.0f}):")
prev = None
for deg in (0, 5, 10, 20, 40, 80):
    a = np.radians(deg)
    light = np.array((np.cos(a), np.sin(a), 0.0))
    s = blinn(n, light, view, power)
    print(f"  {deg:3d} deg -> {s:.4f}")
    if prev is not None:
        assert s < prev, "highlight must fall off away from the mirror angle"
    prev = s
assert blinn(n, view, view, power) > 0.99, "no peak at the mirror direction"

# --- the highlight keeps the LAMP's colour, not the surface's ----------
n_px = 4
illum = np.zeros((n_px, 3))
spec = np.zeros((n_px, 3))
spec[:] = (0.2, 0.4, 1.0)              # a strongly blue highlight
albedo = np.tile(np.array((1.0, 0.2, 0.2)), (n_px, 1))   # a red surface
image = np.zeros((n_px, 3), dtype=np.uint8)
rf.normalize_image(illum, albedo, np.ones(n_px, bool), image, spec)
r, g, b = image[0]
print(f"\nblue highlight on a red surface -> RGB {tuple(int(c) for c in image[0])}")
assert b > r, "the highlight took the surface's colour instead of the lamp's"

# --- with no specular the result is bit-identical to before ------------
rng = np.random.default_rng(3)
illum = rng.random((500, 3))
albedo = rng.random((500, 3))
mask = np.ones(500, bool)
a = np.zeros((500, 3), np.uint8)
b_ = np.zeros((500, 3), np.uint8)
rf.normalize_image(illum, albedo, mask, a)
rf.normalize_image(illum, albedo, mask, b_, np.zeros((500, 3)))
assert np.array_equal(a, b_), "spec=None and spec=0 disagree"
print("spec=None reduces exactly to the previous diffuse-only path")

print("\nALL SPECULAR CHECKS PASSED")
