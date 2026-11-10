"""CC0 texture materials (ambientCG in LP_TEX), box-projected, recoloured, edge-worn and dirtied: orbital_cannon.py's
textured(), shared with component_icons.py.
"""
import os
import bpy
TEX = os.path.expanduser(os.environ.get("LP_TEX", "~/lp-tex"))
def textured(name, tex, hue=None, sat=1.0, val=1.0, scale=0.6, edge=(0.5, 0.5, 0.5), dirt=0.85, normal=0.7, rough_add=0.0):
    """A CC0 material set (ambientCG, in LP_TEX: <tex>/<tex>_2K-JPG_<map>.jpg) box-projected from the object's own
    coordinates (no UVs needed), recoloured by hue/sat/val, its edges worn lighter (the bevel shader) and its crevices
    dirtied (ambient occlusion): procedural noise alone read as a CG render beside Space Age's art (the user, 2026-11-10)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    p = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord"); mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (scale, scale, scale)
    l.new(tc.outputs["Object"], mp.inputs["Vector"])
    def img(kind, color=False):
        path = f"{TEX}/{tex}/{tex}_2K-JPG_{kind}.jpg"
        if not os.path.exists(path): return None
        t = n.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(path, check_existing=True)
        t.projection = "BOX"; t.projection_blend = 0.25
        if not color: t.image.colorspace_settings.name = "Non-Color"
        l.new(mp.outputs["Vector"], t.inputs["Vector"])
        return t
    col = img("Color", True).outputs["Color"]
    if hue is not None or sat != 1.0 or val != 1.0:
        hs = n.new("ShaderNodeHueSaturation")
        hs.inputs["Hue"].default_value = hue if hue is not None else 0.5
        hs.inputs["Saturation"].default_value = sat; hs.inputs["Value"].default_value = val
        l.new(col, hs.inputs["Color"]); col = hs.outputs["Color"]
    mt = img("Metalness")
    if mt: l.new(mt.outputs["Color"], p.inputs["Metallic"])
    rg = img("Roughness")
    if rg:
        ra = n.new("ShaderNodeMath"); ra.operation = "ADD"; ra.inputs[1].default_value = rough_add; ra.use_clamp = True
        l.new(rg.outputs["Color"], ra.inputs[0]); l.new(ra.outputs[0], p.inputs["Roughness"])
    nm = img("NormalGL")
    if nm:
        nmap = n.new("ShaderNodeNormalMap"); nmap.inputs["Strength"].default_value = normal
        l.new(nm.outputs["Color"], nmap.inputs["Color"]); l.new(nmap.outputs["Normal"], p.inputs["Normal"])
    # Edge wear (the bevel shader's normal leaving the true one), broken in patches by the texture's own value.
    geo = n.new("ShaderNodeNewGeometry")
    bv = n.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.05; bv.samples = 6
    dot = n.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    l.new(bv.outputs["Normal"], dot.inputs[0]); l.new(geo.outputs["Normal"], dot.inputs[1])
    em = n.new("ShaderNodeMapRange"); em.inputs["From Min"].default_value = 0.995; em.inputs["From Max"].default_value = 0.92
    l.new(dot.outputs["Value"], em.inputs["Value"])
    me = n.new("ShaderNodeMix"); me.data_type = "RGBA"; me.inputs[7].default_value = (*edge, 1)
    l.new(em.outputs["Result"], me.inputs[0]); l.new(col, me.inputs[6]); col = me.outputs[2]
    ao = n.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.6; ao.samples = 8
    dr = n.new("ShaderNodeMapRange"); dr.inputs["To Min"].default_value = dirt; dr.inputs["To Max"].default_value = 0.0
    l.new(ao.outputs["AO"], dr.inputs["Value"])
    md = n.new("ShaderNodeMix"); md.data_type = "RGBA"; md.inputs[7].default_value = (0.05, 0.03, 0.015, 1)
    l.new(dr.outputs["Result"], md.inputs[0]); l.new(col, md.inputs[6])
    l.new(md.outputs[2], p.inputs["Base Color"])
    return m

