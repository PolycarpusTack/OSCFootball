"""A low-poly footballer's animations (ANIMS: run, jog, stand, kick), on the spot, rendered from
the game's five drawn directions (away, up-right, right, down-right, toward the camera) at 4x
the sprite size.

    blender -b -P tools/blender/footballer.py -- <out_dir> [anim ...]   (default: all of ANIMS)

Writes <out_dir>/<anim>/<dir>_<frame>.png and <out_dir>/<anim>/origin.json: the pixel the
ground point under the player lands on (the same in every render) and each frame's start
tick. tools/blender/pack_sprites.py turns them into a palette-indexed sheet, its palette and
animations.json for the game's kit shader.

The renders aren't pictures but codes, unlit (emission), one sample a pixel so codes never
blend: red is the kit slot of scripts/kit.gdshader (1 shirt, 2 its second colour, 3 shorts,
4 socks, 5 boots, 6 skin, 7 hair) times SLOT_STEP, green how much the surface faces the
light (0.5 + 0.5 light . normal). The shirt is striped in slots 1 and 2 like FIFA 96's
sprites, so a striped kit shows its stripes and a plain one (shirt2 = shirt) doesn't.
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/footballer"
CELL = 256  # render size; the sprite is a quarter of it
ORTHO = 2.56  # metres across the render: 1.8 m tall comes out about 44 px at 64 px
ELEVATION = math.radians(24.0)  # the match camera looks down about this much
DIRECTIONS = {0: 90.0, 2: 45.0, 4: 0.0, 6: -45.0, 8: -90.0}  # drawn dir: heading (deg, 0 = screen right)

SLOTS = {"shirt": 1, "shirt2": 2, "shorts": 3, "socks": 4, "boots": 5, "skin": 6, "hair": 7}
SLOT_STEP = 32  # red byte per slot; pack_sprites.py reads it back to the nearest
LIGHT = (-0.45, -0.55, 0.7)  # toward the light: up, toward the camera, from the left
STRIPE = 0.16  # metres from one stripe to the next across the shirt: 2 px each in the sprite


def linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def material(name):
    """`name` a key of SLOTS, or "striped": the shirt in stripes of slots 1 and 2."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = Vector(LIGHT).normalized()
    links.new(geo.outputs["Normal"], dot.inputs[0])
    lit = nodes.new("ShaderNodeMath")
    lit.operation = "MULTIPLY_ADD"
    lit.use_clamp = True
    lit.inputs[1].default_value = 0.5
    lit.inputs[2].default_value = 0.5
    links.new(dot.outputs["Value"], lit.inputs[0])
    code = nodes.new("ShaderNodeCombineColor")
    links.new(lit.outputs["Value"], code.inputs["Green"])
    slot_code = lambda slot: linear(slot * SLOT_STEP / 255.0)
    if name == "striped":
        coords = nodes.new("ShaderNodeTexCoord")
        xyz = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Object"], xyz.inputs["Vector"])
        across = nodes.new("ShaderNodeMath")
        across.operation = "DIVIDE"
        across.inputs[1].default_value = STRIPE
        links.new(xyz.outputs["X"], across.inputs[0])
        frac = nodes.new("ShaderNodeMath")
        frac.operation = "FRACT"
        links.new(across.outputs["Value"], frac.inputs[0])
        second = nodes.new("ShaderNodeMath")  # 1 on the second half of each stripe
        second.operation = "GREATER_THAN"
        second.inputs[1].default_value = 0.5
        links.new(frac.outputs["Value"], second.inputs[0])
        which = nodes.new("ShaderNodeMath")
        which.operation = "MULTIPLY_ADD"
        which.inputs[1].default_value = slot_code(SLOTS["shirt2"]) - slot_code(SLOTS["shirt"])
        which.inputs[2].default_value = slot_code(SLOTS["shirt"])
        links.new(second.outputs["Value"], which.inputs[0])
        links.new(which.outputs["Value"], code.inputs["Red"])
    else:
        code.inputs["Red"].default_value = slot_code(SLOTS[name])
    emit = nodes.new("ShaderNodeEmission")
    links.new(code.outputs["Color"], emit.inputs["Color"])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return m


def joint(name, parent, at):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.parent = parent
    e.location = at
    e.rotation_mode = "XYZ"
    return e


