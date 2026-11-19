"""Builds the Ouest passport model and exports it as USD.

Run headless:
    /Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b \
        -P make_passport.py -- <output.usdc>

Geometry only. Everything that varies per user (cover colour, title, crest,
stamps) is applied at runtime in PassportView, so the materials here are
neutral and the UVs are clean 0...1 planar maps.

Coordinates: the book stands upright facing the viewer. In Blender X runs
across the width, Z up the page and -Y toward the viewer; the export
converts to Y-up so RealityKit sees X across, Y up and +Z toward the camera.
"d" below is depth toward the viewer (Blender y = -d).

Hierarchy (prim names are what PassportView looks up):
    BackCover            static board, d in [0, t]
    RightBlock           static half of the page block on the back cover
    FrontCoverPivot      hinge at the spine, mid-thickness
        FrontCover       board, d in [t + p, 2t + p]
        LeftBlock        other half of the page block, rides with the cover
    Sheet1..Sheet3       hinges at the spine, just above the stack; each holds
                         <name>Front/<name>Back, subdivided planes so they can
                         bend while turning

PassportScene.swift mirrors the dimensions below; change both together.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Vector

# --- dimensions (metres) ---------------------------------------------------
W = 0.088          # cover width
H = 0.125          # cover height
T = 0.0016         # board thickness
P = 0.0036         # page block thickness, both halves together
R = 0.004          # cover corner radius
BEVEL = 0.0005     # cover edge bevel
M = 0.0015         # page inset from the cover's three outer edges
G = 0.0008         # page inset from the spine
EPS = 0.00016      # vertical gap between turnable sheets, kept wide enough
                   # that neighbouring faces never fight in the depth buffer

HINGE_D = T + P / 2  # every hinge sits mid-thickness at x = 0


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            block.remove(item)


def material(name, rgb, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def new_object(name, bm, materials, parent=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for face in mesh.polygons:
        face.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    for mat in materials:
        obj.data.materials.append(mat)
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def pivot(name, d):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.01
    empty.location = Vector((0.0, -d, 0.0))
    bpy.context.collection.objects.link(empty)
    bpy.context.view_layer.update()
    return empty


def rounded_rect(x0, x1, z0, z1, radius, segments=8):
    """Outline points (x, z) of a rounded rectangle, counter-clockwise."""
    points = []
    corners = [
        (x1 - radius, z1 - radius, 0.0),
        (x0 + radius, z1 - radius, math.pi / 2),
        (x0 + radius, z0 + radius, math.pi),
        (x1 - radius, z0 + radius, 3 * math.pi / 2),
    ]
    for cx, cz, start in corners:
        for i in range(segments + 1):
            a = start + (math.pi / 2) * i / segments
            points.append((cx + radius * math.cos(a), cz + radius * math.sin(a)))
    return points


def planar_uv(bm, x0, x1, z0, z1, mirror_u=False):
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            x, _, z = loop.vert.co
            u = (x - x0) / (x1 - x0)
            v = (z - z0) / (z1 - z0)
            loop[uv_layer].uv = (1.0 - u if mirror_u else u, v)


def slab(outline, d0, d1):
    """Extrudes a closed (x, z) outline between depths d0 < d1."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, -d0, z)) for x, z in outline]
    top = [bm.verts.new((x, -d1, z)) for x, z in outline]
    n = len(outline)
    # Caps. The outline is counter-clockwise seen from +Y (behind the book),
    # so the back cap faces -? We fix winding below with recalc_normals.
    bm.faces.new(bottom)
    bm.faces.new(top)
    for i in range(n):
        bm.faces.new((bottom[i], bottom[(i + 1) % n], top[(i + 1) % n], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, bottom, top


def board(name, d0, d1, mat, parent=None):
    outline = rounded_rect(0.0, W, 0.0, H, R)
    bm, bottom, top = slab(outline, d0, d1)
    rim = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-9]
    bmesh.ops.bevel(
        bm, geom=rim, offset=BEVEL, offset_type="OFFSET", segments=3,
        profile=0.72, affect="EDGES", clamp_overlap=True,
    )
    planar_uv(bm, 0.0, W, 0.0, H)
    return new_object(name, bm, [mat], parent)


def block(name, d0, d1, paper, edges, parent=None):
    x0, x1, z0, z1 = G, W - M, M, H - M
    outline = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    bm, _, _ = slab(outline, d0, d1)
    # Faces whose normal is along Y are paper; the four sides are page edges.
    for face in bm.faces:
        face.material_index = 0 if abs(face.normal.y) > 0.5 else 1
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            x, y, z = loop.vert.co
            if face.material_index == 0:
                # A cap that faces away from the viewer (+Y) is only ever seen
                # after its parent flips 180°, so mirror u to keep text upright.
                u = (x - x0) / (x1 - x0)
                if face.normal.y > 0:
                    u = 1.0 - u
                loop[uv_layer].uv = (u, (z - z0) / (z1 - z0))
            else:
                # Run the stripes along the edge, thickness across v.
                along = (x - x0) / (x1 - x0) if abs(face.normal.z) > 0.5 else (z - z0) / (z1 - z0)
                loop[uv_layer].uv = (along, (-y - d0) / (d1 - d0))
    return new_object(name, bm, [paper, edges], parent)


def sheet_face(name, d, facing_viewer, paper, parent):
    x0, x1, z0, z1 = G, W - M, M, H - M
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=32, y_segments=4, size=0.5)
    # create_grid lies in XY centred on the origin; map it onto XZ.
    for v in bm.verts:
        gx, gy, _ = v.co
        v.co = Vector((x0 + (gx + 0.5) * (x1 - x0), -d, z0 + (gy + 0.5) * (z1 - z0)))
    # An open grid has no "outside", so set the winding explicitly from the
    # recomputed normals. RealityKit culls back faces, so this must be right.
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    want = -1.0 if facing_viewer else 1.0   # viewer is at -Y in Blender space
    if bm.faces and (bm.faces[0].normal.y * want) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.normal_update()
    assert all(f.normal.y * want > 0 for f in bm.faces), name
    planar_uv(bm, x0, x1, z0, z1, mirror_u=not facing_viewer)
    return new_object(name, bm, [paper], parent)


