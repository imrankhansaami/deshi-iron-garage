class_name ElecProps
extends RefCounted
## World A, electronics register: the repair-shop half of the garage. Taken from
## the reference photographs of Bangladeshi computer-repair lanes — stacked dead
## desktops, opened CRTs with the anode still attached, motherboard shards,
## multimeters, solder stations, UPS/IPS batteries, and the tangled cable mass
## that hangs off every bench.
##
## Screens are deliberately NOT modelled here as flat decals: the monitor bodies
## expose a named "Screen" mesh whose material the runtime swaps for a live
## SubViewport texture, so the workstation UI is real geometry in the world.
##
## Orientation note: Godot's TorusMesh is generated in the XZ plane, so a torus
## encircling a VERTICAL cylinder needs no rotation. Only parts whose axis is
## horizontal (fan guards, board connectors, the reel drum) carry the PI/2.


static func register(f: PropFactory) -> void:
	f.generators["desktop_tower"] = desktop_tower
	f.generators["crt_monitor"] = crt_monitor
	f.generators["lcd_monitor"] = lcd_monitor
	f.generators["keyboard"] = keyboard
	f.generators["mouse"] = mouse
	f.generators["laptop_shell"] = laptop_shell
	f.generators["pcb_board"] = pcb_board
	f.generators["pcb_stack"] = pcb_stack
	f.generators["heatsink"] = heatsink
	f.generators["capacitor"] = capacitor
	f.generators["resistor_pack"] = resistor_pack
	f.generators["multimeter"] = multimeter
	f.generators["soldering_iron"] = soldering_iron
	f.generators["solder_spool"] = solder_spool
	f.generators["wire_cutters"] = wire_cutters
	f.generators["wire_spool"] = wire_spool
	f.generators["component_drawer"] = component_drawer
	f.generators["ups_battery"] = ups_battery
	f.generators["ips_battery"] = ips_battery
	f.generators["power_strip"] = power_strip
	f.generators["switchboard"] = switchboard
	f.generators["mcb_row"] = mcb_row
	f.generators["cpu_fan"] = cpu_fan
	f.generators["ram_stick"] = ram_stick
	f.generators["jack_socket"] = jack_socket
	f.generators["power_adapter"] = power_adapter
	f.generators["ribbon_cable"] = ribbon_cable
	f.generators["dip_switch"] = dip_switch
	f.generators["led_cluster"] = led_cluster
	f.generators["transformer_core"] = transformer_core
	f.generators["fuse_glass"] = fuse_glass
	f.generators["oscilloscope"] = oscilloscope
	f.generators["variac"] = variac
	f.generators["voltage_regulator"] = voltage_regulator
	f.generators["transistor_radio"] = transistor_radio
	f.generators["crt_guts"] = crt_guts
	f.generators["blower_fan"] = blower_fan
	f.generators["printer"] = printer
	f.generators["speaker"] = speaker
	f.generators["router_box"] = router_box
	f.generators["stabilizer"] = stabilizer
	f.generators["solder_station"] = solder_station
	f.generators["antenna_roof"] = antenna_roof
	f.generators["battery_rack"] = battery_rack


# ===========================================================================
# Computers
# ===========================================================================

static func desktop_tower(f: PropFactory, o: Dictionary) -> Node3D:
	## The second-hand desktop: yellowed beige case, front mesh, exposed drive
	## bays, and the side panel missing so the motherboard is visible.
	var h: float = float(o.get("height", 0.42))
	var w: float = 0.19
	var d: float = 0.44
	var root := Node3D.new()
	root.name = "DesktopTower"
	var case_mat: StandardMaterial3D = f.ML.beige_plastic()
	var shell: MeshInstance3D = ShapeKit.box(Vector3(w, h, d), case_mat, "Case")
	shell.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(shell)
	var bezel: MeshInstance3D = ShapeKit.box(Vector3(w * 1.02, h * 0.98, 0.012), f.ML.beige_plastic(true), "Bezel")
	bezel.position = Vector3(0.0, h * 0.5, d * 0.5)
	root.add_child(bezel)
	var grille: MeshInstance3D = ShapeKit.box(Vector3(w * 0.6, 0.05, 0.004), f.ML.plastic_black(), "Grille")
	grille.position = Vector3(0.0, h * 0.18, d * 0.5 + 0.008)
	root.add_child(grille)
	var button: MeshInstance3D = ShapeKit.cyl(0.016, 0.008, f.ML.plastic_faded(), 12, Vector3i(0, 0, 1), "PowerButton")
	button.position = Vector3(-w * 0.28, h * 0.82, d * 0.5 + 0.008)
	root.add_child(button)
	var led_p: MeshInstance3D = ShapeKit.sphere(0.006, f.ML.indicator(Color("5fd08a"), 0.0), 8, "PowerLed")
	led_p.position = Vector3(w * 0.28, h * 0.86, d * 0.5 + 0.008)
	root.add_child(led_p)
	var led_h: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(Color("ffb347"), 0.0), 8, "HddLed")
	led_h.position = Vector3(w * 0.28, h * 0.78, d * 0.5 + 0.008)
	root.add_child(led_h)
	for i: int in range(2):
		var bay: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.028, 0.005), f.ML.plastic_faded(), "Bay")
		bay.position = Vector3(0.0, h * 0.62 - float(i) * 0.05, d * 0.5 + 0.006)
		root.add_child(bay)
	# open side: motherboard, PSU, expansion card
	var mobo: MeshInstance3D = ShapeKit.box(Vector3(0.004, h * 0.72, d * 0.72), f.ML.pcb(), "Motherboard")
	mobo.position = Vector3(-w * 0.4, h * 0.45, -0.02)
	root.add_child(mobo)
	var psu: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.08, d * 0.3), f.ML.steel_dark(), "PSU")
	psu.position = Vector3(0.0, h - 0.05, -d * 0.32)
	root.add_child(psu)
	var riser: MeshInstance3D = ShapeKit.box(Vector3(w * 0.7, 0.09, 0.006), f.ML.pcb(), "Card")
	riser.position = Vector3(0.0, h * 0.25, -d * 0.2)
	root.add_child(riser)
	var cooler: MeshInstance3D = ShapeKit.cyl(0.035, 0.03, f.ML.aluminium(), 14, Vector3i(1, 0, 0), "CpuCooler")
	cooler.position = Vector3(-w * 0.3, h * 0.55, 0.02)
	root.add_child(cooler)
	for i: int in range(9):
		var fin: MeshInstance3D = ShapeKit.box(Vector3(0.004, 0.07, 0.07), f.ML.aluminium(), "Fin")
		fin.position = Vector3(-w * 0.3 + float(i) * 0.004 - 0.018, h * 0.55, 0.02)
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fin)
	for i: int in range(5):
		var cap: Node3D = capacitor(f, {"height": 0.028, "radius": 0.006})
		cap.position = Vector3(-w * 0.36, h * 0.3 + float(i) * 0.03, 0.06 + float(i) * 0.02)
		root.add_child(cap)
	var inlet: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.03, 0.006), f.ML.plastic_black(), "MainsInlet")
	inlet.position = Vector3(0.04, h - 0.05, -d * 0.5)
	root.add_child(inlet)
	var feet: MeshInstance3D = ShapeKit.box(Vector3(w + 0.02, 0.012, d + 0.02), f.ML.rubber(), "Feet")
	feet.position = Vector3(0.0, 0.006, 0.0)
	root.add_child(feet)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	root.set_meta("led_power_path", "PowerLed")
	root.set_meta("led_hdd_path", "HddLed")
	root.set_meta("button_path", "PowerButton")
	return root


static func crt_monitor(f: PropFactory, o: Dictionary) -> Node3D:
	## The 17-inch CRT: deep cabinet, curved glass, the control cluster on the
	## front right, and the neck visible where the case is opened in the reference.
	var w: float = float(o.get("width", 0.42))
	var h: float = w * 0.78
	var d: float = w * 0.92
	var root := Node3D.new()
	root.name = "CrtMonitor"
	var case_mat: StandardMaterial3D = f.ML.beige_plastic()
	var body: MeshInstance3D = ShapeKit.box(Vector3(w, h, d * 0.8), case_mat, "Body")
	body.position = Vector3(0.0, h * 0.5, -d * 0.1)
	root.add_child(body)
	var back: MeshInstance3D = ShapeKit.tapered_cyl(w * 0.34, w * 0.2, d * 0.35, case_mat, 16, "Neck")
	back.position = Vector3(0.0, h * 0.55, -d * 0.62)
	back.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(back)
	# the curved tube face: a squashed sphere, the only honest approximation of a
	// shadow-mask envelope without importing a model
	var face: MeshInstance3D = ShapeKit.sphere(w * 0.62, f.ML.glass_screen(), 18, "Screen")
	face.position = Vector3(0.0, h * 0.52, -d * 0.02)
	face.scale = Vector3(1.0, 0.82, 0.28)
	root.add_child(face)
	var bezel: MeshInstance3D = ShapeKit.box(Vector3(w * 0.96, h * 0.86, 0.02), case_mat, "Bezel")
	bezel.position = Vector3(0.0, h * 0.52, d * 0.28)
	root.add_child(bezel)
	var panel: MeshInstance3D = ShapeKit.box(Vector3(w * 0.22, 0.05, 0.012), f.ML.plastic_faded(), "Controls")
	panel.position = Vector3(w * 0.36, h * 0.12, d * 0.3)
	root.add_child(panel)
	for i: int in range(4):
		var btn: MeshInstance3D = ShapeKit.cyl(0.007, 0.006, f.ML.plastic_black(), 8, Vector3i(0, 0, 1), "Btn")
		btn.position = panel.position + Vector3(-0.02 + float(i) * 0.014, 0.0, 0.008)
		root.add_child(btn)
	var led: MeshInstance3D = ShapeKit.sphere(0.006, f.ML.indicator(Color("5fd08a"), 0.0), 8, "StandbyLed")
	led.position = panel.position + Vector3(-w * 0.08, 0.0, 0.008)
	root.add_child(led)
	var neck: MeshInstance3D = ShapeKit.box(Vector3(w * 0.3, 0.06, d * 0.3), case_mat, "Stand")
	neck.position = Vector3(0.0, -0.03, 0.0)
	root.add_child(neck)
	var base: MeshInstance3D = ShapeKit.box(Vector3(w * 0.7, 0.025, d * 0.5), case_mat, "Base")
	base.position = Vector3(0.0, -0.06, 0.02)
	root.add_child(base)
	for i: int in range(6):
		var slot: MeshInstance3D = ShapeKit.box(Vector3(w * 0.5, 0.004, 0.008), f.ML.plastic_black(), "Vent")
		slot.position = Vector3(0.0, h * 0.99, -d * 0.2 + float(i) * 0.02)
		slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(slot)
	root.set_meta("screen_path", "Screen")
	root.set_meta("led_path", "StandbyLed")
	return root


