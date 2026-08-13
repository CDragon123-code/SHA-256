import pya

gds_path = "/home/openroad/SHA-256/flow/SHA256_15ns_full.gds"
lyp_path = "/mnt/d/OpenROAD/SHA-256/sky130_colors.lyp"
out_prefix = "/mnt/d/OpenROAD/SHA-256/layout_view"

layout = pya.Layout()
layout.read(gds_path)
top = layout.cell("SHA256")
bbox = top.dbbox()
print("die w=%.1f h=%.1f um, center=(%.1f, %.1f) um" % (bbox.width(), bbox.height(), bbox.center().x, bbox.center().y))

lv = pya.LayoutView()
lv.load_layout(gds_path)
lv.select_cell(top.cell_index(), 0)
lv.max_hier()
lv.load_layer_props(lyp_path)

# 关键修正：bbox 单位就是 µm，直接使用，不再 *1000
cx = bbox.center().x
cy = bbox.center().y

def zoom_save(name, cx_um, cy_um, w_um):
    lv.zoom_box(pya.DBox(cx_um - w_um/2, cy_um - w_um/2, cx_um + w_um/2, cy_um + w_um/2))
    lv.save_image("%s_%s.png" % (out_prefix, name), 3000, 3000)
    print("Saved %s  center=(%.1f,%.1f) window=%.1fum" % (name, cx_um, cy_um, w_um))

# 中心 1/50（24um）
zoom_save("final_24um", cx, cy, 24)
zoom_save("final_12um", cx, cy, 12)
zoom_save("final_6um", cx, cy, 6)
