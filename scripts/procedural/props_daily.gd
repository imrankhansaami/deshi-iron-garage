class_name DailyProps
extends RefCounted
## World A, daily-life register. These are the objects that decide whether the
## garage reads as Bangladesh or as a generic industrial shed: the tea glasses,
## the flask, the gamcha towel, the wall calendar with Bengali month names, the
## muri tin, the clipboard, the sack of scrap, the inventor's notebook.
##
## Every text-bearing surface here is handed to the SignageBaker, so the Bengali
## is shaped by the engine's text stack rather than drawn as glyphs by hand.
##
## Orientation note: Godot's TorusMesh is generated in the XZ plane, so a band,
## tie or collar around a VERTICAL cylinder needs no rotation. Only parts whose
## axis is horizontal — a wheel, a tin's bail handle, a pen's collar — carry the
## PI/2. ShapeKit.disc() faces +Z (mirror, clock face, gauge) while
## ShapeKit.disc_flat() lies down (tea ring on a page, soap on its dish).


static func register(f: PropFactory) -> void:
	f.generators["tea_glass"] = tea_glass
	f.generators["flask"] = flask
	f.generators["muri_tin"] = muri_tin
	f.generators["biscuit_tin"] = biscuit_tin
	f.generators["newspaper_fold"] = newspaper_fold
	f.generators["towel_hanging"] = towel_hanging
	f.generators["sandals"] = sandals
	f.generators["water_bucket"] = water_bucket
	f.generators["clip_board"] = clip_board
	f.generators["wall_calendar"] = wall_calendar
	f.generators["wall_clock"] = wall_clock
	f.generators["wall_banner"] = wall_banner
	f.generators["wall_plaque"] = wall_plaque
	f.generators["photo_wall"] = photo_wall
	f.generators["armor_figure"] = armor_figure
	f.generators["armor_base"] = armor_base
	f.generators["armor_ghost"] = armor_ghost
	f.generators["armor_legs"] = armor_legs
	f.generators["armor_torso"] = armor_torso
	f.generators["armor_head"] = armor_head
	f.generators["armor_helmet"] = armor_helmet
	f.generators["armor_chest_plate"] = armor_chest_plate
	f.generators["armor_gauntlet"] = armor_gauntlet
	f.generators["armor_boot"] = armor_boot
	f.generators["flag_pole"] = flag_pole
	f.generators["big_coin"] = big_coin
	f.generators["poster"] = poster
	f.generators["notebook"] = notebook
	f.generators["pen"] = pen
	f.generators["plastic_bag_roll"] = plastic_bag_roll
	f.generators["sack"] = sack
	f.generators["mirror_small"] = mirror_small
	f.generators["comb"] = comb
	f.generators["soap_dish"] = soap_dish
	f.generators["cup_brush"] = cup_brush
	f.generators["signboard"] = signboard
	f.generators["shelf_label"] = shelf_label
	f.generators["hook_nail"] = hook_nail
	f.generators["socket_wall"] = socket_wall
	f.generators["switch_wall"] = switch_wall
	f.generators["meter_box"] = meter_box
	f.generators["gas_cylinder"] = gas_cylinder
	f.generators["chair_office"] = chair_office
	f.generators["photo_frame"] = photo_frame
	f.generators["tool_chest"] = tool_chest


# ===========================================================================
# Tea and food
# ===========================================================================

static func tea_glass(f: PropFactory, o: Dictionary) -> Node3D:
	## The tall thin glass of cha that is the social unit of every workshop.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "TeaGlass"
	var glass: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.028, 0.006), Vector2(0.032, 0.06),
		Vector2(0.034, 0.085), Vector2(0.031, 0.086), Vector2(0.029, 0.06), Vector2(0.025, 0.008),
		Vector2(0.0, 0.004),
	]), 14, f.ML.glass_smoky(), true, "Glass")
	root.add_child(glass)
	var liquid: MeshInstance3D = ShapeKit.cyl(0.0285, 0.052, f.ML.tea_liquid(), 12, Vector3i(0, 1, 0), "Tea")
	liquid.position = Vector3(0.0, 0.034, 0.0)
	root.add_child(liquid)
	# the froth sits on the top surface, so it lies flat
	var foam: MeshInstance3D = ShapeKit.disc_flat(0.028, 0.001, f.ML.tea_froth(), "Foam")
	foam.position = Vector3(0.0, 0.061, 0.0)
	root.add_child(foam)
	root.scale = Vector3.ONE * s
	return root


static func flask(f: PropFactory, _o: Dictionary) -> Node3D:
	## The steel vacuum flask that keeps the tea hot through a shift.
	var root := Node3D.new()
	root.name = "Flask"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.053, 0.012), Vector2(0.054, 0.16),
		Vector2(0.048, 0.2), Vector2(0.032, 0.22), Vector2(0.03, 0.24), Vector2(0.0, 0.245),
	]), 16, f.ML.stainless(), true, "Body")
	root.add_child(body)
	var cap: MeshInstance3D = ShapeKit.cyl(0.034, 0.05, f.ML.plastic_black(), 14, Vector3i(0, 1, 0), "Cap")
	cap.position = Vector3(0.0, 0.265, 0.0)
	root.add_child(cap)
	var cup: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.032, 0.005), Vector2(0.034, 0.03),
		Vector2(0.031, 0.031), Vector2(0.029, 0.006), Vector2(0.0, 0.004),
	]), 14, f.ML.stainless(), true, "CupCap")
	cup.position = Vector3(0.06, 0.0, 0.02)
	root.add_child(cup)
	# the grip band encircles the vertical body
	var band: MeshInstance3D = ShapeKit.torus(0.0545, 0.004, f.ML.rubber(), 16, 5, "Grip")
	band.position = Vector3(0.0, 0.09, 0.0)
	root.add_child(band)
	var handle: MeshInstance3D = ShapeKit.torus(0.035, 0.006, f.ML.stainless(), 14, 5, "Handle")
	handle.position = Vector3(0.055, 0.13, 0.0)
	handle.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(handle)
	# the dent every working flask acquires
	var dent: MeshInstance3D = ShapeKit.sphere(0.012, f.ML.stainless(), 8, "Dent")
	dent.position = Vector3(0.05, 0.12, 0.02)
	dent.scale = Vector3(0.4, 1.0, 1.0)
	root.add_child(dent)
	return root


static func muri_tin(f: PropFactory, _o: Dictionary) -> Node3D:
	## The sealed tin of muri (puffed rice) on the shelf.
	var root := Node3D.new()
	root.name = "MuriTin"
	var body: MeshInstance3D = ShapeKit.cyl(0.075, 0.14, f.ML.tinplate(), 18, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, 0.07, 0.0)
	root.add_child(body)
	var lid: MeshInstance3D = ShapeKit.cyl(0.078, 0.02, f.ML.tinplate(), 18, Vector3i(0, 1, 0), "Lid")
	lid.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(lid)
	var label: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.07, 0.002), f.ML.tin_label(), "Label")
	label.position = Vector3(0.0, 0.08, 0.076)
	root.add_child(label)
	# spilled muri on the shelf, each grain lying flat
	for i: int in range(14):
		var grain: MeshInstance3D = ShapeKit.sphere(0.004, f.ML.muri(), 5, "Grain")
		grain.position = Vector3(f.rand().randf_range(-0.12, 0.12), 0.002, f.rand().randf_range(0.05, 0.16))
		grain.scale = Vector3(1.0, 0.7, 1.4)
		grain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(grain)
	return root


static func biscuit_tin(f: PropFactory, _o: Dictionary) -> Node3D:
	## The repurposed biscuit tin that in this country always holds screws instead.
	var root := Node3D.new()
	root.name = "BiscuitTin"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.115, 0.008), Vector2(0.113, 0.09),
		Vector2(0.108, 0.095), Vector2(0.0, 0.095),
	]), 20, f.ML.tinplate(), true, "Body")
	root.add_child(body)
	var lid: MeshInstance3D = ShapeKit.cyl(0.112, 0.014, f.ML.tinplate(), 20, Vector3i(0, 1, 0), "Lid")
	lid.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(lid)
	var art: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.06, 0.002), f.ML.tin_label(), "Art")
	art.position = Vector3(0.0, 0.05, 0.114)
	root.add_child(art)
	# screws rattling loose on top of the lid
	for i: int in range(8):
		var s: Node3D = ShapeKit.bolt(
			f.rand().randf_range(0.006, 0.01), f.rand().randf_range(0.02, 0.045), f.ML.steel(), "Screw")
		s.position = Vector3(f.rand().randf_range(-0.06, 0.06), 0.108, f.rand().randf_range(-0.06, 0.06))
		s.rotation = Vector3(f.rand().randf_range(-1.4, 1.4), f.rand().randf_range(0, 3.14), f.rand().randf_range(-1.4, 1.4))
		root.add_child(s)
	return root


static func newspaper_fold(f: PropFactory, _o: Dictionary) -> Node3D:
	## The folded Bengali daily, used as a bench cover, a rag and a pillow.
	var root := Node3D.new()
	root.name = "Newspaper"
	var mat: StandardMaterial3D = f.ML.newspaper()
	var stack_h: float = 0.0
	for i: int in range(5):
		var sheet: MeshInstance3D = ShapeKit.box(Vector3(0.36 - float(i) * 0.008, 0.0035, 0.26 - float(i) * 0.006), mat, "Fold")
		stack_h += 0.0035
		sheet.position = Vector3(f.rand().randf_range(-0.01, 0.01), stack_h, f.rand().randf_range(-0.01, 0.01))
		sheet.rotation.y = f.rand().randf_range(-0.09, 0.09)
		root.add_child(sheet)
	var head: MeshInstance3D = ShapeKit.box(Vector3(0.2, 0.001, 0.03), f.ML.newsprint_print(), "Headline")
	head.position = Vector3(-0.05, stack_h + 0.003, -0.06)
	head.rotation.y = 0.04
	root.add_child(head)
	for i: int in range(6):
		var col: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.0008, 0.16), f.ML.newsprint_print(), "Column")
		col.position = Vector3(-0.14 + float(i) * 0.055, stack_h + 0.003, 0.03)
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(col)
	return root


