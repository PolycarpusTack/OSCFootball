"""The footballer of footballer.py as a 3D model for the game's 3D edition: one .glb with an
animation for each of its poses (ANIMS), on the spot, facing +Y in Blender (-Z in Godot).

    blender -b -P tools/blender/footballer_gltf.py -- <out.glb> [anim ...]   (default: all of ANIMS)

The parts are rigid and hang on empties, so the animations are the empties' own rotations (and
the pelvis's height), no armature. Each part's material is named after its kit slot (shirt,
striped, shorts, socks, boots, skin, hair); the game colours them per kit. A pose's frame i is
keyed at its start tick (frame 0 at 0), at 30 frames a second, and one more key ends it one
step after the last: the first pose again for a looping run or jog, else the last held.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import footballer as fb  # noqa: E402  (the figure, its poses and ANIMS; doesn't render on import)

LOOPS = {"run", "jog", "walk", "sprint"}
FPS = 30
FLIGHT = 0.06  # metres: how high the sprint carries him between steps


def sprint(j, i, n):
    """The 3D edition's run (Puppet plays it for "run"): a longer stride than the sprites' run,
    and off the ground between steps, as a sprinter at the game's 9 m/s. Each leg lands at the
    top of its swing (phase pi/2 for the left, 3pi/2 for the right), so the flight is just before."""
    phase = i / n * math.tau
    fb._stride(j, phase, swing=1.2, fold=2.3, lean=0.4, arms=1.15, elbow=1.6)
    return FLIGHT * max(0.0, math.cos(2.0 * (phase - math.pi / 2.0) + 0.6)) ** 3


# only in the model: the sprites keep footballer.py's
EXTRA = {"sprint": (sprint, 12, [1, 4, 6, 8, 11, 14, 16, 19, 21, 23, 26, 29])}
POSES = {**fb.ANIMS, **EXTRA}


def plain_materials():
    """footballer.py's materials are render codes; these are plain ones under the same names,
    made first so build() picks them up."""
    for name in list(fb.SLOTS) + ["striped"]:
        m = bpy.data.materials.new(name)
        m.use_nodes = True


def key_pose(j, frame):
    for name, o in j.items():
        if name.startswith("boot"):
            continue
        o.keyframe_insert("rotation_euler", frame=frame)
        if name == "pelvis":
            o.keyframe_insert("location", frame=frame)


def bake(j, anim):
    """`anim` as an NLA track of that name on every joint (the exporter merges same-named
    tracks across objects into one glTF animation)."""
    pose, frames, ticks = POSES[anim]
    for o in j.values():
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new("%s_%s" % (anim, o.name))
    starts = [0] + list(ticks[1:frames])
    end = ticks[frames - 1] + (ticks[frames - 1] - ticks[frames - 2] if frames > 1 else 4)
    for f in range(frames):
        fb._rest(j)
        fb._ground(j, pose(j, f, frames) or 0.0)
        key_pose(j, starts[f])
    fb._rest(j)
    fb._ground(j, pose(j, 0 if anim in LOOPS else frames - 1, frames) or 0.0)
    key_pose(j, end)
    for o in j.values():
        action = o.animation_data.action
        for fc in action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        track = o.animation_data.nla_tracks.new()
        track.name = anim
        track.strips.new(anim, 0, action)
        o.animation_data.action = None


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if args else "/tmp/footballer.glb"
    wanted = args[1:] or list(POSES)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    plain_materials()
    j = fb.build()
    for anim in wanted:
        bake(j, anim)
    fb._rest(j)
    fb._ground(j)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_apply=True,
                              export_optimize_animation_size=False)  # every joint in every animation


if __name__ == "__main__":  # tools can import the poses
    main()