static func lcd_monitor(f: PropFactory, o: Dictionary) -> Node3D:
	var w: float = float(o.get("width", 0.46))
	var h: float = w * 0.6
	var root := Node3D.new()
	root.name = "LcdMonitor"
	var shell: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.035), f.ML.plastic_black(), "Shell")
	shell.position = Vector3(0.0, h * 0.5 + 0.16, 0.0)
	root.add_child(shell)
	var screen: MeshInstance3D = ShapeKit.box(Vector3(w * 0.94, h * 0.88, 0.004), f.ML.glass_screen(), "Screen")
	screen.position = Vector3(0.0, h * 0.5 + 0.16, 0.02)
	root.add_child(screen)
	var chin: MeshInstance3D = ShapeKit.box(Vector3(w, 0.045, 0.04), f.ML.plastic_faded(), "Chin")
	chin.position = Vector3(0.0, 0.16 + 0.02, 0.0)
	root.add_child(chin)
	var brand: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.012, 0.004), f.ML.chrome(), "Brand")
	brand.position = Vector3(0.0, 0.16 + 0.02, 0.021)
	root.add_child(brand)
	var led: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(Color("4fd8ff"), 0.0), 8, "PowerLed")
	led.position = Vector3(w * 0.4, 0.16 + 0.02, 0.021)
	root.add_child(led)
	var post: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.16, 0.04), f.ML.plastic_black(), "Post")
	post.position = Vector3(0.0, 0.08, -0.01)
	root.add_child(post)
	var base: MeshInstance3D = ShapeKit.cyl(0.13, 0.018, f.ML.plastic_black(), 18, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.009, 0.0)
	root.add_child(base)
	root.set_meta("screen_path", "Screen")
	root.set_meta("led_path", "PowerLed")
	return root


static func keyboard(f: PropFactory, o: Dictionary) -> Node3D:
	var w: float = float(o.get("width", 0.42))
	var root := Node3D.new()
	root.name = "Keyboard"
	var body: MeshInstance3D = ShapeKit.box(Vector3(w, 0.018, w * 0.36), f.ML.beige_plastic(true), "Body")
	body.position = Vector3(0.0, 0.009, 0.0)
	root.add_child(body)
	var cols: int = 15
	var rows: int = 5
	var kx: float = (w - 0.03) / float(cols)
	var kz: float = (w * 0.36 - 0.03) / float(rows)
	var key_mesh: Mesh = ShapeKit._cached("key|%.4f|%.4f" % [kx * 0.86, kz * 0.8], func() -> Mesh:
		var bm := BoxMesh.new()
		bm.size = Vector3(kx * 0.86, 0.008, kz * 0.8)
		return bm)
	var key_mat: StandardMaterial3D = f.ML.beige_plastic(false)
	for r: int in range(rows):
		for c: int in range(cols):
			var k := MeshInstance3D.new()
			k.mesh = key_mesh
			k.material_override = key_mat
			k.name = "Key"
			k.position = Vector3(
				-w * 0.5 + 0.015 + (float(c) + 0.5) * kx,
				0.02,
				-w * 0.18 + 0.015 + (float(r) + 0.5) * kz,
			)
			k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(k)
	var cable: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.01, -w * 0.18), Vector3(0.06, 0.0, -w * 0.55), 0.0035, 0.02, f.ML.cable_material(Color("#4a4a44")), "Cable")
	root.add_child(cable)
	return root


static func mouse(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Mouse"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.032, 0.0), Vector2(0.034, 0.008), Vector2(0.028, 0.02),
		Vector2(0.016, 0.026), Vector2(0.0, 0.028),
	]), 14, f.ML.beige_plastic(true), true, "Body")
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	body.scale = Vector3(1.0, 1.35, 1.0)
	root.add_child(body)
	var wheel: MeshInstance3D = ShapeKit.cyl(0.006, 0.012, f.ML.rubber(), 10, Vector3i(0, 0, 1), "Wheel")
	wheel.position = Vector3(0.0, 0.018, 0.01)
	root.add_child(wheel)
	var cable: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.01, -0.04), Vector3(0.05, 0.0, -0.16), 0.0025, 0.01, f.ML.cable_material(Color("#4a4a44")), "Cable")
	root.add_child(cable)
	return root


static func laptop_shell(f: PropFactory, o: Dictionary) -> Node3D:
	## A gutted laptop: base with the keyboard deck missing, lid propped open,
	## ribbon cables and the mainboard exposed — exactly the state in the
	## reference photo of the electronics lane.
	var w: float = float(o.get("width", 0.34))
	var root := Node3D.new()
	root.name = "LaptopShell"
	var base: MeshInstance3D = ShapeKit.box(Vector3(w, 0.022, w * 0.68), f.ML.plastic_black(), "Base")
	base.position = Vector3(0.0, 0.011, 0.0)
	root.add_child(base)
	var cavity: MeshInstance3D = ShapeKit.box(Vector3(w * 0.9, 0.012, w * 0.5), f.ML.pcb(), "Cavity")
	cavity.position = Vector3(0.0, 0.02, -w * 0.05)
	root.add_child(cavity)
	var lid: MeshInstance3D = ShapeKit.box(Vector3(w, w * 0.62, 0.008), f.ML.plastic_black(), "Lid")
	lid.position = Vector3(0.0, w * 0.28, -w * 0.34)
	lid.rotation = Vector3(-1.15, 0.0, 0.0)
	root.add_child(lid)
	var hinge: MeshInstance3D = ShapeKit.cyl(0.006, w * 0.8, f.ML.steel_dark(), 8, Vector3i(1, 0, 0), "Hinge")
	hinge.position = Vector3(0.0, 0.024, -w * 0.33)
	root.add_child(hinge)
	for i: int in range(3):
		var rib: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.002, 0.12 + float(i) * 0.03), f.ML.ribbon_orange(), "Ribbon")
		rib.position = Vector3(-w * 0.25 + float(i) * 0.06, 0.026, -0.02)
		rib.rotation = Vector3(0.0, 0.0, f.rand().randf_range(-0.3, 0.3))
		root.add_child(rib)
	var batt: MeshInstance3D = ShapeKit.box(Vector3(w * 0.4, 0.014, 0.06), f.ML.plastic_black(), "Battery")
	batt.position = Vector3(0.0, 0.018, w * 0.28)
	root.add_child(batt)
	var hdd: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.01, 0.1), f.ML.aluminium(), "Drive")
	hdd.position = Vector3(w * 0.3, 0.03, w * 0.2)
	root.add_child(hdd)
	for i: int in range(6):
		var s: MeshInstance3D = ShapeKit.cyl(0.003, 0.008, f.ML.steel(), 6, Vector3i(0, 1, 0), "Screw")
		s.position = Vector3(f.rand().randf_range(-w * 0.4, w * 0.4), 0.004, f.rand().randf_range(-w * 0.3, w * 0.3))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s)
	return root


static func printer(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Printer"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.14, 0.3), f.ML.beige_plastic(true), "Body")
	body.position = Vector3(0.0, 0.07, 0.0)
	root.add_child(body)
	var tray: MeshInstance3D = ShapeKit.box(Vector3(0.36, 0.02, 0.22), f.ML.plastic_faded(), "FeedTray")
	tray.position = Vector3(0.0, 0.15, -0.02)
	tray.rotation.x = -0.25
	root.add_child(tray)
	var out: MeshInstance3D = ShapeKit.box(Vector3(0.38, 0.01, 0.16), f.ML.plastic_faded(), "Output")
	out.position = Vector3(0.0, 0.06, 0.18)
	root.add_child(out)
	var paper: MeshInstance3D = ShapeKit.box(Vector3(0.3, 0.002, 0.2), f.ML.paper(), "Paper")
	paper.position = Vector3(0.0, 0.065, 0.18)
	root.add_child(paper)
	var led: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(Color("ffb347"), 0.0), 8, "Led")
	led.position = Vector3(0.16, 0.13, 0.14)
	root.add_child(led)
	return root


static func speaker(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Speaker"
	var box_b: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.22, 0.12), f.ML.woodgrain_dark(), "Cabinet")
	box_b.position = Vector3(0.0, 0.11, 0.0)
	root.add_child(box_b)
	var woofer: MeshInstance3D = ShapeKit.cyl(0.05, 0.02, f.ML.rubber(), 16, Vector3i(0, 0, 1), "Woofer")
	woofer.position = Vector3(0.0, 0.07, 0.065)
	root.add_child(woofer)
	var cone: MeshInstance3D = ShapeKit.tapered_cyl(0.012, 0.045, 0.02, f.ML.paper_cone(), 14, "Cone")
	cone.position = Vector3(0.0, 0.07, 0.075)
	cone.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(cone)
	var tweeter: MeshInstance3D = ShapeKit.cyl(0.022, 0.015, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "Tweeter")
	tweeter.position = Vector3(0.0, 0.16, 0.065)
	root.add_child(tweeter)
	var grill: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.21, 0.004), f.ML.fabric_grill(), "Grill")
	grill.position = Vector3(0.0, 0.11, 0.062)
	root.add_child(grill)
	var knob: MeshInstance3D = ShapeKit.cyl(0.012, 0.02, f.ML.plastic_black(), 10, Vector3i(0, 0, 1), "Volume")
	knob.position = Vector3(0.0, 0.02, 0.065)
	root.add_child(knob)
	return root


