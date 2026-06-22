"""
Export the cinema environment as a USD for Envideo's RealityKitContent.

Coordinate contract (verified against the existing Cinema.usdc):
  USD is Y-up / metres. Export with convert_orientation up=Y forward=-Z gives
  USD(x, y, z) = Blender(x, z, y).  We shift the whole scene by (0, -SHIFT_Y, 0)
  in Blender so the middle of the seating sits at the origin, the floor stays at
  USD y=0, and the screen ends up ahead of the viewer at -Z.

Run:
  cd /Users/ishinotento
  Blender -b --factory-startup --python export_rkscene.py -- /tmp/rich_cinema.usdc
"""

import bpy
import sys
import os

sys.path.insert(0, "/Users/ishinotento")
import cinema                                   # defines build(); does not auto-run

argv = sys.argv
args = argv[argv.index("--") + 1:] if "--" in argv else []
RKASSETS = ("/Users/ishinotento/Documents/Envideo/Packages/RealityKitContent/"
            "Sources/RealityKitContent/RealityKitContent.rkassets")
OUT = args[0] if args else os.path.join(RKASSETS, "RichCinema.usdc")

SHIFT_Y = 11.0                                  # Blender Y of the seat we put at origin

CONTRACT_NAMES = {
    "Screen": "VideoScreen",
    "ScreenBorder": "ScreenFrame",
    "Floor": "Floor",
    "Ceiling": "Ceiling",
    "WallFront": "Wall_Front",
    "WallBack": "Wall_Back",
    "WallL": "Wall_Left",
    "WallR": "Wall_Right",
    "Stage": "Stage",
}

def _emission_color(mat):
    if mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "EMISSION":
                c = n.inputs["Color"].default_value
                return (c[0], c[1], c[2])
    return None

def _make_unlit(mat, color):
    """Rebuild a material as a flat colour that survives PBR->Unlit in-app."""
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

def prep_materials():
    """Practical lights -> bright flat colour; screen -> black (video docks over);
    floor/ceiling -> flat (they are replaced by the reflection material in-app, and
    flattening avoids the USD exporter baking procedural inputs to stray textures)."""
    for mat in bpy.data.materials:
        if mat.name.startswith("Strip") or mat.name.startswith("Downlight"):
            _make_unlit(mat, _emission_color(mat) or (1.0, 0.7, 0.4))
        elif mat.name.startswith("Screen"):
            _make_unlit(mat, (0.0, 0.0, 0.0))
        elif mat.name == "Floor":
            _make_unlit(mat, (0.02, 0.02, 0.025))
        elif mat.name == "Ceiling":
            _make_unlit(mat, (0.02, 0.02, 0.025))

def main():
    cinema.build()
    prep_materials()
    scene = bpy.context.scene

    # drop things RealityKit can't use from a static environment
    for o in list(scene.objects):
        if o.type in {"CAMERA", "LIGHT"} or o.name.startswith("Haze"):
            bpy.data.objects.remove(o, do_unlink=True)

    # rename hero objects to the contract the wrapper scene expects
    for old, new in CONTRACT_NAMES.items():
        o = scene.objects.get(old)
        if o:
            o.name = new
            o.data.name = new

    # put the middle seat at the origin (horizontal shift only; floor stays at y=0)
    for o in scene.objects:
        if o.parent is None:
            o.location.y -= SHIFT_Y

    bpy.context.view_layer.update()
    vs = scene.objects.get("VideoScreen")
    if vs:
        c = vs.matrix_world.translation
        # report the post-export USD position for docking-region placement
        print(f"[export] VideoScreen Blender=({c.x:.2f},{c.y:.2f},{c.z:.2f}) "
              f"-> USD=({c.x:.2f},{c.z:.2f},{c.y:.2f})  dims={tuple(round(v,2) for v in vs.dimensions)}")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=OUT,
        convert_orientation=True,
        export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
        root_prim_path="/Root",
        generate_preview_surface=True,
        export_materials=True,
        convert_world_material=False,      # don't bake our world bg into a stray env texture
        export_uvmaps=True,
        use_instancing=True,
        relative_paths=True,
    )
    print("[export] wrote", OUT)

if __name__ == "__main__":
    main()
