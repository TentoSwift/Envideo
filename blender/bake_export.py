"""
Bake Cycles lighting into base-colour textures (WWDC24-10087 workflow) and export
RichCinema.usdc with those textures, so the unlit RealityKit scene looks lit.

Bake targets (kept minimal, per the session's "reduce texture count"):
  - 4 walls  (each its own 2K texture)
  - 1 representative seat (shared by all 216 instances -> one 1K texture)
Floor/Ceiling are skipped: they are replaced by the reflection material in-app.
Practical lights (strips/downlights) stay emissive; the screen is baked as a
neutral emitter so the ambient wall glow isn't tinted by one video frame.

Run:
  cd /Users/ishinotento
  Blender -b --factory-startup --python bake_export.py
"""

import bpy
import bmesh
import sys
import os
from mathutils import Vector

sys.path.insert(0, "/Users/ishinotento")
import cinema

RKASSETS = ("/Users/ishinotento/Documents/Envideo/Packages/RealityKitContent/"
            "Sources/RealityKitContent/RealityKitContent.rkassets")
TEXDIR = os.path.join(RKASSETS, "textures")   # rc_* prefix namespaces the baked maps
OUT = os.path.join(RKASSETS, "RichCinema.usdc")
PREVIEW = "/Users/ishinotento/rich_baked_preview.png"
SHIFT_Y = 11.0

CONTRACT = {
    "Screen": "VideoScreen", "ScreenBorder": "ScreenFrame",
    "Floor": "Floor", "Ceiling": "Ceiling",
    "WallFront": "Wall_Front", "WallBack": "Wall_Back",
    "WallL": "Wall_Left", "WallR": "Wall_Right", "Stage": "Stage",
}
WALLS = ["WallBack", "WallFront", "WallL", "WallR"]

# --------------------------------------------------------------------------- #
def face_inward(obj, inside):
    """Flip faces so the normal points toward `inside` (needed for a correct bake)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for f in bm.faces:
        c = obj.matrix_world @ f.calc_center_median()
        n = obj.matrix_world.to_3x3() @ f.normal
        if n.dot(Vector(inside) - c) < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    me.update()

def quad_uv(obj):
    """Trivial 0..1 UV for a single-quad wall (no distortion, fully headless)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        # order loops; map bounding box of local coords to 0..1
        xs = [l.vert.co for l in f.loops]
        mnx = min(v.x for v in xs); mxx = max(v.x for v in xs)
        mny = min(v.y for v in xs); mxy = max(v.y for v in xs)
        mnz = min(v.z for v in xs); mxz = max(v.z for v in xs)
        # pick the two axes with the largest spread
        spreads = [("x", mxx - mnx), ("y", mxy - mny), ("z", mxz - mnz)]
        spreads.sort(key=lambda s: -s[1])
        a, b = spreads[0][0], spreads[1][0]
        rng = {"x": (mnx, mxx), "y": (mny, mxy), "z": (mnz, mxz)}
        for l in f.loops:
            va = getattr(l.vert.co, a); vb = getattr(l.vert.co, b)
            ua = (va - rng[a][0]) / max(rng[a][1] - rng[a][0], 1e-6)
            ub = (vb - rng[b][0]) / max(rng[b][1] - rng[b][0], 1e-6)
            l[uv].uv = (ua, ub)
    bm.to_mesh(me)
    bm.free()

def smart_uv(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.03)
    bpy.ops.object.mode_set(mode="OBJECT")

def set_bake_image(obj, img):
    """Add the bake-target image node to every material on obj and make it active."""
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.select = True
        nt.nodes.active = node

def bake_object(obj, name, size):
    img = bpy.data.images.new(name, size, size, alpha=False)
    img.filepath_raw = os.path.join(TEXDIR, name + ".png")
    img.file_format = "PNG"
    set_bake_image(obj, img)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="COMBINED", use_clear=True, margin=8)
    img.save()
    print(f"[bake] {name}: {os.path.join(TEXDIR, name + '.png')}")
    return img

