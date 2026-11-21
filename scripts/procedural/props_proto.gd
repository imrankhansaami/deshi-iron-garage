class_name ProtoProps
extends RefCounted
## World B: the futuristic laboratory the inventor built inside the garage.
##
## The design rule for this register is that nothing here looks factory-made.
## Every high-tech object is visibly assembled from World A stock — the robot arms
## are motorcycle forks with servo boxes, the monitor wall is three salvaged
## panels in a welded frame, the reactor housing is a brake drum and a tyre rim.
## That provenance is the entire point of the project, so it is encoded in the
## geometry rather than left to texture.
##
## Orientation: Godot's TorusMesh is generated in the XZ plane, so a ring around
## a VERTICAL axis needs no rotation and a ring around a HORIZONTAL axis needs
## PI/2. The assembly platform's rings, the cradle bezel, the coil turns and the
## nozzle collars are all vertical-axis and therefore flat; the arms' tool tips,
## wheels and guard hoops are horizontal-axis and carry the quarter turn.
##
## Node contracts the dressing pass and the runtime depend on, listed because a
## rename here silently breaks a caller:
##   assembly_platform  -> "Deck", "ReactorCradle", meta radius
##   energy_cradle      -> "CoreBody", "CoreFace", "Bezel", meta ring_paths
##   robot_arm          -> "Shoulder", "Shoulder/Elbow", "Shoulder/Elbow/Wrist"
##   holo_table         -> "HoloVolume"
##   monitor_wall_panel -> "Screen"
##   diagnostic_screen  -> "Screen"
##   instrument_panel   -> "Screen"
##   component_crate    -> "Tag", "Module", meta module_kind


static func register(f: PropFactory) -> void:
	f.generators["monitor_wall_panel"] = monitor_wall_panel
	f.generators["indicator_strip"] = indicator_strip
	f.generators["conduit_run"] = conduit_run
	f.generators["robot_arm"] = robot_arm
	f.generators["suit_stand"] = suit_stand
	f.generators["assembly_platform"] = assembly_platform
	f.generators["holo_table"] = holo_table
	f.generators["testing_platform"] = testing_platform
	f.generators["instrument_panel"] = instrument_panel
	f.generators["safety_boundary"] = safety_boundary
	f.generators["energy_cradle"] = energy_cradle
	f.generators["component_crate"] = component_crate
	f.generators["diagnostic_screen"] = diagnostic_screen
	f.generators["overhead_rail"] = overhead_rail
	f.generators["servo_box"] = servo_box
	f.generators["reactor_housing"] = reactor_housing
	f.generators["cable_tray_future"] = cable_tray_future
	f.generators["part_kit"] = part_kit


# ===========================================================================
# Displays and indicators
# ===========================================================================

static func monitor_wall_panel(f: PropFactory, o: Dictionary) -> Node3D:
	## One screen in the wall array: a salvaged LCD shell in a hand-welded steel
	## bezel, with the status LEDs and the vent slots that mark it as repurposed.
	var w: float = float(o.get("width", 0.5))
	var h: float = w * 0.62
	var root := Node3D.new()
	root.name = "MonitorPanel"
	var shell: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.05), f.ML.steel_dark(), "Shell")
	root.add_child(shell)
	var screen: MeshInstance3D = ShapeKit.box(Vector3(w * 0.92, h * 0.86, 0.008), f.ML.glass_screen(), "Screen")
	screen.position = Vector3(0.0, 0.0, 0.028)
	root.add_child(screen)
	var bezel: MeshInstance3D = ShapeKit.box(Vector3(w * 0.98, h * 0.94, 0.012), f.ML.weld_bead(), "Bezel")
	bezel.position = Vector3(0.0, 0.0, 0.022)
	root.add_child(bezel)
	# the corner brackets, welded on at 45 degrees
	for sx: int in range(2):
		for sy: int in range(2):
			var br: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.05, 0.02), f.ML.steel(), "Bracket")
			br.position = Vector3((w * 0.5 - 0.02) * (1.0 if sx == 0 else -1.0), (h * 0.5 - 0.02) * (1.0 if sy == 0 else -1.0), 0.03)
			br.rotation.z = PI * 0.25
			root.add_child(br)
	var vents: MeshInstance3D = ShapeKit.box(Vector3(w * 0.5, 0.03, 0.006), f.ML.plastic_black(), "Vents")
	vents.position = Vector3(0.0, -h * 0.46, 0.0)
	root.add_child(vents)
	var led_colors: Array[Color] = [Color("5fd08a"), Color("4fd8ff"), Color("ffb347")]
	for i: int in range(3):
		var led: MeshInstance3D = ShapeKit.sphere(0.006, f.ML.indicator(led_colors[i], 0.0), 8, "Led%d" % i)
		led.position = Vector3(w * 0.4 - float(i) * 0.025, -h * 0.42, 0.03)
		root.add_child(led)
	root.set_meta("screen_path", "Screen")
	return root


static func diagnostic_screen(f: PropFactory, o: Dictionary) -> Node3D:
	## The tall portrait panel at the testing corner.
	var w: float = float(o.get("width", 0.42))
	var h: float = w * 1.7
	var root := Node3D.new()
	root.name = "DiagnosticScreen"
	var frame: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.06), f.ML.steel_dark(), "Frame")
	root.add_child(frame)
	var screen: MeshInstance3D = ShapeKit.box(Vector3(w * 0.9, h * 0.92, 0.01), f.ML.glass_screen(), "Screen")
	screen.position = Vector3(0.0, 0.0, 0.034)
	root.add_child(screen)
	var strip: MeshInstance3D = ShapeKit.box(Vector3(w * 0.9, 0.02, 0.012), f.ML.hologram_glow(Color("4fd8ff"), 0.0), "LightStrip")
	strip.position = Vector3(0.0, -h * 0.48, 0.03)
	root.add_child(strip)
	var post: MeshInstance3D = ShapeKit.cyl(0.03, 0.4, f.ML.steel(), 10, Vector3i(0, 1, 0), "Post")
	post.position = Vector3(0.0, -h * 0.5 - 0.2, 0.0)
	root.add_child(post)
	var base: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.04, 0.3), f.ML.steel_dark(), "Base")
	base.position = Vector3(0.0, -h * 0.5 - 0.4, 0.0)
	root.add_child(base)
	root.set_meta("screen_path", "Screen")
	return root


