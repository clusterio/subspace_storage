import bpy

scene = bpy.data.scenes["Scene"]
scene_collection = scene.view_layers["View Layer"].layer_collection


def set_exclude(model, value):
    scene_collection.children[model].exclude = value

def set_obj_color(obj, color):
    for slot in obj.material_slots:
        if slot.material.name.startswith("Brand "):
            slot.material = bpy.data.materials[f"Brand {color}"]

def set_color(model, color):
    for obj in scene_collection.children[model].collection.all_objects.values():
        set_obj_color(obj, color)

    for obj in scene_collection.children["Common"].collection.all_objects.values():
        set_obj_color(obj, color)

def render_subspace_interactor(color, model, output):
    set_exclude(model, False)
    set_color(model, color)
    scene.render.filepath = output
    bpy.ops.render.render(write_still=True)
    set_exclude(model, True)

def render_shadow(model, output):
    set_exclude(model, False)
    scene.render.filepath = output
    bpy.ops.render.render(write_still=True)
    set_exclude(model, True)

models = [
    "Item",
    "Fluid",
    "Electricity",
]


# Code for prototyping speedup
# scene.cycles.samples = 10

# Reset visibility of all collections
set_exclude("Common", False)
set_exclude("Shadow", True)
for model in models:
    set_exclude(model, True)

# Render the models
scene.world = bpy.data.worlds["World"]
for model in models:
    render_subspace_interactor("Blue", model, f"//../render/{model.lower()}-extractor.png")
    render_subspace_interactor("Purple", model, f"//../render/{model.lower()}-injector.png")

# Render the shadows
for obj in scene.objects:
    for slot in obj.material_slots:
        if not slot.material.name.startswith("Shadow "):
            slot.material = bpy.data.materials["Shadow Caster"]

set_exclude("Shadow", False)
scene.world = bpy.data.worlds["Shadow"]
for model in models:
    render_shadow(model, f"//../render/{model.lower()}-shadow.png")
