class_name MechProps
extends RefCounted
## World A, mechanical register: the vehicle and metalwork vocabulary taken from
## the reference photographs of Bangladeshi repair shops — motorcycle engine
## blocks, silencers, sprockets, rickshaw wheels, tube frames, scrap, and the
## fans and lamps that light all of it.
##
## Everything here is dimensional: a 200 cc single-cylinder block is built at the
## scale it actually occupies, because the exosuit is assembled from these parts
## and the contrast only lands if the salvage looks like real salvage.
##
## Orientation note that took a rendered screenshot to expose: Godot's TorusMesh
## is generated in the XZ plane. A torus encircling a VERTICAL cylinder therefore
## needs no rotation at all, and the PI/2-about-X used throughout the first draft
## (copied from the wheel case, where an XY-plane torus is correct) turned every
## collar, band, race and tie in the garage into a vertical hoop. Wheels and
## anything encircling a HORIZONTAL axis keep the rotation; everything else drops
## it. The same reasoning is why ShapeKit.disc() (edge-on) and ShapeKit.disc_flat()
## (lying down) are separate functions.


static func register(f: PropFactory) -> void:
	f.generators["engine_block"] = engine_block
	f.generators["cylinder_head"] = cylinder_head
	f.generators["piston"] = piston
	f.generators["camshaft"] = camshaft
	f.generators["crankshaft"] = crankshaft
	f.generators["carburettor"] = carburettor
	f.generators["silencer"] = silencer
	f.generators["spark_plug"] = spark_plug
	f.generators["chain_sprocket"] = chain_sprocket
	f.generators["bicycle_chain"] = bicycle_chain
	f.generators["gear_set"] = gear_set
	f.generators["bearing"] = bearing
	f.generators["brake_drum"] = brake_drum
	f.generators["headlamp_bowl"] = headlamp_bowl
	f.generators["tail_lamp"] = tail_lamp
	f.generators["suspension_fork"] = suspension_fork
	f.generators["wheel_rickshaw"] = wheel_rickshaw
	f.generators["wheel_motorcycle"] = wheel_motorcycle
	f.generators["tyre"] = tyre
	f.generators["motorcycle_frame"] = motorcycle_frame
	f.generators["rickshaw_frame"] = rickshaw_frame
	f.generators["bicycle"] = bicycle
	f.generators["electric_motor"] = electric_motor
	f.generators["transformer_block"] = transformer_block
	f.generators["scrap_plate"] = scrap_plate
	f.generators["bent_rod"] = bent_rod
	f.generators["offcut_tin"] = offcut_tin
	f.generators["rusty_can"] = rusty_can
	f.generators["old_lock"] = old_lock
	f.generators["spring_coil"] = spring_coil
	f.generators["cable_reel"] = cable_reel
	f.generators["angle_bracket"] = angle_bracket
	f.generators["broken_fan_guard"] = broken_fan_guard
	f.generators["steel_drum"] = steel_drum
	f.generators["pallet"] = pallet
	f.generators["hay_bale"] = hay_bale
	f.generators["tubewell_bucket"] = tubewell_bucket
	f.generators["tea_stall_box"] = tea_stall_box
	f.generators["bamboo_pole"] = bamboo_pole
	f.generators["ceiling_fan"] = ceiling_fan
	f.generators["pedestal_fan"] = pedestal_fan
	f.generators["table_fan"] = table_fan
	f.generators["workbench_lamp"] = workbench_lamp
	f.generators["fluorescent_battlement"] = fluorescent_battlement
	f.generators["bulb_hanging"] = bulb_hanging
	f.generators["desk_lamp"] = desk_lamp
	f.generators["rolling_shutter"] = rolling_shutter
	f.generators["exterior_facade"] = exterior_facade
	f.generators["weld_spatter"] = weld_spatter
	f.generators["cutting_torch"] = cutting_torch
	f.generators["hand_drill"] = hand_drill
	f.generators["impact_driver"] = impact_driver


# ===========================================================================
# Engine and drivetrain
# ===========================================================================

static func engine_block(f: PropFactory, o: Dictionary) -> Node3D:
	## Air-cooled single cylinder, the shape of a 100-200 cc bike engine that is
	## everywhere in the country: crankcase halves, cooling fins, rocker box,
	## kick-starter boss, and the oil-stained patina of a pulled unit.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "EngineBlock"
	var case_mat: StandardMaterial3D = f.ML.cast_iron()
	var fin_mat: StandardMaterial3D = f.ML.aluminium()
	var half_a: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.18, 0.09), case_mat, "CrankcaseA")
	half_a.position = Vector3(0.0, 0.09, -0.055)
	root.add_child(half_a)
	var half_b: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.18, 0.09), case_mat, "CrankcaseB")
	half_b.position = Vector3(0.0, 0.09, 0.055)
	root.add_child(half_b)
	var seam: MeshInstance3D = ShapeKit.box(Vector3(0.245, 0.008, 0.2), f.ML.rust(), "CaseSeam")
	seam.position = Vector3(0.0, 0.09, 0.0)
	root.add_child(seam)
	# cylinder barrel with cooling fins
	var barrel: MeshInstance3D = ShapeKit.cyl(0.055, 0.14, fin_mat, 16, Vector3i(0, 1, 0), "Barrel")
	barrel.position = Vector3(0.02, 0.25, 0.0)
	root.add_child(barrel)
	for i: int in range(9):
		var fin: MeshInstance3D = ShapeKit.cyl(0.078, 0.006, fin_mat, 16, Vector3i(0, 1, 0), "Fin")
		fin.position = Vector3(0.02, 0.19 + float(i) * 0.014, 0.0)
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fin)
	var head: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.05, 0.12), fin_mat, "Head")
	head.position = Vector3(0.02, 0.345, 0.0)
	root.add_child(head)
	var rocker: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.07, 0.1), f.ML.paint_black_or_dark(), "RockerBox")
	rocker.position = Vector3(0.02, 0.41, 0.0)
	root.add_child(rocker)
	ShapeKit.bolt_ring(4, 0.04, 0.006, f.ML.steel(), rocker)
	var clutch: MeshInstance3D = ShapeKit.cyl(0.075, 0.03, case_mat, 16, Vector3i(0, 0, 1), "ClutchCover")
	clutch.position = Vector3(-0.02, 0.09, 0.11)
	root.add_child(clutch)
	var kick: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.12, 0.025), f.ML.steel_dark(), "KickBoss")
	kick.position = Vector3(0.06, 0.06, 0.12)
	kick.rotation.z = -0.4
	root.add_child(kick)
	var alt: MeshInstance3D = ShapeKit.cyl(0.045, 0.05, case_mat, 12, Vector3i(0, 0, 1), "Alternator")
	alt.position = Vector3(0.09, 0.12, -0.11)
	root.add_child(alt)
	var port: MeshInstance3D = ShapeKit.cyl(0.028, 0.06, f.ML.steel_dark(), 12, Vector3i(0, 0, 1), "ExhaustPort")
	port.position = Vector3(-0.09, 0.28, 0.0)
	port.rotation.y = PI * 0.5
	root.add_child(port)
	var intake: MeshInstance3D = ShapeKit.cyl(0.026, 0.05, f.ML.aluminium(), 12, Vector3i(0, 0, 1), "IntakeStub")
	intake.position = Vector3(0.09, 0.3, 0.0)
	intake.rotation.y = PI * 0.5
	root.add_child(intake)
	# the oil stain on the floor beneath, lying flat
	var stain: MeshInstance3D = ShapeKit.disc_flat(0.16, 0.002, f.ML.oil_stain(), "OilStain")
	stain.position = Vector3(0.0, 0.002, 0.0)
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stain)
	root.scale = Vector3.ONE * s
	root.add_child(ShapeKit.col_box(Vector3(0.28 * s, 0.46 * s, 0.26 * s)))
	return root


static func cylinder_head(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "CylinderHead"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.06, 0.11), f.ML.aluminium(), "Body")
	root.add_child(body)
	for i: int in range(6):
		var fin: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.005, 0.12), f.ML.aluminium(), "Fin")
		fin.position = Vector3(0.0, 0.03 - float(i) * 0.012, 0.0)
		root.add_child(fin)
	var valve1: MeshInstance3D = ShapeKit.cyl(0.018, 0.05, f.ML.steel(), 10, Vector3i(0, 1, 0), "Valve")
	valve1.position = Vector3(-0.03, 0.0, 0.0)
	root.add_child(valve1)
	var valve2: MeshInstance3D = valve1.duplicate() as MeshInstance3D
	valve2.position = Vector3(0.03, 0.0, 0.0)
	root.add_child(valve2)
	var plugboss: MeshInstance3D = ShapeKit.cyl(0.012, 0.04, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "PlugBoss")
	plugboss.position = Vector3(0.0, 0.05, 0.03)
	root.add_child(plugboss)
	root.scale = Vector3.ONE * s
	return root


static func piston(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Piston"
	var crown: MeshInstance3D = ShapeKit.cyl(0.045, 0.05, f.ML.aluminium(), 16, Vector3i(0, 1, 0), "Crown")
	crown.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(crown)
	# compression rings: torus encircling the vertical piston body, so no rotation
	for i: int in range(3):
		var ring: MeshInstance3D = ShapeKit.torus(0.046, 0.003, f.ML.steel_dark(), 16, 5, "Ring")
		ring.position = Vector3(0.0, 0.075 - float(i) * 0.014, 0.0)
		root.add_child(ring)
	var skirt: MeshInstance3D = ShapeKit.cyl(0.042, 0.06, f.ML.aluminium(), 16, Vector3i(0, 1, 0), "Skirt")
	skirt.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(skirt)
	var pin: MeshInstance3D = ShapeKit.cyl(0.012, 0.1, f.ML.steel(), 10, Vector3i(0, 0, 1), "WristPin")
	pin.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(pin)
	var rod: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.14, 0.03), f.ML.steel(), "ConRod")
	rod.position = Vector3(0.0, -0.09, 0.0)
	root.add_child(rod)
	# the big end encircles a horizontal pin, so the XY-plane torus is correct here
	var big_end: MeshInstance3D = ShapeKit.torus(0.03, 0.012, f.ML.steel(), 14, 6, "BigEnd")
	big_end.position = Vector3(0.0, -0.16, 0.0)
	big_end.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(big_end)
	root.scale = Vector3.ONE * s
	return root