static func router_box(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Router"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.03, 0.11), f.ML.plastic_white_gloss(), "Body")
	body.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(body)
	var antenna: MeshInstance3D = ShapeKit.cyl(0.005, 0.14, f.ML.plastic_black(), 8, Vector3i(0, 1, 0), "Antenna")
	antenna.position = Vector3(0.06, 0.1, -0.04)
	antenna.rotation.z = 0.3
	root.add_child(antenna)
	for i: int in range(4):
		var led: MeshInstance3D = ShapeKit.sphere(0.004, f.ML.indicator(Color("5fd08a") if i % 2 == 0 else Color("ffb347"), 0.0), 6, "Led%d" % i)
		led.position = Vector3(-0.05 + float(i) * 0.02, 0.028, 0.05)
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(led)
	var ports: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.012, 0.006), f.ML.plastic_black(), "Ports")
	ports.position = Vector3(0.0, 0.012, -0.055)
	root.add_child(ports)
	return root


static func stabilizer(f: PropFactory, _o: Dictionary) -> Node3D:
	## The voltage stabilizer / servo regulator, a fixture in every Bangladeshi
	## home with unreliable supply.
	var root := Node3D.new()
	root.name = "Stabilizer"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.32, 0.18), f.ML.paint_black_or_dark(), "Body")
	body.position = Vector3(0.0, 0.16, 0.0)
	root.add_child(body)
	var meter: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.07, 0.01), f.ML.meter_face(), "Meter")
	meter.position = Vector3(0.0, 0.26, 0.095)
	root.add_child(meter)
	var needle: MeshInstance3D = ShapeKit.box(Vector3(0.002, 0.05, 0.002), f.ML.indicator(Color("e2453c"), 0.4), "Needle")
	needle.position = Vector3(0.0, 0.25, 0.1)
	needle.rotation.z = 0.4
	root.add_child(needle)
	var lamp_colors: Array[Color] = [Color("5fd08a"), Color("ffb347"), Color("e2453c")]
	for i: int in range(3):
		var led: MeshInstance3D = ShapeKit.sphere(0.007, f.ML.indicator(lamp_colors[i], 0.0), 8, "Led")
		led.position = Vector3(-0.07 + float(i) * 0.07, 0.16, 0.095)
		root.add_child(led)
	var socket: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.05, 0.008), f.ML.plastic_faded(), "Socket")
	socket.position = Vector3(0.06, 0.08, 0.095)
	root.add_child(socket)
	var breaker: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.05, 0.02), f.ML.plastic_red(), "Breaker")
	breaker.position = Vector3(-0.08, 0.08, 0.09)
	root.add_child(breaker)
	root.add_child(ShapeKit.col_box(Vector3(0.24, 0.32, 0.18)))
	return root


static func transistor_radio(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Radio"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.11, 0.05), f.ML.woodgrain_dark(), "Case")
	body.position = Vector3(0.0, 0.055, 0.0)
	root.add_child(body)
	var grill: MeshInstance3D = ShapeKit.box(Vector3(0.08, 0.08, 0.006), f.ML.fabric_grill(), "Grill")
	grill.position = Vector3(-0.045, 0.055, 0.027)
	root.add_child(grill)
	var dial: MeshInstance3D = ShapeKit.cyl(0.018, 0.012, f.ML.plastic_faded(), 12, Vector3i(0, 0, 1), "TuningDial")
	dial.position = Vector3(0.05, 0.08, 0.03)
	root.add_child(dial)
	var vol: MeshInstance3D = ShapeKit.cyl(0.014, 0.012, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "Volume")
	vol.position = Vector3(0.05, 0.04, 0.03)
	root.add_child(vol)
	var scale: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.02, 0.004), f.ML.newspaper(), "Scale")
	scale.position = Vector3(0.0, 0.1, 0.026)
	root.add_child(scale)
	# the strap stands in a vertical plane behind the case
	var strap: MeshInstance3D = ShapeKit.torus(0.09, 0.005, f.ML.leather_like(), 14, 5, "Strap")
	strap.position = Vector3(0.0, 0.06, -0.03)
	strap.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(strap)
	return root


# ===========================================================================
# Components and boards
# ===========================================================================

static func pcb_board(f: PropFactory, o: Dictionary) -> Node3D:
	## A board shard: substrate, traces from the texture, pads, capacitors, an IC
	## with legs, a connector edge and the occasional through-hole resistor.
	var w: float = float(o.get("width", 0.14))
	var d: float = float(o.get("depth", 0.09))
	var root := Node3D.new()
	root.name = "PcbBoard"
	var subs: MeshInstance3D = ShapeKit.box(Vector3(w, 0.0016, d), f.ML.pcb(), "Substrate")
	subs.position = Vector3(0.0, 0.0008, 0.0)
	root.add_child(subs)
	var chips: int = clampi(int(o.get("chips", 3)), 0, 6)
	for i: int in range(chips):
		var cw: float = f.rand().randf_range(0.012, 0.03)
		var ic := MeshInstance3D.new()
		ic.mesh = ShapeKit._cached("ic|%.4f|%.4f" % [cw, cw * 0.7], func() -> Mesh:
			var bm := BoxMesh.new()
			bm.size = Vector3(cw, 0.004, cw * 0.7)
			return bm)
		ic.material_override = f.ML.plastic_black()
		ic.name = "Ic%d" % i
		ic.position = Vector3(f.rand().randf_range(-w * 0.35, w * 0.35), 0.0035, f.rand().randf_range(-d * 0.3, d * 0.3))
		ic.rotation.y = 0.0 if f.rand().randf() > 0.5 else PI * 0.5
		root.add_child(ic)
		for k: int in range(4):
			var leg: MeshInstance3D = ShapeKit.box(Vector3(0.0015, 0.001, 0.004), f.ML.silver_solder(), "Leg")
			leg.position = ic.position + Vector3(-cw * 0.4 + float(k) * cw * 0.27, 0.001, cw * 0.38)
			leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(leg)
	for i: int in range(clampi(int(o.get("caps", 2)), 0, 6)):
		var c: Node3D = capacitor(f, {"height": f.rand().randf_range(0.008, 0.02), "radius": f.rand().randf_range(0.003, 0.006)})
		c.position = Vector3(f.rand().randf_range(-w * 0.4, w * 0.4), 0.002, f.rand().randf_range(-d * 0.35, d * 0.35))
		root.add_child(c)
	var fingers: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.0006, 0.008), f.ML.gold_finger(), "Connector")
	fingers.position = Vector3(0.0, 0.0016, d * 0.5 - 0.006)
	root.add_child(fingers)
	return root


static func pcb_stack(f: PropFactory, o: Dictionary) -> Node3D:
	## The heap of board shards that defines a second-hand electronics lane.
	var root := Node3D.new()
	root.name = "PcbStack"
	var n: int = clampi(int(o.get("count", 9)), 2, 30)
	for i: int in range(n):
		var b: Node3D = pcb_board(f, {"width": f.rand().randf_range(0.08, 0.18), "depth": f.rand().randf_range(0.05, 0.12), "chips": 2, "caps": 1})
		b.position = Vector3(f.rand().randf_range(-0.06, 0.06), 0.004 + float(i) * 0.006, f.rand().randf_range(-0.06, 0.06))
		b.rotation = Vector3(f.rand().randf_range(-0.12, 0.12), f.rand().randf_range(0, 3.14), f.rand().randf_range(-0.12, 0.12))
		root.add_child(b)
	return root


static func heatsink(f: PropFactory, o: Dictionary) -> Node3D:
	var size: float = float(o.get("size", 0.06))
	var root := Node3D.new()
	root.name = "Heatsink"
	var base: MeshInstance3D = ShapeKit.box(Vector3(size, 0.006, size), f.ML.aluminium(), "Base")
	base.position = Vector3(0.0, 0.003, 0.0)
	root.add_child(base)
	var fins: int = 9
	for i: int in range(fins):
		var fin: MeshInstance3D = ShapeKit.box(Vector3(size * 0.9, size * 0.9, 0.0025), f.ML.aluminium(), "Fin")
		fin.position = Vector3(0.0, 0.006 + size * 0.45, -size * 0.45 + float(i) * size * 0.9 / float(fins - 1))
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fin)
	# the thermal paste blob lies flat on the base
	var paste: MeshInstance3D = ShapeKit.disc_flat(size * 0.3, 0.001, f.ML.thermal_paste(), "Paste")
	paste.position = Vector3(0.0, 0.0065, 0.0)
	root.add_child(paste)
	return root


