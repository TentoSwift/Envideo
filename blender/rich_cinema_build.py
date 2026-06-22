"""
Rich cinema / movie-theater environment for Blender 5.x (Cycles).
Highlight: the glowing screen is reflected, softly blurred, on a polished floor.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python cinema.py -- [test|final]
"""

import bpy
import bmesh
import sys
import math
from math import radians
from mathutils import Vector

try:
    import numpy as np
except Exception:                      # numpy ships with Blender, but be safe
    np = None

# --------------------------------------------------------------------------- #
#  Quality / args
# --------------------------------------------------------------------------- #
argv = sys.argv
args = argv[argv.index("--") + 1:] if "--" in argv else []
QUALITY = args[0] if args else "test"

if QUALITY == "final":
    RES, SAMPLES = (1920, 1080), 512
else:
    RES, SAMPLES = (960, 540), 110

OUT_PNG = "/Users/ishinotento/cinema_render"      # .png appended by Blender
OUT_BLEND = "/Users/ishinotento/cinema.blend"

# --------------------------------------------------------------------------- #
#  Scene dimensions (metres)
# --------------------------------------------------------------------------- #
WIDTH, DEPTH, HEIGHT = 18.0, 26.0, 7.6            # x, y, z of the hall
SCREEN_MAXW, SCREEN_MAXH = 13.0, 5.5             # image is fitted within this box
SCREEN_BOTTOM = 1.0                               # screen sits on a low stage
SCREEN_STRENGTH = 5.0                             # brighter: the still is dim/green
SCREEN_IMAGE_PATH = ("/Users/ishinotento/.claude/uploads/"
                     "64b547f6-f989-44e7-9324-35e427f4ac95/57872e44-IMG_3621.png")

AISLE_HALF = 1.7                                  # half width of central aisle
SEAT_SPACING = 0.64
ROW_SPACING = 1.20
ROWS = 12
SEATS_PER_SIDE = 9
SEAT_Y0 = 4.6

# --------------------------------------------------------------------------- #
#  Helpers
# --------------------------------------------------------------------------- #
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def link(obj):
    bpy.context.scene.collection.objects.link(obj)

def set_in(node, name, value):
    if name in node.inputs:
        node.inputs[name].default_value = value

def add_plane(name, sx, sy, location, rot=(0, 0, 0), material=None, uv=False):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    link(obj)
    bm = bmesh.new()
    vs = [bm.verts.new((-sx / 2, -sy / 2, 0)),
          bm.verts.new(( sx / 2, -sy / 2, 0)),
          bm.verts.new(( sx / 2,  sy / 2, 0)),
          bm.verts.new((-sx / 2,  sy / 2, 0))]
    face = bm.faces.new(vs)
    if uv:
        uvl = bm.loops.layers.uv.verify()
        for loop in face.loops:
            co = loop.vert.co
            loop[uvl].uv = (co.x / sx + 0.5, co.y / sy + 0.5)
    bm.to_mesh(mesh)
    bm.free()
    obj.location = location
    obj.rotation_euler = rot
    if material:
        obj.data.materials.append(material)
    return obj

def cube_into(bm, cx, cy, cz, sx, sy, sz):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    for v in ret["verts"]:
        v.co.x = v.co.x * sx + cx
        v.co.y = v.co.y * sy + cy
        v.co.z = v.co.z * sz + cz

def add_disc(name, radius, location, rot=(0, 0, 0), material=None, segments=28):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    link(obj)
    bm = bmesh.new()
    try:
        bmesh.ops.create_circle(bm, cap_ends=True, segments=segments, radius=radius)
    except TypeError:
        bmesh.ops.create_circle(bm, cap_ends=True, segments=segments, diameter=radius)
    bm.to_mesh(mesh)
    bm.free()
    obj.location = location
    obj.rotation_euler = rot
    if material:
        obj.data.materials.append(material)
    return obj