static func camshaft(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Camshaft"
	var shaft: MeshInstance3D = ShapeKit.cyl(0.01, 0.3, f.ML.steel_hardened(), 10, Vector3i(1, 0, 0), "Shaft")
	root.add_child(shaft)
	for i: int in range(4):
		var lobe: MeshInstance3D = ShapeKit.sphere(0.028, f.ML.steel_hardened(), 10, "Lobe")
		lobe.position = Vector3(-0.1 + float(i) * 0.066, 0.0, 0.0)
		lobe.scale = Vector3(1.0, 1.55, 0.8)
		lobe.rotation.z = float(i) * 0.9
		root.add_child(lobe)
	var drive: MeshInstance3D = ShapeKit.gear(18, 3.2, 0.012, 0.012, f.ML.steel_dark(), "DriveGear")
	drive.position = Vector3(0.16, 0.0, 0.0)
	drive.rotation.z = PI * 0.5
	root.add_child(drive)
	root.scale = Vector3.ONE * s
	return root


static func crankshaft(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Crankshaft"
	var main: MeshInstance3D = ShapeKit.cyl(0.016, 0.28, f.ML.steel_hardened(), 12, Vector3i(1, 0, 0), "MainJournal")
	root.add_child(main)
	var throw_a: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.06, 0.03), f.ML.steel_hardened(), "Web")
	throw_a.position = Vector3(-0.03, 0.03, 0.0)
	root.add_child(throw_a)
	var throw_b: MeshInstance3D = throw_a.duplicate() as MeshInstance3D
	throw_b.position = Vector3(0.03, 0.03, 0.0)
	root.add_child(throw_b)
	var pin: MeshInstance3D = ShapeKit.cyl(0.02, 0.06, f.ML.chrome(), 12, Vector3i(1, 0, 0), "CrankPin")
	pin.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(pin)
	var counter: MeshInstance3D = ShapeKit.cyl(0.055, 0.028, f.ML.cast_iron(), 14, Vector3i(1, 0, 0), "Counterweight")
	counter.position = Vector3(0.0, -0.035, 0.0)
	root.add_child(counter)
	var fly: MeshInstance3D = ShapeKit.cyl(0.09, 0.03, f.ML.cast_iron(), 20, Vector3i(1, 0, 0), "Flywheel")
	fly.position = Vector3(0.15, 0.0, 0.0)
	root.add_child(fly)
	root.scale = Vector3.ONE * s
	return root


static func carburettor(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Carburettor"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.05, 0.07), f.ML.zinc_diecast(), "Body")
	root.add_child(body)
	var throat: MeshInstance3D = ShapeKit.cyl(0.024, 0.05, f.ML.aluminium(), 12, Vector3i(0, 0, 1), "Throat")
	throat.position = Vector3(0.0, 0.0, 0.05)
	root.add_child(throat)
	var float_bowl: MeshInstance3D = ShapeKit.cyl(0.028, 0.035, f.ML.zinc_diecast(), 12, Vector3i(0, 1, 0), "FloatBowl")
	float_bowl.position = Vector3(0.0, -0.04, 0.0)
	root.add_child(float_bowl)
	var screw: MeshInstance3D = ShapeKit.cyl(0.008, 0.03, f.ML.brass(), 8, Vector3i(1, 0, 0), "IdleScrew")
	screw.position = Vector3(0.045, -0.01, 0.0)
	root.add_child(screw)
	var cable: MeshInstance3D = ShapeKit.hose(Vector3(-0.03, 0.03, 0.0), Vector3(-0.12, 0.09, 0.05), 0.004, 0.03, f.ML.rubber(), "ThrottleCable")
	root.add_child(cable)
	root.scale = Vector3.ONE * s
	return root


static func silencer(f: PropFactory, o: Dictionary) -> Node3D:
	## The motorcycle exhaust can, one of the most recognisable objects in a
	## Bangladeshi roadside workshop.
	var s: float = float(o.get("scale", 1.0))
	var len: float = float(o.get("length", 0.42))
	var root := Node3D.new()
	root.name = "Silencer"
	var can: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.045, 0.005), Vector2(0.05, 0.04), Vector2(0.05, len * 0.8),
		Vector2(0.042, len * 0.92), Vector2(0.03, len), Vector2(0.0, len + 0.005),
	]), 16, f.ML.rust(), true, "Can")
	can.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(can)
	var shield: MeshInstance3D = ShapeKit.cyl(0.056, len * 0.55, f.ML.steel_heatblued(), 16, Vector3i(1, 0, 0), "HeatShield")
	shield.position = Vector3(len * 0.2, 0.0, 0.0)
	root.add_child(shield)
	var inlet: MeshInstance3D = ShapeKit.cyl(0.022, 0.12, f.ML.steel_dark(), 12, Vector3i(1, 0, 0), "Inlet")
	inlet.position = Vector3(-0.08, 0.01, 0.0)
	root.add_child(inlet)
	var mount: MeshInstance3D = ShapeKit.cyl(0.008, 0.06, f.ML.rubber(), 8, Vector3i(0, 1, 0), "Mount")
	mount.position = Vector3(len * 0.45, 0.05, 0.0)
	root.add_child(mount)
	# the clamp encircles the horizontal can, so an XY-plane torus is right
	var clamp1: MeshInstance3D = ShapeKit.torus(0.026, 0.005, f.ML.steel(), 12, 5, "Clamp")
	clamp1.position = Vector3(-0.04, 0.01, 0.0)
	clamp1.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(clamp1)
	var outlet: MeshInstance3D = ShapeKit.cyl(0.03, 0.02, f.ML.steel_dark(), 12, Vector3i(1, 0, 0), "Outlet")
	outlet.position = Vector3(len + 0.01, 0.0, 0.0)
	root.add_child(outlet)
	root.scale = Vector3.ONE * s
	return root


static func spark_plug(f: PropFactory, o: Dictionary) -> Node3D:
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "SparkPlug"
	var ceramic: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.011, 0.0), Vector2(0.013, 0.01), Vector2(0.009, 0.018),
		Vector2(0.012, 0.026), Vector2(0.009, 0.034), Vector2(0.011, 0.042), Vector2(0.006, 0.05),
		Vector2(0.0, 0.052),
	]), 12, f.ML.ceramic_white(), true, "Ceramic")
	root.add_child(ceramic)
	var hex: MeshInstance3D = ShapeKit.cyl(0.011, 0.012, f.ML.steel(), 6, Vector3i(0, 1, 0), "Hex")
	hex.position = Vector3(0.0, 0.006, 0.0)
	root.add_child(hex)
	var thread: MeshInstance3D = ShapeKit.cyl(0.008, 0.022, f.ML.steel_dark(), 12, Vector3i(0, 1, 0), "Thread")
	thread.position = Vector3(0.0, -0.011, 0.0)
	root.add_child(thread)
	var electrode: MeshInstance3D = ShapeKit.box(Vector3(0.002, 0.008, 0.006), f.ML.nickel(), "Electrode")
	electrode.position = Vector3(0.0, -0.026, 0.0)
	root.add_child(electrode)
	var terminal: MeshInstance3D = ShapeKit.cyl(0.005, 0.014, f.ML.steel(), 8, Vector3i(0, 1, 0), "Terminal")
	terminal.position = Vector3(0.0, 0.058, 0.0)
	root.add_child(terminal)
	var lead: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.066, 0.0), Vector3(0.05, 0.13, 0.03), 0.006, 0.02, f.ML.cable_material(Color("#7a1f1a")), "Lead")
	root.add_child(lead)
	root.scale = Vector3.ONE * s
	return root


static func chain_sprocket(f: PropFactory, o: Dictionary) -> Node3D:
	var teeth: int = clampi(int(o.get("teeth", 26)), 10, 60)
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Sprocket"
	var disc_g: MeshInstance3D = ShapeKit.gear(teeth, 6.4, 0.028, 0.008, f.ML.steel_dark(), "Teeth")
	root.add_child(disc_g)
	var hub: MeshInstance3D = ShapeKit.cyl(0.035, 0.02, f.ML.steel(), 14, Vector3i(0, 1, 0), "Hub")
	root.add_child(hub)
	# lightening holes, exactly as a stamped rear sprocket has them
	for i: int in range(5):
		var a: float = ShapeKit.TAU_K * float(i) / 5.0
		var hole: MeshInstance3D = ShapeKit.cyl(0.014, 0.012, f.ML.rust(), 10, Vector3i(0, 1, 0), "Hole")
		hole.position = Vector3(cos(a) * 0.06, 0.0, sin(a) * 0.06)
		root.add_child(hole)
	root.scale = Vector3.ONE * s
	return root


static func bicycle_chain(f: PropFactory, o: Dictionary) -> Node3D:
	var links: int = clampi(int(o.get("links", 22)), 4, 80)
	var root := Node3D.new()
	root.name = "BicycleChain"
	var c: Node3D = ShapeKit.chain(0.0125, links, f.ML.steel_dark(), "Links")
	root.add_child(c)
	root.scale = Vector3.ONE * float(o.get("scale", 1.0))
	return root


static func gear_set(f: PropFactory, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "GearSet"
	var specs: Array = [[22, 5.0, 0.0, 0.0], [14, 5.0, 0.075, 0.02], [18, 4.2, -0.06, -0.05]]
	for i: int in range(specs.size()):
		var sp: Array = specs[i]
		var g: MeshInstance3D = ShapeKit.gear(int(sp[0]), float(sp[1]), 0.012, 0.014, f.ML.steel_hardened(), "Gear%d" % i)
		g.position = Vector3(float(sp[2]), 0.014 * float(i) + 0.014, float(sp[3]))
		g.rotation.y = float(i) * 0.4
		root.add_child(g)
	var shaft: MeshInstance3D = ShapeKit.cyl(0.01, 0.24, f.ML.steel(), 10, Vector3i(0, 1, 0), "Shaft")
	shaft.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(shaft)
	return root


static func bearing(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.035))
	var root := Node3D.new()
	root.name = "Bearing"
	# races lie flat: the bearing's axis is +Y, and TorusMesh is already XZ
	var race: MeshInstance3D = ShapeKit.torus(r, r * 0.16, f.ML.steel_hardened(), 20, 6, "OuterRace")
	root.add_child(race)
	var inner: MeshInstance3D = ShapeKit.torus(r * 0.62, r * 0.12, f.ML.steel_hardened(), 18, 6, "InnerRace")
	root.add_child(inner)
	var balls: int = 9
	for i: int in range(balls):
		var a: float = ShapeKit.TAU_K * float(i) / float(balls)
		var ball: MeshInstance3D = ShapeKit.sphere(r * 0.11, f.ML.chrome(), 8, "Ball")
		ball.position = Vector3(cos(a) * r * 0.8, 0.0, sin(a) * r * 0.8)
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ball)
	return root