static func towel_hanging(f: PropFactory, o: Dictionary) -> Node3D:
	## The gamcha draped over a nail or a bar.
	var length: float = float(o.get("length", 0.7))
	var root := Node3D.new()
	root.name = "Gamcha"
	var mat: StandardMaterial3D = f.ML.gamcha()
	for i: int in range(2):
		var panel: MeshInstance3D = ShapeKit.box(Vector3(length * 0.5, 0.004, 0.16), mat, "Panel")
		panel.position = Vector3(-length * 0.25 + float(i) * length * 0.5, -0.02, 0.0)
		panel.rotation.z = 0.06 * (1.0 if i == 0 else -1.0)
		root.add_child(panel)
		var drop: MeshInstance3D = ShapeKit.box(Vector3(length * 0.46, 0.004, 0.34), mat, "Drop")
		drop.position = Vector3(-length * 0.25 + float(i) * length * 0.5, -0.19, 0.09)
		drop.rotation = Vector3(0.12, 0.0, 0.03 * (1.0 if i == 0 else -1.0))
		root.add_child(drop)
	var stripe: MeshInstance3D = ShapeKit.box(Vector3(length, 0.005, 0.03), f.ML.gamcha_red(), "Border")
	stripe.position = Vector3(0.0, -0.018, -0.06)
	root.add_child(stripe)
	var nail: MeshInstance3D = ShapeKit.cyl(0.004, 0.05, f.ML.steel_dark(), 6, Vector3i(0, 0, 1), "Nail")
	nail.position = Vector3(0.0, 0.0, -0.02)
	root.add_child(nail)
	return root


static func sandals(f: PropFactory, _o: Dictionary) -> Node3D:
	## The rubber slip-on chappal by the door.
	var root := Node3D.new()
	root.name = "Sandals"
	for i: int in range(2):
		var sole: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.048, 0.004), Vector2(0.046, 0.012),
			Vector2(0.0, 0.014),
		]), 12, f.ML.sandal_rubber(), true, "Sole")
		sole.scale = Vector3(1.0, 1.0, 2.2)
		sole.position = Vector3(0.0, 0.0, 0.07 * (1.0 if i == 0 else -1.0))
		sole.rotation.y = f.rand().randf_range(-0.3, 0.3)
		root.add_child(sole)
		# the thong strap arches over the foot in a vertical plane
		var strap: MeshInstance3D = ShapeKit.torus(0.045, 0.006, f.ML.sandal_rubber(), 12, 5, "Strap")
		strap.position = sole.position + Vector3(0.0, 0.02, -0.01)
		strap.rotation = Vector3(1.1, 0.0, 0.0)
		strap.scale = Vector3(1.0, 1.0, 0.6)
		root.add_child(strap)
	return root


static func water_bucket(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WaterBucket"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.17, 0.01), Vector2(0.2, 0.34),
		Vector2(0.205, 0.36), Vector2(0.196, 0.36), Vector2(0.19, 0.34), Vector2(0.155, 0.015),
		Vector2(0.0, 0.012),
	]), 18, f.ML.plastic_blue_body(), true, "Body")
	root.add_child(body)
	var water: MeshInstance3D = ShapeKit.cyl(0.185, 0.002, f.ML.water(), 18, Vector3i(0, 1, 0), "Water")
	water.position = Vector3(0.0, 0.28, 0.0)
	root.add_child(water)
	var ladle: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.07, 0.005), Vector2(0.075, 0.04), Vector2(0.07, 0.045),
		Vector2(0.06, 0.01), Vector2(0.0, 0.004),
	]), 12, f.ML.plastic_red(), true, "Ladle")
	ladle.position = Vector3(0.05, 0.3, 0.05)
	ladle.rotation = Vector3(0.6, 0.3, 0.2)
	root.add_child(ladle)
	var handle: MeshInstance3D = ShapeKit.cyl(0.006, 0.16, f.ML.teak(), 8, Vector3i(1, 0, 0), "LadleHandle")
	handle.position = Vector3(0.12, 0.36, 0.1)
	handle.rotation = Vector3(0.4, 0.0, 0.3)
	root.add_child(handle)
	return root


static func gas_cylinder(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "GasCylinder"
	var body: MeshInstance3D = ShapeKit.cyl(0.14, 0.72, f.ML.paint_blue(1.1), 20, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(body)
	var shoulder: MeshInstance3D = ShapeKit.sphere(0.14, f.ML.paint_blue(1.1), 18, "Shoulder")
	shoulder.position = Vector3(0.0, 0.78, 0.0)
	shoulder.scale = Vector3(1.0, 0.6, 1.0)
	root.add_child(shoulder)
	var valve: MeshInstance3D = ShapeKit.cyl(0.03, 0.1, f.ML.brass(), 12, Vector3i(0, 1, 0), "Valve")
	valve.position = Vector3(0.0, 0.88, 0.0)
	root.add_child(valve)
	# the collar rings encircles the vertical body, so no rotation
	var collar: MeshInstance3D = ShapeKit.torus(0.145, 0.02, f.ML.steel_dark(), 18, 6, "Collar")
	collar.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(collar)
	var foot: MeshInstance3D = ShapeKit.cyl(0.15, 0.04, f.ML.steel_dark(), 18, Vector3i(0, 1, 0), "Foot")
	foot.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(foot)
	root.add_child(ShapeKit.col_cyl(0.16, 0.95))
	return root


# ===========================================================================
# Paper, wall fixtures, personal objects
# ===========================================================================

static func clip_board(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ClipBoard"
	var board: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.32, 0.008), f.ML.teak(), "Board")
	root.add_child(board)
	var paper: MeshInstance3D = ShapeKit.box(Vector3(0.21, 0.28, 0.002), f.ML.paper(), "Paper")
	paper.position = Vector3(0.0, -0.01, 0.006)
	root.add_child(paper)
	var clip: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.03, 0.012), f.ML.steel(), "Clip")
	clip.position = Vector3(0.0, 0.14, 0.008)
	root.add_child(clip)
	for i: int in range(9):
		var line: MeshInstance3D = ShapeKit.box(Vector3(0.16 - float(i % 3) * 0.03, 0.004, 0.001), f.ML.handwriting_line(), "Line")
		line.position = Vector3(-0.01, 0.1 - float(i) * 0.026, 0.0075)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(line)
	return root


static func wall_calendar(f: PropFactory, o: Dictionary) -> Node3D:
	## The free promotional wall calendar with Bengali month names and the two
	## date columns every one of them carries.
	var w: float = float(o.get("width", 0.34))
	var h: float = w * 1.35
	var root := Node3D.new()
	root.name = "WallCalendar"
	var sheet: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.004), f.ML.calendar_stock(), "Sheet")
	sheet.position = Vector3(0.0, -h * 0.5, 0.0)
	root.add_child(sheet)
	var header: MeshInstance3D = ShapeKit.box(Vector3(w * 0.94, h * 0.14, 0.002), f.ML.calendar_header(), "Header")
	header.position = Vector3(0.0, -h * 0.06, 0.003)
	root.add_child(header)
	var cols: int = 7
	var rows: int = 6
	for r: int in range(rows):
		for c: int in range(cols):
			var cell: MeshInstance3D = ShapeKit.box(Vector3(w / float(cols) * 0.82, h * 0.055, 0.001), f.ML.calendar_cell(), "Cell")
			cell.position = Vector3(
				-w * 0.5 + (float(c) + 0.5) * w / float(cols),
				-h * 0.16 - float(r) * h * 0.062,
				0.0035,
			)
			cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(cell)
	var wire: MeshInstance3D = ShapeKit.cyl(0.002, 0.06, f.ML.steel(), 5, Vector3i(0, 0, 1), "Wire")
	wire.position = Vector3(0.0, 0.02, 0.01)
	wire.rotation.x = 1.4
	root.add_child(wire)
	var nail: MeshInstance3D = ShapeKit.cyl(0.003, 0.04, f.ML.steel_dark(), 6, Vector3i(0, 0, 1), "Nail")
	nail.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(nail)
	root.set_meta("sheet_path", "Sheet")
	root.set_meta("header_path", "Header")
	return root


static func wall_clock(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.14))
	var root := Node3D.new()
	root.name = "WallClock"
	# the clock faces +Z: rim and hands are edge-on discs in the XY plane
	var rim: MeshInstance3D = ShapeKit.torus(r, 0.014, f.ML.plastic_black(), 22, 6, "Rim")
	rim.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(rim)
	var face: MeshInstance3D = ShapeKit.disc(r * 0.95, 0.006, f.ML.clock_face(), "Face")
	face.position = Vector3(0.0, 0.0, -0.004)
	root.add_child(face)
	var glass: MeshInstance3D = ShapeKit.disc(r * 0.96, 0.002, f.ML.glass_smoky(), "Glass")
	glass.position = Vector3(0.0, 0.0, 0.008)
	root.add_child(glass)
	for i: int in range(12):
		var a: float = ShapeKit.TAU_K * float(i) / 12.0
		var tick: MeshInstance3D = ShapeKit.box(Vector3(0.006, 0.002, 0.001), f.ML.plastic_black(), "Tick")
		tick.position = Vector3(cos(a) * r * 0.8, sin(a) * r * 0.8, 0.001)
		tick.rotation.z = a
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tick)
	var hour_hand: MeshInstance3D = ShapeKit.box(Vector3(0.006, r * 0.5, 0.002), f.ML.plastic_black(), "HourHand")
	hour_hand.position = Vector3(0.0, r * 0.2, 0.004)
	root.add_child(hour_hand)
	var minute_hand: MeshInstance3D = ShapeKit.box(Vector3(0.004, r * 0.72, 0.002), f.ML.plastic_black(), "MinuteHand")
	minute_hand.position = Vector3(0.0, r * 0.3, 0.006)
	root.add_child(minute_hand)
	var second_hand: MeshInstance3D = ShapeKit.box(Vector3(0.002, r * 0.8, 0.001), f.ML.indicator(Color("e2453c"), 0.2), "SecondHand")
	second_hand.position = Vector3(0.0, r * 0.34, 0.008)
	root.add_child(second_hand)
	var cap: MeshInstance3D = ShapeKit.cyl(0.008, 0.006, f.ML.brass(), 10, Vector3i(0, 0, 1), "Cap")
	cap.position = Vector3(0.0, 0.0, 0.01)
	root.add_child(cap)
	root.set_meta("hour_path", "HourHand")
	root.set_meta("minute_path", "MinuteHand")
	root.set_meta("second_path", "SecondHand")
	return root


static func poster(f: PropFactory, o: Dictionary) -> Node3D:
	## A printed poster on the wall: film, cricket, or a spare-parts advert.
	var w: float = float(o.get("width", 0.4))
	var h: float = w * 1.4
	var root := Node3D.new()
	root.name = "Poster"
	var sheet: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.002), f.ML.poster_stock(int(o.get("variant", 0))), "Sheet")
	sheet.position = Vector3(0.0, -h * 0.5, 0.0)
	sheet.rotation.x = 0.02
	root.add_child(sheet)
	for i: int in range(2):
		var tape: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.02, 0.001), f.ML.adhesive_tape(), "Tape")
		tape.position = Vector3(w * 0.4 * (1.0 if i == 0 else -1.0), -0.01, 0.002)
		tape.rotation.z = -0.4 * (1.0 if i == 0 else -1.0)
		root.add_child(tape)
	return root


