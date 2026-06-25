@tool

const Util = preload("util/util.gd")
const LevelUtil = preload("util/level-util.gd")
const FieldUtil = preload("util/field-util.gd")
const PostImport = preload("post-import.gd")
const Layer = preload("layer.gd")

static var base_directory: String

static func build_levels(
		world_data: Dictionary,
		definitions: Dictionary,
		base_dir: String,
		external_levels: bool
) -> Array[LDTKLevel]:

	Util.timer_start(Util.DebugTime.GENERAL)
	base_directory = base_dir
	var levels: Array[LDTKLevel] = []

	# Calculate level positions
	var level_positions: Array
	match world_data.worldLayout:
		"LinearHorizontal":
			var x = 0
			for level in world_data.levels:
				level_positions.append(Vector2i(x, 0))
				x += level.pxWid
		"LinearVertical":
			var y := 0
			for level in world_data.levels:
				level_positions.append(Vector2i(0, y))
				y += level.pxHei
		"GridVania", "Free":
			level_positions = world_data.levels.map(
				func (current):
					return Vector2i(current.worldX, current.worldY)
			)
		_:
			printerr("World Layout not supported: ", world_data.worldLayout)

	# Create levels
	for level_index in range(world_data.levels.size()):
		Util.timer_start(Util.DebugTime.GENERAL)
		var level_data
		var position: Vector2i = level_positions[level_index]
		level_data = world_data.levels[level_index]

		if external_levels:
			level_data = LevelUtil.get_external_level(level_data, base_dir)

		var level = create_level(level_data, position, definitions)
		Util.timer_finish("Built Level", 2)

		if (Util.options.entities_post_import):
			level = PostImport.run_entity_post_import(level, Util.options.entities_post_import)

		if (Util.options.level_post_import):
			level = PostImport.run_level_post_import(level, Util.options.level_post_import)

		levels.append(level)

	Util.timer_finish("Built %s Levels" % levels.size(), 1)
	return levels

static func create_level(
		level_data: Dictionary,
		position: Vector2i,
		definitions: Dictionary
) -> LDTKLevel:
	var level_name: String = level_data.identifier
	var level := LDTKLevel.new()
	level.name = level_name
	level.iid = level_data.iid
	level.world_position = position
	level.size = Vector2i(level_data.pxWid, level_data.pxHei)
	level.bg_color = level_data.__bgColor
	level.z_index = level_data.worldDepth

	if (Util.options.verbose_output): Util.print("block", level_name, 1)
	Util.update_instance_reference(level_data.iid, level)

	var neighbours = level_data.__neighbours

	if not Util.options.pack_levels:
		for neighbour in neighbours:
			Util.add_unresolved_reference(neighbour, "levelIid", level)

	level.neighbours = neighbours

	# Create background image
	create_background(level, level_data)

	# Create fields
	level.fields = FieldUtil.create_fields(level_data.fieldInstances, level)

	var layer_instances = level_data.layerInstances
	if not layer_instances is Array:
		push_error("level '%s' has no layer instances." % [level_name])
		return level

	# Create layers
	var layers = Layer.create_layers(level_data, layer_instances, definitions)
	for layer in layers:
		level.add_child(layer)

	return level

# Creates the level background (if any) as a Sprite2D placed behind every layer.
# Uses LDTK's __bgPos data (top-left anchor + crop + uniform scale) so the
# framing matches exactly what is shown inside the LDtk editor.
static func create_background(level: LDTKLevel, level_data: Dictionary) -> void:
	if level_data.bgRelPath == null:
		return

	var path := "%s/%s" % [base_directory, level_data.bgRelPath]
	var texture := load(path)
	if texture == null:
		push_warning("LDTK: background not found for level '%s': %s" % [level.name, path])
		return

	var bg_data: Dictionary = level_data.__bgPos
	var pos: Array = bg_data.topLeftPx
	var scale: Array = bg_data.scale
	var region: Array = bg_data.cropRect

	var sprite := Sprite2D.new()
	sprite.name = "BG Image"
	sprite.texture = texture
	sprite.centered = false                                # anchor at top-left
	sprite.position = Vector2(pos[0], pos[1])              # topLeftPx (no centering)
	sprite.scale = Vector2(scale[0], scale[1])            # float scale (no truncation)
	sprite.region_enabled = true
	sprite.region_rect = Rect2i(region[0], region[1], region[2], region[3])
	sprite.z_index = -9999                                 # always behind tiles/entities

	level.add_child(sprite)
	level.move_child(sprite, 0)                            # first child = drawn first