static func brake_drum(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.09))
	var root := Node3D.new()
	root.name = "BrakeDrum"
	var shell: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(r * 0.55, 0.0), Vector2(r * 0.6, 0.005), Vector2(r * 0.62, 0.05),
		Vector2(r, 0.055), Vector2(r, 0.01), Vector2(r * 0.95, 0.0), Vector2(r * 0.55, 0.0),
	]), 20, f.ML.cast_iron(), false, "Shell")
	root.add_child(shell)
	var hub: MeshInstance3D = ShapeKit.cyl(r * 0.3, 0.04, f.ML.steel_dark(), 14, Vector3i(0, 1, 0), "Hub")
	hub.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(hub)
	ShapeKit.bolt_ring(4, r * 0.42, 0.008, f.ML.steel(), root)
	return root


static func headlamp_bowl(f: PropFactory, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "HeadlampBowl"
	var bowl: MeshInstance3D = ShapeKit.sphere(0.075, f.ML.chrome(), 16, "Bowl")
	bowl.scale = Vector3(1.0, 1.0, 0.55)
	root.add_child(bowl)
	# the fluted lens faces +Z, so the edge-on disc is the correct one here
	var lens: MeshInstance3D = ShapeKit.disc(0.072, 0.006, f.ML.glass_fluted(), "Lens")
	lens.position = Vector3(0.0, 0.0, 0.04)
	root.add_child(lens)
	var rim: MeshInstance3D = ShapeKit.torus(0.075, 0.007, f.ML.brass(), 20, 6, "Rim")
	rim.position = Vector3(0.0, 0.0, 0.04)
	rim.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(rim)
	var back: MeshInstance3D = ShapeKit.cyl(0.03, 0.04, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "Socket")
	back.position = Vector3(0.0, 0.0, -0.04)
	root.add_child(back)
	var stay: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.09, 0.01), f.ML.steel_dark(), "Stay")
	stay.position = Vector3(0.0, -0.07, -0.02)
	root.add_child(stay)
	return root


static func tail_lamp(f: PropFactory, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TailLamp"
	var housing: MeshInstance3D = ShapeKit.box(Vector3(0.08, 0.05, 0.035), f.ML.plastic_black(), "Housing")
	root.add_child(housing)
	var lens: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.04, 0.01), f.ML.lens_red(), "Lens")
	lens.position = Vector3(0.0, 0.0, 0.022)
	root.add_child(lens)
	var bulb: MeshInstance3D = ShapeKit.sphere(0.012, f.ML.bulb_material(Color("ffd0a0"), 1.0), 8, "Bulb")
	root.add_child(bulb)
	var stem: MeshInstance3D = ShapeKit.cyl(0.006, 0.05, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Stem")
	stem.position = Vector3(0.0, -0.045, 0.0)
	root.add_child(stem)
	return root


static func suspension_fork(f: PropFactory, o: Dictionary) -> Node3D:
	## Telescopic front fork, one leg — the part every motorcycle repair shop
	## handles weekly.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "SuspensionFork"
	var slider: MeshInstance3D = ShapeKit.cyl(0.026, 0.34, f.ML.chrome(), 14, Vector3i(0, 1, 0), "Slider")
	slider.position = Vector3(0.0, 0.17, 0.0)
	root.add_child(slider)
	var lower: MeshInstance3D = ShapeKit.cyl(0.032, 0.3, f.ML.steel_dark(), 14, Vector3i(0, 1, 0), "LowerLeg")
	lower.position = Vector3(0.0, -0.15, 0.0)
	root.add_child(lower)
	var cap: MeshInstance3D = ShapeKit.cyl(0.03, 0.03, f.ML.paint_black_or_dark(), 12, Vector3i(0, 1, 0), "Cap")
	cap.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(cap)
	var axle: MeshInstance3D = ShapeKit.cyl(0.014, 0.14, f.ML.steel(), 10, Vector3i(0, 0, 1), "Axle")
	axle.position = Vector3(0.0, -0.3, 0.0)
	root.add_child(axle)
	var brace: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.03, 0.16), f.ML.steel_dark(), "Brace")
	brace.position = Vector3(0.0, -0.24, 0.0)
	root.add_child(brace)
	# the dust seal encircles the vertical slider: flat, no rotation
	var dust: MeshInstance3D = ShapeKit.torus(0.028, 0.006, f.ML.rubber(), 14, 5, "DustSeal")
	root.add_child(dust)
	root.scale = Vector3.ONE * s
	return root


static func wheel_rickshaw(f: PropFactory, o: Dictionary) -> Node3D:
	## The wire-spoked rickshaw wheel: a rim, a hub with a bearing, and real radial
	## spokes. One of the most iconic components in the country.
	var r: float = float(o.get("radius", 0.36))
	var root := Node3D.new()
	root.name = "RickshawWheel"
	# built in the XY plane, then stood up: a wheel is a vertical disc
	var rim: MeshInstance3D = ShapeKit.torus(r, 0.022, f.ML.paint_green(), 32, 8, "Rim")
	root.add_child(rim)
	var tyre_w: MeshInstance3D = ShapeKit.torus(r + 0.02, 0.03, f.ML.rubber(), 32, 8, "Tyre")
	root.add_child(tyre_w)
	var hub: MeshInstance3D = ShapeKit.cyl(0.05, 0.11, f.ML.steel_dark(), 14, Vector3i(0, 0, 1), "Hub")
	root.add_child(hub)
	var flange: MeshInstance3D = ShapeKit.disc(0.07, 0.01, f.ML.steel(), "Flange")
	root.add_child(flange)
	var spokes: int = 24
	for i: int in range(spokes):
		var a: float = ShapeKit.TAU_K * float(i) / float(spokes)
		var from: Vector3 = Vector3(cos(a) * 0.055, sin(a) * 0.055, 0.03 if i % 2 == 0 else -0.03)
		var to: Vector3 = Vector3(cos(a + 0.16) * (r - 0.01), sin(a + 0.16) * (r - 0.01), 0.0)
		root.add_child(ShapeKit.frame_tube(from, to, 0.0035, f.ML.chrome(), "Spoke%d" % i))
	return root


static func wheel_motorcycle(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.3))
	var alloy: bool = bool(o.get("alloy", true))
	var root := Node3D.new()
	root.name = "MotorcycleWheel"
	# the wheel is assembled in the XZ plane around a +Y axle, then stood up by the
	# caller, which keeps the spoke maths in one consistent frame
	var tyre_w: MeshInstance3D = ShapeKit.torus(r, 0.055, f.ML.rubber(), 30, 10, "Tyre")
	root.add_child(tyre_w)
	var rim: MeshInstance3D = ShapeKit.torus(r - 0.045, 0.03, f.ML.aluminium() if alloy else f.ML.steel_dark(), 28, 8, "Rim")
	root.add_child(rim)
	var count: int = 5 if alloy else 32
	for i: int in range(count):
		var a: float = ShapeKit.TAU_K * float(i) / float(count)
		var a2: float = ShapeKit.TAU_K * (float(i) + 0.42) / float(count)
		if alloy:
			var spoke: MeshInstance3D = ShapeKit.box(Vector3(0.055, 0.02, r - 0.07), f.ML.aluminium(), "AlloySpoke")
			spoke.position = Vector3(cos(a + 0.2) * (r * 0.5), 0.0, sin(a + 0.2) * (r * 0.5))
			spoke.rotation.y = -(a + 0.2)
			spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(spoke)
		else:
			root.add_child(ShapeKit.frame_tube(
				Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04),
				Vector3(cos(a2) * (r - 0.06), 0.0, sin(a2) * (r - 0.06)),
				0.003, f.ML.chrome(), "Spoke"))
	var hub: MeshInstance3D = ShapeKit.cyl(0.05, 0.09, f.ML.steel_dark(), 14, Vector3i(0, 1, 0), "Hub")
	root.add_child(hub)
	if alloy:
		var disc_brake: MeshInstance3D = ShapeKit.disc_flat(r * 0.62, 0.008, f.ML.steel_brushed_disc(), "BrakeDisc")
		disc_brake.position = Vector3(0.0, 0.05, 0.0)
		root.add_child(disc_brake)
		var caliper: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.035, 0.09), f.ML.paint_red(), "Caliper")
		caliper.position = Vector3(r * 0.5, 0.055, 0.0)
		root.add_child(caliper)
	return root


static func tyre(f: PropFactory, o: Dictionary) -> Node3D:
	var r: float = float(o.get("radius", 0.28))
	var root := Node3D.new()
	root.name = "Tyre"
	var t: MeshInstance3D = ShapeKit.torus(r, 0.05, f.ML.rubber(), 26, 10, "TyreBody")
	root.add_child(t)
	var blocks: int = 30
	for i: int in range(blocks):
		var a: float = ShapeKit.TAU_K * float(i) / float(blocks)
		var b: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.012, 0.02), f.ML.rubber(), "Tread")
		b.position = Vector3(cos(a) * (r + 0.045), 0.0, sin(a) * (r + 0.045))
		b.rotation = Vector3(0.0, -a, 0.0)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b)
	return root


# ===========================================================================
# Frames and vehicles
# ===========================================================================