static func photo_frame(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "PhotoFrame"
	var frame: MeshInstance3D = ShapeKit.box(Vector3(0.18, 0.22, 0.012), f.ML.woodgrain_dark(), "Frame")
	root.add_child(frame)
	var photo: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.18, 0.002), f.ML.photo_paper(), "Photo")
	photo.position = Vector3(0.0, 0.0, 0.008)
	root.add_child(photo)
	var glass: MeshInstance3D = ShapeKit.box(Vector3(0.15, 0.19, 0.001), f.ML.glass_smoky(), "Glass")
	glass.position = Vector3(0.0, 0.0, 0.01)
	root.add_child(glass)
	var stand: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.16, 0.004), f.ML.steel_dark(), "Stand")
	stand.position = Vector3(0.0, -0.02, -0.03)
	stand.rotation.x = -0.5
	root.add_child(stand)
	return root


static func notebook(f: PropFactory, o: Dictionary) -> Node3D:
	## THE notebook: the inventor's engineering khata. Corkboard cover, string
	## binding, dog-eared pages, and the sketch that starts the whole story.
	var w: float = float(o.get("width", 0.24))
	var l: float = w * 1.4
	var root := Node3D.new()
	root.name = "Notebook"
	var cover: MeshInstance3D = ShapeKit.box(Vector3(w, 0.014, l), f.ML.notebook_cover(), "Cover")
	cover.position = Vector3(0.0, 0.007, 0.0)
	root.add_child(cover)
	var block: MeshInstance3D = ShapeKit.box(Vector3(w * 0.96, 0.02, l * 0.96), f.ML.paper(), "Pages")
	block.position = Vector3(0.0, 0.024, 0.0)
	root.add_child(block)
	var top_cover: MeshInstance3D = ShapeKit.box(Vector3(w, 0.006, l), f.ML.notebook_cover(), "TopCover")
	top_cover.position = Vector3(0.0, 0.037, 0.0)
	root.add_child(top_cover)
	# the open page, angled so it reads as a book lying mid-use
	var open_page: MeshInstance3D = ShapeKit.box(Vector3(w * 0.92, 0.002, l * 0.9), f.ML.paper(), "OpenPage")
	open_page.position = Vector3(w * 0.46, 0.045, 0.0)
	open_page.rotation = Vector3(0.0, -0.06, 0.0)
	root.add_child(open_page)
	# string binding down the spine, one loop per signature
	for i: int in range(4):
		var tie: MeshInstance3D = ShapeKit.cyl(0.003, l * 0.94, f.ML.thread_material(), 6, Vector3i(0, 0, 1), "Tie")
		tie.position = Vector3(-w * 0.5 + 0.004, 0.02 + float(i) * 0.004, -l * 0.35 + float(i) * l * 0.23)
		tie.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(tie)
	# a tea ring dried onto the page, lying flat
	var stain: MeshInstance3D = ShapeKit.disc_flat(0.03, 0.001, f.ML.tea_stain(), "TeaRing")
	stain.position = Vector3(w * 0.3, 0.047, l * 0.3)
	root.add_child(stain)
	var corner: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.001, 0.04), f.ML.paper(), "DogEar")
	corner.position = Vector3(w * 0.44, 0.048, -l * 0.42)
	corner.rotation = Vector3(0.0, 0.78, 0.0)
	root.add_child(corner)
	root.add_child(ShapeKit.col_box(Vector3(w, 0.05, l)))
	root.set_meta("page_path", "OpenPage")
	return root


static func pen(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Pen"
	var barrel: MeshInstance3D = ShapeKit.cyl(0.006, 0.14, f.ML.pen_body(), 10, Vector3i(0, 0, 1), "Barrel")
	root.add_child(barrel)
	var nib: MeshInstance3D = ShapeKit.tapered_cyl(0.0012, 0.005, 0.02, f.ML.steel_dark(), 8, "Nib")
	nib.position = Vector3(0.0, 0.0, 0.08)
	nib.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(nib)
	var cap: MeshInstance3D = ShapeKit.cyl(0.0065, 0.05, f.ML.plastic_black(), 10, Vector3i(0, 0, 1), "Cap")
	cap.position = Vector3(0.0, 0.0, -0.05)
	root.add_child(cap)
	var clip: MeshInstance3D = ShapeKit.box(Vector3(0.002, 0.001, 0.04), f.ML.brass(), "Clip")
	clip.position = Vector3(0.006, 0.0, -0.05)
	root.add_child(clip)
	root.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	return root


static func plastic_bag_roll(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BagRoll"
	var roll: MeshInstance3D = ShapeKit.cyl(0.05, 0.16, f.ML.plastic_bag(), 14, Vector3i(1, 0, 0), "Roll")
	roll.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(roll)
	var core: MeshInstance3D = ShapeKit.cyl(0.012, 0.17, f.ML.cardboard(), 10, Vector3i(1, 0, 0), "Core")
	core.position = roll.position
	root.add_child(core)
	var hanging: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.18, 0.002), f.ML.plastic_bag(), "Bag")
	hanging.position = Vector3(0.06, -0.06, 0.02)
	hanging.rotation = Vector3(0.1, 0.2, 0.05)
	root.add_child(hanging)
	return root


static func sack(f: PropFactory, o: Dictionary) -> Node3D:
	## The woven polypropylene sack of scrap. Bulged, stitched, leaning.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Sack"
	var body: MeshInstance3D = ShapeKit.sphere(0.24 * s, f.ML.woven_sack(), 16, "Body")
	body.scale = Vector3(1.0, 0.75, 0.85)
	body.position = Vector3(0.0, 0.18 * s, 0.0)
	root.add_child(body)
	var neck: MeshInstance3D = ShapeKit.cyl(0.06 * s, 0.1 * s, f.ML.woven_sack(), 12, Vector3i(0, 1, 0), "Neck")
	neck.position = Vector3(0.0, 0.34 * s, 0.0)
	neck.rotation.z = 0.15
	root.add_child(neck)
	# the drawstring tie encircles the vertical neck
	var tie: MeshInstance3D = ShapeKit.torus(0.06 * s, 0.006, f.ML.thread_material(), 12, 5, "Tie")
	tie.position = neck.position + Vector3(0.0, -0.02, 0.0)
	root.add_child(tie)
	for i: int in range(8):
		var stitch: MeshInstance3D = ShapeKit.box(Vector3(0.004, 0.004, 0.02), f.ML.thread_material(), "Stitch")
		stitch.position = Vector3(-0.02 + float(i) * 0.006, 0.4 * s, 0.0)
		stitch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stitch)
	root.add_child(ShapeKit.col_sphere(0.26 * s))
	return root


static func mirror_small(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Mirror"
	var frame: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.24, 0.014), f.ML.plastic_faded(), "Frame")
	root.add_child(frame)
	var glass: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.21, 0.004), f.ML.mirror(), "Glass")
	glass.position = Vector3(0.0, 0.0, 0.008)
	root.add_child(glass)
	var hook: MeshInstance3D = ShapeKit.cyl(0.003, 0.03, f.ML.steel_dark(), 6, Vector3i(0, 0, 1), "Hook")
	hook.position = Vector3(0.0, 0.11, -0.01)
	root.add_child(hook)
	return root


static func comb(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Comb"
	var spine: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.004, 0.02), f.ML.plastic_black(), "Spine")
	root.add_child(spine)
	for i: int in range(22):
		var tooth: MeshInstance3D = ShapeKit.box(Vector3(0.0015, 0.003, 0.028), f.ML.plastic_black(), "Tooth")
		tooth.position = Vector3(-0.065 + float(i) * 0.006, -0.002, 0.022)
		tooth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tooth)
	return root


static func soap_dish(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SoapDish"
	var dish: MeshInstance3D = ShapeKit.cyl(0.06, 0.012, f.ML.plastic_faded(), 14, Vector3i(0, 1, 0), "Dish")
	dish.position = Vector3(0.0, 0.006, 0.0)
	root.add_child(dish)
	var soap: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.025, 0.045), f.ML.soap(), "Soap")
	soap.position = Vector3(0.0, 0.022, 0.0)
	soap.rotation.y = 0.3
	root.add_child(soap)
	return root


static func cup_brush(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CupBrush"
	var handle: MeshInstance3D = ShapeKit.cyl(0.012, 0.18, f.ML.plastic_red(), 10, Vector3i(0, 1, 0), "Handle")
	handle.position = Vector3(0.0, 0.09, 0.0)
	root.add_child(handle)
	var head: MeshInstance3D = ShapeKit.cyl(0.02, 0.05, f.ML.bristle(), 12, Vector3i(0, 1, 0), "Head")
	head.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(head)
	for i: int in range(10):
		var a: float = ShapeKit.TAU_K * float(i) / 10.0
		var tuft: MeshInstance3D = ShapeKit.cyl(0.004, 0.03, f.ML.bristle(), 6, Vector3i(0, 1, 0), "Tuft")
		tuft.position = head.position + Vector3(cos(a) * 0.014, 0.03, sin(a) * 0.014)
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tuft)
	return root


static func shelf_label(f: PropFactory, o: Dictionary) -> Node3D:
	## The handwritten strip of paper taped to a shelf edge or bin, in Bangla.
	var w: float = float(o.get("width", 0.14))
	var root := Node3D.new()
	root.name = "ShelfLabel"
	var strip: MeshInstance3D = ShapeKit.box(Vector3(w, 0.035, 0.002), f.ML.label_stock(), "Strip")
	root.add_child(strip)
	var tape: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.012, 0.001), f.ML.adhesive_tape(), "Tape")
	tape.position = Vector3(-w * 0.4, 0.0, 0.002)
	root.add_child(tape)
	return root


