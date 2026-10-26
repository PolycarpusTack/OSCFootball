"""A low-poly footballer's animations (ANIMS: run, jog, stand, kick and the specials), on the spot, rendered from
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
CELL = 320  # render size; the sprite is a quarter of it. Room above for the jumps.
ORTHO = 3.2  # metres across the render: 1.8 m tall comes out about 44 px at 80 px
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
    j["torso"].rotation_euler.x = -lean  # +x tilts back
    j["torso"].rotation_euler.z = 0.12 * swing * math.sin(phase)
    j["head"].rotation_euler.x = 0.5 * lean  # keeps the eyes up


def _ground(j, lift=0.0):
    """Down (or up) until the lowest point of the body touches the ground, where the sprite's
    anchor is, then `lift` metres up for a jump. Standing, that's a boot; diving, the chest."""
    bpy.context.view_layer.update()
    low = min((o.matrix_world @ v.co).z for o in bpy.context.scene.objects if o.type == "MESH"
              for v in o.data.vertices)
    j["pelvis"].location.z += lift - low
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


def keyed(table):
    """A pose from a table, one entry a frame: joint name -> its rotation in radians (x alone, or
    (x, y, z) with None to leave an axis), "outL"/"outR" -> how far that arm is lifted sideways
    (_out), "lift" -> metres off the ground. x swings a hip, shoulder or elbow forward, folds a
    knee back when negative and tilts the torso or the pelvis (the whole body) back; the
    pelvis's z turns the whole body round, its y rolls it (diving, along its length)."""
    def pose(j, i, n):
        for side in ("L", "R"):
            _out(j, side, 0.12)
        lift = 0.0
        for name, v in table[i].items():
            if name == "lift":
                lift = v
            elif name.startswith("out"):
                _out(j, name[3:], v)
            else:
                for axis, a in enumerate(v if isinstance(v, tuple) else (v,)):
                    if a is not None:
                        j[name].rotation_euler[axis] = a
        return lift
    return pose


# The specials, as keyed() tables. Drawn facing right: the right leg is the kicking leg.
# A low ready stance: the left foot forward, knees bent, fists up.
READY = {"hipL": 0.4, "kneeL": -0.6, "hipR": -0.35, "kneeR": -0.5, "torso": -0.15,
         "shoulderL": 0.5, "shoulderR": 0.3, "elbowL": 1.6, "elbowR": 1.6, "outL": 0.35, "outR": 0.35}
# Crouched to spring: both knees deep, arms back.
CROUCH = {"hipL": 0.9, "kneeL": -1.6, "hipR": 0.7, "kneeR": -1.5, "torso": -0.5, "ankleL": -0.4,
          "ankleR": -0.4, "shoulderL": -0.6, "shoulderR": -0.6, "elbowL": 0.4, "elbowR": 0.4}