static func capacitor(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.008))
	var h: float = float(o.get("height", 0.02))
	var root := Node3D.new()
	root.name = "Capacitor"
	var body: MeshInstance3D = ShapeKit.cyl(r, h, f.ML.cap_sleeve(), 10, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(body)
	var top: MeshInstance3D = ShapeKit.cyl(r * 0.92, 0.0015, f.ML.aluminium(), 10, Vector3i(0, 1, 0), "Top")
	top.position = Vector3(0.0, h, 0.0)
	root.add_child(top)
	# the vent score lines on the top face
	for i: int in range(2):
		var vent: MeshInstance3D = ShapeKit.box(Vector3(r * 1.5, 0.0008, 0.0012), f.ML.steel_dark(), "Vent")
		vent.position = Vector3(0.0, h + 0.001, 0.0)
		vent.rotation.y = float(i) * PI * 0.5
		root.add_child(vent)
	for i: int in range(2):
		var leg: MeshInstance3D = ShapeKit.cyl(0.0006, 0.006, f.ML.silver_solder(), 5, Vector3i(0, 1, 0), "Leg")
		leg.position = Vector3((r * 0.4) * (1.0 if i == 0 else -1.0), -0.003, 0.0)
		root.add_child(leg)
	var stripe: MeshInstance3D = ShapeKit.box(Vector3(0.0015, h * 0.9, r * 0.6), f.ML.paper_cone(), "Stripe")
	stripe.position = Vector3(r * 0.9, h * 0.5, 0.0)
	root.add_child(stripe)
	ShapeKit.set_cast(root, false)
	return root


static func resistor_pack(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ResistorPack"
	for i: int in range(10):
		var r := Node3D.new()
		r.name = "Resistor"
		var body: MeshInstance3D = ShapeKit.cyl(0.0035, 0.012, f.ML.resistor_body(), 8, Vector3i(1, 0, 0), "Body")
		r.add_child(body)
		for k: int in range(4):
			var band: MeshInstance3D = ShapeKit.torus(0.0038, 0.0007, f.ML.band_color(k), 8, 4, "Band")
			band.position = Vector3(-0.004 + float(k) * 0.0028, 0.0, 0.0)
			# the resistor body is along X, so its colour bands encircle X
			band.rotation = Vector3(0.0, 0.0, PI * 0.5)
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.add_child(band)
		for k: int in range(2):
			var lead: MeshInstance3D = ShapeKit.cyl(0.0005, 0.012, f.ML.silver_solder(), 5, Vector3i(1, 0, 0), "Lead")
			lead.position = Vector3(0.011 * (1.0 if k == 0 else -1.0), 0.0, 0.0)
			lead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.add_child(lead)
		r.position = Vector3(f.rand().randf_range(-0.05, 0.05), 0.004 + float(i) * 0.0015, f.rand().randf_range(-0.05, 0.05))
		r.rotation = Vector3(0.0, f.rand().randf_range(0, 3.14), 0.0)
		root.add_child(r)
	return root


static func ram_stick(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RamStick"
	var subs: MeshInstance3D = ShapeKit.box(Vector3(0.135, 0.0015, 0.032), f.ML.pcb(), "Substrate")
	subs.position = Vector3(0.0, 0.001, 0.0)
	root.add_child(subs)
	for i: int in range(8):
		var chip: MeshInstance3D = ShapeKit.box(Vector3(0.018, 0.0025, 0.028), f.ML.plastic_black(), "Chip")
		chip.position = Vector3(-0.058 + float(i) * 0.0166, 0.003, 0.0)
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(chip)
	var notch: MeshInstance3D = ShapeKit.box(Vector3(0.006, 0.002, 0.008), f.ML.plastic_faded(), "Notch")
	notch.position = Vector3(-0.02, 0.001, 0.014)
	root.add_child(notch)
	var fingers: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.0008, 0.005), f.ML.gold_finger(), "Fingers")
	fingers.position = Vector3(0.0, 0.0012, 0.0145)
	root.add_child(fingers)
	return root


static func dip_switch(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "DipSwitch"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.006, 0.012), f.ML.plastic_red(), "Body")
	body.position = Vector3(0.0, 0.003, 0.0)
	root.add_child(body)
	for i: int in range(8):
		var sw: MeshInstance3D = ShapeKit.box(Vector3(0.0025, 0.002, 0.004), f.ML.plastic_faded(), "Switch")
		sw.position = Vector3(-0.012 + float(i) * 0.0034, 0.0065, 0.0)
		sw.rotation.x = 0.4 if i % 3 == 0 else -0.4
		root.add_child(sw)
	return root


static func led_cluster(f: PropFactory, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "LedCluster"
	var n: int = clampi(int(o.get("count", 6)), 2, 12)
	var colors: Array[Color] = [Color("e2453c"), Color("ffb347"), Color("5fd08a"), Color("4fd8ff")]
	for i: int in range(n):
		var c: Color = colors[i % colors.size()]
		var dome: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(c, 0.0), 8, "Led")
		dome.position = Vector3(f.rand().randf_range(-0.04, 0.04), 0.005, f.rand().randf_range(-0.04, 0.04))
		dome.scale = Vector3(1.0, 1.4, 1.0)
		root.add_child(dome)
		var lens_base: MeshInstance3D = ShapeKit.cyl(0.004, 0.004, f.ML.plastic_faded(), 8, Vector3i(0, 1, 0), "Base")
		lens_base.position = dome.position + Vector3(0.0, -0.002, 0.0)
		root.add_child(lens_base)
		for k: int in range(2):
			var leg: MeshInstance3D = ShapeKit.cyl(0.0004, 0.006, f.ML.silver_solder(), 4, Vector3i(0, 1, 0), "Leg")
			leg.position = dome.position + Vector3(0.0015 * (1.0 if k == 0 else -1.0), -0.005, 0.0)
			root.add_child(leg)
	return root


static func transformer_core(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TransformerCore"
	var stack: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.06, 0.04), f.ML.steel_laminated(), "Core")
	stack.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(stack)
	var bobbin: MeshInstance3D = ShapeKit.cyl(0.022, 0.045, f.ML.plastic_black(), 12, Vector3i(0, 1, 0), "Bobbin")
	bobbin.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(bobbin)
	# copper layers encircle the vertical bobbin: flat tori
	for i: int in range(6):
		var layer: MeshInstance3D = ShapeKit.torus(0.024, 0.003, f.ML.copper(), 12, 5, "Layer")
		layer.position = Vector3(0.0, 0.012 + float(i) * 0.006, 0.0)
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(layer)
	var wires: MeshInstance3D = ShapeKit.hose(Vector3(0.02, 0.055, 0.0), Vector3(0.09, 0.02, 0.05), 0.002, 0.02, f.ML.cable_material(Color("#8a2a1a")), "Lead")
	root.add_child(wires)
	return root


static func fuse_glass(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Fuse"
	var glass: MeshInstance3D = ShapeKit.cyl(0.005, 0.025, f.ML.glass_smoky(), 10, Vector3i(1, 0, 0), "Glass")
	root.add_child(glass)
	for i: int in range(2):
		var cap: MeshInstance3D = ShapeKit.cyl(0.0055, 0.005, f.ML.silver_solder(), 10, Vector3i(1, 0, 0), "Cap")
		cap.position = Vector3(0.011 * (1.0 if i == 0 else -1.0), 0.0, 0.0)
		root.add_child(cap)
	var element: MeshInstance3D = ShapeKit.cyl(0.0006, 0.02, f.ML.nickel(), 5, Vector3i(1, 0, 0), "Element")
	root.add_child(element)
	return root


static func jack_socket(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "JackSocket"
	var barrel: MeshInstance3D = ShapeKit.cyl(0.008, 0.02, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "Barrel")
	root.add_child(barrel)
	# the retaining ring encircles the barrel, which runs along Z
	var ring: MeshInstance3D = ShapeKit.torus(0.0085, 0.0015, f.ML.silver_solder(), 12, 5, "Ring")
	ring.position = Vector3(0.0, 0.0, 0.008)
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(ring)
	var pin: MeshInstance3D = ShapeKit.cyl(0.0015, 0.012, f.ML.brass(), 6, Vector3i(0, 1, 0), "Pin")
	pin.position = Vector3(0.0, -0.006, 0.0)
	root.add_child(pin)
	return root


static func power_adapter(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "PowerAdapter"
	var brick: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.03, 0.04), f.ML.plastic_black(), "Brick")
	brick.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(brick)
	var label: MeshInstance3D = ShapeKit.box(Vector3(0.045, 0.001, 0.026), f.ML.paper(), "Label")
	label.position = Vector3(0.0, 0.031, 0.0)
	root.add_child(label)
	var lead: MeshInstance3D = ShapeKit.hose(Vector3(0.035, 0.015, 0.0), Vector3(0.14, 0.005, 0.05), 0.003, 0.03, f.ML.cable_material(Color("#20201f")), "Lead")
	root.add_child(lead)
	var plug: MeshInstance3D = ShapeKit.box(Vector3(0.018, 0.012, 0.024), f.ML.plastic_black(), "Plug")
	plug.position = Vector3(0.15, 0.006, 0.055)
	root.add_child(plug)
	for i: int in range(2):
		var pin: MeshInstance3D = ShapeKit.cyl(0.0015, 0.016, f.ML.steel(), 6, Vector3i(0, 0, 1), "Pin")
		pin.position = plug.position + Vector3(0.005 * (1.0 if i == 0 else -1.0), 0.0, 0.016)
		root.add_child(pin)
	return root


static func ribbon_cable(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RibbonCable"
	var ribbon: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.0015, 0.3), f.ML.ribbon_orange(), "Ribbon")
	ribbon.position = Vector3(0.0, 0.001, 0.0)
	# folded once so it reads as slack rather than as a printed plane
	ribbon.rotation.x = 0.35
	root.add_child(ribbon)
	for i: int in range(2):
		var stiff: MeshInstance3D = ShapeKit.box(Vector3(0.054, 0.003, 0.012), f.ML.plastic_blue_stiff(), "Stiffener")
		stiff.position = Vector3(0.0, 0.0015, 0.15 * (1.0 if i == 0 else -1.0))
		root.add_child(stiff)
	return root