static func indicator_strip(f: PropFactory, o: Dictionary) -> Node3D:
	## A run of status lamps along a rail: the garage's cheap version of a
	## futuristic light strip, made from salvaged LEDs in a bent tin channel.
	var length: float = float(o.get("length", 1.2))
	var count: int = clampi(int(o.get("count", 10)), 2, 40)
	var root := Node3D.new()
	root.name = "IndicatorStrip"
	var channel: MeshInstance3D = ShapeKit.box(Vector3(length, 0.03, 0.035), f.ML.aluminium(), "Channel")
	root.add_child(channel)
	var diffuser: MeshInstance3D = ShapeKit.box(Vector3(length * 0.98, 0.006, 0.04), f.ML.diffuser_plastic(), "Diffuser")
	diffuser.position = Vector3(0.0, -0.016, 0.0)
	root.add_child(diffuser)
	for i: int in range(count):
		var x: float = -length * 0.5 + (float(i) + 0.5) * length / float(count)
		var led: MeshInstance3D = ShapeKit.sphere(0.008, f.ML.indicator(Color("4fd8ff"), 0.0), 8, "Led%02d" % i)
		led.position = Vector3(x, -0.014, 0.0)
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(led)
	for i: int in range(2):
		var end_cap: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.036, 0.042), f.ML.plastic_black(), "End%d" % i)
		end_cap.position = Vector3(length * 0.5 * (1.0 if i == 0 else -1.0), 0.0, 0.0)
		root.add_child(end_cap)
	return root


static func conduit_run(f: PropFactory, o: Dictionary) -> Node3D:
	## The power conduit feeding the assembly platform: a steel trunking with the
	## lid plates half-bolted and glowing at the joints where the inventor's
	## insulation has gone thin.
	var length: float = float(o.get("length", 2.0))
	var root := Node3D.new()
	root.name = "ConduitRun"
	var trunk: MeshInstance3D = ShapeKit.box(Vector3(length, 0.11, 0.11), f.ML.aluminium(), "Trunk")
	root.add_child(trunk)
	var lids: int = clampi(int(length / 0.5), 1, 12)
	for i: int in range(lids):
		var lid: MeshInstance3D = ShapeKit.box(Vector3(length / float(lids) * 0.9, 0.006, 0.115), f.ML.steel(), "Lid")
		lid.position = Vector3(-length * 0.5 + (float(i) + 0.5) * length / float(lids), 0.056, 0.0)
		if i % 3 == 1:
			lid.rotation.z = 0.06
		root.add_child(lid)
		for k: int in range(2):
			var bolt: MeshInstance3D = ShapeKit.cyl(0.005, 0.008, f.ML.steel_dark(), 6, Vector3i(0, 1, 0), "Bolt")
			bolt.position = lid.position + Vector3(0.0, 0.004, 0.045 * (1.0 if k == 0 else -1.0))
			bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(bolt)
	for i: int in range(lids - 1):
		var seam: MeshInstance3D = ShapeKit.box(Vector3(0.01, 0.008, 0.118), f.ML.hologram_glow(Color("4fd8ff"), 0.0), "Seam")
		seam.position = Vector3(-length * 0.5 + float(i + 1) * length / float(lids), 0.05, 0.0)
		root.add_child(seam)
	for i: int in range(3):
		var c: MeshInstance3D = ShapeKit.hose(
			Vector3(-length * 0.5 + float(i) * length * 0.4, 0.0, 0.05),
			Vector3(-length * 0.5 + float(i) * length * 0.4 + 0.2, -0.4 - float(i) * 0.1, 0.3),
			0.012, 0.15, f.ML.cable_material(Color("4fd8ff").darkened(0.75)), "Cable")
		root.add_child(c)
	return root


static func cable_tray_future(f: PropFactory, o: Dictionary) -> Node3D:
	var length: float = float(o.get("length", 2.4))
	var root := Node3D.new()
	root.name = "CableTray"
	var bottom: MeshInstance3D = ShapeKit.box(Vector3(length, 0.01, 0.18), f.ML.aluminium(), "Bottom")
	root.add_child(bottom)
	for i: int in range(2):
		var side: MeshInstance3D = ShapeKit.box(Vector3(length, 0.05, 0.01), f.ML.aluminium(), "Side")
		side.position = Vector3(0.0, 0.025, 0.09 * (1.0 if i == 0 else -1.0))
		root.add_child(side)
	var wire_colors: Array[Color] = [Color("1b1d20"), Color("e2453c"), Color("2a5ac9"), Color("e0c04a"), Color("4fd8ff"), Color("5fd08a")]
	for i: int in range(6):
		var wire: MeshInstance3D = ShapeKit.hose(
			Vector3(-length * 0.5, 0.01 + float(i) * 0.006, -0.07 + float(i) * 0.028),
			Vector3(length * 0.5, 0.01 + float(i) * 0.006, -0.06 + float(i) * 0.024),
			0.008, 0.04, f.ML.cable_material(wire_colors[i]), "Wire")
		root.add_child(wire)
	return root


# ===========================================================================
# Manipulators
# ===========================================================================

static func robot_arm(f: PropFactory, o: Dictionary) -> Node3D:
	## A two-axis assembly manipulator built from a motorcycle fork, a servo box,
	## a welded bracket and a gripper. Named joints let the assembly sequence
	## animate shoulder, elbow and wrist independently.
	var reach: float = float(o.get("reach", 1.15))
	var root := Node3D.new()
	root.name = String(o.get("name", "RobotArm"))
	var steel: StandardMaterial3D = f.ML.steel()
	var dark: StandardMaterial3D = f.ML.steel_dark()
	var base: MeshInstance3D = ShapeKit.cyl(0.16, 0.06, dark, 18, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(base)
	ShapeKit.bolt_ring(6, 0.13, 0.01, steel, base)
	var column: MeshInstance3D = ShapeKit.cyl(0.055, 0.9, steel, 14, Vector3i(0, 1, 0), "Column")
	column.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(column)
	var shoulder := Node3D.new()
	shoulder.name = "Shoulder"
	shoulder.position = Vector3(0.0, 0.95, 0.0)
	root.add_child(shoulder)
	shoulder.add_child(servo_box(f, {}))
	var upper: MeshInstance3D = ShapeKit.cyl(0.04, reach * 0.55, steel, 12, Vector3i(0, 0, 1), "UpperArm")
	upper.position = Vector3(0.0, 0.0, reach * 0.28)
	upper.rotation.x = PI * 0.5
	shoulder.add_child(upper)
	shoulder.add_child(ShapeKit.frame_tube(Vector3(0.0, -0.2, -0.05), Vector3(0.0, 0.02, reach * 0.2), 0.018, dark, "StrutA"))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, 0.0, reach * 0.55)
	shoulder.add_child(elbow)
	var joint: MeshInstance3D = ShapeKit.cyl(0.05, 0.1, dark, 14, Vector3i(0, 1, 0), "Joint")
	elbow.add_child(joint)
	var fore: MeshInstance3D = ShapeKit.cyl(0.032, reach * 0.42, f.ML.aluminium(), 12, Vector3i(0, 0, 1), "Forearm")
	fore.position = Vector3(0.0, 0.0, reach * 0.2)
	fore.rotation.x = PI * 0.5
	elbow.add_child(fore)
	elbow.add_child(ShapeKit.frame_tube(Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.01, reach * 0.34), 0.012, steel, "StrutB"))
	var wrist := Node3D.new()
	wrist.name = "Wrist"
	wrist.position = Vector3(0.0, 0.0, reach * 0.42)
	elbow.add_child(wrist)
	var wrist_body: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.05, 0.06), steel, "WristBody")
	wrist.add_child(wrist_body)
	for i: int in range(2):
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = Vector3(0.035 * (1.0 if i == 0 else -1.0), 0.0, 0.03)
		wrist.add_child(finger)
		var link: MeshInstance3D = ShapeKit.box(Vector3(0.014, 0.02, 0.07), dark, "Link")
		link.position = Vector3(0.0, 0.0, 0.035)
		finger.add_child(link)
		var pad: MeshInstance3D = ShapeKit.box(Vector3(0.018, 0.024, 0.03), f.ML.rubber(), "Pad")
		pad.position = Vector3(0.0, 0.0, 0.08)
		pad.rotation.x = 0.5 * (1.0 if i == 0 else -1.0)
		finger.add_child(pad)
	# the tool head: a brass weld tip that doubles as the attachment nozzle. Its
	# axis is +Z, so the collar around it is edge-on.
	var tool: MeshInstance3D = ShapeKit.tapered_cyl(0.006, 0.02, 0.06, f.ML.brass(), 10, "ToolTip")
	tool.position = Vector3(0.0, 0.0, 0.09)
	tool.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	wrist.add_child(tool)
	var glow: MeshInstance3D = ShapeKit.sphere(0.012, f.ML.hologram_glow(Color("ffb347"), 0.0), 8, "StatusEye")
	glow.position = Vector3(0.0, 0.03, 0.02)
	wrist.add_child(glow)
	var loom: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.05, -0.06), Vector3(0.0, 0.02, reach * 0.5), 0.014, 0.06, f.ML.cable_material(Color("#26282c")), "Loom")
	shoulder.add_child(loom)
	root.set_meta("shoulder_path", "Shoulder")
	root.set_meta("elbow_path", "Shoulder/Elbow")
	root.set_meta("wrist_path", "Shoulder/Elbow/Wrist")
	root.set_meta("reach", reach)
	return root


