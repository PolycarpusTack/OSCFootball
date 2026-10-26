# 3D models

`footballer.glb`: the 3D edition's footballer (`scripts/puppet.gd`). Ours, made by
`tools/blender/footballer_gltf.py` from the low-poly figure and poses in
`tools/blender/footballer.py` (the same figure the Rendered sprites are rendered from). No
third-party models or animation data are in it.

    blender -b -P tools/blender/footballer_gltf.py -- game/assets/models/footballer.glb

Rigid parts on empties, no armature; one animation for each pose, plus `sprint`, the 3D run.
Each part's material is named after its kit slot; the game colours them (`scripts/kit3d.gdshader`).