static func wire_cutters(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WireCutters"
	var mat: StandardMaterial3D = f.ML.steel_dark()
	for s: int in range(2):
		var sign: float = 1.0 if s == 0 else -1.0
		var arm: MeshInstance3D = ShapeKit.box(Vector3(0.014, 0.14, 0.008), mat, "Arm")
		arm.position = Vector3(sign * 0.012, -0.05, 0.0)
		arm.rotation.z = -sign * 0.1
		root.add_child(arm)
		var grip: MeshInstance3D = ShapeKit.box(Vector3(0.019, 0.07, 0.012), f.ML.plastic_red(), "Grip")
		grip.position = Vector3(sign * 0.02, -0.11, 0.0)
		grip.rotation.z = -sign * 0.1
		root.add_child(grip)
		var blade: MeshInstance3D = ShapeKit.box(Vector3(0.008, 0.05, 0.006), f.ML.steel_hardened(), "Blade")
		blade.position = Vector3(sign * 0.005, 0.055, 0.0)
		blade.rotation.z = sign * 0.18
		root.add_child(blade)
	# the pivot runs along Z, so the ring around it is edge-on
	var pivot: MeshInstance3D = ShapeKit.cyl(0.007, 0.02, f.ML.chrome(), 8, Vector3i(0, 0, 1), "Pivot")
	pivot.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(pivot)
	var spring: MeshInstance3D = ShapeKit.coil(5.0, 0.012, 0.0015, 0.04, f.ML.steel_spring(), 10, "Spring")
	spring.position = Vector3(0.0, -0.02, 0.01)
	root.add_child(spring)
	return root


static func soldering_iron(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SolderingIron"
	var grip: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.012, 0.0), Vector2(0.014, 0.02), Vector2(0.013, 0.09),
		Vector2(0.009, 0.11), Vector2(0.0, 0.115),
	]), 12, f.ML.woodgrain_dark(), true, "Grip")
	grip.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	grip.position = Vector3(0.0, 0.0, -0.06)
	root.add_child(grip)
	var collar: MeshInstance3D = ShapeKit.cyl(0.011, 0.02, f.ML.nickel(), 10, Vector3i(0, 0, 1), "Collar")
	collar.position = Vector3(0.0, 0.0, 0.02)
	root.add_child(collar)
	var shaft: MeshInstance3D = ShapeKit.cyl(0.005, 0.06, f.ML.copper(), 8, Vector3i(0, 0, 1), "Shaft")
	shaft.position = Vector3(0.0, 0.0, 0.055)
	root.add_child(shaft)
	var tip: MeshInstance3D = ShapeKit.tapered_cyl(0.0012, 0.004, 0.022, f.ML.silver_solder(), 8, "Tip")
	tip.position = Vector3(0.0, 0.0, 0.095)
	tip.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(tip)
	var cord: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.0, -0.13), Vector3(-0.12, -0.02, -0.35), 0.004, 0.05, f.ML.cable_material(Color("#26262a")), "Cord")
	root.add_child(cord)
	return root


static func solder_spool(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SolderSpool"
	# the spool axis is +Z, so flanges are edge-on and the solder turns encircle Z
	for i: int in range(2):
		var flange: MeshInstance3D = ShapeKit.disc(0.045, 0.004, f.ML.plastic_faded(), "Flange")
		flange.position = Vector3(0.0, 0.045, 0.02 * (1.0 if i == 0 else -1.0))
		root.add_child(flange)
	var hub: MeshInstance3D = ShapeKit.cyl(0.012, 0.05, f.ML.plastic_faded(), 12, Vector3i(0, 0, 1), "Hub")
	hub.position = Vector3(0.0, 0.045, 0.0)
	root.add_child(hub)
	for i: int in range(10):
		var turn: MeshInstance3D = ShapeKit.torus(0.02 + float(i) * 0.002, 0.0012, f.ML.silver_solder(), 16, 5, "Turn")
		turn.position = Vector3(0.0, 0.045, -0.02 + float(i) * 0.004)
		turn.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		turn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(turn)
	var tag: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.02, 0.001), f.ML.paper(), "Tag")
	tag.position = Vector3(0.0, 0.075, 0.024)
	root.add_child(tag)
	return root


static func wire_spool(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.09))
	var root := Node3D.new()
	root.name = "WireSpool"
	for i: int in range(2):
		var flange: MeshInstance3D = ShapeKit.disc(r * 1.15, 0.006, f.ML.plywood(), "Flange")
		flange.position = Vector3(0.0, r * 1.15, 0.035 * (1.0 if i == 0 else -1.0))
		root.add_child(flange)
	var hub: MeshInstance3D = ShapeKit.cyl(r * 0.35, 0.08, f.ML.plywood(), 14, Vector3i(0, 0, 1), "Hub")
	hub.position = Vector3(0.0, r * 1.15, 0.0)
	root.add_child(hub)
	var colors: Array[Color] = [Color("#c93a2a"), Color("#2a5ac9"), Color("#e0c04a"), Color("#1b1d20")]
	for i: int in range(14):
		var col: Color = colors[i % colors.size()]
		var turn: MeshInstance3D = ShapeKit.torus(r * 0.7 + float(i) * 0.002, 0.004, f.ML.cable_material(col), 18, 6, "Turn")
		turn.position = Vector3(0.0, r * 1.15, -0.035 + float(i) * 0.005)
		turn.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		turn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(turn)
	var tail: MeshInstance3D = ShapeKit.hose(Vector3(r * 0.7, r * 1.15, 0.04), Vector3(r * 1.4, 0.02, 0.12), 0.004, 0.05, f.ML.cable_material(Color("#c93a2a")), "Tail")
	root.add_child(tail)
	return root


static func component_drawer(f: PropFactory, o: Dictionary) -> Node3D:
	## The multi-drawer component cabinet every electronics shop runs on.
	var drawers: int = clampi(int(o.get("drawers", 6)), 2, 12)
	var w: float = float(o.get("width", 0.34))
	var root := Node3D.new()
	root.name = "ComponentDrawer"
	var carcass: MeshInstance3D = ShapeKit.box(Vector3(w, 0.06 + float(drawers) * 0.075, 0.24), f.ML.plastic_faded(), "Carcass")
	carcass.position = Vector3(0.0, 0.03 + float(drawers) * 0.0375, 0.0)
	root.add_child(carcass)
	for i: int in range(drawers):
		var y: float = 0.06 + float(i) * 0.075
		var d: MeshInstance3D = ShapeKit.box(Vector3(w * 0.94, 0.062, 0.012), f.ML.plastic_translucent(), "Drawer")
		d.position = Vector3(0.0, y, 0.12)
		root.add_child(d)
		var pull: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.008, 0.008), f.ML.steel_dark(), "Pull")
		pull.position = Vector3(0.0, y, 0.128)
		root.add_child(pull)
		var label: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.02, 0.002), f.ML.paper(), "Label")
		label.position = Vector3(-w * 0.25, y + 0.01, 0.127)
		root.add_child(label)
	root.add_child(ShapeKit.col_box(Vector3(w, float(drawers) * 0.075 + 0.06, 0.24)))
	return root


static func multimeter(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Multimeter"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.014, 0.14), f.ML.meter_case(), "Body")
	body.position = Vector3(0.0, 0.007, 0.0)
	root.add_child(body)
	var display: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.002, 0.03), f.ML.lcd_green(), "Display")
	display.position = Vector3(0.0, 0.0145, -0.035)
	root.add_child(display)
	var dial: MeshInstance3D = ShapeKit.cyl(0.026, 0.012, f.ML.plastic_black(), 16, Vector3i(0, 1, 0), "RangeDial")
	dial.position = Vector3(0.0, 0.016, 0.02)
	root.add_child(dial)
	var pointer: MeshInstance3D = ShapeKit.box(Vector3(0.003, 0.002, 0.02), f.ML.plastic_faded(), "Pointer")
	pointer.position = Vector3(0.0, 0.022, 0.028)
	pointer.rotation.y = 0.6
	root.add_child(pointer)
	for i: int in range(3):
		var jack: MeshInstance3D = ShapeKit.cyl(0.006, 0.006, f.ML.plastic_black(), 10, Vector3i(0, 1, 0), "Jack")
		jack.position = Vector3(-0.025 + float(i) * 0.025, 0.0145, 0.058)
		root.add_child(jack)
	var holster: MeshInstance3D = ShapeKit.box(Vector3(0.094, 0.006, 0.144), f.ML.rubber(), "Holster")
	holster.position = Vector3(0.0, 0.003, 0.0)
	root.add_child(holster)
	# the test leads lie coiled on the bench, so the coil axis is vertical
	var lead_colors: Array[Color] = [Color("e2453c"), Color("1b1d20")]
	for i: int in range(2):
		var col: Color = lead_colors[i]
		var lead: MeshInstance3D = ShapeKit.coil(5.0, 0.04, 0.0025, 0.02, f.ML.cable_material(col), 14, "Lead")
		lead.position = Vector3(0.07 + float(i) * 0.02, 0.01, 0.02)
		root.add_child(lead)
		var probe: MeshInstance3D = ShapeKit.cyl(0.004, 0.09, f.ML.cable_material(col), 8, Vector3i(0, 0, 1), "Probe")
		probe.position = Vector3(0.07 + float(i) * 0.02, 0.01, 0.09)
		root.add_child(probe)
		var tip: MeshInstance3D = ShapeKit.cyl(0.0012, 0.02, f.ML.steel_hardened(), 6, Vector3i(0, 0, 1), "Point")
		tip.position = Vector3(0.07 + float(i) * 0.02, 0.01, 0.145)
		root.add_child(tip)
	return root