static func motorcycle_frame(f: PropFactory, o: Dictionary) -> Node3D:
	## Twin-downtube diamond frame, stripped. This is the donor for the exosuit's
	## structural frame module, so it is built to read as a spine.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "MotorcycleFrame"
	var mat: StandardMaterial3D = f.ML.paint_black_or_dark()
	var r: float = 0.022
	root.add_child(ShapeKit.frame_tube(Vector3(-0.32, 0.36, 0.06), Vector3(0.16, 0.14, 0.06), r, mat, "DownA"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.32, 0.36, -0.06), Vector3(0.16, 0.14, -0.06), r, mat, "DownB"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.32, 0.36, 0.0), Vector3(0.3, 0.44, 0.0), r, mat, "Top"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.16, 0.14, 0.06), Vector3(0.42, 0.5, 0.05), r, mat, "SeatA"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.16, 0.14, -0.06), Vector3(0.42, 0.5, -0.05), r, mat, "SeatB"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.3, 0.44, 0.05), Vector3(0.42, 0.5, 0.05), r, mat, "RigA"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.3, 0.44, -0.05), Vector3(0.42, 0.5, -0.05), r, mat, "RigB"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.16, 0.14, 0.06), Vector3(0.62, 0.16, 0.12), r * 0.8, mat, "ChainA"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.16, 0.14, -0.06), Vector3(0.62, 0.16, -0.12), r * 0.8, mat, "ChainB"))
	var headstock: MeshInstance3D = ShapeKit.cyl(0.035, 0.2, mat, 12, Vector3i(0, 1, 0), "Headstock")
	headstock.position = Vector3(-0.34, 0.42, 0.0)
	headstock.rotation.x = 0.35
	root.add_child(headstock)
	for i: int in range(2):
		var pl: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.09, 0.008), f.ML.steel_dark(), "EngineMount")
		pl.position = Vector3(-0.05 + float(i) * 0.1, 0.2, 0.07)
		root.add_child(pl)
	# weld beads at the joints
	var weld_x: Array[float] = [-0.32, 0.16, 0.3, 0.42, 0.62]
	var weld_y: Array[float] = [0.36, 0.14, 0.44, 0.5, 0.16]
	for i: int in range(5):
		var bead: MeshInstance3D = ShapeKit.sphere(0.028, f.ML.weld_bead(), 8, "Weld")
		bead.position = Vector3(weld_x[i], weld_y[i], 0.0)
		bead.scale = Vector3(1.0, 0.7, 1.0)
		root.add_child(bead)
	root.scale = Vector3.ONE * s
	root.add_child(ShapeKit.col_box(Vector3(1.0 * s, 0.55 * s, 0.3 * s)))
	return root


static func rickshaw_frame(f: PropFactory, o: Dictionary) -> Node3D:
	## A cycle-rickshaw chassis: two wheels, a passenger box with a bench seat, and
	## the tow bar. Instantly recognisable in Dhaka.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "RickshawFrame"
	var mat: StandardMaterial3D = f.ML.paint_green()
	var wl: float = 0.34
	for i: int in range(2):
		var w: Node3D = wheel_rickshaw(f, {"radius": wl})
		w.position = Vector3(0.0, wl, 0.62 * (1.0 if i == 0 else -1.0))
		root.add_child(w)
	root.add_child(ShapeKit.frame_tube(Vector3(-0.5, 0.34, 0.55), Vector3(0.55, 0.3, 0.55), 0.025, mat, "RailA"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.5, 0.34, -0.55), Vector3(0.55, 0.3, -0.55), 0.025, mat, "RailB"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.0, 0.33, 0.55), Vector3(0.0, 0.33, -0.55), 0.025, mat, "Cross"))
	var box_body: MeshInstance3D = ShapeKit.box(Vector3(0.9, 0.5, 1.2), f.ML.teak(), "BoxBody")
	box_body.position = Vector3(0.25, 0.62, 0.0)
	root.add_child(box_body)
	var seat: MeshInstance3D = ShapeKit.box(Vector3(0.8, 0.1, 1.1), f.ML.vinyl_cushion(), "SeatCushion")
	seat.position = Vector3(0.25, 0.9, 0.0)
	root.add_child(seat)
	var backrest: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.5, 1.1), f.ML.vinyl_cushion(), "BackRest")
	backrest.position = Vector3(0.66, 1.05, 0.0)
	root.add_child(backrest)
	root.add_child(ShapeKit.frame_tube(Vector3(-0.15, 0.85, 0.55), Vector3(-0.15, 1.5, 0.4), 0.016, f.ML.steel_dark(), "CanopyA"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.15, 0.85, -0.55), Vector3(-0.15, 1.5, -0.4), 0.016, f.ML.steel_dark(), "CanopyB"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.15, 1.5, 0.4), Vector3(-0.15, 1.5, -0.4), 0.016, f.ML.steel_dark(), "CanopyCross"))
	var canopy: MeshInstance3D = ShapeKit.box(Vector3(0.95, 0.02, 1.25), f.ML.tarpaulin(), "CanopySheet")
	canopy.position = Vector3(0.2, 1.52, 0.0)
	root.add_child(canopy)
	root.add_child(ShapeKit.frame_tube(Vector3(-0.5, 0.34, 0.0), Vector3(-1.5, 0.5, 0.0), 0.03, mat, "TowBar"))
	var deco: MeshInstance3D = ShapeKit.plane(Vector2(0.5, 0.35), f.ML.rickshaw_art(), "Deco")
	deco.position = Vector3(0.25, 0.62, 0.61)
	root.add_child(deco)
	root.scale = Vector3.ONE * s
	return root


static func bicycle(f: PropFactory, o: Dictionary) -> Node3D:
	## The old BAT-style bicycle that hangs in every workshop as a spare.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "Bicycle"
	var frame_mat: StandardMaterial3D = f.ML.paint_blue(1.6)
	var wr: float = 0.34
	var fw: Node3D = wheel_rickshaw(f, {"radius": wr})
	fw.position = Vector3(-0.55, wr, 0.0)
	root.add_child(fw)
	var rw: Node3D = wheel_rickshaw(f, {"radius": wr})
	rw.position = Vector3(0.55, wr, 0.0)
	root.add_child(rw)
	root.add_child(ShapeKit.frame_tube(Vector3(-0.55, wr, 0.0), Vector3(-0.1, 0.62, 0.0), 0.018, frame_mat, "ForkTube"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.1, 0.62, 0.0), Vector3(0.4, 0.66, 0.0), 0.018, frame_mat, "TopTube"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.1, 0.62, 0.0), Vector3(0.05, 0.28, 0.0), 0.018, frame_mat, "DownTube"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.05, 0.28, 0.0), Vector3(0.4, 0.66, 0.0), 0.016, frame_mat, "SeatTube"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.05, 0.28, 0.0), Vector3(0.55, wr, 0.0), 0.016, frame_mat, "ChainStay"))
	root.add_child(ShapeKit.frame_tube(Vector3(0.4, 0.66, 0.0), Vector3(0.55, wr, 0.0), 0.014, frame_mat, "SeatStay"))
	root.add_child(ShapeKit.frame_tube(Vector3(-0.55, wr, 0.0), Vector3(0.55, wr, 0.0), 0.012, frame_mat, "BottomRail"))
	var saddle: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.04, 0.14), f.ML.leather_like(), "Saddle")
	saddle.position = Vector3(0.42, 0.72, 0.0)
	root.add_child(saddle)
	var post: MeshInstance3D = ShapeKit.cyl(0.014, 0.16, f.ML.steel(), 8, Vector3i(0, 1, 0), "SeatPost")
	post.position = Vector3(0.4, 0.64, 0.0)
	root.add_child(post)
	var stem: MeshInstance3D = ShapeKit.cyl(0.014, 0.2, f.ML.steel(), 8, Vector3i(0, 1, 0), "Stem")
	stem.position = Vector3(-0.12, 0.68, 0.0)
	root.add_child(stem)
	var bars: MeshInstance3D = ShapeKit.cyl(0.014, 0.5, f.ML.steel_dark(), 10, Vector3i(0, 0, 1), "HandleBar")
	bars.position = Vector3(-0.14, 0.78, 0.0)
	root.add_child(bars)
	for i: int in range(2):
		var grip: MeshInstance3D = ShapeKit.cyl(0.018, 0.11, f.ML.rubber(), 10, Vector3i(0, 0, 1), "Grip")
		grip.position = Vector3(-0.14, 0.78, 0.24 * (1.0 if i == 0 else -1.0))
		root.add_child(grip)
	var chain_run: Node3D = ShapeKit.chain(0.011, 26, f.ML.steel_dark(), "Chain")
	chain_run.position = Vector3(0.3, 0.28, 0.05)
	root.add_child(chain_run)
	var crank: MeshInstance3D = ShapeKit.cyl(0.06, 0.012, f.ML.steel_dark(), 16, Vector3i(0, 0, 1), "Chainring")
	crank.position = Vector3(0.05, 0.28, 0.06)
	root.add_child(crank)
	var pedal: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.02, 0.09), f.ML.plastic_black(), "Pedal")
	pedal.position = Vector3(0.05, 0.36, 0.12)
	root.add_child(pedal)
	var carrier: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.02, 0.16), f.ML.steel_dark(), "Carrier")
	carrier.position = Vector3(0.62, 0.7, 0.0)
	root.add_child(carrier)
	# mudguards are vertical arcs over the wheels, so the XY-plane torus is right
	var guard_x: Array[float] = [-0.55, 0.55]
	for i: int in range(2):
		var guard: MeshInstance3D = ShapeKit.torus(wr + 0.04, 0.012, f.ML.steel_dark(), 20, 5, "Mudguard")
		guard.position = Vector3(guard_x[i], wr, 0.0)
		guard.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		guard.scale = Vector3(1.0, 1.0, 0.4)
		root.add_child(guard)
	root.scale = Vector3.ONE * s
	return root