def build():
    reset_scene()
    leather = material("CoverLeather", (0.55, 0.55, 0.55), 0.62)
    paper = material("Paper", (0.95, 0.93, 0.87), 0.92)
    edges = material("PageEdges", (0.90, 0.88, 0.82), 0.95)

    board("BackCover", 0.0, T, leather)
    block("RightBlock", T, T + P / 2, paper, edges)

    front_pivot = pivot("FrontCoverPivot", HINGE_D)
    board("FrontCover", T + P, 2 * T + P, leather, parent=front_pivot)
    block("LeftBlock", T + P / 2, T + P, paper, edges, parent=front_pivot)

    # Sheets hinge just above the whole stack. A sheet at hinge - k lands at
    # hinge + k, so turned sheets pile on top of the left pages, in order,
    # instead of landing inside the LeftBlock.
    sheet_hinge = HINGE_D + EPS * 4
    for index in range(1, 4):
        d = HINGE_D + EPS * (4 - index)   # Sheet1 is on top
        hinge = pivot(f"Sheet{index}", sheet_hinge)
        sheet_face(f"Sheet{index}Front", d + EPS * 0.25, True, paper, hinge)
        sheet_face(f"Sheet{index}Back", d - EPS * 0.25, False, paper, hinge)


def export(path):
    bpy.ops.wm.usd_export(
        filepath=path,
        selected_objects_only=False,
        export_uvmaps=True,
        export_normals=True,
        export_materials=True,
        export_textures_mode="KEEP",
        triangulate_meshes=True,
        convert_world_material=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        root_prim_path="/Passport",
    )


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1]
    build()
    export(out)
    print(f"wrote {out}")