static func oscilloscope(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Oscilloscope"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.3, 0.22, 0.22), f.ML.beige_plastic(), "Case")
	body.position = Vector3(0.0, 0.11, 0.0)
	root.add_child(body)
	var bezel: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.15, 0.008), f.ML.plastic_black(), "Bezel")
	bezel.position = Vector3(-0.04, 0.14, 0.108)
	root.add_child(bezel)
	var screen: MeshInstance3D = ShapeKit.box(Vector3(0.17, 0.13, 0.01), f.ML.crt_green(), "Screen")
	screen.position = Vector3(-0.04, 0.14, 0.112)
	root.add_child(screen)
	for i: int in range(8):
		var knob: MeshInstance3D = ShapeKit.cyl(0.012, 0.014, f.ML.plastic_faded(), 12, Vector3i(0, 0, 1), "Knob")
		knob.position = Vector3(0.11, 0.05 + float(i % 4) * 0.045, 0.112)
		knob.rotation.x = 0.2
		root.add_child(knob)
	var bnc: MeshInstance3D = ShapeKit.cyl(0.011, 0.02, f.ML.nickel(), 12, Vector3i(0, 0, 1), "Bnc")
	bnc.position = Vector3(-0.1, 0.03, 0.115)
	root.add_child(bnc)
	var grid: MeshInstance3D = ShapeKit.box(Vector3(0.165, 0.125, 0.001), f.ML.scope_grid(), "Graticule")
	grid.position = Vector3(-0.04, 0.14, 0.118)
	root.add_child(grid)
	return root


static func variac(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Variac"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.12, 0.12), f.ML.steel_dark(), "Case")
	body.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(body)
	var knob: MeshInstance3D = ShapeKit.cyl(0.03, 0.04, f.ML.plastic_black(), 16, Vector3i(0, 0, 1), "Dimmer")
	knob.position = Vector3(0.0, 0.11, 0.07)
	root.add_child(knob)
	# the dial face is on the front, so the edge-on disc is correct
	var dial_face: MeshInstance3D = ShapeKit.disc(0.032, 0.004, f.ML.meter_face(), "Dial")
	dial_face.position = Vector3(0.0, 0.11, 0.09)
	root.add_child(dial_face)
	var meter: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.04, 0.006), f.ML.meter_face(), "Meter")
	meter.position = Vector3(-0.04, 0.09, 0.063)
	root.add_child(meter)
	var socket: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.035, 0.006), f.ML.plastic_faded(), "Socket")
	socket.position = Vector3(0.04, 0.04, 0.063)
	root.add_child(socket)
	return root


static func voltage_regulator(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Regulator"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.08, 0.02, 0.02), f.ML.plastic_black(), "Case")
	body.position = Vector3(0.0, 0.01, 0.0)
	root.add_child(body)
	var tab: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.002, 0.016), f.ML.aluminium(), "Tab")
	tab.position = Vector3(0.0, 0.022, 0.0)
	root.add_child(tab)
	for i: int in range(3):
		var leg: MeshInstance3D = ShapeKit.cyl(0.0015, 0.02, f.ML.silver_solder(), 5, Vector3i(0, 0, 1), "Leg")
		leg.position = Vector3(-0.012 + float(i) * 0.012, 0.008, -0.018)
		root.add_child(leg)
	return root


static func blower_fan(f: PropFactory, _o: Dictionary) -> Node3D:
	## The AC blower motor, salvaged, with its squirrel-cage wheel.
	var root := Node3D.new()
	root.name = "BlowerFan"
	var housing: MeshInstance3D = ShapeKit.cyl(0.11, 0.09, f.ML.plastic_black(), 18, Vector3i(0, 0, 1), "Housing")
	root.add_child(housing)
	# the scroll encircles the +Z shaft, so it is edge-on
	var scroll: MeshInstance3D = ShapeKit.torus(0.12, 0.03, f.ML.plastic_faded(), 18, 6, "Scroll")
	scroll.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(scroll)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	root.add_child(rotor)
	for i: int in range(12):
		var a: float = ShapeKit.TAU_K * float(i) / 12.0
		var blade: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.07, 0.06), f.ML.plastic_faded(), "Blade")
		blade.position = Vector3(cos(a) * 0.05, sin(a) * 0.05, 0.0)
		blade.rotation = Vector3(0.0, 0.0, a)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotor.add_child(blade)
	var shaft: MeshInstance3D = ShapeKit.cyl(0.008, 0.16, f.ML.steel(), 8, Vector3i(0, 0, 1), "Shaft")
	root.add_child(shaft)
	var term: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.025, 0.03), f.ML.plastic_black(), "Terminal")
	term.position = Vector3(0.1, 0.06, 0.0)
	root.add_child(term)
	root.set_meta("rotor_path", "Rotor")
	return root


static func crt_guts(f: PropFactory, _o: Dictionary) -> Node3D:
	## The opened tube from the reference photo: funnel, yoke, anode cap, flyback
	## transformer and the deflection coils. Donor for the energy module.
	var root := Node3D.new()
	root.name = "CrtGuts"
	var funnel: MeshInstance3D = ShapeKit.tapered_cyl(0.16, 0.05, 0.22, f.ML.glass_screen(), 20, "Funnel")
	funnel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(funnel)
	var neck: MeshInstance3D = ShapeKit.cyl(0.035, 0.1, f.ML.glass_screen(), 14, Vector3i(0, 0, 1), "Neck")
	neck.position = Vector3(0.0, 0.0, -0.16)
	root.add_child(neck)
	# the yoke encircles the neck, which runs along Z
	var yoke: MeshInstance3D = ShapeKit.torus(0.05, 0.022, f.ML.copper(), 16, 6, "Yoke")
	yoke.position = Vector3(0.0, 0.0, -0.14)
	yoke.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(yoke)
	for i: int in range(4):
		var coil: MeshInstance3D = ShapeKit.coil(6.0, 0.03, 0.002, 0.06, f.ML.copper(), 14, "Coil")
		var a: float = ShapeKit.TAU_K * float(i) / 4.0
		coil.position = Vector3(cos(a) * 0.045, sin(a) * 0.045, -0.14)
		coil.rotation = Vector3(PI * 0.5, 0.0, a)
		root.add_child(coil)
	var flyback: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.06, 0.05), f.ML.plastic_black(), "Flyback")
	flyback.position = Vector3(0.0, 0.06, -0.18)
	root.add_child(flyback)
	var hb: MeshInstance3D = ShapeKit.cyl(0.012, 0.06, f.ML.ceramic_white(), 10, Vector3i(0, 0, 1), "HtLead")
	hb.position = Vector3(0.0, 0.08, -0.22)
	root.add_child(hb)
	# the anode clip is the tube's own circumference: edge-on about Z
	var anode: MeshInstance3D = ShapeKit.torus(0.16, 0.008, f.ML.silver_solder(), 20, 5, "AnodeClip")
	anode.position = Vector3(0.0, 0.0, 0.02)
	anode.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(anode)
	var board: Node3D = pcb_board(f, {"width": 0.16, "depth": 0.1, "chips": 3})
	board.position = Vector3(0.06, -0.08, -0.05)
	board.rotation = Vector3(0.3, 0.4, 0.0)
	root.add_child(board)
	return root


static func cpu_fan(f: PropFactory, o: Dictionary) -> Node3D:
	## The 80 mm case fan, one of the most repeated small objects in a second-hand
	## computer shop. Square frame, four corner mounts, the impeller and the hub
	## label; the impeller is named "Rotor" so the power system can spin it.
	var size: float = float(o.get("size", 0.08))
	var root := Node3D.new()
	root.name = "CpuFan"
	var frame: MeshInstance3D = ShapeKit.box(Vector3(size, size, size * 0.28), f.ML.plastic_black(), "Frame")
	frame.position = Vector3(0.0, 0.0, size * 0.14)
	root.add_child(frame)
	var opening: MeshInstance3D = ShapeKit.cyl(size * 0.46, size * 0.94, f.ML.plastic_faded(), 8, Vector3i(0, 0, 1), "Opening")
	opening.position = Vector3(0.0, 0.0, size * 0.14)
	root.add_child(opening)
	var hub: MeshInstance3D = ShapeKit.cyl(size * 0.14, size * 0.2, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "Hub")
	hub.position = Vector3(0.0, 0.0, size * 0.16)
	root.add_child(hub)
	# the hub label faces +Z
	var label: MeshInstance3D = ShapeKit.disc(size * 0.13, 0.001, f.ML.label_stock(), "Label")
	label.position = Vector3(0.0, 0.0, size * 0.27)
	root.add_child(label)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 0.0, size * 0.15)
	root.add_child(rotor)
	for i: int in range(7):
		var a: float = ShapeKit.TAU_K * float(i) / 7.0
		var blade: MeshInstance3D = ShapeKit.box(Vector3(size * 0.3, size * 0.05, size * 0.16), f.ML.plastic_faded(), "Blade")
		blade.position = Vector3(cos(a) * size * 0.26, sin(a) * size * 0.26, 0.0)
		blade.rotation = Vector3(0.0, 0.0, a + 0.5)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotor.add_child(blade)
	for i: int in range(4):
		var a2: float = ShapeKit.TAU_K * float(i) / 4.0 + 0.4
		var strut: MeshInstance3D = ShapeKit.box(Vector3(size * 0.62, 0.006, 0.006), f.ML.plastic_black(), "Strut")
		strut.position = Vector3(cos(a2) * size * 0.28, sin(a2) * size * 0.28, 0.004)
		strut.rotation.z = a2
		strut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strut)
	for i: int in range(4):
		var corner: MeshInstance3D = ShapeKit.cyl(size * 0.05, size * 0.3, f.ML.plastic_faded(), 8, Vector3i(0, 0, 1), "Mount")
		var sx: float = -1.0 if i % 2 == 0 else 1.0
		var sy: float = -1.0 if i < 2 else 1.0
		corner.position = Vector3(sx * size * 0.42, sy * size * 0.42, size * 0.14)
		root.add_child(corner)
	var lead: MeshInstance3D = ShapeKit.hose(
		Vector3(size * 0.4, -size * 0.4, size * 0.2),
		Vector3(size * 1.1, -size * 0.9, size * 0.1), 0.0018, 0.02, f.ML.cable_material(Color("#1b1d20")), "Lead")
	root.add_child(lead)
	var conn: MeshInstance3D = ShapeKit.box(Vector3(0.012, 0.008, 0.006), f.ML.plastic_white_gloss(), "Connector")
	conn.position = Vector3(size * 1.1, -size * 0.9, size * 0.1)
	root.add_child(conn)
	root.set_meta("rotor_path", "Rotor")
	return root