static func hook_nail(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "NailHook"
	var shank: MeshInstance3D = ShapeKit.cyl(0.003, 0.05, f.ML.steel_dark(), 6, Vector3i(0, 0, 1), "Shank")
	shank.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(shank)
	var crook: MeshInstance3D = ShapeKit.torus(0.012, 0.003, f.ML.steel_dark(), 10, 5, "Crook")
	crook.position = Vector3(0.0, -0.012, 0.02)
	root.add_child(crook)
	return root


static func socket_wall(f: PropFactory, _o: Dictionary) -> Node3D:
	## The three-pin wall socket, Bangladeshi rectangular pattern.
	var root := Node3D.new()
	root.name = "WallSocket"
	var plate: MeshInstance3D = ShapeKit.box(Vector3(0.085, 0.055, 0.008), f.ML.plastic_white_gloss(), "Plate")
	root.add_child(plate)
	var insert: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.036, 0.006), f.ML.plastic_faded(), "Insert")
	insert.position = Vector3(0.0, 0.0, 0.006)
	root.add_child(insert)
	for i: int in range(3):
		var hole: MeshInstance3D = ShapeKit.box(Vector3(0.008, 0.004, 0.004), f.ML.plastic_black(), "Pin")
		hole.position = Vector3(-0.018 + float(i) * 0.018, 0.004 if i == 2 else -0.004, 0.01)
		hole.rotation.z = 0.78 if i < 2 else 0.0
		root.add_child(hole)
	for i: int in range(2):
		var screw: MeshInstance3D = ShapeKit.cyl(0.003, 0.004, f.ML.brass(), 6, Vector3i(0, 0, 1), "Screw")
		screw.position = Vector3(0.0, 0.02 * (1.0 if i == 0 else -1.0), 0.008)
		root.add_child(screw)
	return root


static func switch_wall(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WallSwitch"
	var plate: MeshInstance3D = ShapeKit.box(Vector3(0.055, 0.075, 0.008), f.ML.plastic_white_gloss(), "Plate")
	root.add_child(plate)
	var rocker: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.04, 0.01), f.ML.plastic_faded(), "Rocker")
	rocker.position = Vector3(0.0, 0.0, 0.008)
	root.add_child(rocker)
	for i: int in range(2):
		var scr: MeshInstance3D = ShapeKit.cyl(0.003, 0.004, f.ML.brass(), 6, Vector3i(0, 0, 1), "Screw")
		scr.position = Vector3(0.0, 0.028 * (1.0 if i == 0 else -1.0), 0.008)
		root.add_child(scr)
	root.set_meta("rocker_path", "Rocker")
	return root


static func meter_box(f: PropFactory, _o: Dictionary) -> Node3D:
	## The external electricity meter on the wall, with the seal wire.
	var root := Node3D.new()
	root.name = "MeterBox"
	var box_b: MeshInstance3D = ShapeKit.box(Vector3(0.28, 0.36, 0.12), f.ML.plastic_faded(), "Box")
	box_b.position = Vector3(0.0, 0.18, 0.06)
	root.add_child(box_b)
	var window: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.1, 0.006), f.ML.glass_smoky(), "Window")
	window.position = Vector3(0.0, 0.24, 0.124)
	root.add_child(window)
	var dials: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.06, 0.002), f.ML.meter_face(), "Register")
	dials.position = Vector3(0.0, 0.24, 0.12)
	root.add_child(dials)
	var led: MeshInstance3D = ShapeKit.sphere(0.006, f.ML.indicator(Color("e2453c"), 0.0), 8, "PulseLed")
	led.position = Vector3(0.09, 0.16, 0.124)
	root.add_child(led)
	var seal: MeshInstance3D = ShapeKit.cyl(0.008, 0.02, f.ML.brass(), 8, Vector3i(0, 0, 1), "Seal")
	seal.position = Vector3(-0.1, 0.05, 0.12)
	root.add_child(seal)
	var seal_wire: MeshInstance3D = ShapeKit.hose(Vector3(-0.1, 0.05, 0.13), Vector3(0.1, 0.05, 0.13), 0.002, 0.02, f.ML.cable_material(Color("#8a8f94")), "SealWire")
	root.add_child(seal_wire)
	var conduit: MeshInstance3D = ShapeKit.cyl(0.02, 0.4, f.ML.plastic_faded(), 10, Vector3i(0, 1, 0), "Conduit")
	conduit.position = Vector3(0.08, -0.02, 0.06)
	root.add_child(conduit)
	root.set_meta("led_path", "PulseLed")
	return root


static func chair_office(f: PropFactory, _o: Dictionary) -> Node3D:
	## The one genuinely modern object in World A: a second-hand office chair at
	## the workstation. It is the visual hinge between the two worlds.
	var root := Node3D.new()
	root.name = "OfficeChair"
	var seat: MeshInstance3D = ShapeKit.box(Vector3(0.46, 0.07, 0.44), f.ML.chair_fabric(), "Seat")
	seat.position = Vector3(0.0, 0.46, 0.0)
	root.add_child(seat)
	var back: MeshInstance3D = ShapeKit.box(Vector3(0.44, 0.52, 0.06), f.ML.chair_fabric(), "Back")
	back.position = Vector3(0.0, 0.78, -0.2)
	back.rotation.x = 0.14
	root.add_child(back)
	var lumbar: MeshInstance3D = ShapeKit.box(Vector3(0.36, 0.1, 0.04), f.ML.plastic_black(), "Lumbar")
	lumbar.position = Vector3(0.0, 0.62, -0.19)
	root.add_child(lumbar)
	var column: MeshInstance3D = ShapeKit.cyl(0.035, 0.36, f.ML.chrome(), 12, Vector3i(0, 1, 0), "Column")
	column.position = Vector3(0.0, 0.24, 0.0)
	root.add_child(column)
	for i: int in range(5):
		var a: float = ShapeKit.TAU_K * float(i) / 5.0
		var leg: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.03, 0.3), f.ML.plastic_black(), "Spoke")
		leg.position = Vector3(cos(a) * 0.15, 0.06, sin(a) * 0.15)
		leg.rotation.y = -a
		root.add_child(leg)
		# castors roll on a horizontal axle, so the wheel torus is vertical
		var caster: MeshInstance3D = ShapeKit.cyl(0.03, 0.02, f.ML.rubber(), 10, Vector3i(0, 0, 1), "Caster")
		caster.position = Vector3(cos(a) * 0.3, 0.03, sin(a) * 0.3)
		root.add_child(caster)
	for i: int in range(2):
		var arm: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.03, 0.28), f.ML.plastic_black(), "Arm")
		arm.position = Vector3(0.25 * (1.0 if i == 0 else -1.0), 0.62, 0.0)
		root.add_child(arm)
	root.add_child(ShapeKit.col_cyl(0.32, 1.05))
	return root


static func tool_chest(f: PropFactory, o: Dictionary) -> Node3D:
	## The red steel toolbox on the bench: three drawers, the fold-out handle,
	## the latches, and the dented paint of a tool that is used daily.
	var w: float = float(o.get("width", 0.42))
	var h: float = w * 0.55
	var d: float = w * 0.5
	var root := Node3D.new()
	root.name = "ToolChest"
	var shell: MeshInstance3D = ShapeKit.box(Vector3(w, h, d), f.ML.paint_red(1.1), "Shell")
	shell.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(shell)
	for i: int in range(3):
		var dr: MeshInstance3D = ShapeKit.box(Vector3(w * 0.94, h * 0.26, 0.008), f.ML.paint_red(1.4), "Drawer%d" % i)
		dr.position = Vector3(0.0, h * 0.18 + float(i) * h * 0.28, d * 0.5 + 0.004)
		root.add_child(dr)
		var pull: MeshInstance3D = ShapeKit.box(Vector3(w * 0.4, 0.012, 0.014), f.ML.steel(), "Pull")
		pull.position = dr.position + Vector3(0.0, -h * 0.08, 0.008)
		root.add_child(pull)
		var tag: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.018, 0.002), f.ML.label_stock(), "Tag")
		tag.position = dr.position + Vector3(-w * 0.3, 0.0, 0.006)
		root.add_child(tag)
	# the carrying handle hinges on a horizontal pin
	var hinge: MeshInstance3D = ShapeKit.cyl(0.008, w * 0.5, f.ML.steel_dark(), 8, Vector3i(1, 0, 0), "HandleHinge")
	hinge.position = Vector3(0.0, h + 0.01, 0.0)
	root.add_child(hinge)
	var grip: MeshInstance3D = ShapeKit.box(Vector3(w * 0.46, 0.012, 0.05), f.ML.plastic_black(), "Handle")
	grip.position = Vector3(0.0, h + 0.09, 0.0)
	root.add_child(grip)
	for i: int in range(2):
		var latch: MeshInstance3D = ShapeKit.box(Vector3(0.035, 0.05, 0.012), f.ML.steel(), "Latch")
		latch.position = Vector3((w * 0.36) * (1.0 if i == 0 else -1.0), h * 0.98, d * 0.5 + 0.006)
		root.add_child(latch)
	var dent: MeshInstance3D = ShapeKit.sphere(0.03, f.ML.paint_red(1.1), 8, "Dent")
	dent.position = Vector3(w * 0.3, h * 0.4, d * 0.5)
	dent.scale = Vector3(1.0, 1.0, 0.3)
	root.add_child(dent)
	var sticker: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.04, 0.001), f.ML.label_stock(), "Sticker")
	sticker.position = Vector3(-w * 0.2, h * 0.7, d * 0.5 + 0.002)
	root.add_child(sticker)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	root.set_meta("handle_path", "Handle")
	root.set_meta("drawer_count", 3)
	return root


static func wall_banner(f: PropFactory, o: Dictionary) -> Node3D:
	## A printed banner mounted on the wall — a backboard, the print and two
	## batten rollers, the way a flex banner is actually hung. Two modes: with an
	## `image` file the print is that photograph (the project's one supplied
	## image), and with `spec` true the print is left as a blank stock for the
	## SignageBaker, which bakes a generated banner onto it exactly like the
	## signboard over the shutter.
	var w: float = float(o.get("width", 2.0))
	var aspect: float = float(o.get("aspect", 0.558))
	var h: float = w * aspect
	var root := Node3D.new()
	root.name = "WallBanner"
	# the backboard, so the print never reads as a decal floating on the wall
	var back: MeshInstance3D = ShapeKit.box(Vector3(w + 0.05, h + 0.05, 0.018), f.ML.plywood(), "Back")
	back.position = Vector3(0.0, h * 0.5, -0.014)
	root.add_child(back)
	# the print itself — ShapeKit.plane faces +Z, which is the wall's outward normal
	var print_mat: Material = f.ML.banner_print(String(o.get("image", "res://assets/textures/user/imran_banner.jpeg")))
	if bool(o.get("spec", false)):
		print_mat = f.ML.label_stock()
	var print_face: MeshInstance3D = ShapeKit.plane(Vector2(w, h), print_mat, "Print")
	print_face.position = Vector3(0.0, h * 0.5, -0.004)
	root.add_child(print_face)
	# batten rollers top and bottom, with end caps: how these are really hung
	for i: int in range(2):
		var batten: MeshInstance3D = ShapeKit.cyl(0.022, w + 0.10, f.ML.steel_dark(), 10, Vector3i(1, 0, 0), "Batten")
		batten.position = Vector3(0.0, h * float(i), -0.006)
		root.add_child(batten)
		for k: int in range(2):
			var cap: MeshInstance3D = ShapeKit.cyl(0.03, 0.02, f.ML.plastic_black(), 10, Vector3i(1, 0, 0), "Cap")
			cap.position = batten.position + Vector3((w * 0.5 + 0.05) * (1.0 if k == 0 else -1.0), 0.0, 0.0)
			root.add_child(cap)
	# two nails into the wall behind the top batten
	for i: int in range(2):
		var nail: MeshInstance3D = ShapeKit.cyl(0.006, 0.03, f.ML.steel(), 6, Vector3i(0, 0, 1), "Nail")
		nail.position = Vector3((w * 0.35) * (1.0 if i == 0 else -1.0), h + 0.01, -0.012)
		root.add_child(nail)
	return root