static func servo_box(f: PropFactory, _o: Dictionary) -> Node3D:
	## The actuator housing: a finned cylinder with a bolted cover, an indicator
	## and a connector. Salvaged from an industrial blower drive.
	var root := Node3D.new()
	root.name = "ServoBox"
	var body: MeshInstance3D = ShapeKit.cyl(0.06, 0.12, f.ML.cast_iron(), 16, Vector3i(0, 1, 0), "Body")
	root.add_child(body)
	for i: int in range(7):
		var fin: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.006, 0.012), f.ML.aluminium(), "Fin")
		fin.position = Vector3(0.0, -0.05 + float(i) * 0.016, 0.0)
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fin)
	var cover: MeshInstance3D = ShapeKit.cyl(0.065, 0.014, f.ML.steel(), 16, Vector3i(0, 1, 0), "Cover")
	cover.position = Vector3(0.0, 0.065, 0.0)
	root.add_child(cover)
	ShapeKit.bolt_ring(4, 0.05, 0.007, f.ML.steel_dark(), cover)
	var conn: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.03, 0.03), f.ML.plastic_black(), "Connector")
	conn.position = Vector3(0.06, 0.0, 0.0)
	root.add_child(conn)
	var led: MeshInstance3D = ShapeKit.sphere(0.006, f.ML.indicator(Color("5fd08a"), 0.0), 8, "Led")
	led.position = Vector3(0.0, 0.072, 0.03)
	root.add_child(led)
	return root


static func overhead_rail(f: PropFactory, o: Dictionary) -> Node3D:
	## The gantry the assembly arms hang from: a box-section beam on two columns,
	## with the trolley that carries the hoist.
	var span: float = float(o.get("span", 4.2))
	var root := Node3D.new()
	root.name = "OverheadRail"
	var beam: MeshInstance3D = ShapeKit.box(Vector3(span, 0.16, 0.14), f.ML.steel_dark(), "Beam")
	root.add_child(beam)
	var flange: MeshInstance3D = ShapeKit.box(Vector3(span, 0.02, 0.2), f.ML.steel(), "Flange")
	flange.position = Vector3(0.0, -0.09, 0.0)
	root.add_child(flange)
	for i: int in range(2):
		var web: MeshInstance3D = ShapeKit.box(Vector3(span, 0.02, 0.02), f.ML.steel(), "Stiffener")
		web.position = Vector3(0.0, 0.07, 0.06 * (1.0 if i == 0 else -1.0))
		root.add_child(web)
	var trolley := Node3D.new()
	trolley.name = "Trolley"
	root.add_child(trolley)
	var tbody: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.1, 0.24), f.ML.paint_yellow(), "TrolleyBody")
	tbody.position = Vector3(0.0, 0.13, 0.0)
	trolley.add_child(tbody)
	for i: int in range(4):
		# the trolley wheels roll on horizontal axles, so their discs are vertical
		var wheel: MeshInstance3D = ShapeKit.cyl(0.05, 0.03, f.ML.steel_hardened(), 12, Vector3i(0, 0, 1), "Wheel")
		wheel.position = tbody.position + Vector3(-0.14 + float(i % 2) * 0.28, -0.06, 0.1 * (1.0 if i < 2 else -1.0))
		trolley.add_child(wheel)
	var hoist: MeshInstance3D = ShapeKit.cyl(0.04, 0.12, f.ML.cast_iron(), 12, Vector3i(0, 1, 0), "Hoist")
	hoist.position = Vector3(0.0, 0.02, 0.0)
	trolley.add_child(hoist)
	# the hook hangs in a vertical plane
	var hook: MeshInstance3D = ShapeKit.torus(0.06, 0.014, f.ML.steel(), 14, 6, "Hook")
	hook.position = Vector3(0.0, -0.14, 0.0)
	hook.rotation = Vector3(0.0, PI * 0.5, 0.0)
	trolley.add_child(hook)
	var cable: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.1, 0.0), 0.004, 0.02, f.ML.cable_material(Color("#26282c")), "HoistCable")
	trolley.add_child(cable)
	root.set_meta("trolley_path", "Trolley")
	return root


# ===========================================================================
# The station hardware
# ===========================================================================