static func electric_motor(f: PropFactory, o: Dictionary) -> Node3D:
	## A stripped induction/blower motor: finned can, end bells, shaft, terminal
	## box, and the copper winding visible where the casing is cut open.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "ElectricMotor"
	var can: MeshInstance3D = ShapeKit.cyl(0.09, 0.2, f.ML.paint_black_or_dark(), 18, Vector3i(1, 0, 0), "Casing")
	root.add_child(can)
	for i: int in range(8):
		var fin: MeshInstance3D = ShapeKit.box(Vector3(0.19, 0.008, 0.02), f.ML.cast_iron(), "CoolFin")
		var a: float = ShapeKit.TAU_K * float(i) / 8.0
		fin.position = Vector3(0.0, cos(a) * 0.095, sin(a) * 0.095)
		fin.rotation.x = a
		root.add_child(fin)
	var bell_a: MeshInstance3D = ShapeKit.cyl(0.092, 0.02, f.ML.cast_iron(), 18, Vector3i(1, 0, 0), "EndBellA")
	bell_a.position = Vector3(-0.11, 0.0, 0.0)
	root.add_child(bell_a)
	var bell_b: MeshInstance3D = bell_a.duplicate() as MeshInstance3D
	bell_b.position = Vector3(0.11, 0.0, 0.0)
	root.add_child(bell_b)
	var shaft: MeshInstance3D = ShapeKit.cyl(0.016, 0.32, f.ML.steel(), 10, Vector3i(1, 0, 0), "Shaft")
	root.add_child(shaft)
	var fan: MeshInstance3D = ShapeKit.cyl(0.07, 0.02, f.ML.plastic_black(), 12, Vector3i(1, 0, 0), "FanBlade")
	fan.position = Vector3(-0.14, 0.0, 0.0)
	root.add_child(fan)
	var term: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.04, 0.05), f.ML.plastic_faded(), "TerminalBox")
	term.position = Vector3(0.0, 0.11, 0.0)
	root.add_child(term)
	# cut-away window showing the stator winding
	var window: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.05, 0.005), f.ML.copper(), "Winding")
	window.position = Vector3(0.0, 0.06, 0.088)
	window.rotation.x = 0.3
	root.add_child(window)
	for i: int in range(6):
		var turn: MeshInstance3D = ShapeKit.torus(0.02, 0.004, f.ML.copper(), 12, 5, "Turn")
		turn.position = Vector3(-0.04 + float(i) * 0.016, 0.055, 0.08)
		turn.rotation = Vector3(1.2, 0.0, 0.0)
		turn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(turn)
	var feet: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.02, 0.22), f.ML.cast_iron(), "Foot")
	feet.position = Vector3(0.0, -0.1, 0.0)
	root.add_child(feet)
	root.scale = Vector3.ONE * s
	return root


static func transformer_block(f: PropFactory, o: Dictionary) -> Node3D:
	## The heavy laminated-core transformer pulled out of a dead UPS.
	var s: float = float(o.get("scale", 1.0))
	var root := Node3D.new()
	root.name = "TransformerBlock"
	var core_mat: StandardMaterial3D = f.ML.steel_laminated()
	var coil_mat: StandardMaterial3D = f.ML.copper()
	var limb_a: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.14, 0.05), core_mat, "LimbA")
	limb_a.position = Vector3(-0.05, 0.07, 0.0)
	root.add_child(limb_a)
	var limb_b: MeshInstance3D = limb_a.duplicate() as MeshInstance3D
	limb_b.position = Vector3(0.05, 0.07, 0.0)
	root.add_child(limb_b)
	var yoke_t: MeshInstance3D = ShapeKit.box(Vector3(0.13, 0.028, 0.05), core_mat, "YokeTop")
	yoke_t.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(yoke_t)
	var yoke_b: MeshInstance3D = yoke_t.duplicate() as MeshInstance3D
	yoke_b.position = Vector3(0.0, -0.01, 0.0)
	root.add_child(yoke_b)
	for i: int in range(2):
		var x: float = 0.05 if i == 0 else -0.05
		var wind: MeshInstance3D = ShapeKit.cyl(0.035, 0.09, coil_mat, 16, Vector3i(0, 1, 0), "Winding")
		wind.position = Vector3(x, 0.07, 0.0)
		root.add_child(wind)
		# insulation tape bands encircle the vertical winding: flat tori
		for k: int in range(5):
			var band: MeshInstance3D = ShapeKit.torus(0.036, 0.004, f.ML.insulation_tape(), 14, 5, "Band")
			band.position = Vector3(x, 0.035 + float(k) * 0.018, 0.0)
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(band)
	var former: MeshInstance3D = ShapeKit.cyl(0.02, 0.1, f.ML.plastic_black(), 12, Vector3i(0, 1, 0), "Former")
	former.position = Vector3(0.0, 0.07, 0.0)
	root.add_child(former)
	var mount: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.012, 0.07), f.ML.steel_dark(), "Mount")
	mount.position = Vector3(0.0, -0.03, 0.0)
	root.add_child(mount)
	root.scale = Vector3.ONE * s
	return root


# ===========================================================================
# Scrap and misc metalwork
# ===========================================================================

static func scrap_plate(f: PropFactory, o: Dictionary) -> Node3D:
	var w: float = _rf(f, 0.18, 0.42)
	var root := Node3D.new()
	root.name = "ScrapPlate"
	var p: Node3D = ShapeKit.plate(Vector3(w, 0.004, w * 0.7), _rf(f, 0.0, 0.05), f.ML.rust(), "Plate")
	p.rotation = Vector3(_rf(f, -0.15, 0.15), _rf(f, 0, 3.14), _rf(f, -0.15, 0.15))
	root.add_child(p)
	return root


static func bent_rod(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BentRod"
	var a: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.FORWARD
	for i: int in range(4):
		var seg: float = _rf(f, 0.08, 0.2)
		var b: Vector3 = a + dir * seg
		root.add_child(ShapeKit.frame_tube(a, b, _rf(f, 0.005, 0.011), f.ML.steel_dark(), "Seg%d" % i))
		a = b
		dir = dir.rotated(Vector3.UP if i % 2 == 0 else Vector3.RIGHT, _rf(f, -1.1, 1.1))
		dir = dir.normalized()
	return root


static func offcut_tin(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "OffcutTin"
	var w: float = _rf(f, 0.2, 0.5)
	var sheet: MeshInstance3D = ShapeKit.box(Vector3(w, 0.002, w * 0.5), f.ML.roof_tin(), "Sheet")
	sheet.rotation = Vector3(_rf(f, -0.4, 0.4), _rf(f, 0, 3.14), 0.0)
	root.add_child(sheet)
	return root


static func rusty_can(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RustyCan"
	var body: MeshInstance3D = ShapeKit.cyl(0.055, 0.13, f.ML.rust(), 14, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, 0.065, 0.0)
	root.add_child(body)
	var lid: MeshInstance3D = ShapeKit.cyl(0.058, 0.01, f.ML.rust(), 14, Vector3i(0, 1, 0), "Lid")
	lid.position = Vector3(0.0, 0.135, 0.0)
	root.add_child(lid)
	# the bail handle stands up out of the lid
	var handle: MeshInstance3D = ShapeKit.torus(0.05, 0.005, f.ML.steel_dark(), 14, 5, "Handle")
	handle.position = Vector3(0.0, 0.14, 0.0)
	handle.rotation = Vector3(0.0, PI * 0.5, 0.3)
	root.add_child(handle)
	return root


static func old_lock(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "OldLock"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.055, 0.018), f.ML.brass(), "Body")
	body.position = Vector3(0.0, 0.027, 0.0)
	root.add_child(body)
	# the shackle stands in a vertical plane
	var shackle: MeshInstance3D = ShapeKit.torus(0.024, 0.006, f.ML.steel(), 14, 5, "Shackle")
	shackle.position = Vector3(0.0, 0.06, 0.0)
	shackle.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(shackle)
	var keyhole: MeshInstance3D = ShapeKit.cyl(0.005, 0.02, f.ML.plastic_black(), 8, Vector3i(0, 0, 1), "Keyhole")
	keyhole.position = Vector3(0.0, 0.03, 0.01)
	root.add_child(keyhole)
	return root


static func spring_coil(f: PropFactory, o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SpringCoil"
	var c: MeshInstance3D = ShapeKit.coil(
		float(o.get("turns", 7.0)), float(o.get("radius", 0.03)), 0.005,
		float(o.get("height", 0.11)), f.ML.steel_spring(), 16, "Coil")
	root.add_child(c)
	return root


static func cable_reel(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CableReel"
	# the drum axis is +Z, so the flanges are edge-on discs and the wound turns
	# encircle a horizontal axis
	for i: int in range(2):
		var flange: MeshInstance3D = ShapeKit.disc(0.16, 0.015, f.ML.plywood(), "Flange")
		flange.position = Vector3(0.0, 0.0, 0.06 * (1.0 if i == 0 else -1.0))
		root.add_child(flange)
	var drum: MeshInstance3D = ShapeKit.cyl(0.06, 0.11, f.ML.plywood(), 16, Vector3i(0, 0, 1), "Drum")
	root.add_child(drum)
	for i: int in range(7):
		var turn: MeshInstance3D = ShapeKit.torus(0.09 + float(i) * 0.008, 0.008, f.ML.cable_material(Color("#26282c")), 20, 6, "Turn")
		turn.position = Vector3(0.0, 0.0, -0.05 + float(i) * 0.016)
		turn.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		turn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(turn)
	var plug: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.025, 0.05), f.ML.plastic_black(), "Plug")
	plug.position = Vector3(0.17, 0.02, 0.0)
	root.add_child(plug)
	return root


static func angle_bracket(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "AngleBracket"
	var a: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.004, 0.03), f.ML.steel_dark(), "LegA")
	root.add_child(a)
	var b: MeshInstance3D = ShapeKit.box(Vector3(0.004, 0.09, 0.03), f.ML.steel_dark(), "LegB")
	b.position = Vector3(-0.043, 0.045, 0.0)
	root.add_child(b)
	for i: int in range(2):
		var hole: MeshInstance3D = ShapeKit.cyl(0.005, 0.01, f.ML.rust(), 8, Vector3i(0, 1, 0), "Hole")
		hole.position = Vector3(-0.02 + float(i) * 0.05, 0.002, 0.0)
		root.add_child(hole)
	return root


static func broken_fan_guard(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BrokenFanGuard"
	# the guard is a flat disc in its own frame; it is hung at an angle afterwards
	var rim: MeshInstance3D = ShapeKit.torus(0.14, 0.006, f.ML.steel_dark(), 20, 5, "Rim")
	root.add_child(rim)
	for i: int in range(9):
		var a: float = ShapeKit.TAU_K * float(i) / 12.0
		var spoke: MeshInstance3D = ShapeKit.cyl(0.003, 0.13, f.ML.steel_dark(), 5, Vector3i(0, 1, 0), "Wire")
		spoke.position = Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.0)
		spoke.rotation = Vector3(0.0, 0.0, a + PI * 0.5)
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spoke)
	root.rotation = Vector3(0.4, 0.2, 0.9)
	return root