static func wall_plaque(f: PropFactory, o: Dictionary) -> Node3D:
	## A small framed wall plaque: teak battens around a plywood back, with a blank
	## print face the SignageBaker fills. The format used for the inventors' corner
	## (scientists' plaques and the inventions board) on the lab wall — engraving is
	## a SignCanvas bake, like every other sign in the room. Pass a `photo` path and
	## the print face carries that image instead: the author's photographs hang in
	## the same frames as everything else.
	var w: float = float(o.get("width", 0.30))
	var h: float = float(o.get("height", 0.38))
	var root := Node3D.new()
	root.name = "WallPlaque"
	var back: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.014), f.ML.plywood(), "Back")
	back.position = Vector3(0.0, h * 0.5, -0.012)
	root.add_child(back)
	var photo: String = String(o.get("photo", ""))
	var print_mat: Material = f.ML.label_stock() if photo == "" else f.ML.photo_print(photo)
	var print_face: MeshInstance3D = ShapeKit.plane(Vector2(w * 0.96, h * 0.96), print_mat, "Print")
	print_face.position = Vector3(0.0, h * 0.5, -0.002)
	root.add_child(print_face)
	for i: int in range(2):
		var bar_h: MeshInstance3D = ShapeKit.box(Vector3(w + 0.032, 0.022, 0.022), f.ML.teak(), "FrameH")
		bar_h.position = Vector3(0.0, 0.0 if i == 0 else h, -0.006)
		root.add_child(bar_h)
		var bar_v: MeshInstance3D = ShapeKit.box(Vector3(0.022, h + 0.026, 0.022), f.ML.teak(), "FrameV")
		bar_v.position = Vector3((w * 0.5 + 0.008) * (1.0 if i == 0 else -1.0), h * 0.5, -0.006)
		root.add_child(bar_v)
	return root


static func flag_pole(f: PropFactory, o: Dictionary) -> Node3D:
	## The national flag on a courtyard pole. The cloth is a subdivided plane the
	## flag shader waves; the pattern is baked by _signage() through the SignCanvas,
	## at the official construction: a bottle-green field, a red disc whose centre
	## sits 9/20 of the length from the hoist with a radius of 1/5 the length. The
	## pole, finial and base are physical; the flag itself casts no shadow (a moving
	## caster is not worth a shadow pass for a cloth this small).
	var h: float = float(o.get("height", 5.6))
	var flag_w: float = float(o.get("flag_width", 0.9))
	var flag_h: float = flag_w * 0.667
	var root := Node3D.new()
	root.name = "FlagPole"
	var pole: MeshInstance3D = ShapeKit.cyl(0.045, h, f.ML.steel(), 12, Vector3i(0, 1, 0), "Pole")
	pole.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(pole)
	var finial: MeshInstance3D = ShapeKit.sphere(0.075, f.ML.brass(), 12, "Finial")
	finial.position = Vector3(0.0, h + 0.05, 0.0)
	root.add_child(finial)
	var base: MeshInstance3D = ShapeKit.cyl(0.16, 0.18, f.ML.surface("concrete_block"), 12, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.09, 0.0)
	root.add_child(base)
	var tie: MeshInstance3D = ShapeKit.torus(0.07, 0.008, f.ML.thread_material(), 12, 6, "Cleat")
	tie.position = Vector3(0.0, h * 0.42, 0.0)
	tie.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(tie)
	# the cloth: hoist edge at the pole, fly edge away from it (+X)
	var flag: MeshInstance3D = ShapeKit.plane(
		Vector2(flag_w, flag_h),
		f.ML.shader_material("res://shaders/flag.gdshader", {}),
		"Flag", 24)
	flag.position = Vector3(flag_w * 0.5 + 0.05, h - flag_h * 0.5 - 0.12, 0.0)
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flag)
	# the two ties that actually hold it to the pole
	for i: int in range(2):
		var loop: MeshInstance3D = ShapeKit.torus(0.055, 0.007, f.ML.thread_material(), 10, 5, "HoistTie")
		loop.position = Vector3(0.02, flag.position.y + flag_h * (0.42 if i == 0 else -0.42), 0.0)
		loop.rotation = Vector3(0.0, PI * 0.5, 0.0)
		loop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(loop)
	# the pole is solid: a landmark you can walk into and feel
	var body := StaticBody3D.new()
	body.name = "PoleBody"
	body.add_child(ShapeKit.col_cyl(0.07, h))
	root.add_child(body)
	return root


static func big_coin(f: PropFactory, o: Dictionary) -> Node3D:
	## A big display coin leaning on its plinth, the sort of thing a shop puts by
	## its gate. The body is a brass cylinder; both faces are blank discs that
	## _signage() bakes (front: বাংলাদেশ, a shapla and ৫ টাকা; back: the
	## denomination in three lines). It is a display piece, not currency, and the
	## inspection text says exactly that.
	var r: float = float(o.get("radius", 0.42))
	var root := Node3D.new()
	root.name = "BigCoin"
	# the plinth behind it, which the coin leans against
	var plinth: MeshInstance3D = ShapeKit.box(Vector3(r * 1.5, 0.30, 0.16), f.ML.surface("concrete_block"), "Plinth")
	plinth.position = Vector3(0.0, 0.15, -0.11)
	root.add_child(plinth)
	var coin := Node3D.new()
	coin.name = "Coin"
	coin.position = Vector3(0.0, 0.30 + r + 0.01, 0.0)
	# stand the disc up: the cylinder's axis goes from +Y (natural) to +Z, with a
	# nine-hundredth-of-a-radian lean back onto the plinth
	coin.rotation.x = PI * 0.5 - 0.09
	root.add_child(coin)
	var body: MeshInstance3D = ShapeKit.cyl(r, 0.055, f.ML.brass(), 48, Vector3i(0, 1, 0), "Body")
	coin.add_child(body)
	# the rim band circles the cylinder's circumference, which is TorusMesh's
	# native plane once the coin is stood up — no extra rotation
	var rim: MeshInstance3D = ShapeKit.torus(r - 0.012, 0.014, f.ML.brass(), 48, 8, "Rim")
	coin.add_child(rim)
	# the faces: ShapeKit.disc_flat lies in XZ; inside this group (rotated x=+90
	# degrees) a disc above the coin's centre ends up facing +Z, toward the street
	var front: MeshInstance3D = ShapeKit.disc_flat(r * 0.97, 0.006, f.ML.brass(), "Front")
	front.position = Vector3(0.0, 0.031, 0.0)
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin.add_child(front)
	var back: MeshInstance3D = ShapeKit.disc_flat(r * 0.97, 0.006, f.ML.brass(), "Back")
	back.position = Vector3(0.0, -0.031, 0.0)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin.add_child(back)
	# solid presence on the ground
	var body_col := StaticBody3D.new()
	body_col.name = "CoinBody"
	body_col.add_child(ShapeKit.col_box(Vector3(r * 2.0, 0.30 + r * 2.0, 0.4)))
	body_col.position = Vector3(0.0, (0.30 + r * 2.0) * 0.5, 0.0)
	root.add_child(body_col)
	return root


static func photo_wall(f: PropFactory, o: Dictionary) -> Node3D:
	## A wall of pinned photographs: a plywood sheet with a grid of small prints,
	## each slightly crooked, each its own material. The photographs arrive as an
	## array of paths and load through MaterialLibrary.photo_print() — no import
	## side files, like the street banner. Used for the entrance notice wall, the
	## author-curated Commons set listed in docs/ASSET_LICENSES.md.
	var photos: Array = o.get("photos", [])
	var cols: int = int(o.get("cols", 4))
	var cell := Vector2(0.24, 0.19)
	var pad: float = 0.06
	var rows: int = int(ceil(float(photos.size()) / float(cols)))
	var board_w: float = pad * 2.0 + cell.x * float(cols)
	var board_h: float = pad * 2.0 + cell.y * float(rows)
	var root := Node3D.new()
	root.name = "PhotoWall"
	var back: MeshInstance3D = ShapeKit.box(Vector3(board_w, board_h, 0.02), f.ML.plywood(), "Board")
	back.position = Vector3(0.0, board_h * 0.5, -0.014)
	root.add_child(back)
	for i: int in range(photos.size()):
		var col: int = i % cols
		var row: int = i / cols
		var px: float = -board_w * 0.5 + pad + cell.x * (float(col) + 0.5) + f.rand().randf_range(-0.006, 0.006)
		# the board's origin is its bottom edge, so rows count down from the top
		var py: float = board_h - pad - cell.y * (float(row) + 0.5) + f.rand().randf_range(-0.006, 0.006)
		var photo: MeshInstance3D = ShapeKit.plane(Vector2(0.20, 0.15), f.ML.photo_print(String(photos[i])), "Photo%d" % i)
		photo.position = Vector3(px, py, 0.0)
		photo.rotation.z = f.rand().randf_range(-0.055, 0.055)
		root.add_child(photo)
		var pin: MeshInstance3D = ShapeKit.sphere(0.007, f.ML.steel(), 8, "Pin")
		pin.position = Vector3(px, py + 0.066, 0.002)
		pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pin)
	return root