def make_baked_material(mat, img):
    """Base Color + Emission both = baked texture -> reads as 'lit' whether the app
    keeps it PBR or converts it to unlit."""
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf.inputs["Roughness"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if "Emission Color" in bsdf.inputs:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

def make_flat(mat, color):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

def emission_color(mat):
    for n in mat.node_tree.nodes:
        if n.type == "EMISSION":
            c = n.inputs["Color"].default_value
            return (c[0], c[1], c[2])
    return (1.0, 0.7, 0.4)

# --------------------------------------------------------------------------- #
def main():
    cinema.build()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cinema.setup_gpu(scene)
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.bake.use_pass_direct = True
    scene.render.bake.use_pass_indirect = True
    scene.render.bake.margin = 8

    # remove the volumetric haze (not bakeable / slows bakes)
    for o in list(scene.objects):
        if o.name.startswith("Haze"):
            bpy.data.objects.remove(o, do_unlink=True)

    # screen -> neutral bright emitter (avoid baking a single frame's colour cast)
    scr = bpy.data.materials.get("Screen")
    if scr:
        scr.use_nodes = True
        nt = scr.node_tree; nt.nodes.clear()
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (1.0, 0.96, 0.9, 1)
        em.inputs["Strength"].default_value = 3.0
        nt.links.new(em.outputs["Emission"], o.inputs["Surface"])

    os.makedirs(TEXDIR, exist_ok=True)
    inside = (0.0, cinema.DEPTH / 2, cinema.HEIGHT / 2)

    # give each wall its own material + inward normals + uv, then bake
    wall_imgs = {}
    for wname in WALLS:
        obj = scene.objects[wname]
        m = obj.data.materials[0].copy()
        m.name = "Bake_" + wname
        obj.data.materials[0] = m
        face_inward(obj, inside)
        quad_uv(obj)
        wall_imgs[wname] = (m, bake_object(obj, "rc_" + wname, 2048))

    # representative seat (mid room) -> shared seat texture
    seats = [o for o in scene.objects if o.name.startswith("SeatTemplate")]
    seat = min(seats, key=lambda o: (o.location - Vector((-2.3, 10.5, 0))).length)
    smart_uv(seat)
    seat_img = bake_object(seat, "rc_Seat", 1024)

    # rebuild baked materials as lit-looking (base+emission = baked)
    for wname, (m, img) in wall_imgs.items():
        make_baked_material(m, img)
    for mname in ("SeatFabric", "SeatMetal"):
        mm = bpy.data.materials.get(mname)
        if mm:
            make_baked_material(mm, seat_img)

    # ---- preview render approximating the in-app unlit look ----
    for o in list(scene.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
    if scene.world and scene.world.use_nodes:
        bg = scene.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs["Strength"].default_value = 0.0
    scene.cycles.samples = 64
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("[preview] wrote", PREVIEW + ".png" if not PREVIEW.endswith('.png') else PREVIEW)

    # ---- finalize for export ----
    for mat in bpy.data.materials:
        if mat.name.startswith("Strip") or mat.name.startswith("Downlight"):
            make_flat(mat, emission_color(mat))
        elif mat.name.startswith("Screen"):
            make_flat(mat, (0.0, 0.0, 0.0))
        elif mat.name in ("Floor", "Ceiling"):
            make_flat(mat, (0.02, 0.02, 0.025))

    for o in list(scene.objects):
        if o.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(o, do_unlink=True)
    for old, new in CONTRACT.items():
        o = scene.objects.get(old)
        if o:
            o.name = new
            o.data.name = new
    for o in scene.objects:
        if o.parent is None:
            o.location.y -= SHIFT_Y

    bpy.ops.wm.usd_export(
        filepath=OUT,
        convert_orientation=True,
        export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
        root_prim_path="/Root",
        generate_preview_surface=True,
        export_materials=True,
        export_uvmaps=True,
        use_instancing=True,
        relative_paths=True,
        convert_world_material=False,
    )
    print("[export] wrote", OUT)

if __name__ == "__main__":
    main()