static func steel_drum(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SteelDrum"
	var body: MeshInstance3D = ShapeKit.cyl(0.28, 0.85, f.ML.paint_blue(1.2), 20, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, 0.425, 0.0)
	root.add_child(body)
	# the rolling hoops encircle the vertical drum: flat tori
	for i: int in range(2):
		var rib: MeshInstance3D = ShapeKit.torus(0.285, 0.02, f.ML.steel_dark(), 20, 6, "Rib")
		rib.position = Vector3(0.0, 0.25 + float(i) * 0.35, 0.0)
		root.add_child(rib)
	var lid: MeshInstance3D = ShapeKit.cyl(0.27, 0.02, f.ML.rust(), 20, Vector3i(0, 1, 0), "Lid")
	lid.position = Vector3(0.0, 0.86, 0.0)
	root.add_child(lid)
	root.add_child(ShapeKit.col_cyl(0.29, 0.88))
	return root


static func pallet(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Pallet"
	var wood: StandardMaterial3D = f.ML.teak(1.5)
	for i: int in range(5):
		var plank: MeshInstance3D = ShapeKit.box(Vector3(1.1, 0.025, 0.14), wood, "Plank")
		plank.position = Vector3(0.0, 0.14, -0.42 + float(i) * 0.21)
		root.add_child(plank)
	for i: int in range(3):
		var runner: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.12, 1.0), wood, "Runner")
		runner.position = Vector3(-0.45 + float(i) * 0.45, 0.06, 0.0)
		root.add_child(runner)
	root.add_child(ShapeKit.col_box(Vector3(1.15, 0.18, 1.05)))
	return root


static func hay_bale(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "HayBale"
	var bale: MeshInstance3D = ShapeKit.box(Vector3(0.6, 0.4, 0.35), f.ML.hay(), "Bale")
	bale.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(bale)
	for i: int in range(2):
		var tie: MeshInstance3D = ShapeKit.box(Vector3(0.012, 0.42, 0.37), f.ML.steel_dark(), "Tie")
		tie.position = Vector3(-0.15 + float(i) * 0.3, 0.2, 0.0)
		root.add_child(tie)
	return root


static func tubewell_bucket(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Bucket"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.14, 0.01), Vector2(0.155, 0.28),
		Vector2(0.16, 0.3), Vector2(0.15, 0.3), Vector2(0.145, 0.28), Vector2(0.13, 0.015),
		Vector2(0.0, 0.012),
	]), 18, f.ML.plastic_faded(), true, "Body")
	root.add_child(body)
	# the bail handle stands up across the rim
	var handle: MeshInstance3D = ShapeKit.torus(0.15, 0.007, f.ML.steel_dark(), 16, 5, "Handle")
	handle.position = Vector3(0.0, 0.3, 0.0)
	handle.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(handle)
	return root


static func tea_stall_box(f: PropFactory, _o: Dictionary) -> Node3D:
	## The roadside tea stall cart: a wooden box on wheels with a gas burner,
	## glasses and a kettle on top. Present in the reference set.
	var root := Node3D.new()
	root.name = "TeaStall"
	var box_body: MeshInstance3D = ShapeKit.box(Vector3(0.9, 0.55, 0.5), f.ML.teak(), "Box")
	box_body.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(box_body)
	var top: MeshInstance3D = ShapeKit.box(Vector3(1.0, 0.03, 0.6), f.ML.plywood(), "Top")
	top.position = Vector3(0.0, 0.79, 0.0)
	root.add_child(top)
	for i: int in range(2):
		var z: float = 0.3 * (1.0 if i == 0 else -1.0)
		var wheel: MeshInstance3D = ShapeKit.torus(0.22, 0.03, f.ML.rubber(), 18, 6, "Wheel")
		wheel.position = Vector3(0.0, 0.22, z)
		wheel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(wheel)
		var hub: MeshInstance3D = ShapeKit.cyl(0.05, 0.04, f.ML.steel_dark(), 12, Vector3i(0, 0, 1), "Hub")
		hub.position = Vector3(0.0, 0.22, z)
		root.add_child(hub)
	var burner: MeshInstance3D = ShapeKit.cyl(0.1, 0.06, f.ML.steel_dark(), 14, Vector3i(0, 1, 0), "Burner")
	burner.position = Vector3(-0.3, 0.83, 0.0)
	root.add_child(burner)
	var flame: MeshInstance3D = ShapeKit.sphere(0.06, f.ML.flame_material(), 10, "Flame")
	flame.position = Vector3(-0.3, 0.9, 0.0)
	flame.scale = Vector3(0.7, 1.3, 0.7)
	root.add_child(flame)
	var kettle: Node3D = tubewell_bucket(f, {})
	kettle.position = Vector3(0.2, 0.8, 0.05)
	kettle.scale = Vector3.ONE * 0.6
	root.add_child(kettle)
	for i: int in range(4):
		var glass: Node3D = DailyProps.tea_glass(f, {})
		glass.position = Vector3(0.05 + float(i) * 0.08, 0.8, -0.15)
		root.add_child(glass)
	root.add_child(ShapeKit.col_box(Vector3(1.0, 0.85, 0.6)))
	return root


static func bamboo_pole(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BambooPole"
	var pole: MeshInstance3D = ShapeKit.cyl(0.035, 2.6, f.ML.surface("bamboo"), 12, Vector3i(0, 1, 0), "Pole")
	pole.position = Vector3(0.0, 1.3, 0.0)
	root.add_child(pole)
	# the nodes are rings around the vertical pole: flat tori
	for i: int in range(9):
		var node: MeshInstance3D = ShapeKit.torus(0.038, 0.008, f.ML.surface("bamboo"), 12, 5, "Node")
		node.position = Vector3(0.0, 0.2 + float(i) * 0.28, 0.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return root


# ===========================================================================
# Fans and lighting
# ===========================================================================

static func ceiling_fan(f: PropFactory, o: Dictionary) -> Node3D:
	## The three-blade ceiling fan that is in literally every room in the country.
	var blades: int = clampi(int(o.get("blades", 3)), 3, 5)
	var radius: float = float(o.get("radius", 0.6))
	var drop: float = float(o.get("drop", 0.35))
	var root := Node3D.new()
	root.name = "CeilingFan"
	var canopy: MeshInstance3D = ShapeKit.cyl(0.06, 0.05, f.ML.paint_white_or(), 14, Vector3i(0, 1, 0), "Canopy")
	root.add_child(canopy)
	var rod: MeshInstance3D = ShapeKit.cyl(0.014, drop, f.ML.steel(), 8, Vector3i(0, 1, 0), "Downrod")
	rod.position = Vector3(0.0, -drop * 0.5, 0.0)
	root.add_child(rod)
	var motor_hub: MeshInstance3D = ShapeKit.cyl(0.09, 0.11, f.ML.paint_black_or_dark(), 18, Vector3i(0, 1, 0), "MotorHub")
	motor_hub.position = Vector3(0.0, -drop - 0.055, 0.0)
	root.add_child(motor_hub)
	var hub_mat: StandardMaterial3D = f.ML.paint_white_or()
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = motor_hub.position
	root.add_child(rotor)
	for i: int in range(blades):
		var a: float = ShapeKit.TAU_K * float(i) / float(blades)
		var arm: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.02, radius * 0.35), hub_mat, "BladeArm")
		arm.position = Vector3(cos(a) * radius * 0.2, 0.0, sin(a) * radius * 0.2)
		arm.rotation.y = -a
		rotor.add_child(arm)
		var blade: MeshInstance3D = ShapeKit.box(Vector3(radius * 0.72, 0.008, 0.13), f.ML.teak(1.2) if bool(o.get("wood", false)) else hub_mat, "Blade")
		blade.position = Vector3(cos(a) * (radius * 0.62), 0.0, sin(a) * (radius * 0.62))
		# blade pitch is the whole reason a fan moves air, and it is the detail
		// that makes a static render of one look wrong when it is missing
		blade.rotation = Vector3(0.0, -a, 0.28)
		rotor.add_child(blade)
	var pull: MeshInstance3D = ShapeKit.cyl(0.002, 0.18, f.ML.brass(), 5, Vector3i(0, 1, 0), "PullChain")
	pull.position = motor_hub.position + Vector3(0.07, -0.1, 0.0)
	root.add_child(pull)
	var bead: MeshInstance3D = ShapeKit.sphere(0.012, f.ML.brass(), 8, "Bead")
	bead.position = pull.position + Vector3(0.0, -0.1, 0.0)
	root.add_child(bead)
	var globe: MeshInstance3D = ShapeKit.sphere(0.075, f.ML.bulb_material(Color("fff2d8"), 0.0), 14, "Globe")
	globe.position = motor_hub.position + Vector3(0.0, -0.11, 0.0)
	root.add_child(globe)
	var shade: MeshInstance3D = ShapeKit.tapered_cyl(0.09, 0.05, 0.06, f.ML.glass_smoky(), 16, "Shade")
	shade.position = motor_hub.position + Vector3(0.0, -0.08, 0.0)
	root.add_child(shade)
	root.set_meta("rotor_path", "Rotor")
	return root