def limb(parent, length, radius, colour, start=0.0, sx=1.0):
    """A cylinder hanging down from `parent`'s origin, from `start` to `start + length`."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=length)
    o = bpy.context.object
    o.parent = parent
    o.location = (0.0, 0.0, -(start + length / 2.0))
    o.scale = (sx, 1.0, 1.0)
    o.data.materials.append(material(colour))
    bpy.ops.object.shade_smooth()
    return o


def ball(parent, radius, colour, at, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius)
    o = bpy.context.object
    o.parent = parent
    o.location = at
    o.scale = scale
    o.data.materials.append(material(colour))
    bpy.ops.object.shade_smooth()
    return o


def box(parent, size, colour, at):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.object
    o.parent = parent
    o.location = at
    o.scale = size
    o.data.materials.append(material(colour))
    return o


def build():
    """The figure faces +Y; its left is -X. Returns the joints to animate."""
    root = joint("root", None, (0.0, 0.0, 0.0))
    pelvis = joint("pelvis", root, (0.0, 0.0, 0.95))
    torso = joint("torso", pelvis, (0.0, 0.0, 0.0))
    # chest: the shirt from the waist to the shoulders, flattened front to back
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.2, depth=0.52)
    chest = bpy.context.object
    chest.parent = torso
    chest.location = (0.0, 0.0, 0.27)
    chest.scale = (1.0, 0.62, 1.0)
    chest.data.materials.append(material("striped"))
    bpy.ops.object.shade_smooth()
    box(pelvis, (0.36, 0.24, 0.16), "shorts", (0.0, 0.0, -0.02))
    neck = joint("neck", torso, (0.0, 0.0, 0.53))
    limb(neck, 0.08, 0.05, "skin", start=-0.08)
    head = joint("head", neck, (0.0, 0.0, 0.16))
    ball(head, 0.13, "skin", (0.0, 0.0, 0.0), (0.9, 1.0, 1.1))
    ball(head, 0.135, "hair", (0.0, -0.03, 0.04), (0.92, 0.95, 0.95))
    j = {"root": root, "pelvis": pelvis, "torso": torso, "head": head}
    for side, x in (("L", -1.0), ("R", 1.0)):
        hip = joint("hip" + side, pelvis, (0.11 * x, 0.0, -0.05))
        limb(hip, 0.2, 0.1, "shorts")
        limb(hip, 0.25, 0.078, "skin", start=0.2)
        knee = joint("knee" + side, hip, (0.0, 0.0, -0.43))
        limb(knee, 0.4, 0.068, "socks", start=0.02)
        ankle = joint("ankle" + side, knee, (0.0, 0.0, -0.42))
        boot = box(ankle, (0.12, 0.27, 0.09), "boots", (0.0, 0.06, -0.03))
        shoulder = joint("shoulder" + side, torso, (0.24 * x, 0.0, 0.47))
        limb(shoulder, 0.14, 0.072, "shirt")
        limb(shoulder, 0.13, 0.055, "skin", start=0.14)
        elbow = joint("elbow" + side, shoulder, (0.0, 0.0, -0.28))
        limb(elbow, 0.22, 0.05, "skin")
        ball(elbow, 0.06, "skin", (0.0, 0.0, -0.25))
        j.update({"boot" + side: boot, "hip" + side: hip, "knee" + side: knee, "ankle" + side: ankle,
                  "shoulder" + side: shoulder, "elbow" + side: elbow})
    return j


def _rest(j):
    for name, o in j.items():
        if name != "root" and not name.startswith("boot"):
            o.rotation_euler = (0.0, 0.0, 0.0)
    j["pelvis"].location.z = 0.95


def _out(j, side, angle):
    """Arm `side` lifted `angle` out sideways (the left arm hangs at -X, the right at +X)."""
    j["shoulder" + side].rotation_euler.y = angle if side == "L" else -angle


def _stride(j, phase, swing, fold, lean, arms, elbow):
    """A run or jog at `phase` (0..2pi): legs swing, the knee folds as the leg comes through,
    arms swing against the legs, the body leans in (_ground then puts a foot on the ground)."""
    for side, off in (("L", 0.0), ("R", math.pi)):
        p = phase + off
        j["hip" + side].rotation_euler.x = swing * math.sin(p) + 0.15 * swing
        j["knee" + side].rotation_euler.x = -(0.3 * fold / 1.9 + fold * max(0.0, math.cos(p - 0.35)) ** 1.3)
        j["ankle" + side].rotation_euler.x = 0.3 * math.sin(p - 0.8)
        j["shoulder" + side].rotation_euler.x = -arms * math.sin(p)
        j["elbow" + side].rotation_euler.x = elbow
        _out(j, side, 0.08)
    j["torso"].rotation_euler.x = lean
    j["torso"].rotation_euler.z = 0.12 * swing * math.sin(phase)
    j["head"].rotation_euler.x = -0.5 * lean


def _ground(j):
    """Down (or up) until the lowest boot stands on the ground, where the sprite's anchor is."""
    bpy.context.view_layer.update()
    low = min((b.matrix_world @ Vector(c)).z for b in (j["bootL"], j["bootR"]) for c in b.bound_box)
    j["pelvis"].location.z -= low
    bpy.context.view_layer.update()