static func armor_figure(f: PropFactory, _o: Dictionary) -> Node3D:
	## The shop's other project, whole: a red-and-gold armoured figure at rest on a
	## service base, its core lens and eye slits lit. Built entirely from ShapeKit
	## primitives — an homage in the reference palette, deliberately not branded,
	## and the station text says as much. Red #a51f1b over gold #c9992f is the
	## classic pairing; the dark alloy shows between the plates.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var dark: StandardMaterial3D = f.ML.armor_dark()
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 3.0)
	var root := Node3D.new()
	root.name = "ArmorFigure"
	var base: MeshInstance3D = ShapeKit.cyl(0.3, 0.05, f.ML.steel_dark(), 24, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(base)
	var glow_ring: MeshInstance3D = ShapeKit.torus(0.27, 0.012, glow, 24, 6, "GlowRing")
	glow_ring.position = Vector3(0.0, 0.052, 0.0)
	glow_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow_ring)
	for side: int in [-1, 1]:
		var x: float = 0.11 * float(side)
		var thigh: MeshInstance3D = ShapeKit.box(Vector3(0.17, 0.36, 0.2), red, "Thigh")
		thigh.position = Vector3(x, 0.62, 0.0)
		root.add_child(thigh)
		var knee: MeshInstance3D = ShapeKit.cyl(0.075, 0.09, gold, 12, Vector3i(1, 0, 0), "Knee")
		knee.position = Vector3(x, 0.42, 0.0)
		root.add_child(knee)
		var shin: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.32, 0.17), red, "Shin")
		shin.position = Vector3(x, 0.25, 0.0)
		root.add_child(shin)
		var boot: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.11, 0.32), gold, "Boot")
		boot.position = Vector3(x, 0.105, 0.03)
		root.add_child(boot)
	var pelvis: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.15, 0.26), dark, "Pelvis")
	pelvis.position = Vector3(0.0, 0.84, 0.0)
	root.add_child(pelvis)
	var belt: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.06, 0.28), gold, "Belt")
	belt.position = Vector3(0.0, 0.93, 0.0)
	root.add_child(belt)
	var abdomen: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.16, 0.24), red, "Abdomen")
	abdomen.position = Vector3(0.0, 1.02, 0.0)
	root.add_child(abdomen)
	var chest: MeshInstance3D = ShapeKit.box(Vector3(0.46, 0.3, 0.28), red, "Chest")
	chest.position = Vector3(0.0, 1.26, 0.0)
	root.add_child(chest)
	var chest_upper: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.1, 0.26), gold, "ChestUpper")
	chest_upper.position = Vector3(0.0, 1.44, 0.0)
	root.add_child(chest_upper)
	var core_ring: MeshInstance3D = ShapeKit.torus(0.075, 0.014, gold, 20, 6, "CoreRing")
	core_ring.position = Vector3(0.0, 1.3, 0.15)
	core_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(core_ring)
	var core: MeshInstance3D = ShapeKit.cyl(0.06, 0.02, glow, 20, Vector3i(0, 0, 1), "Core")
	core.position = Vector3(0.0, 1.3, 0.145)
	root.add_child(core)
	for side2: int in [-1, 1]:
		var sx: float = 0.3 * float(side2)
		var shoulder: MeshInstance3D = ShapeKit.sphere(0.11, gold, 14, "Shoulder")
		shoulder.position = Vector3(sx, 1.42, 0.0)
		shoulder.scale = Vector3(1.0, 0.8, 1.0)
		root.add_child(shoulder)
		var upper: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.3, 0.15), red, "UpperArm")
		upper.position = Vector3(sx + 0.02 * float(side2), 1.2, 0.0)
		root.add_child(upper)
		var elbow: MeshInstance3D = ShapeKit.cyl(0.06, 0.08, gold, 12, Vector3i(1, 0, 0), "Elbow")
		elbow.position = Vector3(sx + 0.02 * float(side2), 1.02, 0.0)
		root.add_child(elbow)
		var forearm: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.28, 0.14), red, "Forearm")
		forearm.position = Vector3(sx + 0.03 * float(side2), 0.86, 0.0)
		root.add_child(forearm)
		var hand: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.12, 0.12), gold, "Hand")
		hand.position = Vector3(sx + 0.03 * float(side2), 0.68, 0.0)
		root.add_child(hand)
	var helmet: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.22, 0.26), red, "Helmet")
	helmet.position = Vector3(0.0, 1.66, 0.0)
	root.add_child(helmet)
	var faceplate: MeshInstance3D = ShapeKit.box(Vector3(0.2, 0.16, 0.06), gold, "Faceplate")
	faceplate.position = Vector3(0.0, 1.65, 0.12)
	root.add_child(faceplate)
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.18, 0.06, 0.1), gold, "Jaw")
	jaw.position = Vector3(0.0, 1.55, 0.08)
	root.add_child(jaw)
	for side3: int in [-1, 1]:
		var eye: MeshInstance3D = ShapeKit.box(Vector3(0.045, 0.018, 0.012), glow, "Eye")
		eye.position = Vector3(0.05 * float(side3), 1.68, 0.148)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(eye)
	return root


static func armor_helmet(f: PropFactory, _o: Dictionary) -> Node3D:
	## A spare helmet, off the figure: the same shell in miniature with its own lit
	## eyes, waiting on the bench.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 2.6)
	var root := Node3D.new()
	root.name = "ArmorHelmet"
	var skull: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.22, 0.26), red, "Skull")
	skull.position = Vector3(0.0, 0.11, 0.0)
	root.add_child(skull)
	var faceplate: MeshInstance3D = ShapeKit.box(Vector3(0.2, 0.16, 0.06), gold, "Faceplate")
	faceplate.position = Vector3(0.0, 0.1, 0.12)
	root.add_child(faceplate)
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.18, 0.06, 0.1), gold, "Jaw")
	jaw.position = Vector3(0.0, 0.0, 0.08)
	root.add_child(jaw)
	for side: int in [-1, 1]:
		var eye: MeshInstance3D = ShapeKit.box(Vector3(0.045, 0.018, 0.012), glow, "Eye")
		eye.position = Vector3(0.05 * float(side), 0.13, 0.148)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(eye)
	return root


static func armor_chest_plate(f: PropFactory, _o: Dictionary) -> Node3D:
	## A chest plate with its core lens, laid up: the figure's own spare.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 2.4)
	var root := Node3D.new()
	root.name = "ArmorChestPlate"
	var plate: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.3, 0.22), red, "Plate")
	plate.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(plate)
	var band: MeshInstance3D = ShapeKit.box(Vector3(0.36, 0.06, 0.24), gold, "Band")
	band.position = Vector3(0.0, 0.27, 0.0)
	root.add_child(band)
	var core_ring: MeshInstance3D = ShapeKit.torus(0.06, 0.012, gold, 18, 6, "CoreRing")
	core_ring.position = Vector3(0.0, 0.15, 0.12)
	core_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(core_ring)
	var core: MeshInstance3D = ShapeKit.cyl(0.05, 0.018, glow, 18, Vector3i(0, 0, 1), "Core")
	core.position = Vector3(0.0, 0.15, 0.115)
	root.add_child(core)
	return root


static func armor_gauntlet(f: PropFactory, _o: Dictionary) -> Node3D:
	## A forearm gauntlet: red shell, gold knuckle, a slit of glow at the wrist.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 2.0)
	var root := Node3D.new()
	root.name = "ArmorGauntlet"
	var shell: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.3, 0.16), red, "Shell")
	shell.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(shell)
	var knuckle: MeshInstance3D = ShapeKit.box(Vector3(0.15, 0.08, 0.17), gold, "Knuckle")
	knuckle.position = Vector3(0.0, 0.34, 0.0)
	root.add_child(knuckle)
	var slit: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.012, 0.012), glow, "Slit")
	slit.position = Vector3(0.0, 0.02, 0.082)
	slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slit)
	return root


static func armor_boot(f: PropFactory, _o: Dictionary) -> Node3D:
	## The spare boot: gold toe over red, a dark sole under.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var dark: StandardMaterial3D = f.ML.armor_dark()
	var root := Node3D.new()
	root.name = "ArmorBoot"
	var sole: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.03, 0.33), dark, "Sole")
	sole.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(sole)
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.18, 0.1, 0.3), red, "Body")
	body.position = Vector3(0.0, 0.08, 0.0)
	root.add_child(body)
	var toe: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.08, 0.08), gold, "Toe")
	toe.position = Vector3(0.0, 0.07, 0.14)
	root.add_child(toe)
	var cuff: MeshInstance3D = ShapeKit.box(Vector3(0.17, 0.1, 0.12), red, "Cuff")
	cuff.position = Vector3(0.0, 0.15, -0.08)
	root.add_child(cuff)
	return root


static func armor_base(f: PropFactory, _o: Dictionary) -> Node3D:
	## The service base the whole figure is built on: the dark disc and the gold
	## ring that doubles as the progress meter while the three assemblies go on.
	## The base stays when the figure is stripped, so it is its own prop.
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 3.0)
	var root := Node3D.new()
	root.name = "ArmorBase"
	var base: MeshInstance3D = ShapeKit.cyl(0.3, 0.05, f.ML.steel_dark(), 24, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(base)
	var glow_ring: MeshInstance3D = ShapeKit.torus(0.27, 0.012, glow, 24, 6, "GlowRing")
	glow_ring.position = Vector3(0.0, 0.052, 0.0)
	glow_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow_ring)
	return root


static func armor_ghost(f: PropFactory, _o: Dictionary) -> Node3D:
	## The build target made visible: a cyan hologram of the whole figure over the
	## service base, in its three pieces. Each ghost piece hides as the real
	## assembly seats, so the empty base reads "this is what you are building"
	## from across the room. Purely for the eye: excluded from carrying and from
	## the overlap audit.
	var ghost := StandardMaterial3D.new()
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.albedo_color = Color(0.32, 0.80, 1.0, 0.30)
	ghost.emission_enabled = true
	ghost.emission = Color(0.30, 0.78, 1.0)
	ghost.emission_energy_multiplier = 2.2
	var root := Node3D.new()
	root.name = "ArmorGhost"
	var groups: Array = [
		{"name": "GhostLegs", "node": armor_legs(f, {}), "y": 0.05},
		{"name": "GhostTorso", "node": armor_torso(f, {}), "y": 0.62},
		{"name": "GhostHead", "node": armor_head(f, {}), "y": 1.52},
	]
	for g: Dictionary in groups:
		var part: Node3D = g["node"]
		part.name = String(g["name"])
		part.position = Vector3(0.0, float(g["y"]), 0.0)
		root.add_child(part)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = ghost
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _armor_studs(parent: Node3D, mat: Material, spots: Array, axis: Vector3i, radius: float = 0.012, name: String = "Stud", depth: float = -1.0) -> void:
	## Fake-detail scatter: six-sided screw heads on a plate. The realism pass
	## covers the figure in these — bolts, hubs, nubs — because clean primitives
	## read as toys and hardware reads as a build. Shadow casting is off: they
	## are centimetres wide and add nothing to the shadow pass.
	for p: Vector3 in spots:
		var d: float = radius * 1.3 if depth <= 0.0 else depth
		var stud: MeshInstance3D = ShapeKit.cyl(radius, d, mat, 6, axis, name)
		stud.position = p
		stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(stud)