static func pedestal_fan(f: PropFactory, o: Dictionary) -> Node3D:
	## The standing fan with the wire guard, another absolute fixture.
	var height: float = float(o.get("height", 1.15))
	var root := Node3D.new()
	root.name = "PedestalFan"
	var base: MeshInstance3D = ShapeKit.cyl(0.19, 0.035, f.ML.plastic_black(), 18, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.018, 0.0)
	root.add_child(base)
	var post: MeshInstance3D = ShapeKit.cyl(0.021, height, f.ML.steel_dark(), 10, Vector3i(0, 1, 0), "Post")
	post.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(post)
	var head_y: float = height + 0.08
	var housing: MeshInstance3D = ShapeKit.cyl(0.07, 0.1, f.ML.plastic_faded(), 16, Vector3i(0, 0, 1), "MotorHousing")
	housing.position = Vector3(0.0, head_y, 0.0)
	root.add_child(housing)
	# the guards face +Z, so they are edge-on rings about a horizontal axis
	var guard_front: MeshInstance3D = ShapeKit.torus(0.19, 0.008, f.ML.steel_dark(), 22, 5, "GuardFront")
	guard_front.position = Vector3(0.0, head_y, 0.06)
	guard_front.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(guard_front)
	var guard_back: MeshInstance3D = guard_front.duplicate() as MeshInstance3D
	guard_back.position = Vector3(0.0, head_y, -0.06)
	root.add_child(guard_back)
	for i: int in range(14):
		var a: float = ShapeKit.TAU_K * float(i) / 14.0
		var wire: MeshInstance3D = ShapeKit.cyl(0.0025, 0.19, f.ML.steel_dark(), 5, Vector3i(0, 1, 0), "GuardWire")
		wire.position = Vector3(cos(a) * 0.095, head_y + sin(a) * 0.095, 0.06)
		wire.rotation = Vector3(PI * 0.5, 0.0, a + PI * 0.5)
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wire)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, head_y, 0.0)
	root.add_child(rotor)
	for i: int in range(3):
		var a: float = ShapeKit.TAU_K * float(i) / 3.0
		var blade: MeshInstance3D = ShapeKit.box(Vector3(0.17, 0.006, 0.075), f.ML.plastic_faded(), "Blade")
		blade.position = Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.0)
		blade.rotation = Vector3(0.35, 0.0, a + PI * 0.5)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotor.add_child(blade)
	var collar: MeshInstance3D = ShapeKit.cyl(0.03, 0.05, f.ML.plastic_black(), 12, Vector3i(0, 0, 1), "NeckCollar")
	collar.position = Vector3(0.0, head_y - 0.06, 0.0)
	root.add_child(collar)
	var buttons: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.03, 0.02), f.ML.plastic_black(), "SwitchPack")
	buttons.position = Vector3(0.0, head_y - 0.12, 0.03)
	root.add_child(buttons)
	root.add_child(ShapeKit.col_cyl(0.22, height + 0.3))
	root.set_meta("rotor_path", "Rotor")
	return root


static func table_fan(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TableFan"
	var base: MeshInstance3D = ShapeKit.box(Vector3(0.2, 0.03, 0.18), f.ML.plastic_black(), "Base")
	base.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(base)
	var housing: MeshInstance3D = ShapeKit.cyl(0.05, 0.07, f.ML.plastic_faded(), 14, Vector3i(0, 0, 1), "Housing")
	housing.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(housing)
	var guard: MeshInstance3D = ShapeKit.torus(0.13, 0.006, f.ML.steel_dark(), 18, 5, "Guard")
	guard.position = Vector3(0.0, 0.14, 0.04)
	guard.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(guard)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(rotor)
	for i: int in range(3):
		var a: float = ShapeKit.TAU_K * float(i) / 3.0
		var blade: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.005, 0.05), f.ML.plastic_faded(), "Blade")
		blade.position = Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.0)
		blade.rotation = Vector3(0.3, 0.0, a + PI * 0.5)
		rotor.add_child(blade)
	root.set_meta("rotor_path", "Rotor")
	return root


static func workbench_lamp(f: PropFactory, o: Dictionary) -> Node3D:
	## The articulated bench lamp with the spring arm and the metal bowl shade.
	var root := Node3D.new()
	root.name = "WorkbenchLamp"
	var clamp_b: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.09, 0.05), f.ML.steel_dark(), "Clamp")
	root.add_child(clamp_b)
	var lower: MeshInstance3D = ShapeKit.cyl(0.011, 0.34, f.ML.steel(), 8, Vector3i(0, 1, 0), "LowerArm")
	lower.position = Vector3(0.0, 0.2, 0.0)
	lower.rotation.z = 0.35
	root.add_child(lower)
	var joint: MeshInstance3D = ShapeKit.sphere(0.022, f.ML.brass(), 10, "Joint")
	joint.position = Vector3(0.115, 0.36, 0.0)
	root.add_child(joint)
	var upper: MeshInstance3D = ShapeKit.cyl(0.011, 0.3, f.ML.steel(), 8, Vector3i(0, 1, 0), "UpperArm")
	upper.position = Vector3(0.2, 0.28, 0.0)
	upper.rotation.z = -1.0
	root.add_child(upper)
	var spring: MeshInstance3D = ShapeKit.coil(9.0, 0.014, 0.0025, 0.22, f.ML.steel_spring(), 14, "Spring")
	spring.position = Vector3(0.06, 0.24, 0.02)
	spring.rotation = Vector3(0.0, 0.0, 0.6)
	root.add_child(spring)
	var shade: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.015, 0.0), Vector2(0.02, 0.01), Vector2(0.06, 0.05), Vector2(0.085, 0.09),
		Vector2(0.08, 0.095), Vector2(0.055, 0.055), Vector2(0.014, 0.008), Vector2(0.0, 0.0),
	]), 18, f.ML.paint_red(1.2), false, "Shade")
	shade.position = Vector3(0.28, 0.13, 0.0)
	shade.rotation = Vector3(PI * 0.9, 0.0, 0.3)
	root.add_child(shade)
	var bulb: MeshInstance3D = ShapeKit.sphere(0.028, f.ML.bulb_material(Color("fff0cf"), 0.0), 12, "Bulb")
	bulb.position = Vector3(0.28, 0.11, 0.0)
	root.add_child(bulb)
	var socket: MeshInstance3D = ShapeKit.cyl(0.02, 0.04, f.ML.plastic_black(), 10, Vector3i(0, 1, 0), "Socket")
	socket.position = Vector3(0.28, 0.15, 0.0)
	root.add_child(socket)
	root.set_meta("bulb_path", "Bulb")
	root.scale = Vector3.ONE * float(o.get("scale", 1.0))
	return root


static func fluorescent_battlement(f: PropFactory, o: Dictionary) -> Node3D:
	## The tube-light fitting: steel channel, two tube ends, the choke and starter
	## canister, and a diffuser that is yellowed with age.
	var length: float = float(o.get("length", 1.2))
	var root := Node3D.new()
	root.name = "FluorescentBattlement"
	var channel: MeshInstance3D = ShapeKit.box(Vector3(length, 0.06, 0.09), f.ML.aluminium(), "Channel")
	root.add_child(channel)
	var tube: MeshInstance3D = ShapeKit.cyl(0.018, length - 0.06, f.ML.tube_glow(), 12, Vector3i(1, 0, 0), "Tube")
	tube.position = Vector3(0.0, -0.02, 0.0)
	root.add_child(tube)
	var diffuser: MeshInstance3D = ShapeKit.box(Vector3(length - 0.04, 0.012, 0.1), f.ML.diffuser_plastic(), "Diffuser")
	diffuser.position = Vector3(0.0, -0.05, 0.0)
	root.add_child(diffuser)
	for i: int in range(2):
		var cap: MeshInstance3D = ShapeKit.cyl(0.02, 0.025, f.ML.plastic_faded(), 10, Vector3i(1, 0, 0), "EndCap")
		cap.position = Vector3((length - 0.06) * 0.5 * (1.0 if i == 0 else -1.0), -0.02, 0.0)
		root.add_child(cap)
	var choke: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.035, 0.03), f.ML.steel_dark(), "Choke")
	choke.position = Vector3(length * 0.3, 0.03, 0.0)
	root.add_child(choke)
	var starter: MeshInstance3D = ShapeKit.cyl(0.011, 0.035, f.ML.glass_smoky(), 10, Vector3i(0, 1, 0), "Starter")
	starter.position = Vector3(length * 0.18, 0.035, 0.02)
	root.add_child(starter)
	var chain: Node3D = ShapeKit.chain(0.008, 5, f.ML.steel_dark(), "MountChain")
	chain.position = Vector3(-length * 0.35, 0.06, 0.0)
	root.add_child(chain)
	root.set_meta("tube_path", "Tube")
	root.set_meta("diffuser_path", "Diffuser")
	return root


static func bulb_hanging(f: PropFactory, o: Dictionary) -> Node3D:
	## A bare bulb on a flex, the most common light source in the country.
	var drop: float = float(o.get("drop", 0.7))
	var root := Node3D.new()
	root.name = "HangingBulb"
	var flex: MeshInstance3D = ShapeKit.hose(
		Vector3(0.0, 0.0, 0.0),
		Vector3(f.rand().randf_range(-0.05, 0.05), -drop, f.rand().randf_range(-0.05, 0.05)),
		0.005, drop * 0.12, f.ML.cable_material(Color("#3a2f28")), "Flex")
	root.add_child(flex)
	var holder: MeshInstance3D = ShapeKit.cyl(0.022, 0.05, f.ML.plastic_black(), 12, Vector3i(0, 1, 0), "Holder")
	holder.position = Vector3(0.0, -drop, 0.0)
	root.add_child(holder)
	var bulb: MeshInstance3D = ShapeKit.sphere(0.04, f.ML.bulb_material(Color("ffe6b8"), 0.0), 14, "Bulb")
	bulb.position = Vector3(0.0, -drop - 0.05, 0.0)
	root.add_child(bulb)
	var filament: MeshInstance3D = ShapeKit.coil(6.0, 0.012, 0.0012, 0.03, f.ML.tungsten(), 10, "Filament")
	filament.position = bulb.position + Vector3(0.0, 0.005, 0.0)
	root.add_child(filament)
	root.set_meta("bulb_path", "Bulb")
	return root