static func assembly_platform(f: PropFactory, o: Dictionary) -> Node3D:
	## The circular assembly stage: a welded steel ring, a rotating deck, the
	## reactor pit in the middle, the four arm mounts and the perimeter lights.
	## Everything the assembly sequence animates is a named child here.
	var radius: float = float(o.get("radius", 2.6))
	var root := Node3D.new()
	root.name = "AssemblyPlatform"
	var steel: StandardMaterial3D = f.ML.steel()
	var dark: StandardMaterial3D = f.ML.steel_dark()
	for i: int in range(12):
		var a: float = ShapeKit.TAU_K * float(i) / 12.0
		var beam: MeshInstance3D = ShapeKit.box(Vector3(0.5, 0.12, 0.16), dark, "Spoke%02d" % i)
		beam.position = Vector3(cos(a) * radius * 0.55, 0.06, sin(a) * radius * 0.55)
		beam.rotation.y = -a
		root.add_child(beam)
	# the platform's rings are horizontal, which is TorusMesh's native plane
	var ring: MeshInstance3D = ShapeKit.torus(radius, 0.09, steel, 40, 10, "OuterRing")
	ring.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(ring)
	var inner_ring: MeshInstance3D = ShapeKit.torus(radius * 0.62, 0.06, steel, 32, 8, "InnerRing")
	inner_ring.position = Vector3(0.0, 0.16, 0.0)
	root.add_child(inner_ring)
	var deck := Node3D.new()
	deck.name = "Deck"
	root.add_child(deck)
	var segments: int = 8
	for i: int in range(segments):
		var a: float = ShapeKit.TAU_K * float(i) / float(segments)
		var plate: MeshInstance3D = ShapeKit.box(Vector3(radius * 0.5, 0.05, radius * 0.42), f.ML.tread_plate(), "DeckPlate%02d" % i)
		plate.position = Vector3(cos(a) * radius * 0.42, 0.2, sin(a) * radius * 0.42)
		plate.rotation.y = -a
		deck.add_child(plate)
		var grip: MeshInstance3D = ShapeKit.box(Vector3(radius * 0.46, 0.008, 0.02), dark, "Grip")
		grip.position = plate.position + Vector3(0.0, 0.03, 0.08)
		grip.rotation.y = -a
		grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		deck.add_child(grip)
	var pit: MeshInstance3D = ShapeKit.cyl(radius * 0.26, 0.3, dark, 24, Vector3i(0, 1, 0), "ReactorPit")
	pit.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(pit)
	# the cradle is named so the runtime can find it and install the core shader
	var cradle: Node3D = energy_cradle(f, {"radius": radius * 0.22})
	cradle.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(cradle)
	for i: int in range(8):
		var a: float = ShapeKit.TAU_K * (float(i) + 0.5) / 8.0
		var pod: MeshInstance3D = ShapeKit.cyl(0.05, 0.06, steel, 12, Vector3i(0, 1, 0), "LightPod%02d" % i)
		pod.position = Vector3(cos(a) * (radius - 0.12), 0.22, sin(a) * (radius - 0.12))
		root.add_child(pod)
		# the pod lens faces upward, so it lies flat
		var lens: MeshInstance3D = ShapeKit.disc_flat(0.04, 0.01, f.ML.hologram_glow(Color("ffd9a0"), 0.0), "PodLens%02d" % i)
		lens.position = pod.position + Vector3(0.0, 0.034, 0.0)
		root.add_child(lens)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0 + 0.4
		var mount: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.22, 0.34), dark, "ArmMount%02d" % i)
		mount.position = Vector3(cos(a) * (radius - 0.3), 0.11, sin(a) * (radius - 0.3))
		mount.rotation.y = -a
		root.add_child(mount)
		ShapeKit.bolt_ring(4, 0.12, 0.012, steel, mount)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0
		var ram: MeshInstance3D = ShapeKit.cyl(0.03, 0.4, f.ML.chrome(), 10, Vector3i(0, 1, 0), "Ram%02d" % i)
		ram.position = Vector3(cos(a) * radius * 0.5, 0.2, sin(a) * radius * 0.5)
		root.add_child(ram)
		var sleeve: MeshInstance3D = ShapeKit.cyl(0.04, 0.18, dark, 10, Vector3i(0, 1, 0), "Sleeve")
		sleeve.position = ram.position + Vector3(0.0, -0.12, 0.0)
		root.add_child(sleeve)
	var umbilical: MeshInstance3D = ShapeKit.hose(
		Vector3(radius * 0.24, 0.28, 0.0), Vector3(radius * 0.9, 0.1, radius * 0.4), 0.03, 0.25,
		f.ML.cable_material(Color("1a2a33")), "Umbilical")
	root.add_child(umbilical)
	root.add_child(ShapeKit.col_cyl(radius, 0.35))
	root.set_meta("deck_path", "Deck")
	root.set_meta("cradle_path", "ReactorCradle")
	root.set_meta("radius", radius)
	return root


static func energy_cradle(f: PropFactory, o: Dictionary) -> Node3D:
	## The housing the fictional core sits in: a brake-drum-derived bezel, three
	## containment rings and the coil former from a salvaged flyback.
	## The runtime calls install_core() on this node, so the names matter.
	var radius: float = float(o.get("radius", 0.55))
	var root := Node3D.new()
	root.name = "ReactorCradle"
	var bezel: MeshInstance3D = ShapeKit.torus(radius, radius * 0.14, f.ML.steel(), 26, 8, "Bezel")
	root.add_child(bezel)
	var plate: MeshInstance3D = ShapeKit.cyl(radius * 0.95, 0.06, f.ML.cast_iron(), 26, Vector3i(0, 1, 0), "BackPlate")
	plate.position = Vector3(0.0, -0.05, 0.0)
	root.add_child(plate)
	ShapeKit.bolt_ring(8, radius * 0.85, radius * 0.05, f.ML.steel_dark(), root)
	# containment rings, named so the core system can counter-rotate them
	for i: int in range(3):
		var r: float = radius * (0.55 + float(i) * 0.2)
		var ring: MeshInstance3D = ShapeKit.torus(r, radius * 0.035, f.ML.aluminium(), 22, 6, "Ring%d" % i)
		ring.rotation = Vector3(float(i) * 0.35, float(i) * 0.6, 0.0)
		root.add_child(ring)
	var former: MeshInstance3D = ShapeKit.cyl(radius * 0.4, radius * 0.5, f.ML.ferrite(), 18, Vector3i(0, 1, 0), "CoilFormer")
	former.position = Vector3(0.0, -0.02, 0.0)
	root.add_child(former)
	# the winding turns encircle the vertical former, so they are flat
	for i: int in range(5):
		var turn: MeshInstance3D = ShapeKit.torus(radius * 0.42, radius * 0.025, f.ML.copper(), 18, 5, "Turn%d" % i)
		turn.position = Vector3(0.0, -0.05 + float(i) * radius * 0.12, 0.0)
		root.add_child(turn)
	# the glowing core body itself; shader applied by the energy-core system
	var core: MeshInstance3D = ShapeKit.sphere(radius * 0.34, null, 24, "CoreBody")
	core.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(core)
	var core_face: MeshInstance3D = ShapeKit.disc_flat(radius * 0.32, 0.01, null, "CoreFace")
	core_face.position = Vector3(0.0, 0.32, 0.0)
	root.add_child(core_face)
	for i: int in range(6):
		var a: float = ShapeKit.TAU_K * float(i) / 6.0
		var led: MeshInstance3D = ShapeKit.sphere(radius * 0.05, f.ML.hologram_glow(Color("4fd8ff"), 0.0), 8, "CradleLed%d" % i)
		led.position = Vector3(cos(a) * radius * 0.98, 0.0, sin(a) * radius * 0.98)
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(led)
	root.set_meta("core_body", "CoreBody")
	root.set_meta("core_face", "CoreFace")
	root.set_meta("ring_paths", PackedStringArray(["Ring0", "Ring1", "Ring2"]))
	return root