def cylinder_into(bm, cx, cy, cz, radius, depth, segments=16):
    try:
        ret = bmesh.ops.create_cone(bm, segments=segments, radius1=radius,
                                    radius2=radius, depth=depth,
                                    cap_ends=True, cap_tris=False)
    except TypeError:
        ret = bmesh.ops.create_cone(bm, segments=segments, diameter1=radius * 2,
                                    diameter2=radius * 2, depth=depth,
                                    cap_ends=True, cap_tris=False)
    for v in ret["verts"]:
        v.co.x += cx
        v.co.y += cy
        v.co.z += cz

def add_box(name, sx, sy, sz, location, material=None):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    link(obj)
    bm = bmesh.new()
    cube_into(bm, 0, 0, 0, sx, sy, sz)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj.location = location
    if material:
        obj.data.materials.append(material)
    return obj

def point_camera(cam_obj, target):
    d = Vector(target) - cam_obj.location
    cam_obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

# --------------------------------------------------------------------------- #
#  Materials
# --------------------------------------------------------------------------- #
def emission_mat(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m

def principled_mat(name, base, rough, metallic=0.0, sheen=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    set_in(bsdf, "Base Color", (*base, 1))
    set_in(bsdf, "Roughness", rough)
    set_in(bsdf, "Metallic", metallic)
    set_in(bsdf, "Sheen Weight", sheen)
    set_in(bsdf, "Coat Weight", coat)
    set_in(bsdf, "Coat Roughness", 0.1)
    return m

def floor_mat():
    """Dark polished floor; noise-modulated roughness -> soft/blurry reflection."""
    m = bpy.data.materials.new("Floor")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    set_in(bsdf, "Base Color", (0.045, 0.045, 0.05, 1))
    set_in(bsdf, "Metallic", 0.0)
    set_in(bsdf, "Specular IOR Level", 0.4)        # dim, dielectric sheen
    set_in(bsdf, "Coat Weight", 0.0)               # no sharp clearcoat layer
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["To Min"].default_value = 0.32      # broad, soft -> faint blur
    rng.inputs["To Max"].default_value = 0.46
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], bsdf.inputs["Roughness"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m

# --------------------------------------------------------------------------- #
#  Procedural "movie still" for the screen (sunset)
# --------------------------------------------------------------------------- #
def make_screen_image():
    W, H = 1920, 804
    if np is None:
        img = bpy.data.images.new("ScreenImg", W, H)
        return img
    uu, vv = np.meshgrid(np.linspace(0, 1, W), np.linspace(0, 1, H))  # (H,W), row0=bottom
    aspect = W / H
    horizon = 0.34

    t = np.clip((vv - horizon) / (1 - horizon), 0, 1)
    vp = [0.0, 0.10, 0.32, 1.0]
    R = np.interp(t, vp, [1.00, 0.96, 0.80, 0.05])
    G = np.interp(t, vp, [0.46, 0.30, 0.32, 0.12])
    B = np.interp(t, vp, [0.14, 0.30, 0.55, 0.34])
    sky = np.stack([R, G, B], -1)

    # sun
    su, sv = 0.40, horizon + 0.085
    d = np.sqrt(((uu - su) * aspect) ** 2 + (vv - sv) ** 2)
    core = np.exp(-(d / 0.013) ** 2)
    glow = np.exp(-(d / 0.10) ** 2) * 0.75
    halo = np.exp(-(d / 0.32) ** 2) * 0.22
    sky += (core[..., None] * np.array([1.0, 0.97, 0.9])
            + glow[..., None] * np.array([1.0, 0.8, 0.5])
            + halo[..., None] * np.array([1.0, 0.45, 0.25]))

    # soft horizontal cloud streaks just above horizon
    cloud = (np.sin(vv * 70 + np.sin(uu * 6) * 2) * 0.5 + 0.5) ** 6
    cloud *= np.clip(1 - np.abs(vv - (horizon + 0.16)) / 0.16, 0, 1)
    sky += cloud[..., None] * np.array([0.5, 0.18, 0.12])

    # ground / hills below horizon
    gt = np.clip(vv / horizon, 0, 1)
    ground = np.array([0.05, 0.025, 0.02]) * gt[..., None]
    hill_h = 0.13 + 0.05 * np.sin(uu * 7.0) + 0.025 * np.sin(uu * 17.0 + 2.0)
    ground = np.where((vv < hill_h)[..., None],
                      np.array([0.004, 0.003, 0.006]), ground)

    rgb = np.where((vv >= horizon)[..., None], sky, ground)
    rgb = np.clip(rgb, 0, 1).astype(np.float32)
    rgba = np.concatenate([rgb, np.ones((H, W, 1), np.float32)], -1)

    img = bpy.data.images.new("ScreenImg", W, H, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img

def volume_mat():
    """Faint atmospheric haze so light beams and the screen glow read in air."""
    m = bpy.data.materials.new("Haze")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Density"].default_value = 0.008
    vol.inputs["Anisotropy"].default_value = 0.4          # forward scatter -> glow
    vol.inputs["Color"].default_value = (0.85, 0.82, 0.9, 1)
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    return m

def get_screen_image():
    """Load the user-supplied still; fall back to the procedural sunset."""
    if SCREEN_IMAGE_PATH:
        try:
            img = bpy.data.images.load(SCREEN_IMAGE_PATH, check_existing=True)
            img.name = "ScreenStill"
            return img
        except Exception as e:
            print("  could not load screen image, using procedural:", e)
    return make_screen_image()

def screen_mat(image):
    m = bpy.data.materials.new("Screen")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = SCREEN_STRENGTH
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Cubic"
    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m

# --------------------------------------------------------------------------- #
#  Seat
# --------------------------------------------------------------------------- #
def build_seat_template(fabric_mat, metal_mat):
    """Detailed modern cinema seat: plush contoured back, padded cushion,
    armrests with cupholders, metal legs.  Faces -Y (toward the screen)."""
    mesh = bpy.data.meshes.new("SeatMesh")
    bm = bmesh.new()

    # ---- upholstery (material slot 0) ----------------------------------
    cube_into(bm, 0.00,  0.00, 0.46, 0.52, 0.54, 0.15)   # seat cushion
    cube_into(bm, 0.00,  0.31, 0.85, 0.48, 0.15, 0.74)   # back panel
    cube_into(bm, -0.25, 0.24, 0.83, 0.11, 0.20, 0.66)   # left bolster
    cube_into(bm,  0.25, 0.24, 0.83, 0.11, 0.20, 0.66)   # right bolster
    cube_into(bm, 0.00,  0.30, 1.21, 0.44, 0.17, 0.13)   # headrest cap
    cube_into(bm, -0.30, -0.03, 0.64, 0.10, 0.48, 0.08)  # left arm pad
    cube_into(bm,  0.30, -0.03, 0.64, 0.10, 0.48, 0.08)  # right arm pad
    uph = set(bm.faces)

    # ---- hard parts: supports, legs, cupholders (material slot 1) -------
    cube_into(bm, -0.30, 0.12, 0.40, 0.05, 0.27, 0.44)   # left arm support
    cube_into(bm,  0.30, 0.12, 0.40, 0.05, 0.27, 0.44)   # right arm support
    cube_into(bm, -0.27, 0.06, 0.17, 0.05, 0.13, 0.34)   # left leg
    cube_into(bm,  0.27, 0.06, 0.17, 0.05, 0.13, 0.34)   # right leg
    cube_into(bm, -0.27, 0.04, 0.02, 0.11, 0.22, 0.04)   # left foot
    cube_into(bm,  0.27, 0.04, 0.02, 0.11, 0.22, 0.04)   # right foot
    cylinder_into(bm, -0.30, -0.19, 0.69, 0.040, 0.06)   # left cupholder
    cylinder_into(bm,  0.30, -0.19, 0.69, 0.040, 0.06)   # right cupholder

    for f in bm.faces:
        f.material_index = 0 if f in uph else 1
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()

    for p in mesh.polygons:                              # plush smooth shading
        p.use_smooth = True

    obj = bpy.data.objects.new("SeatTemplate", mesh)     # not linked -> source only
    obj.data.materials.append(fabric_mat)                # slot 0
    obj.data.materials.append(metal_mat)                 # slot 1
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.02
    bev.segments = 3
    bev.limit_method = "ANGLE"
    bev.angle_limit = radians(50)
    try:                                                 # clean shading on bevels
        obj.modifiers.new("WN", "WEIGHTED_NORMAL")
    except Exception:
        pass
    return obj

def scatter_seats(template):
    for side in (-1, 1):
        for r in range(ROWS):
            y = SEAT_Y0 + r * ROW_SPACING
            for c in range(SEATS_PER_SIDE):
                x = side * (AISLE_HALF + 0.45 + c * SEAT_SPACING)
                o = template.copy()                      # linked (shares mesh)
                o.location = (x, y, 0)
                link(o)

# --------------------------------------------------------------------------- #
#  Build the world
# --------------------------------------------------------------------------- #
def setup_world():
    w = bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.01, 0.012, 0.02, 1)
    bg.inputs["Strength"].default_value = 0.04

def build():
    reset_scene()
    setup_world()

    mat_floor = floor_mat()
    mat_wall = principled_mat("Wall", (0.10, 0.018, 0.022), 0.85)
    mat_ceil = principled_mat("Ceiling", (0.02, 0.02, 0.025), 0.9)
    mat_fabric = principled_mat("SeatFabric", (0.028, 0.028, 0.032), 0.62, sheen=0.55)
    mat_metal = principled_mat("SeatMetal", (0.05, 0.05, 0.055), 0.42, metallic=1.0)
    mat_black = principled_mat("Black", (0.01, 0.01, 0.01), 0.6)
    mat_strip = emission_mat("Strip", (1.0, 0.55, 0.22), 2.5)
    mat_down = emission_mat("Downlight", (1.0, 0.72, 0.42), 8.0)

    # floor / ceiling
    add_plane("Floor", WIDTH, DEPTH, (0, DEPTH / 2, 0), material=mat_floor)
    add_plane("Ceiling", WIDTH, DEPTH, (0, DEPTH / 2, HEIGHT),
              rot=(radians(180), 0, 0), material=mat_ceil)

    # walls
    add_plane("WallBack", WIDTH, HEIGHT, (0, DEPTH, HEIGHT / 2),
              rot=(radians(90), 0, 0), material=mat_wall)
    add_plane("WallFront", WIDTH, HEIGHT, (0, 0, HEIGHT / 2),
              rot=(radians(-90), 0, 0), material=mat_wall)
    add_plane("WallL", DEPTH, HEIGHT, (-WIDTH / 2, DEPTH / 2, HEIGHT / 2),
              rot=(radians(90), 0, radians(90)), material=mat_wall)
    add_plane("WallR", DEPTH, HEIGHT, (WIDTH / 2, DEPTH / 2, HEIGHT / 2),
              rot=(radians(90), 0, radians(-90)), material=mat_wall)

    # stage + screen (with black masking border)
    add_box("Stage", WIDTH * 0.96, 1.5, SCREEN_BOTTOM,
            (0, 0.75, SCREEN_BOTTOM / 2), material=mat_black)
    img = get_screen_image()
    w, h = img.size
    aspect = (w / h) if h else 1.9
    sw = SCREEN_MAXW
    sh = sw / aspect
    if sh > SCREEN_MAXH:                              # too tall -> fit by height
        sh = SCREEN_MAXH
        sw = sh * aspect
    sc_cz = SCREEN_BOTTOM + sh / 2
    add_plane("ScreenBorder", sw + 0.6, sh + 0.6, (0, 0.05, sc_cz),
              rot=(radians(90), 0, 0), material=mat_black)
    add_plane("Screen", sw, sh, (0, 0.07, sc_cz),
              rot=(radians(90), 0, 0), material=screen_mat(img), uv=True)

    # seats
    scatter_seats(build_seat_template(mat_fabric, mat_metal))

    # atmospheric haze filling the hall interior (surface is transparent)
    add_box("Haze", WIDTH - 0.4, DEPTH - 0.4, HEIGHT - 0.4,
            (0, DEPTH / 2, HEIGHT / 2), material=volume_mat())

    # aisle strip lights (leading lines that reflect on the floor)
    for sx in (-AISLE_HALF, AISLE_HALF):
        add_plane("Strip", 0.08, DEPTH - 6, (sx, DEPTH / 2, 0.06),
                  rot=(0, radians(90), 0), material=mat_strip)

    # ceiling downlights (starlight grid)
    nx, ny = 6, 9
    for ix in range(nx):
        for iy in range(ny):
            x = -WIDTH / 2 + (ix + 0.5) * WIDTH / nx
            y = (iy + 0.5) * DEPTH / ny
            add_disc("Down", 0.085, (x, y, HEIGHT - 0.02),
                     rot=(radians(180), 0, 0), material=mat_down)

    # soft cool fill so seats are readable
    fill_d = bpy.data.lights.new("Fill", "AREA")
    fill_d.shape = "RECTANGLE"
    fill_d.size = 10
    fill_d.size_y = 18
    fill_d.energy = 160
    fill_d.color = (0.45, 0.55, 0.85)
    fill_o = bpy.data.objects.new("Fill", fill_d)
    fill_o.location = (0, DEPTH * 0.55, HEIGHT - 0.1)
    link(fill_o)

    # warm key bounce from the screen direction
    key_d = bpy.data.lights.new("Key", "AREA")
    key_d.size = 8
    key_d.energy = 400
    key_d.color = (1.0, 0.6, 0.35)
    key_o = bpy.data.objects.new("Key", key_d)
    key_o.location = (0, 3.0, 4.0)
    key_o.rotation_euler = (radians(90), 0, 0)
    link(key_o)

    # camera
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 24
    cam_o = bpy.data.objects.new("Cam", cam_d)
    cam_o.location = (0.0, DEPTH * 0.80, 1.5)
    link(cam_o)
    point_camera(cam_o, (0.0, 0.0, 2.6))
    bpy.context.scene.camera = cam_o

# --------------------------------------------------------------------------- #
#  Render
# --------------------------------------------------------------------------- #
def setup_compositor(scene):
    """Subtle bloom on the bright screen and practical lights (Blender 5.x API)."""
    try:
        scene.use_nodes = True
        ng = bpy.data.node_groups.new("Compositor", "CompositorNodeTree")
        scene.compositing_node_group = ng
        ng.interface.new_socket("Image", in_out="OUTPUT",
                                socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers")
        glare = ng.nodes.new("CompositorNodeGlare")     # defaults to Bloom in 5.x
        out = ng.nodes.new("NodeGroupOutput")

        def seti(node, name, val):
            if name in node.inputs:
                try:
                    node.inputs[name].default_value = val
                except Exception:
                    pass
        seti(glare, "Type", "Bloom")        # soft round halo, not streaks
        seti(glare, "Threshold", 1.0)
        seti(glare, "Strength", 0.5)
        seti(glare, "Size", 0.45)

        ng.links.new(rl.outputs["Image"], glare.inputs["Image"])
        ng.links.new(glare.outputs["Image"], out.inputs["Image"])
    except Exception as e:
        print("  compositor setup skipped:", e)

def setup_gpu(scene):
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        try:
            prefs.get_devices()
        except Exception:
            pass
        gpu = False
        for dev in prefs.devices:
            on = dev.type != "CPU"
            dev.use = on
            gpu = gpu or on
            print("  device:", dev.type, dev.name, "->", dev.use)
        scene.cycles.device = "GPU" if gpu else "CPU"
        print("  render device:", scene.cycles.device)
    except Exception as e:
        print("  GPU setup failed, using CPU:", e)
        scene.cycles.device = "CPU"

def render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    setup_gpu(scene)
    setup_compositor(scene)
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.01
    scene.cycles.use_light_tree = True
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = OUT_PNG
    scene.view_settings.view_transform = "AgX"

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"[cinema] {QUALITY} render {RES} @ {SAMPLES} spp ...")
    bpy.ops.render.render(write_still=True)
    print("[cinema] saved:", OUT_PNG + ".png")

if __name__ == "__main__":
    build()
    render()