def run(j, i, n):
    _stride(j, i / n * math.tau, swing=0.95, fold=1.9, lean=0.32, arms=0.95, elbow=1.6)


def jog(j, i, n):
    _stride(j, i / n * math.tau, swing=0.6, fold=1.2, lean=0.14, arms=0.55, elbow=1.45)


def stand(j, i, n):
    """Weight on both feet a little apart, knees soft, arms hanging just off the body."""
    for side, x in (("L", -1.0), ("R", 1.0)):
        j["hip" + side].rotation_euler.y = 0.06 * -x
        j["hip" + side].rotation_euler.x = 0.05
        j["knee" + side].rotation_euler.x = -0.1
        j["ankle" + side].rotation_euler.x = 0.05
        j["elbow" + side].rotation_euler.x = 0.25
        _out(j, side, 0.12)
    j["torso"].rotation_euler.x = 0.04


# The right foot kicks: back-swing, coming through, contact, follow-through, recovering.
# Per frame: kicking hip, kicking knee, standing hip, standing knee, lean, arms out, arm swing.
KICK = [
    (-0.9, -2.0, 0.25, -0.45, 0.3, 0.9, 0.6),
    (-0.4, -1.7, 0.2, -0.4, 0.32, 1.0, 0.4),
    (0.45, -0.35, 0.1, -0.3, 0.12, 1.05, -0.1),
    (1.35, -0.1, 0.0, -0.2, -0.15, 1.1, -0.6),
    (0.35, -0.6, 0.05, -0.15, 0.1, 0.5, -0.2),
]


def kick(j, i, n):
    hip, knee, stand_hip, stand_knee, lean, arms, swing = KICK[i]
    j["hipR"].rotation_euler.x = hip
    j["kneeR"].rotation_euler.x = knee
    j["ankleR"].rotation_euler.x = 0.4 if i >= 2 else -0.2  # toes pointed through the ball
    j["hipL"].rotation_euler.x = stand_hip
    j["kneeL"].rotation_euler.x = stand_knee
    for side in ("L", "R"):
        _out(j, side, arms)
        j["elbow" + side].rotation_euler.x = 0.5
    j["shoulderL"].rotation_euler.x = swing  # the other arm comes across against the kick
    j["shoulderR"].rotation_euler.x = -swing
    j["torso"].rotation_euler.x = lean
    j["torso"].rotation_euler.z = -0.45 * swing  # the shoulders turn against the leg


# name in the game: pose, frames, start tick of each frame (FIFA 96's timing for the same
# animation, so loops and the kick's contact time stay what the game is tuned to)
ANIMS = {
    "run": (run, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29]),
    "jog": (jog, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29]),
    "xstandd": (stand, 1, [1]),
    "kick": (kick, 5, [4, 7, 10, 13, 18]),
}


def setup_scene():
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = 1  # codes: one ray a pixel, at its centre, so no two codes blend
    s.cycles.filter_width = 0.01
    s.cycles.device = "CPU"
    s.cycles.use_denoising = False  # the distro build has no OpenImageDenoise; the downscale smooths the noise
    s.render.resolution_x = CELL
    s.render.resolution_y = CELL
    s.render.film_transparent = True
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.render.image_settings.color_depth = "8"
    s.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ORTHO
    target = Vector((0.0, 0.0, 0.9))
    cam.location = target + Vector((0.0, -math.cos(ELEVATION), math.sin(ELEVATION))) * 10.0
    cam.rotation_euler = (math.pi / 2.0 - ELEVATION, 0.0, 0.0)
    s.collection.objects.link(cam)
    s.camera = cam
    return s, cam


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s, cam = setup_scene()
    j = build()
    o = world_to_camera_view(s, cam, Vector((0.0, 0.0, 0.0)))
    for anim in WANTED:
        pose, frames, ticks = ANIMS[anim]
        out = os.path.join(OUT, anim)
        os.makedirs(out, exist_ok=True)
        for d, heading in DIRECTIONS.items():
            # the figure faces +Y (into the screen); turn it to face `heading`
            j["root"].rotation_euler.z = math.radians(heading - 90.0)
            for f in range(frames):
                _rest(j)
                pose(j, f, frames)
                _ground(j)
                s.render.filepath = os.path.join(out, "%d_%02d.png" % (d, f))
                bpy.ops.render.render(write_still=True)
        with open(os.path.join(out, "origin.json"), "w") as fh:
            json.dump({"cell": CELL, "x": o.x * CELL, "y": (1.0 - o.y) * CELL, "ticks": ticks}, fh)


WANTED = ARGS[1:] or list(ANIMS)
main()
