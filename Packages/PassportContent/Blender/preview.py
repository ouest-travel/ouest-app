"""Renders quick check frames of the exported passport.

    Blender --factory-startup -b -P preview.py -- <Passport.usdc> <out_dir>

Writes closed.png, open.png and open_side.png using the Workbench engine, so
it is geometry and shading only, not a look-dev render.
"""

import math
import sys

import bpy
from mathutils import Vector

usd_path, out_dir = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.usd_import(filepath=usd_path)

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 900
scene.render.resolution_y = 700
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("Preview")
scene.world.color = (0.9, 0.9, 0.9)

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def look_at(position, target):
    cam.location = position
    direction = Vector(target) - Vector(position)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def find(name):
    return bpy.data.objects[name]


# USD was exported Y-up; the importer converts back, so the book stands in
# X / Z with the viewer at -Y, hinges along Z at x = 0.
W, H = 0.088, 0.125
centre_closed = (W / 2, 0, H / 2)
look_at((W / 2 + 0.03, -0.30, H / 2 + 0.06), centre_closed)
scene.render.filepath = f"{out_dir}/closed.png"
bpy.ops.render.render(write_still=True)

# Open the front cover and the first sheets: rotate about the Z hinge.
# Negative angles swing toward the viewer (-Y), the way a page lifts.
find("FrontCoverPivot").rotation_euler = (0, 0, math.radians(-180))
find("Sheet1").rotation_euler = (0, 0, math.radians(-150))
find("Sheet2").rotation_euler = (0, 0, math.radians(-40))
look_at((0.0, -0.36, H / 2 + 0.04), (0.0, 0, H / 2))
scene.render.filepath = f"{out_dir}/open.png"
bpy.ops.render.render(write_still=True)

look_at((0.16, -0.22, H / 2 + 0.16), (0.0, 0, H / 2))
scene.render.filepath = f"{out_dir}/open_side.png"
bpy.ops.render.render(write_still=True)
print("previews written")