static func _armor_seam(parent: Node3D, mat: Material, spot: Vector3, size: Vector3, name: String = "Seam") -> void:
	## Fake-detail line: a thin dark box laid on a surface for a recessed panel
	## line, a vent slot or a strapped-down pack. Same shadow rule as the studs.
	var seam: MeshInstance3D = ShapeKit.box(size, mat, name)
	seam.position = spot
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(seam)


static func armor_legs(f: PropFactory, _o: Dictionary) -> Node3D:
	## The figure in three parts, one: the lower assembly — layered thigh and
	## shin plates over the red shells, hip plates, belt with buckle, knee caps,
	## vented shins, boot toe caps and heel blocks, plus the realism pass's
	## hardware: bolted outer plates, a knee hub, shin panel lines, boot and
	## heel vents, a groin guard. Geometry is the figure's own, rebased so the
	## soles sit at y = 0.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var red2: StandardMaterial3D = f.ML.armor_paint(Color("8f1c17"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var dark: StandardMaterial3D = f.ML.armor_dark()
	var root := Node3D.new()
	root.name = "ArmorLegs"
	for side: int in [-1, 1]:
		var x: float = 0.11 * float(side)
		var thigh: MeshInstance3D = ShapeKit.box(Vector3(0.17, 0.36, 0.2), red, "Thigh")
		thigh.position = Vector3(x, 0.57, 0.0)
		root.add_child(thigh)
		# the outer thigh plate over the shell, a shade darker than it
		var tplate: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.3, 0.22), red2, "ThighPlate")
		tplate.position = Vector3(x + 0.1 * float(side), 0.6, 0.0)
		root.add_child(tplate)
		var knee: MeshInstance3D = ShapeKit.cyl(0.075, 0.09, gold, 12, Vector3i(1, 0, 0), "Knee")
		knee.position = Vector3(x, 0.37, 0.0)
		root.add_child(knee)
		var kneecap: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.1, 0.05), gold, "KneeCap")
		kneecap.position = Vector3(x, 0.4, 0.1)
		root.add_child(kneecap)
		var shin: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.32, 0.17), red, "Shin")
		shin.position = Vector3(x, 0.20, 0.0)
		root.add_child(shin)
		for i: int in range(2):
			var vent: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.015, 0.02), dark, "ShinVent")
			vent.position = Vector3(x, 0.16 + 0.05 * float(i), 0.09)
			root.add_child(vent)
		var calf: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.2, 0.04), red2, "CalfPlate")
		calf.position = Vector3(x, 0.22, -0.1)
		root.add_child(calf)
		var ankle: MeshInstance3D = ShapeKit.cyl(0.062, 0.03, dark, 12, Vector3i(0, 1, 0), "AnkleRing")
		ankle.position = Vector3(x, 0.115, 0.0)
		root.add_child(ankle)
		var boot: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.11, 0.32), gold, "Boot")
		boot.position = Vector3(x, 0.055, 0.03)
		root.add_child(boot)
		var toe: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.07, 0.06), gold, "ToeCap")
		toe.position = Vector3(x, 0.05, 0.19)
		root.add_child(toe)
		var heel: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.08, 0.05), dark, "Heel")
		heel.position = Vector3(x, 0.04, -0.13)
		root.add_child(heel)
		# realism pass: the outer plate is bolted, the knee pad gets a hub, the
		# shin wears panel lines, the boot a side vent and the heel a grille
		_armor_studs(root, dark, [
			Vector3(x + 0.125 * float(side), 0.49, 0.0),
			Vector3(x + 0.125 * float(side), 0.60, 0.0),
			Vector3(x + 0.125 * float(side), 0.71, 0.0),
			Vector3(x + 0.125 * float(side), 0.60, 0.06),
			Vector3(x + 0.125 * float(side), 0.60, -0.06),
		], Vector3i(1, 0, 0), 0.013, "ThighBolt")
		_armor_studs(root, dark, [Vector3(x, 0.40, 0.127)], Vector3i(0, 0, 1), 0.014, "KneeHub")
		_armor_seam(root, dark, Vector3(x, 0.20, 0.092), Vector3(0.01, 0.26, 0.012), "ShinLine")
		_armor_seam(root, dark, Vector3(x - 0.048, 0.20, 0.090), Vector3(0.008, 0.24, 0.010), "ShinLine")
		_armor_seam(root, dark, Vector3(x + 0.048, 0.20, 0.090), Vector3(0.008, 0.24, 0.010), "ShinLine")
		_armor_seam(root, dark, Vector3(x + 0.098 * float(side), 0.06, 0.05), Vector3(0.012, 0.035, 0.08), "BootVent")
		_armor_seam(root, dark, Vector3(x, 0.045, -0.158), Vector3(0.09, 0.028, 0.012), "HeelVent")
	var pelvis: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.15, 0.26), dark, "Pelvis")
	pelvis.position = Vector3(0.0, 0.79, 0.0)
	root.add_child(pelvis)
	for side2: int in [-1, 1]:
		var hip: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.14, 0.2), red2, "HipPlate")
		hip.position = Vector3(0.22 * float(side2), 0.79, 0.0)
		root.add_child(hip)
		_armor_studs(root, dark, [
			Vector3(0.253 * float(side2), 0.79, 0.05),
			Vector3(0.253 * float(side2), 0.79, -0.05),
		], Vector3i(1, 0, 0), 0.012, "HipBolt")
	var belt: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.06, 0.28), gold, "Belt")
	belt.position = Vector3(0.0, 0.88, 0.0)
	root.add_child(belt)
	var buckle: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.05, 0.03), gold, "Buckle")
	buckle.position = Vector3(0.0, 0.88, 0.15)
	root.add_child(buckle)
	_armor_studs(root, dark, [
		Vector3(-0.1, 0.88, 0.147),
		Vector3(0.1, 0.88, 0.147),
	], Vector3i(0, 0, 1), 0.013, "BeltBolt")
	_armor_seam(root, dark, Vector3(0.0, 0.77, 0.135), Vector3(0.12, 0.09, 0.02), "GroinGuard")
	return root


static func armor_torso(f: PropFactory, _o: Dictionary) -> Node3D:
	## The figure in three parts, two: the upper assembly — waist with ab bands,
	## a layered chest with pec plates around the core, back plate and spine
	## ridges, pauldron caps over the shoulder spheres, arm plates, vents and
	## wrist bands, plus the realism pass's hardware: a studded bezel around the
	## core, chest vents, a shoulder hub per side, bolted pauldrons, a forearm
	## ridge, finger seams, shoulder-blade vents and a strapped power pack.
	## Rebased so the hands sit at y = 0.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var red2: StandardMaterial3D = f.ML.armor_paint(Color("8f1c17"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var gold2: StandardMaterial3D = f.ML.armor_paint(Color("b0882c"))
	var dark: StandardMaterial3D = f.ML.armor_dark()
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 3.0)
	var root := Node3D.new()
	root.name = "ArmorTorso"
	var abdomen: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.16, 0.24), red, "Abdomen")
	abdomen.position = Vector3(0.0, 0.40, 0.0)
	root.add_child(abdomen)
	for i: int in range(2):
		var band: MeshInstance3D = ShapeKit.box(Vector3(0.28, 0.02, 0.02), dark, "AbBand")
		band.position = Vector3(0.0, 0.36 + 0.08 * float(i), 0.125)
		root.add_child(band)
	var chest: MeshInstance3D = ShapeKit.box(Vector3(0.46, 0.3, 0.28), red, "Chest")
	chest.position = Vector3(0.0, 0.64, 0.0)
	root.add_child(chest)
	for side: int in [-1, 1]:
		var pec: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.16, 0.05), red2, "PecPlate")
		pec.position = Vector3(0.15 * float(side), 0.65, 0.155)
		root.add_child(pec)
	var back: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.36, 0.06), red2, "BackPlate")
	back.position = Vector3(0.0, 0.6, -0.15)
	root.add_child(back)
	for i2: int in range(3):
		var ridge: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.03, 0.03), dark, "SpineRidge")
		ridge.position = Vector3(0.0, 0.5 + 0.1 * float(i2), -0.185)
		root.add_child(ridge)
	for side_back: int in [-1, 1]:
		_armor_seam(root, dark, Vector3(0.13 * float(side_back), 0.68, -0.186), Vector3(0.10, 0.02, 0.012), "BladeVent")
	_armor_seam(root, dark, Vector3(0.0, 0.42, -0.145), Vector3(0.14, 0.09, 0.045), "PowerPack")
	_armor_seam(root, gold2, Vector3(0.0, 0.466, -0.146), Vector3(0.145, 0.016, 0.048), "PackTrim")
	_armor_studs(root, dark, [
		Vector3(-0.05, 0.42, -0.169),
		Vector3(0.05, 0.42, -0.169),
	], Vector3i(0, 0, 1), 0.012, "PackBolt")
	var chest_upper: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.1, 0.26), gold2, "ChestUpper")
	chest_upper.position = Vector3(0.0, 0.82, 0.0)
	root.add_child(chest_upper)
	var core_ring: MeshInstance3D = ShapeKit.torus(0.075, 0.014, gold, 20, 6, "CoreRing")
	core_ring.position = Vector3(0.0, 0.68, 0.15)
	core_ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(core_ring)
	var core: MeshInstance3D = ShapeKit.cyl(0.06, 0.02, glow, 20, Vector3i(0, 0, 1), "Core")
	core.position = Vector3(0.0, 0.68, 0.145)
	root.add_child(core)
	# the bezel: six studs ringing the core ring, chest vents below the pecs and
	# a sternum line between them — the classic armour read, unbranded
	_armor_studs(root, gold, [
		Vector3(0.0, 0.77, 0.146),
		Vector3(0.058, 0.749, 0.146),
		Vector3(-0.058, 0.749, 0.146),
		Vector3(0.0, 0.59, 0.146),
		Vector3(0.058, 0.611, 0.146),
		Vector3(-0.058, 0.611, 0.146),
	], Vector3i(0, 0, 1), 0.011, "BezelStud")
	for side4: int in [-1, 1]:
		_armor_seam(root, dark, Vector3(0.125 * float(side4), 0.51, 0.144), Vector3(0.08, 0.016, 0.014), "ChestVent")
		_armor_seam(root, dark, Vector3(0.125 * float(side4), 0.555, 0.144), Vector3(0.08, 0.016, 0.014), "ChestVent")
	_armor_seam(root, dark, Vector3(0.0, 0.55, 0.145), Vector3(0.012, 0.10, 0.012), "SternumLine")
	for side2: int in [-1, 1]:
		var sx: float = 0.3 * float(side2)
		var shoulder: MeshInstance3D = ShapeKit.sphere(0.11, gold, 14, "Shoulder")
		shoulder.position = Vector3(sx, 0.80, 0.0)
		shoulder.scale = Vector3(1.0, 0.8, 1.0)
		root.add_child(shoulder)
		var cap: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.06, 0.2), gold2, "PauldronCap")
		cap.position = Vector3(0.33 * float(side2), 0.9, 0.0)
		root.add_child(cap)
		var upper: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.3, 0.15), red, "UpperArm")
		upper.position = Vector3(sx + 0.02 * float(side2), 0.58, 0.0)
		root.add_child(upper)
		var uplate: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.24, 0.16), red2, "ArmPlate")
		uplate.position = Vector3(sx + 0.095 * float(side2), 0.58, 0.0)
		root.add_child(uplate)
		var elbow: MeshInstance3D = ShapeKit.cyl(0.06, 0.08, gold2, 12, Vector3i(1, 0, 0), "Elbow")
		elbow.position = Vector3(sx + 0.02 * float(side2), 0.40, 0.0)
		root.add_child(elbow)
		var forearm: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.28, 0.14), red, "Forearm")
		forearm.position = Vector3(sx + 0.03 * float(side2), 0.24, 0.0)
		root.add_child(forearm)
		for i3: int in range(2):
			var vent: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.015, 0.02), dark, "ArmVent")
			vent.position = Vector3(sx + 0.03 * float(side2), 0.2 + 0.06 * float(i3), 0.075)
			root.add_child(vent)
		var wrist: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.03, 0.15), gold, "WristBand")
		wrist.position = Vector3(sx + 0.03 * float(side2), 0.13, 0.0)
		root.add_child(wrist)
		var hand: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.12, 0.12), gold, "Hand")
		hand.position = Vector3(sx + 0.03 * float(side2), 0.06, 0.0)
		root.add_child(hand)
		var knuckle: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.04, 0.03), red, "KnucklePlate")
		knuckle.position = Vector3(sx + 0.03 * float(side2), 0.1, 0.07)
		root.add_child(knuckle)
		# realism pass: a hub on the shoulder joint, bolted pauldron, armpit
		# vent, a forearm ridge with its bolts, seams across the hand
		_armor_studs(root, dark, [Vector3(0.412 * float(side2), 0.80, 0.0)], Vector3i(1, 0, 0), 0.022, "ShoulderHub")
		_armor_studs(root, dark, [
			Vector3(0.33 * float(side2) - 0.045, 0.932, 0.0),
			Vector3(0.33 * float(side2) + 0.045, 0.932, 0.0),
		], Vector3i(0, 1, 0), 0.012, "PauldronBolt")
		_armor_seam(root, dark, Vector3(0.232 * float(side2), 0.56, 0.0), Vector3(0.012, 0.07, 0.05), "ArmpitVent")
		_armor_seam(root, red2, Vector3(sx + 0.03 * float(side2), 0.24, 0.075), Vector3(0.08, 0.2, 0.02), "ForearmRidge")
		_armor_studs(root, dark, [
			Vector3(sx + 0.03 * float(side2), 0.18, 0.088),
			Vector3(sx + 0.03 * float(side2), 0.30, 0.088),
		], Vector3i(0, 0, 1), 0.011, "RidgeBolt")
		_armor_seam(root, dark, Vector3(sx + 0.03 * float(side2) - 0.025, 0.06, 0.062), Vector3(0.007, 0.07, 0.010), "FingerLine")
		_armor_seam(root, dark, Vector3(sx + 0.03 * float(side2) + 0.025, 0.06, 0.062), Vector3(0.007, 0.07, 0.010), "FingerLine")
	return root