static func suit_stand(f: PropFactory, o: Dictionary) -> Node3D:
	## The display stand the exosuit is built on: a base plate, a spine column,
	## a torso cradle with four attachment arms, a head yoke and boot supports.
	## Named so the assembly sequence can raise and lower it.
	var root := Node3D.new()
	root.name = "SuitStand"
	var steel: StandardMaterial3D = f.ML.steel()
	var dark: StandardMaterial3D = f.ML.steel_dark()
	# the base plate is sized by the caller: at full width it spans the platform's
	# reactor pit and the cradle rings rise through it, so the assembly passes a
	# radius that tucks the plate inside the pit mouth
	var base_r: float = float(o.get("base_radius", 0.55))
	var base: MeshInstance3D = ShapeKit.cyl(base_r, 0.08, dark, 22, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.04, 0.0)
	root.add_child(base)
	ShapeKit.bolt_ring(6, maxf(base_r - 0.1, 0.1), 0.014, steel, base)
	var column: MeshInstance3D = ShapeKit.cyl(0.07, 1.15, steel, 14, Vector3i(0, 1, 0), "Column")
	column.position = Vector3(0.0, 0.65, -0.08)
	root.add_child(column)
	root.add_child(ShapeKit.frame_tube(Vector3(0.19, 0.1, -0.06), Vector3(0.05, 0.9, -0.08), 0.03, steel, "BraceA"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.19, 0.1, -0.06), Vector3(0.05, 0.9, -0.08), 0.03, steel, "BraceB"))
	var cradle := Node3D.new()
	cradle.name = "TorsoCradle"
	cradle.position = Vector3(0.0, 1.32, -0.06)
	root.add_child(cradle)
	var spine_plate: MeshInstance3D = ShapeKit.box(Vector3(0.3, 0.42, 0.05), dark, "SpinePlate")
	spine_plate.position = Vector3(0.0, 0.0, -0.12)
	cradle.add_child(spine_plate)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0 + 0.4
		var arm: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.05, 0.22), steel, "CradleArm")
		arm.position = Vector3(cos(a) * 0.16, sin(a) * 0.16, 0.02)
		arm.rotation = Vector3(0.0, -a, 0.0)
		cradle.add_child(arm)
		var pad: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.06, 0.03), f.ML.rubber(), "Pad")
		pad.position = arm.position + Vector3(cos(a) * 0.11, sin(a) * 0.11, 0.06)
		cradle.add_child(pad)
	# the head yoke is a horizontal hoop, so it lies flat. Raised 5 cm: at 1.78
	# the hoop's band passed through the suit's neck collar
	var yoke: MeshInstance3D = ShapeKit.torus(0.14, 0.025, steel, 18, 6, "HeadYoke")
	yoke.position = Vector3(0.0, 1.83, -0.06)
	root.add_child(yoke)
	var yoke_post: MeshInstance3D = ShapeKit.cyl(0.025, 0.3, steel, 10, Vector3i(0, 1, 0), "YokePost")
	yoke_post.position = Vector3(0.0, 1.69, -0.12)
	root.add_child(yoke_post)
	for i: int in range(2):
		var boot: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.06, 0.3), dark, "BootSupport")
		boot.position = Vector3(0.14 * (1.0 if i == 0 else -1.0), 0.11, 0.16)
		root.add_child(boot)
		var riser: MeshInstance3D = ShapeKit.cyl(0.03, 0.16, steel, 10, Vector3i(0, 1, 0), "Riser")
		riser.position = boot.position + Vector3(0.0, 0.1, 0.0)
		root.add_child(riser)
	# the stand's own umbilical lands on the deck plates now; at y = 0.2 it ended
	# in mid-air a hand's width above them
	var umb: MeshInstance3D = ShapeKit.hose(Vector3(0.35, 0.055, -0.3), Vector3(0.05, 1.1, -0.14), 0.02, 0.2, f.ML.cable_material(Color("1a2a33")), "Umbilical")
	root.add_child(umb)
	root.set_meta("cradle_path", "TorsoCradle")
	root.set_meta("yoke_path", "HeadYoke")
	return root


static func holo_table(f: PropFactory, o: Dictionary) -> Node3D:
	## The design table: a steel pedestal, a glass top with the projection grid
	## underneath, four emitter posts, the control plinth and the hologram volume
	## the shader fills.
	var radius: float = float(o.get("radius", 0.95))
	var root := Node3D.new()
	root.name = "HoloTable"
	var pedestal: MeshInstance3D = ShapeKit.cyl(radius * 0.42, 0.72, f.ML.steel_dark(), 20, Vector3i(0, 1, 0), "Pedestal")
	pedestal.position = Vector3(0.0, 0.36, 0.0)
	root.add_child(pedestal)
	var foot: MeshInstance3D = ShapeKit.cyl(radius * 0.62, 0.06, f.ML.steel(), 22, Vector3i(0, 1, 0), "Foot")
	foot.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(foot)
	ShapeKit.bolt_ring(6, radius * 0.5, 0.012, f.ML.steel(), foot)
	var top_ring: MeshInstance3D = ShapeKit.torus(radius, 0.05, f.ML.steel(), 30, 8, "TopRing")
	top_ring.position = Vector3(0.0, 0.74, 0.0)
	root.add_child(top_ring)
	# the glass top and the projection plate beneath it both lie flat
	var glass: MeshInstance3D = ShapeKit.disc_flat(radius * 0.96, 0.02, f.ML.glass_smoky(), "GlassTop")
	glass.position = Vector3(0.0, 0.75, 0.0)
	root.add_child(glass)
	var emitter: MeshInstance3D = ShapeKit.disc_flat(radius * 0.9, 0.01, f.ML.hologram_glow(Color("4fd8ff"), 0.0), "EmitterPlate")
	emitter.position = Vector3(0.0, 0.735, 0.0)
	root.add_child(emitter)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0 + 0.3
		var post: MeshInstance3D = ShapeKit.cyl(0.035, 0.28, f.ML.steel(), 12, Vector3i(0, 1, 0), "EmitterPost%02d" % i)
		post.position = Vector3(cos(a) * radius * 0.86, 0.88, sin(a) * radius * 0.86)
		root.add_child(post)
		var lens: MeshInstance3D = ShapeKit.tapered_cyl(0.05, 0.0, 0.08, f.ML.hologram_glow(Color("9ff0ff"), 0.0), 12, "Lens%02d" % i)
		lens.position = post.position + Vector3(0.0, 0.16, 0.0)
		root.add_child(lens)
	var plinth: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.5, 0.24), f.ML.steel_dark(), "ControlPlinth")
	plinth.position = Vector3(radius * 0.9, 0.25, radius * 0.5)
	plinth.rotation.y = -0.6
	root.add_child(plinth)
	var keys: MeshInstance3D = ShapeKit.box(Vector3(0.26, 0.01, 0.16), f.ML.plastic_black(), "Keypad")
	keys.position = plinth.position + Vector3(0.0, 0.26, 0.0)
	root.add_child(keys)
	for i: int in range(12):
		var k: MeshInstance3D = ShapeKit.box(Vector3(0.035, 0.008, 0.03), f.ML.indicator(Color("4fd8ff"), 0.0), "Key")
		k.position = keys.position + Vector3(-0.09 + float(i % 3) * 0.09, 0.006, -0.055 + float(i / 3) * 0.037)
		k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(k)
	# the hologram volume itself, filled by the shader at runtime
	var volume := Node3D.new()
	volume.name = "HoloVolume"
	volume.position = Vector3(0.0, 0.78, 0.0)
	root.add_child(volume)
	root.add_child(ShapeKit.col_cyl(radius, 1.0))
	root.set_meta("volume_path", "HoloVolume")
	root.set_meta("glass_path", "GlassTop")
	root.set_meta("emitter_path", "EmitterPlate")
	return root