static func antenna_roof(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RoofAntenna"
	var mast: MeshInstance3D = ShapeKit.cyl(0.02, 2.2, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Mast")
	mast.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(mast)
	for i: int in range(5):
		var el: MeshInstance3D = ShapeKit.cyl(0.008, 0.5 - float(i) * 0.05, f.ML.aluminium(), 6, Vector3i(1, 0, 0), "Element")
		el.position = Vector3(0.0, 1.4 + float(i) * 0.16, 0.0)
		root.add_child(el)
	var boom: MeshInstance3D = ShapeKit.cyl(0.01, 0.9, f.ML.aluminium(), 6, Vector3i(0, 0, 1), "Boom")
	boom.position = Vector3(0.0, 1.6, -0.3)
	root.add_child(boom)
	var feed: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.04, 0.03), f.ML.plastic_faded(), "Feed")
	feed.position = Vector3(0.0, 1.5, 0.1)
	root.add_child(feed)
	var lead: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 1.45, 0.1), Vector3(0.3, 0.4, 0.3), 0.004, 0.2, f.ML.cable_material(Color("#4a4a44")), "Lead")
	root.add_child(lead)
	return root


# ===========================================================================
# Power hardware — the bridge between World A and World B
# ===========================================================================

static func ups_battery(f: PropFactory, o: Dictionary) -> Node3D:
	## The sealed lead-acid IPS/UPS unit. Every workshop in the country has two of
	## these, and they are the fictional donor for the exosuit's energy module.
	var s: float = float(o.get("scale", 1.0))
	var w: float = 0.18 * s
	var h: float = 0.17 * s
	var d: float = 0.09 * s
	var root := Node3D.new()
	root.name = "UpsBattery"
	var case_b: MeshInstance3D = ShapeKit.box(Vector3(w, h, d), f.ML.battery_case(), "Case")
	case_b.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(case_b)
	var lid: MeshInstance3D = ShapeKit.box(Vector3(w * 0.98, 0.012, d * 0.96), f.ML.plastic_black(), "Lid")
	lid.position = Vector3(0.0, h + 0.006, 0.0)
	root.add_child(lid)
	for i: int in range(2):
		var term: MeshInstance3D = ShapeKit.cyl(0.012 * s, 0.02 * s, f.ML.lead_terminal(), 10, Vector3i(0, 1, 0), "Terminal")
		term.position = Vector3((w * 0.28) * (1.0 if i == 0 else -1.0), h + 0.016, d * 0.2)
		root.add_child(term)
		var strap: MeshInstance3D = ShapeKit.box(Vector3(0.02 * s, 0.006 * s, 0.03 * s), f.ML.lead_terminal(), "Strap")
		strap.position = term.position + Vector3(0.0, 0.004, 0.0)
		root.add_child(strap)
		var bolt: MeshInstance3D = ShapeKit.cyl(0.005 * s, 0.008 * s, f.ML.steel(), 6, Vector3i(0, 1, 0), "Bolt")
		bolt.position = term.position + Vector3(0.0, 0.01, 0.0)
		root.add_child(bolt)
	var label: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, h * 0.45, 0.002), f.ML.battery_label(), "Label")
	label.position = Vector3(0.0, h * 0.55, d * 0.5 + 0.002)
	root.add_child(label)
	var vent: MeshInstance3D = ShapeKit.box(Vector3(w * 0.4, 0.008, 0.004), f.ML.plastic_black(), "Vent")
	vent.position = Vector3(0.0, h * 0.9, d * 0.5)
	root.add_child(vent)
	# the acid stain lies flat on the floor
	var stain: MeshInstance3D = ShapeKit.disc_flat(0.05 * s, 0.002, f.ML.oil_stain(), "Corrosion")
	stain.position = Vector3(0.0, 0.002, d * 0.3)
	root.add_child(stain)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	root.set_meta("terminal_count", 2)
	return root


static func ips_battery(f: PropFactory, o: Dictionary) -> Node3D:
	## The tall tubular IPS cell, the workhorse of a Bangladeshi load-shedding
	## household. Bigger than the UPS unit, with the filler caps on top.
	var s: float = float(o.get("scale", 1.0))
	var w: float = 0.2 * s
	var h: float = 0.32 * s
	var d: float = 0.14 * s
	var root := Node3D.new()
	root.name = "IpsBattery"
	var case_b: MeshInstance3D = ShapeKit.box(Vector3(w, h, d), f.ML.battery_case(), "Case")
	case_b.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(case_b)
	var lid: MeshInstance3D = ShapeKit.box(Vector3(w, 0.02, d), f.ML.plastic_black(), "Lid")
	lid.position = Vector3(0.0, h + 0.01, 0.0)
	root.add_child(lid)
	for i: int in range(6):
		var cap: MeshInstance3D = ShapeKit.cyl(0.012 * s, 0.014 * s, f.ML.plastic_red(), 10, Vector3i(0, 1, 0), "FillerCap")
		cap.position = Vector3(-w * 0.35 + float(i % 3) * w * 0.35, h + 0.026, -d * 0.22 + float(i / 3) * d * 0.44)
		root.add_child(cap)
	for i: int in range(2):
		var term: MeshInstance3D = ShapeKit.cyl(0.016 * s, 0.028 * s, f.ML.lead_terminal(), 12, Vector3i(0, 1, 0), "Terminal")
		term.position = Vector3((w * 0.34) * (1.0 if i == 0 else -1.0), h + 0.03, d * 0.34)
		root.add_child(term)
		var col: Color = Color("e2453c") if i == 0 else Color("#1b1d20")
		var cable: MeshInstance3D = ShapeKit.hose(
			term.position + Vector3(0.0, 0.02, 0.0),
			term.position + Vector3(f.rand().randf_range(-0.2, 0.2), -0.1, f.rand().randf_range(0.2, 0.5)),
			0.008 * s, 0.08, f.ML.cable_material(col), "Lead")
		root.add_child(cable)
	var label: MeshInstance3D = ShapeKit.box(Vector3(w * 0.85, h * 0.35, 0.002), f.ML.battery_label(), "Label")
	label.position = Vector3(0.0, h * 0.62, d * 0.5 + 0.002)
	root.add_child(label)
	# the carry handle stands up across the lid
	var carry: MeshInstance3D = ShapeKit.torus(0.07 * s, 0.008 * s, f.ML.steel_dark(), 14, 5, "Handle")
	carry.position = Vector3(0.0, h + 0.04, 0.0)
	carry.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(carry)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	return root


static func battery_rack(f: PropFactory, _o: Dictionary) -> Node3D:
	## Two IPS cells strapped in series on a wooden skid with a distribution board
	## — the physical donor for the exosuit's energy module.
	var root := Node3D.new()
	root.name = "BatteryRack"
	var skid: MeshInstance3D = ShapeKit.box(Vector3(0.56, 0.06, 0.34), f.ML.teak(), "Skid")
	skid.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(skid)
	for i: int in range(2):
		var b: Node3D = ips_battery(f, {"scale": 0.9})
		b.position = Vector3(-0.14 + float(i) * 0.28, 0.06, 0.0)
		root.add_child(b)
	var board: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.09, 0.02), f.ML.pcb(), "DistributionBoard")
	board.position = Vector3(0.0, 0.44, 0.17)
	root.add_child(board)
	for i: int in range(4):
		var term: MeshInstance3D = ShapeKit.cyl(0.008, 0.02, f.ML.brass(), 8, Vector3i(0, 0, 1), "BoardTerm")
		term.position = board.position + Vector3(-0.14 + float(i) * 0.09, 0.0, 0.015)
		root.add_child(term)
	# the coupling coil that becomes the futuristic core; its axis is vertical,
	# so the ferrite ring around it needs no rotation
	var coil: MeshInstance3D = ShapeKit.coil(9.0, 0.06, 0.006, 0.09, f.ML.copper(), 18, "CouplingCoil")
	coil.position = Vector3(0.0, 0.5, -0.05)
	root.add_child(coil)
	var core: MeshInstance3D = ShapeKit.torus(0.055, 0.02, f.ML.ferrite(), 18, 6, "FerriteCore")
	core.position = coil.position
	root.add_child(core)
	var strap_a: MeshInstance3D = ShapeKit.box(Vector3(0.58, 0.02, 0.02), f.ML.steel_dark(), "Strap")
	strap_a.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(strap_a)
	root.add_child(ShapeKit.col_box(Vector3(0.6, 0.55, 0.4)))
	root.set_meta("coil_path", "CouplingCoil")
	return root