static func desk_lamp(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "DeskLamp"
	var base: MeshInstance3D = ShapeKit.cyl(0.09, 0.02, f.ML.plastic_black(), 16, Vector3i(0, 1, 0), "Base")
	base.position = Vector3(0.0, 0.01, 0.0)
	root.add_child(base)
	var stem: MeshInstance3D = ShapeKit.cyl(0.012, 0.36, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Stem")
	stem.position = Vector3(0.0, 0.19, 0.0)
	root.add_child(stem)
	var elbow: MeshInstance3D = ShapeKit.sphere(0.02, f.ML.brass(), 10, "Elbow")
	elbow.position = Vector3(0.0, 0.37, 0.0)
	root.add_child(elbow)
	var arm: MeshInstance3D = ShapeKit.cyl(0.01, 0.26, f.ML.steel_dark(), 8, Vector3i(0, 1, 0), "Arm")
	arm.position = Vector3(0.09, 0.44, 0.0)
	arm.rotation.z = -1.1
	root.add_child(arm)
	var shade: MeshInstance3D = ShapeKit.tapered_cyl(0.03, 0.075, 0.08, f.ML.paint_black_or_dark(), 16, "Shade")
	shade.position = Vector3(0.2, 0.5, 0.0)
	shade.rotation = Vector3(0.0, 0.0, 0.5)
	root.add_child(shade)
	var bulb: MeshInstance3D = ShapeKit.sphere(0.024, f.ML.bulb_material(Color("fff4dd"), 0.0), 10, "Bulb")
	bulb.position = Vector3(0.21, 0.47, 0.0)
	root.add_child(bulb)
	var switch_b: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.012, 0.015), f.ML.plastic_red(), "Switch")
	switch_b.position = Vector3(0.06, 0.02, 0.06)
	root.add_child(switch_b)
	root.set_meta("bulb_path", "Bulb")
	return root


# ===========================================================================
# Entrance hardware
# ===========================================================================

static func rolling_shutter(f: PropFactory, o: Dictionary) -> Node3D:
	## The corrugated rolling shutter. Slats are individual geometry so the curtain
	## curls realistically around the barrel as it opens, which is the
	## mechanical-animation requirement from the brief.
	var width: float = float(o.get("width", 3.4))
	var height: float = float(o.get("height", 2.9))
	var slat_h: float = float(o.get("slat_height", 0.11))
	var count: int = clampi(int(height / slat_h), 4, 60)
	var root := Node3D.new()
	root.name = "RollingShutter"
	for i: int in range(2):
		var track: MeshInstance3D = ShapeKit.box(Vector3(0.09, height + 0.3, 0.13), f.ML.steel_dark(), "Track")
		track.position = Vector3((width * 0.5 + 0.045) * (1.0 if i == 0 else -1.0), height * 0.5, 0.0)
		root.add_child(track)
	var barrel: MeshInstance3D = ShapeKit.cyl(0.16, width + 0.1, f.ML.steel_dark(), 20, Vector3i(1, 0, 0), "Barrel")
	barrel.position = Vector3(0.0, height + 0.28, -0.16)
	root.add_child(barrel)
	var barrel_cap: MeshInstance3D = ShapeKit.cyl(0.17, 0.03, f.ML.rust(), 20, Vector3i(1, 0, 0), "Cap")
	barrel_cap.position = Vector3((width * 0.5 + 0.06), height + 0.28, -0.16)
	root.add_child(barrel_cap)
	var curtain := Node3D.new()
	curtain.name = "Curtain"
	root.add_child(curtain)
	var slat_mat: StandardMaterial3D = f.ML.paint_blue(0.6)
	for i: int in range(count):
		var slat: MeshInstance3D = ShapeKit.box(Vector3(width, slat_h * 0.94, 0.022), slat_mat, "Slat%03d" % i)
		slat.position = Vector3(0.0, slat_h * (float(i) + 0.5), 0.0)
		curtain.add_child(slat)
		var rib: MeshInstance3D = ShapeKit.box(Vector3(width, 0.012, 0.012), f.ML.steel(), "Rib")
		rib.position = Vector3(0.0, slat_h * (float(i) + 0.5) + slat_h * 0.45, 0.014)
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		curtain.add_child(rib)
	var rail: MeshInstance3D = ShapeKit.box(Vector3(width + 0.02, 0.12, 0.06), f.ML.paint_yellow(), "BottomRail")
	rail.position = Vector3(0.0, 0.06, 0.02)
	curtain.add_child(rail)
	var handle: MeshInstance3D = ShapeKit.cyl(0.014, 0.3, f.ML.steel(), 8, Vector3i(1, 0, 0), "Handle")
	handle.position = Vector3(0.0, 0.02, 0.08)
	curtain.add_child(handle)
	root.add_child(ShapeKit.col_box(Vector3(width + 0.2, height + 0.4, 0.2)))
	root.set_meta("curtain_path", "Curtain")
	root.set_meta("slat_count", count)
	root.set_meta("slat_height", slat_h)
	return root


static func exterior_facade(f: PropFactory, o: Dictionary) -> Node3D:
	## The courtyard wall, plinth and neighbouring shopfronts that make the garage
	## read as being in Bangladesh rather than in a void.
	var root := Node3D.new()
	root.name = "Facade"
	var plaster: StandardMaterial3D = f.ML.plaster()
	var plinth: MeshInstance3D = ShapeKit.box(Vector3(7.0, 0.35, 0.3), f.ML.surface("concrete_block"), "Plinth")
	plinth.position = Vector3(0.0, 0.175, 0.0)
	root.add_child(plinth)
	for i: int in range(2):
		var pier: MeshInstance3D = ShapeKit.box(Vector3(0.4, 3.2, 0.35), plaster, "Pier")
		pier.position = Vector3((2.0 + 0.2) * (1.0 if i == 0 else -1.0), 1.6, 0.0)
		root.add_child(pier)
	var lintel: MeshInstance3D = ShapeKit.box(Vector3(4.9, 0.35, 0.35), plaster, "Lintel")
	lintel.position = Vector3(0.0, 3.35, 0.0)
	root.add_child(lintel)
	var awning: MeshInstance3D = ShapeKit.box(Vector3(3.2, 0.02, 1.4), f.ML.roof_tin(), "Awning")
	awning.position = Vector3(-2.6, 2.5, 0.7)
	awning.rotation = Vector3(-0.18, 0.0, 0.06)
	root.add_child(awning)
	for i: int in range(2):
		var prop: MeshInstance3D = ShapeKit.cyl(0.03, 2.4, f.ML.surface("bamboo"), 8, Vector3i(0, 1, 0), "AwningPost")
		prop.position = Vector3(-3.8 + float(i) * 1.6, 1.2, 1.3)
		root.add_child(prop)
	root.add_child(ShapeKit.col_box(Vector3(7.0, 3.4, 0.4)))
	return root


# ===========================================================================
# Small extras
# ===========================================================================

static func weld_spatter(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WeldSpatter"
	for i: int in range(9):
		var s: MeshInstance3D = ShapeKit.sphere(_rf(f, 0.004, 0.012), f.ML.weld_bead(), 6, "Spatter")
		s.position = Vector3(_rf(f, -0.12, 0.12), 0.002, _rf(f, -0.12, 0.12))
		s.scale = Vector3(1.0, 0.35, 1.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s)
	return root


static func cutting_torch(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CuttingTorch"
	var body: MeshInstance3D = ShapeKit.cyl(0.02, 0.28, f.ML.brass(), 12, Vector3i(0, 0, 1), "Body")
	body.position = Vector3(0.0, 0.0, -0.1)
	root.add_child(body)
	var nozzle: MeshInstance3D = ShapeKit.tapered_cyl(0.008, 0.022, 0.08, f.ML.steel_heatblued(), 12, "Nozzle")
	nozzle.position = Vector3(0.0, 0.0, 0.06)
	nozzle.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(nozzle)
	for i: int in range(2):
		var grip: MeshInstance3D = ShapeKit.cyl(0.012, 0.14, f.ML.steel_dark(), 8, Vector3i(0, 0, 1), "Grip")
		grip.position = Vector3(0.03 * (1.0 if i == 0 else -1.0), 0.0, -0.16)
		root.add_child(grip)
	var hose_a: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.0, -0.24), Vector3(0.3, -0.2, -0.8), 0.008, 0.12, f.ML.cable_material(Color("#1f3a52")), "HoseA")
	root.add_child(hose_a)
	var valve: MeshInstance3D = ShapeKit.cyl(0.02, 0.012, f.ML.brass(), 10, Vector3i(0, 1, 0), "Valve")
	valve.position = Vector3(0.0, 0.02, -0.2)
	root.add_child(valve)
	return root


static func hand_drill(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "HandDrill"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.12, 0.05), f.ML.cast_iron(), "Body")
	root.add_child(body)
	var chuck: MeshInstance3D = ShapeKit.cyl(0.025, 0.05, f.ML.steel(), 12, Vector3i(0, 1, 0), "Chuck")
	chuck.position = Vector3(0.0, 0.09, 0.0)
	root.add_child(chuck)
	var bit: MeshInstance3D = ShapeKit.cyl(0.005, 0.09, f.ML.steel_hardened(), 6, Vector3i(0, 1, 0), "Bit")
	bit.position = Vector3(0.0, 0.16, 0.0)
	root.add_child(bit)
	var handle: MeshInstance3D = ShapeKit.cyl(0.016, 0.16, f.ML.teak(), 10, Vector3i(1, 0, 0), "Handle")
	handle.position = Vector3(0.08, 0.02, 0.0)
	root.add_child(handle)
	var gear: MeshInstance3D = ShapeKit.gear(16, 3.0, 0.008, 0.01, f.ML.steel_dark(), "Pinion")
	gear.position = Vector3(0.0, 0.02, 0.035)
	root.add_child(gear)
	return root


static func impact_driver(f: PropFactory, _o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ImpactDriver"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.16, 0.09), f.ML.paint_red(1.4), "Body")
	body.position = Vector3(0.0, 0.08, 0.0)
	root.add_child(body)
	var nose: MeshInstance3D = ShapeKit.cyl(0.028, 0.06, f.ML.steel_dark(), 12, Vector3i(0, 0, 1), "Nose")
	nose.position = Vector3(0.0, 0.08, 0.07)
	root.add_child(nose)
	var grip: MeshInstance3D = ShapeKit.cyl(0.022, 0.14, f.ML.rubber(), 12, Vector3i(0, 1, 0), "Grip")
	grip.position = Vector3(0.0, -0.06, -0.02)
	root.add_child(grip)
	var trigger: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.03, 0.02), f.ML.plastic_black(), "Trigger")
	trigger.position = Vector3(0.0, -0.01, 0.02)
	root.add_child(trigger)
	var cord: MeshInstance3D = ShapeKit.hose(Vector3(0.0, -0.13, -0.02), Vector3(0.4, -0.2, -0.4), 0.005, 0.1, f.ML.cable_material(Color("#20140f")), "Cord")
	root.add_child(cord)
	return root


static func _rf(f: PropFactory, lo: float, hi: float) -> float:
	return f.rand().randf_range(lo, hi)