static func testing_platform(f: PropFactory, o: Dictionary) -> Node3D:
	## The prototype testing corner: a raised deck with the safety boundary, the
	## instrument panel, the diagnostic screen mount and the tether rig.
	var size: float = float(o.get("size", 2.2))
	var root := Node3D.new()
	root.name = "TestingPlatform"
	var deck: MeshInstance3D = ShapeKit.box(Vector3(size, 0.14, size), f.ML.tread_plate(), "Deck")
	deck.position = Vector3(0.0, 0.07, 0.0)
	root.add_child(deck)
	var lip: MeshInstance3D = ShapeKit.box(Vector3(size + 0.06, 0.05, size + 0.06), f.ML.paint_yellow(), "Lip")
	lip.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(lip)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0 + 0.4
		var foot: MeshInstance3D = ShapeKit.cyl(0.06, 0.06, f.ML.rubber(), 12, Vector3i(0, 1, 0), "Isolator")
		foot.position = Vector3(cos(a) * size * 0.42, 0.0, sin(a) * size * 0.42)
		root.add_child(foot)
	for i: int in range(4):
		var a: float = ShapeKit.TAU_K * float(i) / 4.0
		var post: MeshInstance3D = ShapeKit.cyl(0.03, 0.9, f.ML.steel(), 10, Vector3i(0, 1, 0), "TetherPost%02d" % i)
		post.position = Vector3(cos(a) * size * 0.42, 0.59, sin(a) * size * 0.42)
		root.add_child(post)
		# the eyelet ring stands upright on top of the post
		var eye: MeshInstance3D = ShapeKit.torus(0.035, 0.008, f.ML.steel_dark(), 12, 5, "Eye")
		eye.position = post.position + Vector3(0.0, 0.45, 0.0)
		eye.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(eye)
		var chain: Node3D = ShapeKit.chain(0.02, 6, f.ML.steel_dark(), "Chain")
		chain.position = eye.position + Vector3(0.0, -0.12, 0.0)
		chain.rotation = Vector3(0.0, 0.0, PI * 0.5)
		root.add_child(chain)
	for i: int in range(2):
		var mark: MeshInstance3D = ShapeKit.box(Vector3(size * 0.9, 0.004, 0.12), f.ML.hazard_paint(), "Marking%d" % i)
		mark.position = Vector3(0.0, 0.145, size * 0.42 * (1.0 if i == 0 else -1.0))
		root.add_child(mark)
	root.add_child(ShapeKit.col_box(Vector3(size, 0.2, size)))
	return root


static func instrument_panel(f: PropFactory, o: Dictionary) -> Node3D:
	## The diagnostics console: analog gauges, toggle banks, the big emergency
	## stop, and a small screen. World A instruments driving World B readings.
	var w: float = float(o.get("width", 0.9))
	var root := Node3D.new()
	root.name = "InstrumentPanel"
	var desk: MeshInstance3D = ShapeKit.box(Vector3(w, 0.7, 0.4), f.ML.steel_dark(), "Console")
	desk.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(desk)
	var faceplate: MeshInstance3D = ShapeKit.box(Vector3(w * 0.96, 0.02, 0.36), f.ML.steel(), "Faceplate")
	faceplate.position = Vector3(0.0, 0.74, 0.02)
	faceplate.rotation.x = -0.45
	root.add_child(faceplate)
	for i: int in range(3):
		var g: MeshInstance3D = ShapeKit.disc(0.055, 0.02, f.ML.meter_face(), "Gauge%d" % i)
		g.position = Vector3(-w * 0.32 + float(i) * w * 0.22, 0.79, -0.06)
		g.rotation.x = -0.45 + PI * 0.5
		root.add_child(g)
		var needle: MeshInstance3D = ShapeKit.box(Vector3(0.004, 0.045, 0.004), f.ML.indicator(Color("e2453c"), 0.3), "Needle%d" % i)
		needle.position = g.position + Vector3(0.0, 0.0, 0.014)
		needle.rotation = Vector3(-0.45, 0.0, 0.6 + float(i) * 0.4)
		root.add_child(needle)
		# the bezel ring encircles the gauge, which faces +Z
		var rim: MeshInstance3D = ShapeKit.torus(0.058, 0.008, f.ML.brass(), 16, 5, "GaugeRim")
		rim.position = g.position
		rim.rotation = Vector3(-0.45 + PI * 0.5, 0.0, 0.0)
		root.add_child(rim)
	for i: int in range(6):
		var base: MeshInstance3D = ShapeKit.cyl(0.014, 0.012, f.ML.steel(), 10, Vector3i(0, 0, 1), "ToggleBase")
		base.position = Vector3(w * 0.12 + float(i % 3) * 0.05, 0.76 - float(i / 3) * 0.06, 0.06)
		root.add_child(base)
		var lever: MeshInstance3D = ShapeKit.cyl(0.005, 0.04, f.ML.chrome(), 6, Vector3i(0, 1, 0), "ToggleLever")
		lever.position = base.position + Vector3(0.0, 0.02, 0.0)
		lever.rotation.x = 0.6 if i % 2 == 0 else -0.6
		root.add_child(lever)
	var lamp_colors: Array[Color] = [Color("5fd08a"), Color("ffb347"), Color("e2453c"), Color("4fd8ff"), Color("5fd08a")]
	for i: int in range(5):
		var led: MeshInstance3D = ShapeKit.sphere(0.01, f.ML.indicator(lamp_colors[i], 0.0), 8, "PanelLed%d" % i)
		led.position = Vector3(-w * 0.4 + float(i) * 0.05, 0.72, 0.14)
		root.add_child(led)
	var estop: MeshInstance3D = ShapeKit.cyl(0.045, 0.03, f.ML.paint_red(), 16, Vector3i(0, 0, 1), "EmergencyStop")
	estop.position = Vector3(w * 0.4, 0.72, 0.16)
	estop.rotation.x = -0.45
	root.add_child(estop)
	var collar: MeshInstance3D = ShapeKit.cyl(0.055, 0.012, f.ML.paint_yellow(), 16, Vector3i(0, 0, 1), "EStopCollar")
	collar.position = estop.position + Vector3(0.0, -0.02, 0.0)
	root.add_child(collar)
	var screen: MeshInstance3D = ShapeKit.box(Vector3(w * 0.3, 0.16, 0.01), f.ML.glass_screen(), "Screen")
	screen.position = Vector3(w * 0.22, 0.82, -0.1)
	screen.rotation.x = -0.45
	root.add_child(screen)
	root.add_child(ShapeKit.col_box(Vector3(w, 0.85, 0.45)))
	root.set_meta("screen_path", "Screen")
	return root