static func power_strip(f: PropFactory, o: Dictionary) -> Node3D:
	var sockets: int = clampi(int(o.get("sockets", 4)), 2, 8)
	var root := Node3D.new()
	root.name = "PowerStrip"
	var length: float = 0.09 * float(sockets) + 0.06
	var body: MeshInstance3D = ShapeKit.box(Vector3(length, 0.03, 0.06), f.ML.plastic_faded(), "Body")
	body.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(body)
	for i: int in range(sockets):
		var face: MeshInstance3D = ShapeKit.box(Vector3(0.055, 0.004, 0.05), f.ML.plastic_white_gloss(), "Socket")
		face.position = Vector3(-length * 0.5 + 0.05 + float(i) * 0.09, 0.032, 0.0)
		root.add_child(face)
		for k: int in range(3):
			var hole: MeshInstance3D = ShapeKit.cyl(0.004, 0.008, f.ML.plastic_black(), 8, Vector3i(0, 1, 0), "Pin")
			var a: float = ShapeKit.TAU_K * float(k) / 3.0
			hole.position = face.position + Vector3(cos(a) * 0.014, 0.0, sin(a) * 0.014)
			hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(hole)
	var switch_b: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.012, 0.03), f.ML.plastic_red(), "Switch")
	switch_b.position = Vector3(length * 0.5 - 0.03, 0.034, 0.0)
	root.add_child(switch_b)
	var led: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(Color("e2453c"), 0.0), 8, "Led")
	led.position = Vector3(length * 0.5 - 0.06, 0.034, 0.0)
	root.add_child(led)
	var cord: MeshInstance3D = ShapeKit.hose(Vector3(-length * 0.5, 0.015, 0.0), Vector3(-length * 0.5 - 0.4, 0.0, 0.2), 0.006, 0.1, f.ML.cable_material(Color("#26282c")), "Cord")
	root.add_child(cord)
	root.set_meta("led_path", "Led")
	root.set_meta("switch_path", "Switch")
	return root


static func switchboard(f: PropFactory, o: Dictionary) -> Node3D:
	## The wall-mounted distribution board: metal box, the main switch, the MCB
	## row, the busbar and the incoming weather-proof cable gland. This is the
	## object the power-restoration puzzle operates on.
	var w: float = float(o.get("width", 0.46))
	var h: float = float(o.get("height", 0.6))
	var root := Node3D.new()
	root.name = "Switchboard"
	var box_b: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.14), f.ML.paint_white_or(), "Box")
	box_b.position = Vector3(0.0, 0.0, 0.07)
	root.add_child(box_b)
	# the door, hinged on the left, named so it can swing open
	var door := Node3D.new()
	door.name = "Door"
	door.position = Vector3(-w * 0.5, 0.0, 0.15)
	root.add_child(door)
	var door_skin: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.012), f.ML.paint_white_or(), "DoorSkin")
	door_skin.position = Vector3(w * 0.5, 0.0, 0.006)
	door.add_child(door_skin)
	var latch: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.05, 0.02), f.ML.brass(), "Latch")
	latch.position = Vector3(w * 0.95, 0.0, 0.02)
	door.add_child(latch)
	var handle: MeshInstance3D = ShapeKit.cyl(0.008, 0.06, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Handle")
	handle.position = Vector3(w * 0.9, 0.0, 0.03)
	door.add_child(handle)
	var back: MeshInstance3D = ShapeKit.box(Vector3(w * 0.94, h * 0.94, 0.006), f.ML.bakelite(), "Backplate")
	back.position = Vector3(0.0, 0.0, 0.02)
	root.add_child(back)
	var main_switch := Node3D.new()
	main_switch.name = "MainSwitch"
	main_switch.position = Vector3(-w * 0.28, h * 0.3, 0.03)
	root.add_child(main_switch)
	var ms_base: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.14, 0.03), f.ML.bakelite(), "Base")
	main_switch.add_child(ms_base)
	var ms_lever: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.1, 0.02), f.ML.plastic_red(), "Lever")
	ms_lever.position = Vector3(0.0, 0.02, 0.03)
	ms_lever.rotation.x = 0.9
	main_switch.add_child(ms_lever)
	var ms_gauge: MeshInstance3D = ShapeKit.cyl(0.02, 0.008, f.ML.meter_face(), 12, Vector3i(0, 0, 1), "AmpMeter")
	ms_gauge.position = Vector3(0.0, -0.05, 0.02)
	main_switch.add_child(ms_gauge)
	var mcbs: Node3D = mcb_row(f, {"count": int(o.get("mcbs", 5))})
	mcbs.position = Vector3(w * 0.12, h * 0.28, 0.03)
	root.add_child(mcbs)
	var busbar: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.012, 0.006), f.ML.copper(), "Busbar")
	busbar.position = Vector3(0.0, -h * 0.1, 0.026)
	root.add_child(busbar)
	var neutral: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.008, 0.006), f.ML.brass(), "NeutralBar")
	neutral.position = Vector3(0.0, -h * 0.2, 0.026)
	root.add_child(neutral)
	var gland: MeshInstance3D = ShapeKit.cyl(0.022, 0.05, f.ML.plastic_black(), 12, Vector3i(0, 1, 0), "Gland")
	gland.position = Vector3(-w * 0.35, -h * 0.5 - 0.02, 0.06)
	root.add_child(gland)
	var incoming: MeshInstance3D = ShapeKit.hose(
		Vector3(-w * 0.35, -h * 0.5 - 0.05, 0.06),
		Vector3(-w * 0.3, -h * 0.25, 0.03), 0.012, 0.06, f.ML.cable_material(Color("#3a3f45")), "Incoming")
	root.add_child(incoming)
	var wire_cols: Array[Color] = [Color("e2453c"), Color("#1b1d20"), Color("#2a5ac9"), Color("e0c04a")]
	for i: int in range(4):
		var w2: MeshInstance3D = ShapeKit.hose(
			Vector3(-w * 0.2 + float(i) * 0.05, -h * 0.1, 0.03),
			Vector3(w * 0.05 + float(i) * 0.04, h * 0.2, 0.03),
			0.004, 0.02, f.ML.cable_material(wire_cols[i]), "Wire")
		root.add_child(w2)
	var earth: MeshInstance3D = ShapeKit.cyl(0.006, 0.02, f.ML.brass(), 8, Vector3i(0, 0, 1), "EarthStud")
	earth.position = Vector3(w * 0.3, -h * 0.35, 0.03)
	root.add_child(earth)
	root.set_meta("door_path", "Door")
	root.set_meta("main_switch_path", "MainSwitch")
	root.set_meta("lever_path", "MainSwitch/Lever")
	return root


static func mcb_row(f: PropFactory, o: Dictionary) -> Node3D:
	var count: int = clampi(int(o.get("count", 5)), 1, 12)
	var root := Node3D.new()
	root.name = "McbRow"
	var rail: MeshInstance3D = ShapeKit.box(Vector3(0.036 * float(count) + 0.02, 0.012, 0.014), f.ML.steel(), "DinRail")
	rail.position = Vector3(0.0, -0.03, 0.0)
	root.add_child(rail)
	for i: int in range(count):
		var m: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.055, 0.028), f.ML.plastic_white_gloss(), "Mcb%d" % i)
		m.position = Vector3(-0.018 * float(count) + 0.036 * float(i) + 0.018, 0.0, 0.008)
		root.add_child(m)
		var tog: MeshInstance3D = ShapeKit.box(Vector3(0.01, 0.018, 0.008), f.ML.plastic_black(), "Toggle")
		tog.position = m.position + Vector3(0.0, 0.006, 0.018)
		tog.rotation.x = -0.5 if i % 3 == 0 else 0.5
		root.add_child(tog)
		var win: MeshInstance3D = ShapeKit.box(Vector3(0.008, 0.006, 0.002), f.ML.indicator(Color("e2453c"), 0.0), "Window")
		win.position = m.position + Vector3(0.0, 0.02, 0.015)
		root.add_child(win)
	return root


static func solder_station(f: PropFactory, _o: Dictionary) -> Node3D:
	## The temperature-controlled station: box, holder with the sponge, the coil
	## rest, and the iron sitting in it.
	var root := Node3D.new()
	root.name = "SolderStation"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.09, 0.13), f.ML.paint_blue(1.2), "Body")
	body.position = Vector3(0.0, 0.045, 0.0)
	root.add_child(body)
	var dial: MeshInstance3D = ShapeKit.cyl(0.02, 0.02, f.ML.plastic_black(), 14, Vector3i(0, 0, 1), "Dial")
	dial.position = Vector3(0.04, 0.06, 0.068)
	root.add_child(dial)
	var display: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.022, 0.004), f.ML.seven_segment(), "Display")
	display.position = Vector3(-0.03, 0.065, 0.067)
	root.add_child(display)
	var led: MeshInstance3D = ShapeKit.sphere(0.005, f.ML.indicator(Color("e2453c"), 0.0), 8, "HeatLed")
	led.position = Vector3(-0.03, 0.03, 0.068)
	root.add_child(led)
	var post: MeshInstance3D = ShapeKit.cyl(0.008, 0.12, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Post")
	post.position = Vector3(0.1, 0.15, 0.0)
	root.add_child(post)
	var arm: MeshInstance3D = ShapeKit.cyl(0.006, 0.08, f.ML.steel_dark(), 8, Vector3i(0, 0, 1), "Arm")
	arm.position = Vector3(0.1, 0.2, -0.04)
	root.add_child(arm)
	var coil: MeshInstance3D = ShapeKit.coil(7.0, 0.018, 0.0015, 0.05, f.ML.copper(), 14, "Coil")
	coil.position = Vector3(0.1, 0.17, -0.08)
	root.add_child(coil)
	var sponge: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.03, 0.04), f.ML.sponge(), "Sponge")
	sponge.position = Vector3(0.06, 0.1, 0.0)
	root.add_child(sponge)
	var tray: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.012, 0.1), f.ML.steel(), "DripTray")
	tray.position = Vector3(0.08, 0.094, 0.0)
	root.add_child(tray)
	var iron: Node3D = soldering_iron(f, {})
	iron.position = Vector3(0.1, 0.19, -0.08)
	iron.rotation = Vector3(0.4, 0.2, 0.1)
	root.add_child(iron)
	var spool: Node3D = solder_spool(f, {})
	spool.position = Vector3(-0.1, 0.02, 0.02)
	root.add_child(spool)
	root.set_meta("led_path", "HeatLed")
	return root