static func armor_head(f: PropFactory, _o: Dictionary) -> Node3D:
	## The figure in three parts, three: the head assembly — the red helmet with
	## a brow and crown ridge, the faceted gold faceplate with a mouth slit and
	## cheek plates, side ear discs, a neck ring, the two lit eye slits, and the
	## realism pass's hardware: brow bolts, a crest fin, temple nubs, ear hubs,
	## cheek bolts, mouth guards and rear vents. Rebased so the jaw sits at
	## y = 0.
	var red: StandardMaterial3D = f.ML.armor_paint(Color("a51f1b"))
	var gold: StandardMaterial3D = f.ML.armor_paint(Color("c9992f"))
	var dark: StandardMaterial3D = f.ML.armor_dark()
	var glow: StandardMaterial3D = f.ML.led(Color("cfe8ff"), 3.0)
	var root := Node3D.new()
	root.name = "ArmorHead"
	var helmet: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.22, 0.26), red, "Helmet")
	helmet.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(helmet)
	var brow: MeshInstance3D = ShapeKit.box(Vector3(0.26, 0.045, 0.27), red, "Brow")
	brow.position = Vector3(0.0, 0.235, 0.005)
	root.add_child(brow)
	var crown: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.03, 0.2), red, "CrownRidge")
	crown.position = Vector3(0.0, 0.265, 0.0)
	root.add_child(crown)
	_armor_seam(root, gold, Vector3(0.0, 0.285, -0.03), Vector3(0.018, 0.045, 0.13), "CrestFin")
	var faceplate: MeshInstance3D = ShapeKit.box(Vector3(0.2, 0.16, 0.06), gold, "Faceplate")
	faceplate.position = Vector3(0.0, 0.13, 0.12)
	root.add_child(faceplate)
	var mouth: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.012, 0.02), dark, "MouthSlit")
	mouth.position = Vector3(0.0, 0.075, 0.15)
	root.add_child(mouth)
	_armor_studs(root, dark, [
		Vector3(-0.095, 0.235, 0.142),
		Vector3(0.095, 0.235, 0.142),
	], Vector3i(0, 0, 1), 0.009, "BrowBolt")
	for side: int in [-1, 1]:
		var cheek: MeshInstance3D = ShapeKit.box(Vector3(0.04, 0.1, 0.05), gold, "Cheek")
		cheek.position = Vector3(0.11 * float(side), 0.1, 0.12)
		root.add_child(cheek)
		var ear: MeshInstance3D = ShapeKit.cyl(0.038, 0.02, gold, 14, Vector3i(1, 0, 0), "EarDisc")
		ear.position = Vector3(0.125 * float(side), 0.14, 0.0)
		root.add_child(ear)
		# realism pass: a temple nub, a hub in the ear disc, a cheek bolt and a
		# mouth guard per side
		_armor_studs(root, dark, [Vector3(0.123 * float(side), 0.19, 0.03)], Vector3i(1, 0, 0), 0.011, "TempleNub", 0.035)
		_armor_studs(root, dark, [Vector3(0.137 * float(side), 0.14, 0.0)], Vector3i(1, 0, 0), 0.017, "EarHub")
		_armor_studs(root, dark, [Vector3(0.11 * float(side), 0.09, 0.147)], Vector3i(0, 0, 1), 0.008, "CheekBolt")
		_armor_seam(root, gold, Vector3(0.058 * float(side), 0.075, 0.148), Vector3(0.014, 0.045, 0.018), "MouthGuard")
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.18, 0.06, 0.1), gold, "Jaw")
	jaw.position = Vector3(0.0, 0.03, 0.08)
	root.add_child(jaw)
	var neck: MeshInstance3D = ShapeKit.cyl(0.07, 0.03, dark, 14, Vector3i(0, 1, 0), "NeckRing")
	neck.position = Vector3(0.0, 0.02, 0.02)
	root.add_child(neck)
	_armor_seam(root, dark, Vector3(0.0, 0.13, -0.137), Vector3(0.06, 0.016, 0.014), "RearVent")
	_armor_seam(root, dark, Vector3(0.0, 0.175, -0.137), Vector3(0.06, 0.016, 0.014), "RearVent")
	for side2: int in [-1, 1]:
		var eye: MeshInstance3D = ShapeKit.box(Vector3(0.045, 0.018, 0.012), glow, "Eye")
		eye.position = Vector3(0.05 * float(side2), 0.16, 0.148)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(eye)
	return root


static func signboard(f: PropFactory, o: Dictionary) -> Node3D:
	## The garage signboard over the shutter. The text is baked from a SignCanvas
	## spec, so the Bangla headline and the English subtitle are shaped by the
	## engine, not hand-placed.
	var w: float = float(o.get("width", 2.6))
	var h: float = float(o.get("height", 0.7))
	var root := Node3D.new()
	root.name = "Signboard"
	var board: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.05), f.ML.signboard_back(), "Board")
	root.add_child(board)
	var face: MeshInstance3D = ShapeKit.plane(Vector2(w * 0.98, h * 0.94), f.ML.signboard_face(), "Face")
	face.position = Vector3(0.0, 0.0, 0.027)
	root.add_child(face)
	for i: int in range(2):
		var trim: MeshInstance3D = ShapeKit.box(Vector3(w * 1.02, 0.03, 0.06), f.ML.paint_yellow(), "Trim")
		trim.position = Vector3(0.0, h * 0.5 * (1.0 if i == 0 else -1.0), 0.0)
		root.add_child(trim)
	for i: int in range(2):
		var hanger: MeshInstance3D = ShapeKit.cyl(0.006, 0.5, f.ML.steel_dark(), 6, Vector3i(0, 1, 0), "Hanger")
		hanger.position = Vector3((w * 0.4) * (1.0 if i == 0 else -1.0), h * 0.5 + 0.25, 0.0)
		root.add_child(hanger)
	# the chasing LED frame: the colour-cycling strip the sign shops sell by the
	# metre, run around the board's edge. The shader self-animates
	# (shaders/sign_rgb.gdshader), so the prop stays a pure builder.
	var neon_mat: Material = f.ML.shader_material("res://shaders/sign_rgb.gdshader", {})
	for i: int in range(2):
		var bar_h: MeshInstance3D = ShapeKit.box(Vector3(w + 0.08, 0.032, 0.032), neon_mat, "NeonH")
		bar_h.position = Vector3(0.0, (h * 0.5 + 0.016) * (1.0 if i == 0 else -1.0), 0.045)
		bar_h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bar_h)
		var bar_v: MeshInstance3D = ShapeKit.box(Vector3(0.032, h + 0.08, 0.032), neon_mat, "NeonV")
		bar_v.position = Vector3((w * 0.5 + 0.016) * (1.0 if i == 0 else -1.0), 0.0, 0.045)
		bar_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bar_v)
	root.set_meta("face_path", "Face")
	return root