static func safety_boundary(f: PropFactory, o: Dictionary) -> Node3D:
	## The painted-and-taped perimeter around the testing area, plus the low steel
	## barrier rail. Cheap, effective, and exactly what a real workshop would do.
	var radius: float = float(o.get("radius", 2.0))
	var root := Node3D.new()
	root.name = "SafetyBoundary"
	var posts: int = 8
	# spans to leave out, so the barrier has real gates: a span index i covers
	# post i to post i+1, and the posts at either end of a gap still stand
	var skip_spans: Array = o.get("skip_spans", [])
	for i: int in range(posts):
		var a: float = ShapeKit.TAU_K * float(i) / float(posts)
		var post: MeshInstance3D = ShapeKit.cyl(0.028, 0.95, f.ML.hazard_paint(), 10, Vector3i(0, 1, 0), "Post%02d" % i)
		post.position = Vector3(cos(a) * radius, 0.475, sin(a) * radius)
		root.add_child(post)
		var cap: MeshInstance3D = ShapeKit.sphere(0.032, f.ML.paint_yellow(), 8, "Cap")
		cap.position = post.position + Vector3(0.0, 0.48, 0.0)
		root.add_child(cap)
		if skip_spans.has(i):
			continue
		var next_a: float = ShapeKit.TAU_K * float(i + 1) / float(posts)
		var rail: MeshInstance3D = ShapeKit.frame_tube(
			post.position + Vector3(0.0, 0.3, 0.0),
			Vector3(cos(next_a) * radius, 0.775, sin(next_a) * radius),
			0.016, f.ML.steel(), "Rail%02d" % i)
		root.add_child(rail)
		var tape: MeshInstance3D = ShapeKit.frame_tube(
			post.position + Vector3(0.0, 0.05, 0.0),
			Vector3(cos(next_a) * radius, 0.55, sin(next_a) * radius),
			0.006, f.ML.hazard_tape_paint(), "Tape%02d" % i)
		root.add_child(tape)
	return root


static func component_crate(f: PropFactory, o: Dictionary) -> Node3D:
	## The labelled crate a prototype module is found in. The tag is a baked
	## SignCanvas, so the component name and its spec are real text.
	var root := Node3D.new()
	root.name = "ComponentCrate"
	var w: float = float(o.get("width", 0.5))
	var body: MeshInstance3D = ShapeKit.box(Vector3(w, w * 0.6, w * 0.7), f.ML.teak(), "Crate")
	body.position = Vector3(0.0, w * 0.3, 0.0)
	root.add_child(body)
	for i: int in range(4):
		var band: MeshInstance3D = ShapeKit.box(Vector3(w * 1.02, 0.03, 0.02), f.ML.steel_dark(), "Band")
		band.position = Vector3(0.0, w * 0.15 + float(i % 2) * w * 0.3, (w * 0.35) * (1.0 if i < 2 else -1.0))
		root.add_child(band)
	var lid: MeshInstance3D = ShapeKit.box(Vector3(w * 1.04, 0.03, w * 0.74), f.ML.teak(), "Lid")
	lid.position = Vector3(0.0, w * 0.62, 0.0)
	root.add_child(lid)
	var tag: MeshInstance3D = ShapeKit.plane(Vector2(w * 0.7, w * 0.28), f.ML.label_stock(), "Tag")
	tag.position = Vector3(0.0, w * 0.42, w * 0.36)
	root.add_child(tag)
	var module_kind: String = String(o.get("module", "frame"))
	var payload: Node3D = _module_prop(f, module_kind)
	payload.position = Vector3(0.0, w * 0.66, 0.0)
	payload.name = "Module"
	root.add_child(payload)
	root.add_child(ShapeKit.col_box(Vector3(w, w * 0.7, w * 0.7)))
	root.set_meta("module_path", "Module")
	root.set_meta("tag_path", "Tag")
	root.set_meta("module_kind", module_kind)
	return root