POWER_STRIKE = keyed([
    READY,
    {**READY, "hipR": -0.9, "kneeR": -1.4, "torso": 0.1, "shoulderL": -0.7, "shoulderR": -0.7, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -0.6, "kneeR": -1.8, "torso": -0.1, "shoulderL": 0.6, "shoulderR": 0.6, "elbowL": 1.0, "elbowR": 1.0},
    {"hipL": -0.1, "kneeL": -0.3, "hipR": 1.5, "kneeR": -0.05, "ankleR": -0.4, "torso": 0.25,
     "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 0.1, "elbowR": 0.1, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.0, "kneeL": -0.4, "hipR": 0.9, "kneeR": -0.4, "torso": 0.1, "shoulderL": 1.2, "shoulderR": 1.2, "elbowL": 0.3, "elbowR": 0.3},
    READY,
])

BULLDOZER_CLEAR = keyed([
    READY,
    CROUCH,
    {"pelvis": -0.7, "hipL": -0.2, "kneeL": -0.8, "hipR": -0.5, "kneeR": -0.3, "shoulderL": 2.6, "shoulderR": 2.4, "elbowL": 0.2, "elbowR": 0.2, "lift": 0.35},
    {"pelvis": (-1.5, 0.9, 0.0), "hipL": 0.0, "hipR": -0.1, "kneeL": -0.2, "kneeR": -0.4, "shoulderL": 2.9, "shoulderR": 2.9, "lift": 0.45},
    {"pelvis": (-1.55, 2.6, 0.0), "hipL": 0.1, "hipR": 0.0, "kneeL": -0.3, "kneeR": -0.2, "shoulderL": 2.9, "shoulderR": 2.9, "lift": 0.15},
    {"pelvis": -0.6, "hipL": 1.4, "kneeL": -2.0, "hipR": -0.6, "kneeR": -0.3, "torso": -0.3, "shoulderL": 1.4, "shoulderR": 0.6, "elbowL": 0.2, "elbowR": 0.3},
])

GRAPPLE_TACKLE = keyed([
    {**READY, "shoulderL": 1.3, "shoulderR": 1.3, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.5, "outR": 0.5},
    {**READY, "torso": -0.4, "hipL": 0.7, "kneeL": -0.9, "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 1.2, "elbowR": 1.2, "outL": 0.2, "outR": 0.2},
    {"pelvis": (None, None, 1.4), "hipL": 0.3, "kneeL": -0.5, "hipR": -0.3, "kneeR": -0.5, "torso": 0.1,
     "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 1.3, "elbowR": 1.3, "outL": 0.2, "outR": 0.2},
    {"pelvis": (None, None, 2.9), "hipL": -0.3, "kneeL": -0.5, "hipR": 0.4, "kneeR": -0.5, "torso": 0.15,
     "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 1.3, "elbowR": 1.3, "outL": 0.2, "outR": 0.2},
    {"pelvis": (None, None, 4.6), "hipL": 0.3, "kneeL": -0.4, "hipR": -0.2, "kneeR": -0.4,
     "shoulderL": 1.0, "shoulderR": 1.0, "elbowL": 0.2, "elbowR": 0.2, "outL": 1.0, "outR": 1.0},
    READY,
])

LASER_PASS = keyed([
    READY,
    {**READY, "hipL": 0.6, "kneeL": -0.9, "hipR": -0.7, "kneeR": -0.4, "torso": -0.3,
     "shoulderL": -0.8, "shoulderR": -0.8, "elbowL": 0.3, "elbowR": 0.3},
    {"hipL": 0.1, "kneeL": -0.5, "hipR": -0.8, "kneeR": -1.5, "torso": -0.2, "shoulderL": 0.4, "shoulderR": 0.2, "elbowL": 1.2, "elbowR": 1.2},
    {"hipL": -0.2, "kneeL": -0.4, "hipR": 1.25, "kneeR": -0.05, "ankleR": -0.3, "torso": 0.15,
     "shoulderL": 1.6, "shoulderR": 1.6, "elbowL": 0.0, "elbowR": 0.0, "outL": 0.1, "outR": 0.1},
    {"hipL": 0.0, "kneeL": -0.4, "hipR": 0.8, "kneeR": -0.5, "torso": 0.05, "shoulderL": 1.0, "shoulderR": 0.6, "elbowL": 0.5, "elbowR": 0.5, "outL": 0.6, "outR": 0.6},
    READY,
])

WHIRLWIND_TURN = keyed([
    READY,
    {"hipL": 1.3, "kneeL": -2.0, "hipR": 0.6, "kneeR": -1.4, "torso": -0.2, "shoulderL": 1.0, "shoulderR": 0.6, "elbowL": 1.2, "elbowR": 1.2, "lift": 0.3},
    {"pelvis": (0.3, None, 1.6), "hipL": 1.2, "kneeL": -1.8, "hipR": (0.2, -1.3, None), "kneeR": 0.0, "outL": 1.3, "outR": 1.3, "lift": 0.4},
    {"pelvis": (0.3, None, 3.6), "hipL": 1.2, "kneeL": -1.8, "hipR": (0.2, -1.3, None), "kneeR": 0.0, "outL": 1.3, "outR": 1.3, "lift": 0.35},
    {"pelvis": (None, None, 6.0), "hipL": 0.5, "kneeL": -1.2, "hipR": 0.8, "kneeR": -1.5, "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 1.0, "elbowR": 1.0, "lift": 0.1},
    READY,
])

# The keeper: arms crossed at the chest, a sweeping punt.
CROSSED = {"shoulderL": 1.3, "shoulderR": 1.3, "elbowL": 1.7, "elbowR": 1.7, "outL": -0.25, "outR": -0.25}
CANNON_PUNT = keyed([
    {**READY, **CROSSED},
    {**READY, **CROSSED, "hipL": 0.6, "kneeL": -1.0, "hipR": -0.5, "kneeR": -0.8, "torso": -0.35},
    {"hipL": 0.3, "kneeL": -0.5, "hipR": -0.9, "kneeR": -1.4, "torso": 0.1, "shoulderL": 0.4, "shoulderR": 0.4, "elbowL": 0.2, "elbowR": 0.2, "outL": 1.4, "outR": 1.4},
    {"hipL": -0.1, "kneeL": -0.2, "hipR": 1.9, "kneeR": 0.0, "ankleR": -0.4, "torso": 0.4, "shoulderL": 0.6, "shoulderR": 0.2, "outL": 1.3, "outR": 1.3},
    {"hipL": 0.0, "kneeL": -0.3, "hipR": 1.0, "kneeR": -0.6, "torso": 0.2, "shoulderL": 0.8, "shoulderR": 0.4, "outL": 1.0, "outR": 1.0},
    READY,
])

RISING_FIST = keyed([
    READY,
    {**CROUCH, "shoulderR": 0.4, "elbowR": 2.0, "shoulderL": 0.3, "elbowL": 1.8},
    {"hipL": 0.9, "kneeL": -1.5, "hipR": -0.1, "kneeR": -0.3, "torso": 0.0, "shoulderR": 3.0, "elbowR": 0.1, "shoulderL": 0.5, "elbowL": 1.5, "lift": 0.45},
    {"pelvis": 0.35, "hipL": 1.1, "kneeL": -1.8, "hipR": 0.3, "kneeR": -1.2, "torso": 0.3, "head": 0.3, "shoulderR": 3.1, "elbowR": 0.0,
     "shoulderL": 1.8, "elbowL": 0.2, "outL": 0.6, "lift": 0.65},
    {"hipL": 0.5, "kneeL": -1.0, "hipR": 0.3, "kneeR": -0.9, "torso": 0.1, "shoulderR": 1.6, "elbowR": 0.8, "shoulderL": 0.8, "elbowL": 0.8, "lift": 0.25},
    {**READY, "hipL": 0.7, "kneeL": -1.2, "hipR": 0.4, "kneeR": -1.1, "torso": -0.3},
])

# Low, quick stepovers: the free leg swings round over the ball, outward and back.
_LOW = {"torso": -0.25, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 1.4, "elbowR": 1.4, "outL": 0.5, "outR": 0.5}
STEPOVER_STORM = keyed([
    {**_LOW, "hipL": 0.3, "kneeL": -0.7, "hipR": -0.2, "kneeR": -0.6},
    {**_LOW, "hipL": 0.0, "kneeL": -0.6, "hipR": (0.9, -0.8, None), "kneeR": -1.3},
    {**_LOW, "hipL": 0.1, "kneeL": -0.6, "hipR": (0.4, -1.1, None), "kneeR": -0.9, "torso": (-0.25, 0.25, None)},
    {**_LOW, "hipR": 0.0, "kneeR": -0.6, "hipL": (0.9, 0.8, None), "kneeL": -1.3},
    {**_LOW, "hipR": 0.1, "kneeR": -0.6, "hipL": (0.4, 1.1, None), "kneeL": -0.9, "torso": (-0.25, -0.25, None)},
    {**_LOW, "hipL": 0.3, "kneeL": -0.7, "hipR": -0.2, "kneeR": -0.6},
])

# Specials borrowed from FIFA 96's animation names, on FIFA 96's frame timing.
VOLLEY = keyed([
    {"hipL": 0.5, "kneeL": -0.8, "hipR": -0.4, "kneeR": -0.6, "torso": -0.1, "shoulderL": -0.4, "shoulderR": 0.5, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.6, "kneeL": -1.4, "hipR": (-0.2, -0.9, None), "kneeR": -1.6, "torso": (0.2, 0.3, None), "outL": 1.2, "outR": 0.8, "lift": 0.2},
    {"pelvis": (0.2, 0.35, -0.6), "hipL": 0.2, "kneeL": -0.6, "hipR": (1.3, -1.0, None), "kneeR": -0.1, "outL": 1.4, "outR": 1.0, "lift": 0.2},
    {"pelvis": (0.1, 0.2, -1.2), "hipL": 0.1, "kneeL": -0.5, "hipR": (0.9, -0.4, None), "kneeR": -0.5, "outL": 1.1, "outR": 0.9, "lift": 0.05},
    {"hipL": 0.2, "kneeL": -0.5, "hipR": 0.4, "kneeR": -0.6, "torso": -0.1, "shoulderL": 0.3, "shoulderR": -0.2, "elbowL": 0.6, "elbowR": 0.6},
])

BICYCLE = keyed([
    {"hipL": 0.4, "kneeL": -0.9, "hipR": 0.3, "kneeR": -0.9, "torso": -0.2, "shoulderL": -0.3, "shoulderR": -0.3},
    {"pelvis": 0.6, "hipL": 1.2, "kneeL": -1.2, "hipR": 0.2, "kneeR": -0.4, "outL": 1.0, "outR": 1.0, "lift": 0.35},
    {"pelvis": 1.3, "hipL": 0.6, "kneeL": -0.5, "hipR": 1.4, "kneeR": -1.2, "outL": 1.3, "outR": 1.3, "lift": 0.7},
    {"pelvis": 2.1, "hipL": 0.2, "kneeL": -0.3, "hipR": 1.9, "kneeR": -0.1, "ankleR": -0.4, "outL": 1.4, "outR": 1.4, "lift": 0.8},
    {"pelvis": 2.3, "hipL": 1.6, "kneeL": -0.2, "hipR": 0.5, "kneeR": -0.6, "outL": 1.4, "outR": 1.4, "lift": 0.6},
    {"pelvis": 1.7, "hipL": 1.0, "kneeL": -0.8, "hipR": 0.8, "kneeR": -0.8, "shoulderL": -0.8, "shoulderR": -0.8, "outL": 0.6, "outR": 0.6, "lift": 0.25},
    {"pelvis": 1.5, "hipL": 0.6, "kneeL": -0.9, "hipR": 0.3, "kneeR": -0.5, "shoulderL": -0.4, "shoulderR": -0.4, "elbowL": 1.0, "elbowR": 1.0, "outL": 0.7, "outR": 0.7},
])

TACKLE = keyed([
    {"hipL": 0.4, "kneeL": -0.7, "hipR": -0.4, "kneeR": -0.6, "torso": -0.2, "shoulderL": -0.4, "shoulderR": 0.4, "elbowL": 0.8, "elbowR": 0.8},
    {"hipL": -0.3, "kneeL": -1.3, "hipR": 1.3, "kneeR": -0.1, "ankleR": 0.3, "torso": -0.3, "outL": 0.7, "outR": 0.6, "shoulderL": 0.5, "shoulderR": -0.3},
    {"hipL": -0.4, "kneeL": -1.5, "hipR": 1.5, "kneeR": 0.0, "ankleR": 0.4, "torso": -0.35, "outL": 0.8, "outR": 0.7, "shoulderL": 0.6, "shoulderR": -0.4},
    {"hipL": 0.2, "kneeL": -0.9, "hipR": 0.6, "kneeR": -0.6, "torso": -0.2, "shoulderL": 0.2, "shoulderR": 0.2, "elbowL": 0.8, "elbowR": 0.8},
])

HEADER = keyed([
    {"hipL": 0.4, "kneeL": -0.8, "hipR": 0.3, "kneeR": -0.8, "torso": -0.2, "shoulderL": -0.4, "shoulderR": -0.4, "elbowL": 0.6, "elbowR": 0.6},
    {**CROUCH},
    {"hipL": 0.1, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.4, "torso": 0.3, "head": 0.3, "shoulderL": 1.0, "shoulderR": 1.0, "elbowL": 1.2, "elbowR": 1.2, "outL": 0.6, "outR": 0.6, "lift": 0.35},
    {"hipL": 0.0, "kneeL": -0.8, "hipR": -0.2, "kneeR": -1.0, "torso": -0.5, "head": -0.4, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.8, "elbowR": 0.8, "outL": 0.9, "outR": 0.9, "lift": 0.45},
    {"hipL": 0.1, "kneeL": -0.6, "hipR": 0.0, "kneeR": -0.7, "torso": -0.3, "head": -0.2, "shoulderL": 0.4, "shoulderR": 0.4, "outL": 0.8, "outR": 0.8, "lift": 0.3},
    {"hipL": 0.3, "kneeL": -0.4, "hipR": 0.2, "kneeR": -0.4, "torso": -0.1, "shoulderL": 0.4, "shoulderR": 0.4, "outL": 0.6, "outR": 0.6, "lift": 0.1},
    {"hipL": 0.6, "kneeL": -1.0, "hipR": 0.5, "kneeR": -1.0, "torso": -0.3, "shoulderL": 0.2, "shoulderR": 0.2, "elbowL": 0.6, "elbowR": 0.6},
])

# The sole drags the ball back, then the other foot pokes it through, then away.
NUTMEG = keyed([
    {"hipL": 0.1, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.3, "torso": -0.1, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.0, "kneeL": -0.4, "hipR": 0.6, "kneeR": -0.5, "ankleR": 0.5, "torso": -0.1, "outL": 0.4, "outR": 0.3, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.0, "kneeL": -0.5, "hipR": 0.1, "kneeR": -0.9, "ankleR": 0.5, "torso": -0.15, "outL": 0.5, "outR": 0.4, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.0, "kneeL": -0.5, "hipR": -0.4, "kneeR": -1.2, "torso": -0.2, "outL": 0.5, "outR": 0.4, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.4, "kneeL": -0.6, "hipR": -0.3, "kneeR": -0.5, "torso": -0.2, "outL": 0.4, "outR": 0.5, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": (0.5, 0.3, None), "kneeL": -0.3, "hipR": 0.0, "kneeR": -0.6, "torso": -0.25, "outL": 0.6, "outR": 0.5, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.1, "kneeL": -0.5, "hipR": 0.4, "kneeR": -0.7, "torso": -0.25, "shoulderL": 0.4, "shoulderR": -0.4, "elbowL": 0.9, "elbowR": 0.9},
    {"hipL": -0.4, "kneeL": -0.9, "hipR": 0.6, "kneeR": -0.5, "torso": -0.3, "shoulderL": 0.6, "shoulderR": -0.6, "elbowL": 1.2, "elbowR": 1.2},
    {"hipL": 0.6, "kneeL": -0.6, "hipR": -0.5, "kneeR": -1.0, "torso": -0.3, "shoulderL": -0.6, "shoulderR": 0.6, "elbowL": 1.2, "elbowR": 1.2},
])

# Jockeying: low, side-on, small shuffles; a loop.
MARK = keyed([
    {"hipL": (0.3, 0.15, None), "kneeL": -0.7, "hipR": (-0.2, -0.15, None), "kneeR": -0.7, "torso": -0.3, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.6, "outR": 0.6},
    {"hipL": (0.3, 0.3, None), "kneeL": -0.8, "hipR": (-0.2, -0.05, None), "kneeR": -0.6, "torso": -0.3, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.65, "outR": 0.55},
    {"hipL": (0.3, 0.15, None), "kneeL": -0.7, "hipR": (-0.2, -0.15, None), "kneeR": -0.7, "torso": -0.3, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.6, "outR": 0.6},
    {"hipL": (0.3, 0.05, None), "kneeL": -0.6, "hipR": (-0.2, -0.3, None), "kneeR": -0.8, "torso": -0.3, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.55, "outR": 0.65},
])

FALL = keyed([
    {"hipL": 0.5, "kneeL": -0.5, "hipR": -0.6, "kneeR": -1.2, "torso": -0.3, "shoulderL": 0.8, "shoulderR": -0.4, "outL": 0.6, "outR": 0.6},
    {"pelvis": -0.5, "hipL": 0.3, "kneeL": -0.3, "hipR": -0.7, "kneeR": -0.9, "shoulderL": 1.4, "shoulderR": 1.0, "outL": 0.8, "outR": 0.8, "lift": 0.1},
    {"pelvis": -1.0, "hipL": 0.1, "kneeL": -0.3, "hipR": -0.5, "kneeR": -0.7, "shoulderL": 1.8, "shoulderR": 1.7, "elbowL": 0.4, "elbowR": 0.4, "outL": 0.5, "outR": 0.5, "lift": 0.15},
    {"pelvis": -1.4, "hipL": 0.0, "kneeL": -0.4, "hipR": -0.2, "kneeR": -0.6, "shoulderL": 2.2, "shoulderR": 2.1, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.4, "outR": 0.4},
    {"pelvis": -1.55, "hipL": 0.0, "kneeL": -0.3, "hipR": 0.0, "kneeR": -0.5, "head": 0.6, "shoulderL": 2.6, "shoulderR": 2.5, "elbowL": 1.4, "elbowR": 1.4, "outL": 0.5, "outR": 0.5},
    {"pelvis": -1.55, "hipL": 0.0, "kneeL": -0.8, "hipR": 0.0, "kneeR": -0.3, "head": 0.7, "shoulderL": 2.5, "shoulderR": 2.7, "elbowL": 1.5, "elbowR": 1.2, "outL": 0.5, "outR": 0.5},
])

# The keeper's ground pound: up, and both fists down on the turf.
GPOUND = keyed([
    {"hipL": 0.4, "kneeL": -0.8, "hipR": 0.3, "kneeR": -0.8, "torso": -0.2, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 1.2, "elbowR": 1.2},
    {**CROUCH},
    {"hipL": 0.1, "kneeL": -0.3, "hipR": 0.0, "kneeR": -0.3, "torso": 0.15, "shoulderL": 3.0, "shoulderR": 3.0, "elbowL": 0.3, "elbowR": 0.3, "outL": 0.2, "outR": 0.2, "lift": 0.35},
    {"hipL": 0.8, "kneeL": -1.3, "hipR": 0.7, "kneeR": -1.3, "torso": 0.05, "shoulderL": 3.1, "shoulderR": 3.1, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.15, "outR": 0.15, "lift": 0.4},
    {"hipL": 1.2, "kneeL": -2.0, "hipR": 1.1, "kneeR": -2.0, "torso": -0.6, "shoulderL": 1.2, "shoulderR": 1.2, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.15, "outR": 0.15},
    {"hipL": 1.3, "kneeL": -2.2, "hipR": 1.2, "kneeR": -2.2, "torso": -0.9, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 0.1, "elbowR": 0.1, "outL": 0.15, "outR": 0.15},
    {"hipL": 1.3, "kneeL": -2.2, "hipR": 1.2, "kneeR": -2.2, "torso": -0.9, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 0.1, "elbowR": 0.1, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.4, "kneeL": -0.8, "hipR": 0.3, "kneeR": -0.8, "torso": -0.3, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 1.0, "elbowR": 1.0},
])

# The keeper rolls the ball out underarm with the right hand.
GLWTHRW = keyed([
    {"hipL": 0.1, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.3, "torso": -0.1, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.4, "elbowR": 1.4, "outL": -0.1, "outR": -0.1},
    {"hipL": 0.5, "kneeL": -0.6, "hipR": -0.4, "kneeR": -0.5, "torso": -0.2, "shoulderL": 0.9, "shoulderR": -1.2, "elbowL": 0.6, "elbowR": 0.3},
    {"hipL": 0.9, "kneeL": -1.4, "hipR": -0.6, "kneeR": -0.6, "torso": -0.7, "shoulderL": 0.6, "shoulderR": -0.3, "elbowL": 0.5, "elbowR": 0.2},
    {"hipL": 0.9, "kneeL": -1.5, "hipR": -0.7, "kneeR": -0.5, "torso": -0.75, "shoulderL": 0.4, "shoulderR": 0.9, "elbowL": 0.5, "elbowR": 0.1},
    {"hipL": 0.8, "kneeL": -1.2, "hipR": -0.5, "kneeR": -0.6, "torso": -0.6, "shoulderL": 0.3, "shoulderR": 1.4, "elbowL": 0.5, "elbowR": 0.1},
    {"hipL": 0.3, "kneeL": -0.5, "hipR": -0.2, "kneeR": -0.4, "torso": -0.2, "shoulderL": 0.2, "shoulderR": 0.4, "elbowL": 0.6, "elbowR": 0.6},
])

# The keeper punches a high ball away with both fists.
GPUNCHU = keyed([
    {"hipL": 0.4, "kneeL": -0.8, "hipR": 0.3, "kneeR": -0.8, "torso": -0.2, "shoulderL": 0.6, "shoulderR": 0.6, "elbowL": 1.6, "elbowR": 1.6},
    {**CROUCH, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 2.0, "elbowR": 2.0},
    {"hipL": 0.6, "kneeL": -1.2, "hipR": 0.0, "kneeR": -0.3, "torso": 0.1, "shoulderL": 2.9, "shoulderR": 2.9, "elbowL": 0.1, "elbowR": 0.1, "outL": 0.05, "outR": 0.05, "lift": 0.45},
    {"pelvis": 0.15, "hipL": 0.8, "kneeL": -1.5, "hipR": 0.2, "kneeR": -0.6, "torso": 0.15, "shoulderL": 3.1, "shoulderR": 3.1, "elbowL": 0.0, "elbowR": 0.0, "outL": 0.05, "outR": 0.05, "lift": 0.55},
    {"hipL": 0.5, "kneeL": -0.9, "hipR": 0.3, "kneeR": -0.8, "shoulderL": 1.8, "shoulderR": 1.8, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.5, "outR": 0.5, "lift": 0.2},
    {"hipL": 0.5, "kneeL": -1.0, "hipR": 0.4, "kneeR": -1.0, "torso": -0.3, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 1.2, "elbowR": 1.2},
])


# Everyday play, on FIFA 96's frame timing.
def walk(j, i, n):
    _stride(j, i / n * math.tau, swing=0.35, fold=0.5, lean=0.04, arms=0.3, elbow=0.3)


SHOOT = keyed([
    {"hipL": 0.6, "kneeL": -0.5, "hipR": -0.6, "kneeR": -1.2, "torso": -0.2, "shoulderL": -0.5, "shoulderR": 0.6, "elbowL": 0.8, "elbowR": 0.8},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -1.0, "kneeR": -2.0, "torso": 0.1, "outL": 1.0, "outR": 0.8, "shoulderL": 0.5, "shoulderR": -0.4},
    {"hipL": 0.1, "kneeL": -0.4, "hipR": -0.3, "kneeR": -1.8, "torso": 0.1, "outL": 1.1, "outR": 0.9, "shoulderL": 0.4, "shoulderR": -0.3},
    {"hipL": 0.1, "kneeL": -0.35, "hipR": 0.6, "kneeR": -0.3, "ankleR": -0.3, "torso": 0.0, "outL": 1.1, "outR": 1.0, "shoulderL": -0.1, "shoulderR": 0.1},
    {"hipL": 0.0, "kneeL": -0.2, "hipR": 1.6, "kneeR": -0.1, "ankleR": -0.4, "torso": 0.25, "outL": 1.0, "outR": 1.0, "shoulderL": -0.6, "shoulderR": 0.6, "lift": 0.05},
    {"hipL": 0.1, "kneeL": -0.5, "hipR": 0.9, "kneeR": -0.6, "torso": 0.1, "outL": 0.7, "outR": 0.7, "shoulderL": -0.3, "shoulderR": 0.3},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": 0.2, "kneeR": -0.5, "torso": -0.05, "outL": 0.3, "outR": 0.3, "elbowL": 0.5, "elbowR": 0.5},
])

SLIDE = keyed([
    {"hipL": 0.6, "kneeL": -0.6, "hipR": -0.5, "kneeR": -1.1, "torso": -0.3, "shoulderL": -0.6, "shoulderR": 0.6, "elbowL": 1.0, "elbowR": 1.0},
    {"pelvis": 0.5, "hipL": -0.2, "kneeL": -1.4, "hipR": 0.8, "kneeR": -0.2, "torso": -0.2, "shoulderL": -0.6, "outL": 0.7, "outR": 0.7},
    {"pelvis": (1.2, 0.3, None), "hipL": -0.3, "kneeL": -1.6, "hipR": 0.3, "kneeR": -0.05, "torso": -0.45, "shoulderL": -0.9, "shoulderR": -0.4, "outL": 0.6, "outR": 0.9},
    {"pelvis": (1.25, 0.3, None), "hipL": -0.3, "kneeL": -1.6, "hipR": 0.25, "kneeR": -0.05, "torso": -0.5, "shoulderL": -1.0, "shoulderR": -0.3, "outL": 0.6, "outR": 1.0},
    {"pelvis": 0.4, "hipL": 1.4, "kneeL": -2.2, "hipR": -0.6, "kneeR": -1.6, "torso": -0.4, "shoulderL": 0.5, "shoulderR": -0.3, "elbowL": 0.4},
])

# Both hands bring the ball from behind the head.
THROWIN = keyed([
    {"hipL": 0.2, "kneeL": -0.2, "hipR": -0.2, "kneeR": -0.2, "shoulderL": 1.2, "shoulderR": 1.2, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.2, "outR": 0.2},
    {"hipL": 0.4, "kneeL": -0.3, "hipR": -0.3, "kneeR": -0.4, "torso": 0.35, "shoulderL": 2.8, "shoulderR": 2.8, "elbowL": 0.9, "elbowR": 0.9, "outL": 0.2, "outR": 0.2},
    {"hipL": 0.4, "kneeL": -0.5, "hipR": -0.3, "kneeR": -0.5, "torso": 0.45, "shoulderL": 2.7, "shoulderR": 2.7, "elbowL": 1.2, "elbowR": 1.2, "outL": 0.2, "outR": 0.2},
    {"hipL": 0.3, "kneeL": -0.4, "hipR": -0.4, "kneeR": -0.4, "torso": -0.1, "shoulderL": 2.9, "shoulderR": 2.9, "elbowL": 0.4, "elbowR": 0.4, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.3, "kneeL": -0.4, "hipR": -0.4, "kneeR": -0.5, "torso": -0.35, "shoulderL": 2.0, "shoulderR": 2.0, "elbowL": 0.1, "elbowR": 0.1, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.2, "kneeL": -0.3, "hipR": -0.2, "kneeR": -0.3, "torso": -0.1, "shoulderL": 0.4, "shoulderR": 0.4, "elbowL": 0.4, "elbowR": 0.4},
])

# A hop over a lunging tackle.
JUMP = keyed([
    {"hipL": 0.5, "kneeL": -1.0, "hipR": 0.3, "kneeR": -1.0, "torso": -0.35, "shoulderL": -0.5, "shoulderR": -0.5, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.2, "kneeL": -0.3, "hipR": -0.3, "kneeR": -0.4, "torso": -0.1, "shoulderL": 0.9, "shoulderR": 0.6, "elbowL": 0.9, "elbowR": 0.9, "lift": 0.1},
    {"hipL": 1.3, "kneeL": -2.0, "hipR": 1.0, "kneeR": -2.0, "torso": -0.2, "shoulderL": 1.2, "shoulderR": 1.0, "elbowL": 0.8, "elbowR": 0.8, "outL": 0.6, "outR": 0.6, "lift": 0.45},
    {"hipL": 1.2, "kneeL": -1.8, "hipR": 0.8, "kneeR": -1.8, "torso": -0.15, "shoulderL": 1.0, "shoulderR": 0.9, "elbowL": 0.8, "elbowR": 0.8, "outL": 0.8, "outR": 0.8, "lift": 0.5},
    {"hipL": 0.5, "kneeL": -0.7, "hipR": 0.2, "kneeR": -0.6, "torso": -0.1, "shoulderL": 0.6, "shoulderR": 0.5, "outL": 0.7, "outR": 0.7, "lift": 0.2},
    {"hipL": 0.6, "kneeL": -1.1, "hipR": 0.3, "kneeR": -1.0, "torso": -0.3, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.4, "outR": 0.4},
])

# Leaning back to take the ball on the chest, arms out, then it drops to the feet.
CHEST = keyed([
    {"hipL": 0.2, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.3, "torso": 0.15, "outL": 0.6, "outR": 0.6, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.3, "kneeL": -0.6, "hipR": -0.1, "kneeR": -0.6, "torso": 0.45, "head": -0.3, "outL": 0.9, "outR": 0.9, "elbowL": 0.4, "elbowR": 0.4},
    {"hipL": 0.3, "kneeL": -0.5, "hipR": -0.1, "kneeR": -0.5, "torso": 0.3, "head": 0.2, "outL": 0.8, "outR": 0.8, "elbowL": 0.4, "elbowR": 0.4},
    {"hipL": 0.2, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.3, "torso": -0.1, "head": 0.3, "outL": 0.4, "outR": 0.4, "elbowL": 0.5, "elbowR": 0.5},
])

# Tripped: lurches forward, arms flung out, and catches himself.
STUMBLE = keyed([
    {"hipL": 0.4, "kneeL": -0.4, "hipR": -0.7, "kneeR": -1.3, "torso": -0.3, "shoulderL": 0.4, "shoulderR": -0.4, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": -0.2, "kneeL": -0.5, "hipR": -0.9, "kneeR": -1.5, "torso": -0.6, "head": 0.3, "shoulderL": 1.4, "shoulderR": 1.1, "outL": 0.9, "outR": 0.9},
    {"hipL": -0.4, "kneeL": -0.6, "hipR": 0.6, "kneeR": -0.8, "torso": -0.75, "head": 0.4, "shoulderL": 1.8, "shoulderR": 1.5, "outL": 1.0, "outR": 1.0},
    {"hipL": 0.7, "kneeL": -1.0, "hipR": -0.5, "kneeR": -0.6, "torso": -0.65, "head": 0.4, "shoulderL": 1.2, "shoulderR": 1.6, "outL": 1.1, "outR": 0.8},
    {"hipL": -0.3, "kneeL": -0.6, "hipR": 0.6, "kneeR": -0.9, "torso": -0.5, "head": 0.3, "shoulderL": 0.8, "shoulderR": 0.6, "outL": 0.9, "outR": 0.9},
    {"hipL": 0.5, "kneeL": -0.7, "hipR": -0.3, "kneeR": -0.7, "torso": -0.35, "head": 0.2, "shoulderL": 0.2, "shoulderR": 0.4, "outL": 0.6, "outR": 0.6},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -0.1, "kneeR": -0.4, "torso": -0.15, "outL": 0.3, "outR": 0.3, "elbowL": 0.5, "elbowR": 0.5},
])

# Two-handed shove.
PUSH = keyed([
    {"hipL": 0.4, "kneeL": -0.5, "hipR": -0.4, "kneeR": -0.6, "torso": -0.15, "shoulderL": 0.4, "shoulderR": 0.4, "elbowL": 1.4, "elbowR": 1.4},
    {"hipL": 0.6, "kneeL": -0.8, "hipR": -0.4, "kneeR": -0.5, "torso": -0.25, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.7, "elbowR": 1.7, "outL": 0.2, "outR": 0.2},
    {"hipL": 0.7, "kneeL": -0.9, "hipR": -0.6, "kneeR": -0.3, "torso": -0.4, "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 0.4, "elbowR": 0.4, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.7, "kneeL": -0.9, "hipR": -0.7, "kneeR": -0.2, "torso": -0.5, "shoulderL": 1.6, "shoulderR": 1.6, "elbowL": 0.05, "elbowR": 0.05, "outL": 0.15, "outR": 0.15},
    {"hipL": 0.6, "kneeL": -0.8, "hipR": -0.5, "kneeR": -0.4, "torso": -0.35, "shoulderL": 1.3, "shoulderR": 1.3, "elbowL": 0.3, "elbowR": 0.3, "outL": 0.2, "outR": 0.2},
    {"hipL": 0.4, "kneeL": -0.6, "hipR": -0.3, "kneeR": -0.5, "torso": -0.2, "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 0.9, "elbowR": 0.9},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -0.2, "kneeR": -0.4, "torso": -0.1, "shoulderL": 0.3, "shoulderR": 0.3, "elbowL": 0.6, "elbowR": 0.6},
])

# Shoulder barge: turns side-on and drives the left shoulder in.
BODYCHK = keyed([
    {"hipL": 0.5, "kneeL": -0.6, "hipR": -0.5, "kneeR": -0.9, "torso": -0.2, "shoulderL": -0.4, "shoulderR": 0.4, "elbowL": 0.8, "elbowR": 0.8},
    {"pelvis": (None, None, 0.6), "hipL": 0.4, "kneeL": -0.7, "hipR": -0.4, "kneeR": -0.7, "torso": (-0.3, -0.2, None), "shoulderL": 0.2, "shoulderR": 0.2, "elbowL": 1.5, "elbowR": 1.2},
    {"pelvis": (None, None, 0.9), "hipL": 0.5, "kneeL": -0.8, "hipR": -0.5, "kneeR": -0.5, "torso": (-0.4, -0.35, None), "shoulderL": 0.1, "shoulderR": 0.3, "elbowL": 1.7, "elbowR": 1.3, "outL": 0.1},
    {"pelvis": (None, None, 1.0), "hipL": 0.6, "kneeL": -0.9, "hipR": -0.7, "kneeR": -0.3, "torso": (-0.45, -0.45, None), "shoulderL": 0.1, "shoulderR": 0.4, "elbowL": 1.8, "elbowR": 1.3, "outL": 0.1, "lift": 0.05},
    {"pelvis": (None, None, 0.8), "hipL": 0.5, "kneeL": -0.8, "hipR": -0.5, "kneeR": -0.6, "torso": (-0.35, -0.3, None), "shoulderL": 0.2, "shoulderR": 0.4, "elbowL": 1.4, "elbowR": 1.2},
    {"pelvis": (None, None, 0.4), "hipL": 0.4, "kneeL": -0.6, "hipR": -0.3, "kneeR": -0.6, "torso": (-0.2, -0.1, None), "shoulderL": 0.2, "shoulderR": 0.3, "elbowL": 1.0, "elbowR": 1.0},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -0.1, "kneeR": -0.4, "torso": -0.1, "elbowL": 0.6, "elbowR": 0.6},
])

# Diving header: launches flat, head first, and lands on the chest.
DIVEHED = keyed([
    {**CROUCH, "shoulderL": -0.3, "shoulderR": -0.3},
    {"pelvis": -0.9, "hipL": -0.3, "kneeL": -0.6, "hipR": -0.5, "kneeR": -0.3, "head": -0.4, "shoulderL": -0.6, "shoulderR": -0.6, "outL": 0.5, "outR": 0.5, "lift": 0.35},
    {"pelvis": -1.45, "hipL": -0.1, "kneeL": -0.3, "hipR": -0.2, "kneeR": -0.4, "head": -0.6, "shoulderL": -0.4, "shoulderR": -0.4, "outL": 0.6, "outR": 0.6, "lift": 0.45},
    {"pelvis": -1.5, "hipL": 0.0, "kneeL": -0.4, "hipR": 0.0, "kneeR": -0.6, "head": -0.5, "shoulderL": 2.2, "shoulderR": 2.2, "elbowL": 0.8, "elbowR": 0.8, "outL": 0.4, "outR": 0.4},
    {"pelvis": -1.55, "hipL": 0.0, "kneeL": -0.5, "hipR": 0.0, "kneeR": -0.3, "head": -0.6, "shoulderL": 2.6, "shoulderR": 2.5, "elbowL": 1.3, "elbowR": 1.3, "outL": 0.5, "outR": 0.5},
])

# The keeper: a set stance, gloves up.
SET = {"hipL": (0.3, 0.15, None), "kneeL": -0.7, "hipR": (0.3, -0.15, None), "kneeR": -0.7, "torso": -0.3,
       "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 0.8, "elbowR": 0.8, "outL": 0.5, "outR": 0.5}


def dive(side, high):
    """A keeper's dive to his left (side -1) or right (+1), high (arms over the head) or low (along
    the ground): set, push off, stretched in the air, down on his side, and lying there."""
    s = side
    turn = 0.6 * s  # turned forward into the dive, so it reads across the screen, not into it
    reach = 2.9 if high else 2.2
    up = 0.55 if high else 0.25
    out = "out" + ("L" if s < 0 else "R")
    away = "out" + ("R" if s < 0 else "L")
    push = "hip" + ("R" if s < 0 else "L")  # the leg he pushes off with
    knee = "knee" + push[3]
    return keyed([
        SET,
        {**SET, push: (0.4, 0.4 * -s, None), knee: -1.3, "torso": (-0.3, 0.2 * s, None)},
        {"pelvis": (None, 0.5 * s, turn * 0.5), push: (0.1, 0.3 * -s, None), knee: -0.2, "torso": -0.1,
         "shoulderL": reach - 0.6, "shoulderR": reach - 0.6, out: 0.9, away: 0.3, "lift": 0.1},
        {"pelvis": (None, 1.25 * s, turn), "torso": -0.05, "kneeL": -0.2, "kneeR": -0.4,
         "shoulderL": reach, "shoulderR": reach, "elbowL": 0.1, "elbowR": 0.1, out: 0.2, away: 0.2, "lift": up},
        {"pelvis": (None, 1.45 * s, turn), "kneeL": -0.4, "kneeR": -0.5,
         "shoulderL": reach, "shoulderR": reach, "elbowL": 0.3, "elbowR": 0.3, out: 0.3, away: 0.2, "lift": up * 0.5},
        {"pelvis": (None, 1.55 * s, turn), "kneeL": -0.7, "kneeR": -0.4, "hipL": 0.3, "hipR": 0.3,
         "shoulderL": reach - 0.3, "shoulderR": reach - 0.3, "elbowL": 0.6, "elbowR": 0.6, out: 0.4, away: 0.3},
        {"pelvis": (None, 1.55 * s, turn), "kneeL": -1.0, "kneeR": -0.6, "hipL": 0.5, "hipR": 0.4,
         "shoulderL": 1.6, "shoulderR": 1.6, "elbowL": 1.4, "elbowR": 1.4, out: 0.2, away: 0.2},
        {"pelvis": (None, 1.55 * s, turn), "kneeL": -1.2, "kneeR": -0.8, "hipL": 0.7, "hipR": 0.5,
         "shoulderL": 1.3, "shoulderR": 1.3, "elbowL": 1.8, "elbowR": 1.8, out: 0.1, away: 0.1},
    ])


# Catches: the game draws the ball in his hands.
GLWCTCH = keyed([  # a low ball scooped up
    SET,
    {**SET, "torso": -0.7, "kneeL": -0.9, "kneeR": -0.9, "shoulderL": 0.6, "shoulderR": 0.6, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.15, "outR": 0.15},
    {**SET, "torso": -0.75, "kneeL": -1.0, "kneeR": -1.0, "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 1.0, "elbowR": 1.0, "outL": 0.1, "outR": 0.1},
    {**SET, "torso": -0.3, "kneeL": -0.6, "kneeR": -0.6, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.9, "elbowR": 1.9, "outL": -0.1, "outR": -0.1},
])
GMDCTCH = keyed([  # at the chest
    SET,
    {**SET, "torso": -0.1, "shoulderL": 1.4, "shoulderR": 1.4, "elbowL": 0.4, "elbowR": 0.4, "outL": 0.2, "outR": 0.2},
    {**SET, "torso": 0.1, "shoulderL": 1.2, "shoulderR": 1.2, "elbowL": 1.5, "elbowR": 1.5, "outL": 0.0, "outR": 0.0},
    {**SET, "torso": -0.15, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.9, "elbowR": 1.9, "outL": -0.1, "outR": -0.1},
])
GJMCTCH = keyed([  # jumping for a high ball
    SET,
    {**CROUCH, "shoulderL": 0.4, "shoulderR": 0.4},
    {"hipL": 0.7, "kneeL": -1.2, "hipR": 0.0, "kneeR": -0.3, "torso": 0.1, "shoulderL": 2.9, "shoulderR": 2.9, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.1, "outR": 0.1, "lift": 0.45},
    {"hipL": 0.8, "kneeL": -1.4, "hipR": 0.2, "kneeR": -0.6, "torso": 0.1, "shoulderL": 3.0, "shoulderR": 3.0, "elbowL": 0.5, "elbowR": 0.5, "outL": 0.0, "outR": 0.0, "lift": 0.5},
    {"hipL": 0.5, "kneeL": -0.9, "hipR": 0.3, "kneeR": -0.8, "torso": -0.1, "shoulderL": 1.6, "shoulderR": 1.6, "elbowL": 1.4, "elbowR": 1.4, "outL": 0.0, "outR": 0.0, "lift": 0.2},
    {**SET, "torso": -0.2, "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.9, "elbowR": 1.9, "outL": -0.1, "outR": -0.1},
])

# The keeper's drop kick: ball held out, dropped, volleyed high upfield.
GDKICK = keyed([
    {"hipL": 0.3, "kneeL": -0.3, "hipR": -0.3, "kneeR": -0.4, "shoulderL": 1.3, "shoulderR": 1.3, "elbowL": 0.4, "elbowR": 0.4, "outL": 0.1, "outR": 0.1},
    {"hipL": 0.5, "kneeL": -0.5, "hipR": -0.5, "kneeR": -0.9, "torso": 0.05, "shoulderL": 1.4, "shoulderR": 1.4, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.1, "outR": 0.1},
    {"hipL": 0.2, "kneeL": -0.4, "hipR": -0.8, "kneeR": -1.6, "torso": 0.15, "shoulderL": 0.6, "shoulderR": 0.4, "outL": 1.2, "outR": 1.2},
    {"hipL": -0.1, "kneeL": -0.2, "hipR": 1.9, "kneeR": -0.05, "ankleR": -0.4, "torso": 0.45, "shoulderL": 0.8, "shoulderR": 0.2, "outL": 1.2, "outR": 1.2, "lift": 0.05},
    {"hipL": 0.0, "kneeL": -0.3, "hipR": 1.3, "kneeR": -0.4, "torso": 0.3, "shoulderL": 0.6, "shoulderR": 0.3, "outL": 1.0, "outR": 1.0},
    {"hipL": 0.1, "kneeL": -0.5, "hipR": 0.5, "kneeR": -0.7, "torso": 0.05, "outL": 0.6, "outR": 0.6, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.2, "kneeL": -0.3, "hipR": -0.1, "kneeR": -0.3, "torso": -0.05, "outL": 0.3, "outR": 0.3, "elbowL": 0.5, "elbowR": 0.5},
])

# Skill moves.
BCKHEEL = keyed([  # steps past the ball and flicks it back with the right heel
    {"hipL": 0.4, "kneeL": -0.5, "hipR": -0.4, "kneeR": -0.7, "torso": -0.15, "shoulderL": -0.4, "shoulderR": 0.4, "elbowL": 0.7, "elbowR": 0.7},
    {"hipL": 0.1, "kneeL": -0.4, "hipR": 0.5, "kneeR": -0.6, "torso": -0.1, "outL": 0.6, "outR": 0.5, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.0, "kneeL": -0.4, "hipR": -0.2, "kneeR": -1.5, "torso": -0.2, "outL": 0.7, "outR": 0.6, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.0, "kneeL": -0.4, "hipR": -0.7, "kneeR": -1.0, "ankleR": 0.4, "torso": -0.3, "outL": 0.8, "outR": 0.7, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.2, "kneeL": -0.5, "hipR": -0.2, "kneeR": -0.6, "torso": -0.15, "outL": 0.4, "outR": 0.4, "elbowL": 0.7, "elbowR": 0.7},
])

RAINBOW = keyed([  # the ball between the feet, rolled up the left calf with the right heel and over the head
    {"hipL": 0.4, "kneeL": -0.6, "hipR": -0.4, "kneeR": -0.8, "torso": -0.2, "shoulderL": -0.4, "shoulderR": 0.4, "elbowL": 0.8, "elbowR": 0.8},
    {"hipL": 0.2, "kneeL": -0.3, "hipR": 0.1, "kneeR": -0.4, "torso": -0.1, "outL": 0.6, "outR": 0.6, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.05, "kneeL": -0.2, "hipR": (-0.1, 0.15, None), "kneeR": -0.9, "torso": -0.05, "outL": 0.7, "outR": 0.7, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.0, "kneeL": -0.2, "hipR": (-0.5, 0.2, None), "kneeR": -1.7, "ankleR": 0.5, "torso": 0.05, "outL": 0.9, "outR": 0.8, "elbowL": 0.5, "elbowR": 0.5},
    {"hipL": 0.1, "kneeL": -0.3, "hipR": -0.7, "kneeR": -2.0, "ankleR": 0.6, "torso": 0.1, "head": 0.3, "outL": 1.0, "outR": 0.9, "elbowL": 0.5, "elbowR": 0.5, "lift": 0.1},
    {"hipL": 0.3, "kneeL": -0.6, "hipR": -0.2, "kneeR": -1.0, "torso": 0.0, "head": 0.3, "outL": 0.8, "outR": 0.8, "elbowL": 0.5, "elbowR": 0.5, "lift": 0.05},
    {"hipL": 0.5, "kneeL": -0.6, "hipR": -0.4, "kneeR": -0.7, "torso": -0.15, "outL": 0.5, "outR": 0.5, "elbowL": 0.7, "elbowR": 0.7},
    {"hipL": -0.3, "kneeL": -0.9, "hipR": 0.6, "kneeR": -0.5, "torso": -0.25, "shoulderL": 0.5, "shoulderR": -0.5, "elbowL": 1.0, "elbowR": 1.0},
])


# Goal celebrations.
def aeroplane(j, i, n):
    """Running, arms out like wings, banking from side to side."""
    _stride(j, i / n * math.tau, swing=0.7, fold=1.4, lean=0.2, arms=0.0, elbow=0.05)
    for side in ("L", "R"):
        _out(j, side, 1.35)
    j["torso"].rotation_euler.y = 0.22 * math.sin(i / n * math.tau)


def victory_run(j, i, n):
    """Running with both fists up."""
    _stride(j, i / n * math.tau, swing=0.75, fold=1.5, lean=0.15, arms=0.0, elbow=0.4)
    for side in ("L", "R"):
        j["shoulder" + side].rotation_euler.x = 2.8 + 0.15 * math.sin(i / n * math.tau)
        _out(j, side, 0.35)


_DANCE = {"hipL": (0.1, 0.1, None), "kneeL": -0.4, "hipR": (0.1, -0.1, None), "kneeR": -0.4, "torso": -0.05}
CELDNCE = keyed([  # a fist pumped at the sky, the weight rocking foot to foot
    {**_DANCE, "shoulderR": 2.9, "elbowR": 0.6, "shoulderL": 0.3, "elbowL": 1.4},
    {**_DANCE, "kneeL": -0.7, "pelvis": (None, 0.1, None), "shoulderR": 2.4, "elbowR": 1.6, "shoulderL": 0.4, "elbowL": 1.5},
    {**_DANCE, "shoulderR": 3.0, "elbowR": 0.3, "shoulderL": 0.3, "elbowL": 1.4},
    {**_DANCE, "kneeR": -0.7, "pelvis": (None, -0.1, None), "shoulderR": 2.4, "elbowR": 1.6, "shoulderL": 0.4, "elbowL": 1.5},
    {**_DANCE, "shoulderR": 3.0, "elbowR": 0.3, "shoulderL": 0.3, "elbowL": 1.4},
    {**_DANCE, "kneeL": -0.7, "pelvis": (None, 0.1, None), "shoulderR": 2.4, "elbowR": 1.6, "shoulderL": 0.4, "elbowL": 1.5},
    {**_DANCE, "shoulderR": 3.0, "elbowR": 0.2, "shoulderL": 0.5, "elbowL": 1.2, "outR": 0.5},
])

CELDNC2 = keyed([  # knees bobbing, elbows out, a shuffle side to side
    {"hipL": 0.4, "kneeL": -0.6, "hipR": -0.3, "kneeR": -0.5, "torso": -0.2, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 1.5, "elbowR": 1.5},
    {**_DANCE, "kneeL": -0.9, "kneeR": -0.9, "hipL": 0.4, "hipR": 0.4, "torso": -0.3, "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 1.8, "elbowR": 1.8, "outL": 0.8, "outR": 0.8},
    {**_DANCE, "pelvis": (None, None, 0.4), "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.7, "elbowR": 1.7, "outL": 0.7, "outR": 0.7},
    {**_DANCE, "kneeL": -0.9, "kneeR": -0.9, "hipL": 0.4, "hipR": 0.4, "torso": -0.3, "pelvis": (None, None, 0.2), "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 1.8, "elbowR": 1.8, "outL": 0.8, "outR": 0.8},
    {**_DANCE, "pelvis": (None, None, -0.4), "shoulderL": 0.9, "shoulderR": 0.9, "elbowL": 1.7, "elbowR": 1.7, "outL": 0.7, "outR": 0.7},
    {**_DANCE, "kneeL": -0.9, "kneeR": -0.9, "hipL": 0.4, "hipR": 0.4, "torso": -0.3, "pelvis": (None, None, -0.2), "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 1.8, "elbowR": 1.8, "outL": 0.8, "outR": 0.8},
    {**_DANCE, "shoulderL": 1.4, "shoulderR": 1.4, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.6, "outR": 0.6},
    {**_DANCE, "shoulderL": 0.5, "shoulderR": 0.5, "elbowL": 1.2, "elbowR": 1.2, "outL": 0.4, "outR": 0.4},
])

# Down on one knee: a fist pumped, then both fists hammering the turf, and up again.
_KNEEL = {"hipL": 1.4, "kneeL": -1.5, "hipR": -0.2, "kneeR": -2.1, "ankleR": 0.6}
CELDPNC = keyed([
    {"hipL": 0.5, "kneeL": -0.8, "hipR": 0.3, "kneeR": -0.9, "torso": -0.3, "shoulderL": 0.4, "shoulderR": 0.4, "elbowL": 1.2, "elbowR": 1.2},
    {**_KNEEL, "torso": 0.0, "shoulderR": 1.5, "elbowR": 1.8, "shoulderL": 0.3, "elbowL": 1.0},
    {**_KNEEL, "torso": 0.1, "shoulderR": 3.0, "elbowR": 0.2, "shoulderL": 0.3, "elbowL": 1.0},
    {**_KNEEL, "torso": 0.0, "shoulderR": 1.6, "elbowR": 1.9, "shoulderL": 0.4, "elbowL": 1.0},
    {**_KNEEL, "torso": -0.8, "shoulderL": 1.6, "shoulderR": 1.6, "elbowL": 0.3, "elbowR": 0.3, "outL": 0.3, "outR": 0.3},
    {**_KNEEL, "torso": -0.6, "shoulderL": 2.3, "shoulderR": 2.3, "elbowL": 1.2, "elbowR": 1.2, "outL": 0.3, "outR": 0.3},
    {**_KNEEL, "torso": -0.85, "shoulderL": 1.5, "shoulderR": 1.5, "elbowL": 0.2, "elbowR": 0.2, "outL": 0.3, "outR": 0.3},
    {"hipL": 0.9, "kneeL": -1.2, "hipR": -0.1, "kneeR": -1.2, "torso": -0.5, "shoulderL": 0.8, "shoulderR": 0.8, "elbowL": 0.6, "elbowR": 0.6},
    {"hipL": 0.3, "kneeL": -0.4, "hipR": 0.0, "kneeR": -0.4, "torso": -0.1, "shoulderR": 2.9, "elbowR": 0.3, "shoulderL": 0.4, "elbowL": 0.8},
])

# Squatting low, flapping elbows like wings, waddling.
_SQUAT = {"hipL": (1.2, 0.25, None), "kneeL": -2.0, "hipR": (1.2, -0.25, None), "kneeR": -2.0, "torso": -0.4, "head": 0.3,
          "shoulderL": -0.3, "shoulderR": -0.3, "elbowL": 2.2, "elbowR": 2.2}
DUCKFLP = keyed([
    {**_SQUAT, "outL": 0.4, "outR": 0.4},
    {**_SQUAT, "outL": 1.5, "outR": 1.5, "pelvis": (None, 0.12, None)},
    {**_SQUAT, "outL": 0.4, "outR": 0.4},
    {**_SQUAT, "outL": 1.5, "outR": 1.5, "pelvis": (None, -0.12, None)},
    {**_SQUAT, "outL": 0.4, "outR": 0.4},
    {**_SQUAT, "outL": 1.5, "outR": 1.5, "pelvis": (None, 0.12, None)},
    {**_SQUAT, "outL": 0.4, "outR": 0.4},
    {**_SQUAT, "outL": 1.5, "outR": 1.5, "pelvis": (None, -0.12, None)},
    {**_SQUAT, "outL": 0.4, "outR": 0.4},
    {**_SQUAT, "outL": 1.5, "outR": 1.5},
])

VCTFLIP = keyed([  # a front handspring, landed with both arms up
    {**CROUCH, "shoulderL": 1.0, "shoulderR": 1.0, "elbowL": 0.2, "elbowR": 0.2},
    {"pelvis": -1.9, "hipL": 0.3, "kneeL": -0.4, "hipR": -0.4, "kneeR": -0.2, "shoulderL": 2.9, "shoulderR": 2.9, "elbowL": 0.0, "elbowR": 0.0, "outL": 0.2, "outR": 0.2},
    {"pelvis": -3.0, "hipL": 0.1, "kneeL": -0.3, "hipR": -0.3, "kneeR": -0.2, "shoulderL": 3.0, "shoulderR": 3.0, "elbowL": 0.0, "elbowR": 0.0, "outL": 0.25, "outR": 0.25},
    {"pelvis": -4.3, "hipL": -0.3, "kneeL": -0.6, "hipR": -0.5, "kneeR": -0.6, "shoulderL": 2.6, "shoulderR": 2.6, "elbowL": 0.2, "elbowR": 0.2, "lift": 0.35},
    {"pelvis": -5.6, "hipL": 0.6, "kneeL": -1.0, "hipR": 0.4, "kneeR": -0.9, "torso": 0.1, "shoulderL": 2.9, "shoulderR": 2.9, "elbowL": 0.2, "elbowR": 0.2, "lift": 0.2},
    {"hipL": 0.8, "kneeL": -1.4, "hipR": 0.6, "kneeR": -1.4, "torso": -0.4, "shoulderL": 1.0, "shoulderR": 1.0, "elbowL": 0.6, "elbowR": 0.6, "outL": 0.6, "outR": 0.6},
    {"hipL": 0.1, "kneeL": -0.2, "hipR": -0.1, "kneeR": -0.2, "torso": 0.1, "shoulderL": 2.8, "shoulderR": 2.8, "elbowL": 0.3, "elbowR": 0.3, "outL": 0.5, "outR": 0.5},
])

# name in the game: pose, frames, start tick of each frame (FIFA 96's timing for the same
# animation, so loops and the kick's contact time stay what the game is tuned to)
ANIMS = {
    "run": (run, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29]),
    "jog": (jog, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29]),
    "xstandd": (stand, 1, [1]),
    "kick": (kick, 5, [4, 7, 10, 13, 18]),
    "vollkck": (VOLLEY, 5, [6, 12, 16, 20, 25]),
    "bicycle": (BICYCLE, 7, [6, 16, 20, 26, 33, 37, 41]),
    "tackle": (TACKLE, 4, [6, 12, 18, 21]),
    "header": (HEADER, 7, [5, 10, 19, 23, 26, 30, 33]),
    "nutmeg": (NUTMEG, 9, [1, 6, 11, 16, 20, 25, 29, 39, 45]),
    "mark": (MARK, 4, [5, 10, 15, 20]),
    "fall": (FALL, 6, [5, 8, 10, 13, 22, 30]),
    "gpound": (GPOUND, 8, [6, 12, 18, 23, 29, 35, 41, 52]),
    "glwthrw": (GLWTHRW, 6, [4, 10, 15, 21, 29, 36]),
    "gpunchu": (GPUNCHU, 6, [6, 9, 12, 19, 24, 27]),
    "walk": (walk, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29]),
    "shoot": (SHOOT, 7, [4, 7, 10, 13, 16, 19, 22]),
    "slide": (SLIDE, 5, [5, 9, 12, 18, 24]),
    "throwin": (THROWIN, 6, [1, 5, 14, 21, 24, 34]),
    "jump": (JUMP, 6, [4, 8, 12, 19, 23, 26]),
    "chest": (CHEST, 4, [8, 15, 21, 25]),
    "stumble": (STUMBLE, 7, [1, 4, 7, 13, 21, 26, 29]),
    "push": (PUSH, 7, [4, 6, 8, 13, 15, 17, 19]),
    "bodychk": (BODYCHK, 7, [6, 12, 18, 24, 27, 30, 41]),
    "divehed": (DIVEHED, 5, [6, 10, 14, 22, 27]),
    # the keeper's dives: a to his left, b to his right (FIFA 96 draws them per direction)
    "ghdsa": (dive(-1, True), 8, [4, 6, 9, 14, 18, 20, 24, 27]),
    "ghdsb": (dive(1, True), 8, [4, 6, 9, 14, 18, 20, 24, 27]),
    "gldsa": (dive(-1, False), 8, [4, 6, 9, 14, 18, 20, 24, 27]),
    "gldsb": (dive(1, False), 8, [4, 6, 9, 14, 18, 20, 24, 27]),
    "glwctch": (GLWCTCH, 4, [6, 9, 12, 16]),
    "gmdctch": (GMDCTCH, 4, [6, 9, 12, 16]),
    "gjmctch": (GJMCTCH, 6, [7, 12, 17, 21, 25, 30]),
    "gdkick": (GDKICK, 7, [6, 12, 17, 22, 27, 32, 37]),
    "bckheel": (BCKHEEL, 5, [6, 12, 16, 20, 25]),
    "rainbow": (RAINBOW, 8, [5, 9, 13, 17, 22, 25, 28, 34]),
    "aeropla": (aeroplane, 6, [1, 6, 11, 16, 21, 26]),
    "victrun": (victory_run, 6, [1, 6, 11, 16, 21, 26]),
    "celdnce": (CELDNCE, 7, [8, 13, 16, 18, 20, 23, 33]),
    "celdnc2": (CELDNC2, 8, [5, 14, 20, 24, 27, 32, 34, 37]),
    "celdpnc": (CELDPNC, 9, [5, 9, 13, 15, 19, 21, 26, 29, 32]),
    "duckflp": (DUCKFLP, 10, [18, 22, 26, 31, 36, 40, 44, 49, 54, 58]),
    "vctflip": (VCTFLIP, 7, [7, 18, 22, 27, 31, 38, 45]),
    # the Chaos line moves, on their drawn art's timing (brand/sprites/line_actions/manifest.json)
    "power_strike": (POWER_STRIKE, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "bulldozer_clear": (BULLDOZER_CLEAR, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "grapple_tackle": (GRAPPLE_TACKLE, 6, [0, 3.9, 7.5, 9.9, 12.3, 15.3]),
    "laser_pass": (LASER_PASS, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "whirlwind_turn": (WHIRLWIND_TURN, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "cannon_punt": (CANNON_PUNT, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "rising_fist": (RISING_FIST, 6, [0, 4.5, 8.1, 10.5, 15, 18]),
    "stepover_storm": (STEPOVER_STORM, 6, [0, 4.5, 6.3, 8.1, 9.9, 11.7]),
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
                _ground(j, pose(j, f, frames) or 0.0)
                s.render.filepath = os.path.join(out, "%d_%02d.png" % (d, f))
                bpy.ops.render.render(write_still=True)
        with open(os.path.join(out, "origin.json"), "w") as fh:
            json.dump({"cell": CELL, "x": o.x * CELL, "y": (1.0 - o.y) * CELL, "ticks": ticks}, fh)


WANTED = ARGS[1:] or list(ANIMS)
if __name__ == "__main__":  # footballer_gltf.py imports the figure and its poses
    main()