static func _module_prop(f: PropFactory, kind: String) -> Node3D:
	## The three fictional prototype modules, each visibly built from a World A
	## donor part. Non-weaponised by construction: frame, power buffer, shell.
	match kind:
		"energy":
			var root2 := Node3D.new()
			root2.name = "EnergyModule"
			var pack: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.14, 0.16), f.ML.battery_case(), "Pack")
			root2.add_child(pack)
			for i: int in range(4):
				var cell: MeshInstance3D = ShapeKit.cyl(0.03, 0.2, f.ML.lead_terminal(), 12, Vector3i(1, 0, 0), "Cell")
				cell.position = Vector3(0.0, 0.02, -0.06 + float(i) * 0.04)
				root2.add_child(cell)
			var board: MeshInstance3D = ShapeKit.box(Vector3(0.26, 0.01, 0.18), f.ML.pcb(), "BufferBoard")
			board.position = Vector3(0.0, 0.08, 0.0)
			root2.add_child(board)
			var coil: MeshInstance3D = ShapeKit.coil(8.0, 0.05, 0.005, 0.06, f.ML.copper(), 16, "CouplingCoil")
			coil.position = Vector3(0.0, 0.09, 0.0)
			root2.add_child(coil)
			# the ferrite ring sits around the vertical coil
			var core: MeshInstance3D = ShapeKit.torus(0.045, 0.018, f.ML.ferrite(), 16, 6, "Ferrite")
			core.position = Vector3(0.0, 0.12, 0.0)
			root2.add_child(core)
			for i: int in range(2):
				var term: MeshInstance3D = ShapeKit.cyl(0.012, 0.03, f.ML.brass(), 8, Vector3i(0, 1, 0), "Term%d" % i)
				term.position = Vector3(0.1 * (1.0 if i == 0 else -1.0), 0.1, 0.05)
				root2.add_child(term)
			return root2
		"shell":
			var root3 := Node3D.new()
			root3.name = "ArmourShell"
			var red: StandardMaterial3D = f.ML.armour_red()
			var chest: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
				Vector2(0.02, 0.0), Vector2(0.16, 0.01), Vector2(0.2, 0.05), Vector2(0.18, 0.12),
				Vector2(0.1, 0.16), Vector2(0.02, 0.17),
			]), 20, red, false, "ChestBlank")
			root3.add_child(chest)
			var shoulder: MeshInstance3D = ShapeKit.sphere(0.09, f.ML.armour_gold(), 14, "ShoulderBlank")
			shoulder.position = Vector3(0.2, 0.1, 0.0)
			shoulder.scale = Vector3(1.0, 0.6, 1.0)
			root3.add_child(shoulder)
			var plate: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.01, 0.1), red, "ForearmBlank")
			plate.position = Vector3(-0.18, 0.02, 0.05)
			root3.add_child(plate)
			for i: int in range(3):
				var rivet: MeshInstance3D = ShapeKit.sphere(0.008, f.ML.brass(), 6, "Rivet")
				rivet.position = Vector3(-0.06 + float(i) * 0.06, 0.175, 0.06)
				root3.add_child(rivet)
			return root3
		_:
			var root := Node3D.new()
			root.name = "FrameModule"
			var steel: StandardMaterial3D = f.ML.steel()
			root.add_child(ShapeKit.frame_tube(Vector3(-0.2, 0.0, 0.05), Vector3(0.2, 0.16, 0.05), 0.022, steel, "SpineA"))
			root.add_child(ShapeKit.frame_tube(Vector3(-0.2, 0.0, -0.05), Vector3(0.2, 0.16, -0.05), 0.022, steel, "SpineB"))
			root.add_child(ShapeKit.frame_tube(Vector3(-0.2, 0.0, 0.05), Vector3(-0.2, 0.0, -0.05), 0.018, f.ML.steel_dark(), "CrossA"))
			root.add_child(ShapeKit.frame_tube(Vector3(0.2, 0.16, 0.05), Vector3(0.2, 0.16, -0.05), 0.018, f.ML.steel_dark(), "CrossB"))
			for i: int in range(3):
				var bracket: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.02, 0.14), f.ML.weld_bead(), "Bracket")
				bracket.position = Vector3(-0.14 + float(i) * 0.14, 0.05 + float(i) * 0.04, 0.0)
				root.add_child(bracket)
			# the shoulder ring is a vertical hoop here: it stands on the frame's end
			var shoulder_ring: MeshInstance3D = ShapeKit.torus(0.09, 0.02, steel, 16, 6, "ShoulderRing")
			shoulder_ring.position = Vector3(0.22, 0.18, 0.0)
			shoulder_ring.rotation = Vector3(0.0, PI * 0.5, 0.0)
			root.add_child(shoulder_ring)
			return root


static func reactor_housing(f: PropFactory, o: Dictionary) -> Node3D:
	## The large wall-mounted housing behind the stand: a tyre rim, brake drum and
	## welded fins, with the diagnostic ring that lights when the core is live.
	var radius: float = float(o.get("radius", 0.7))
	var root := Node3D.new()
	root.name = "ReactorHousing"
	# the housing is mounted flat against the wall, so its rim faces the room
	var rim: MeshInstance3D = ShapeKit.torus(radius, radius * 0.12, f.ML.steel(), 28, 8, "Rim")
	rim.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(rim)
	var drum: MeshInstance3D = ShapeKit.cyl(radius * 0.8, radius * 0.4, f.ML.cast_iron(), 26, Vector3i(0, 0, 1), "Drum")
	root.add_child(drum)
	for i: int in range(12):
		var a: float = ShapeKit.TAU_K * float(i) / 12.0
		var fin: MeshInstance3D = ShapeKit.box(Vector3(radius * 0.1, radius * 0.5, 0.02), f.ML.aluminium(), "Fin")
		fin.position = Vector3(cos(a) * radius * 0.6, sin(a) * radius * 0.6, radius * 0.2)
		fin.rotation.z = a
		root.add_child(fin)
	var ring: MeshInstance3D = ShapeKit.torus(radius * 0.95, radius * 0.03, f.ML.hologram_glow(Color("4fd8ff"), 0.0), 30, 6, "DiagRing")
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	ring.position = Vector3(0.0, 0.0, radius * 0.22)
	root.add_child(ring)
	ShapeKit.bolt_ring(8, radius * 0.85, radius * 0.04, f.ML.steel_dark(), root)
	var mount: MeshInstance3D = ShapeKit.box(Vector3(radius * 0.3, radius * 1.6, 0.06), f.ML.steel_dark(), "WallMount")
	mount.position = Vector3(0.0, 0.0, -radius * 0.25)
	root.add_child(mount)
	root.set_meta("ring_path", "DiagRing")
	return root


static func part_kit(f: PropFactory, o: Dictionary) -> Node3D:
	## A tray of small fabricated parts, used to dress the assembly area so it
	## reads as a working station rather than a showroom.
	var root := Node3D.new()
	root.name = "PartKit"
	var tray: MeshInstance3D = ShapeKit.box(Vector3(0.36, 0.02, 0.26), f.ML.plastic_faded(), "Tray")
	tray.position = Vector3(0.0, 0.01, 0.0)
	root.add_child(tray)
	var rim: MeshInstance3D = ShapeKit.box(Vector3(0.38, 0.03, 0.28), f.ML.plastic_faded(), "Rim")
	rim.position = Vector3(0.0, 0.005, 0.0)
	root.add_child(rim)
	var kinds: Array[String] = ["bolt", "bearing", "gear", "plate", "coil"]
	for i: int in range(int(o.get("count", 9))):
		var kind: String = kinds[i % kinds.size()]
		var p: Node3D
		match kind:
			"bolt":
				p = ShapeKit.bolt(f.rand().randf_range(0.008, 0.014), f.rand().randf_range(0.02, 0.05), f.ML.steel(), "Bolt")
			"bearing":
				p = bearing_stub(f)
			"gear":
				p = ShapeKit.gear(int(f.rand().randi_range(8, 18)), f.rand().randf_range(2.0, 4.0), 0.01, 0.012, f.ML.steel_hardened(), "Gear")
			"plate":
				p = ShapeKit.box(Vector3(f.rand().randf_range(0.04, 0.09), 0.004, f.rand().randf_range(0.04, 0.09)), f.ML.armour_red(), "Plate")
			_:
				p = ShapeKit.coil(5.0, f.rand().randf_range(0.02, 0.04), 0.003, 0.03, f.ML.copper(), 12, "Coil")
		p.position = Vector3(f.rand().randf_range(-0.15, 0.15), 0.03, f.rand().randf_range(-0.1, 0.1))
		p.rotation.y = f.rand().randf_range(0, 3.14)
		root.add_child(p)
	return root


static func bearing_stub(f: PropFactory) -> Node3D:
	## A small ball race lying flat in the tray: its axis is +Y.
	var n := Node3D.new()
	n.name = "Bearing"
	var race: MeshInstance3D = ShapeKit.torus(0.03, 0.006, f.ML.steel_hardened(), 16, 5, "Race")
	n.add_child(race)
	var inner: MeshInstance3D = ShapeKit.torus(0.018, 0.005, f.ML.chrome(), 14, 5, "Inner")
	n.add_child(inner)
	return n
