class_name FlowField extends TileMapLayer

## A basic representation of a traversable region as a grid of tiles.
##
## In this basic representation, each tile 

#region Exports

@export_category("Tile Info")
## The tile ID of passable tiles.
@export var FLOOR_ATLAS_ID := Vector2i(0, 0);
## The tile ID of impassible tiles.
@export var WALL_ATLAS_ID := Vector2i(1, 0);
## The camera.
@export var CAMERA_NODE: Camera2D;

## An array containing the flow position of each tile.
var flow_positions: Array[Vector2i] = [];
## An array containing the flow length of each tile.
var flow_lengths: Array[float] = [];
## Whether the region currently has a flow generated/generating.

var flow_drawer: FlowDrawer = null;
var flow_generator: FlowGenerator = null;

#endregion

#region Methods

func _ready() -> void:
	assert(tile_set != null, "forgot to assigne a tile set to the flow field");
	init_flow_data();

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("space_button"):
		if flow_generator != null:
			if flow_generator.process_mode == Node.PROCESS_MODE_DISABLED:
				flow_generator.process_mode = Node.PROCESS_MODE_PAUSABLE;
			else:
				flow_generator.process_mode = Node.PROCESS_MODE_DISABLED;
		else:
			flow_from_random_pos();
	
	if Input.is_action_just_pressed("escape_button"):
		get_tree().quit();

func _draw() -> void:
	if flow_generator == null: return;
	
	if flow_drawer != null: flow_drawer.queue_free();
	
	flow_drawer = FlowDrawer.new();
	flow_drawer.region = self;
	add_child(flow_drawer);

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var m_event := event as InputEventMouseButton;
		if m_event.is_pressed():
			var mouse_pos := m_event.global_position;
			var tile_size := tile_set.tile_size;
			@warning_ignore("integer_division")
			var tile_pos := Vector2i(roundi(mouse_pos.x) / tile_size.x, roundi(mouse_pos.y) / tile_size.y);
			
			if tile_is_wall(tile_pos):
				set_cell(tile_pos, 0, FLOOR_ATLAS_ID);
			else:
				set_cell(tile_pos, 0, WALL_ATLAS_ID);

#endregion

#region Functions

## Initializes the flow positions and lengths arrays.
func init_flow_data() -> void:
	flow_positions = [];
	flow_lengths = [];
	
	var span := get_used_rect();
	
	for i in range(span.size.x * span.size.y):
		flow_positions.push_back(Vector2i.ZERO);
		flow_lengths.push_back(-1.0);

## Resets the board and wipes all flow values.
func wipe_flow() -> void:
	for i in range(flow_positions.size()):
		flow_positions[i] = Vector2i.ZERO;
		flow_lengths[i] = -1.0;

## Converts a 2D position to an index in the flow data arrays.
func pos_to_index(pos: Vector2i) -> int:
	var rect := get_used_rect();
	
	assert(rect.has_point(pos), "invalid index");
	
	var relative := pos - rect.position;
	return relative.x + relative.y * rect.size.x;

## Sets the flow of a specific tile.
func set_flow(at: Vector2i, flow_position: Vector2i, length: float) -> void:
	var idx := pos_to_index(at);
	flow_positions[idx] = flow_position;
	flow_lengths[idx] = length;

## Returns whether the tile at the given position is a wall.
func tile_is_wall(at: Vector2i) -> bool:
	return get_cell_atlas_coords(at) == WALL_ATLAS_ID;

## Returns the flow position of the specified tile.
func tile_flow(at: Vector2i) -> Vector2i:
	return flow_positions[pos_to_index(at)];

## Returns the flow length of the specified tile.
func tile_flow_length(at: Vector2i) -> float:
	return flow_lengths[pos_to_index(at)];

func tile_has_shorter_flow(at: Vector2i, flow_length: float) -> bool:
	if tile_is_wall(at): return true;
	
	var flow_len := tile_flow_length(at);
	return flow_len != -1.0 && flow_len < flow_length

func flow_from_random_pos() -> void:
	for _i in range(128):
		var rect := get_used_rect();
		var x := randi() % rect.size.x + rect.position.x;
		var y := randi() % rect.size.y + rect.position.y;
		
		var pos := Vector2i(x, y);
		if !tile_is_wall(pos):
			FlowGenerator.new().init_flow_from(pos, self);
			return;

#endregion

class FlowGenerator extends Node:
	var shrooms: Array[Shroom];
	var spores: Array[Spore];
	var spore_destination: Array[Spore] = [];
	var shroom_destination: Array[Shroom] = [];
	var region: FlowField;
	var is_init := false;
	
	func init_flow_from(pos: Vector2i, new_region: FlowField) -> void:
		is_init = true;
		
		region = new_region;
		region.wipe_flow();
		region.set_flow(pos, pos, 0.0);
		
		shrooms = [];
		spores = [];
		
		var shroom := Shroom.new();
		shroom.initialize(pos, Utility.UP, 0.0, 0);
		shrooms.push_back(shroom);
		
		shroom = Shroom.new();
		shroom.initialize(pos, Utility.RIGHT, 0.0, 0);
		shrooms.push_back(shroom);
		
		shroom = Shroom.new();
		shroom.initialize(pos, Utility.DOWN, 0.0, 0);
		shrooms.push_back(shroom);
		
		shroom = Shroom.new();
		shroom.initialize(pos, Utility.LEFT, 0.0, 0);
		shrooms.push_back(shroom);
		
		var spore := Spore.new();
		spore.initialize(pos, Utility.UP_LEFT, 0.0, 0);
		spores.push_back(spore);
		
		spore = Spore.new();
		spore.initialize(pos, Utility.UP_RIGHT, 0.0, 0);
		spores.push_back(spore);
		
		spore = Spore.new();
		spore.initialize(pos, Utility.DOWN_RIGHT, 0.0, 0);
		spores.push_back(spore);
		
		spore = Spore.new();
		spore.initialize(pos, Utility.DOWN_LEFT, 0.0, 0);
		spores.push_back(spore);
		
		region.add_child(self);
		region.flow_generator = self;
	
	func drain_live_spores(live_spores: Array[Spore]) -> void:
		for spore in live_spores:
			if spore.step(region, shroom_destination):
				spore_destination.push_back(spore);
		
		live_spores.clear();
	
	func _process(_dt: float) -> void:
		if !is_init: return;
		
		if shrooms.is_empty() && spores.is_empty():
			queue_free();
			region.flow_generator = null;
			return;
		
		
		var spore_index := 0;
		var shroom_index := 0;
		
		var lowest_step_count := 0;
		var live_spores: Array[Spore] = [];
		
		while shroom_index < shrooms.size() || spore_index < spores.size():
			# If out of shrooms
			if shroom_index == shrooms.size():
				drain_live_spores(live_spores);
				
				while spore_index < spores.size():
					var spore := spores[spore_index];
					
					if spore.step(region, shroom_destination):
						spore_destination.push_back(spore);
					
					spore_index += 1;
				
				break;
			
			# If out of spores
			if spore_index == spores.size():
				while shroom_index < shrooms.size():
					var shroom := shrooms[shroom_index] as Shroom;
					
					if lowest_step_count != shroom.step_count:
						drain_live_spores(live_spores);
						lowest_step_count = shroom.step_count;
					
					if shroom.step(region, live_spores, spore_destination):
						shroom_destination.push_back(shroom);
					
					shroom_index += 1;
				
				break;
			
			# Step Counts #
			
			var shroom_step_count := shrooms[shroom_index].step_count;
			var spore_step_count := spores[spore_index].step_count;
			
			if lowest_step_count == shroom_step_count:
				var shroom := shrooms[shroom_index];
				
				if shroom.step(region, live_spores, spore_destination):
					shroom_destination.push_back(shroom);
				
				shroom_index += 1;
				
				continue;
			else:
				if live_spores.size() != 0:
					drain_live_spores(live_spores);
			
			lowest_step_count = mini(shroom_step_count, spore_step_count);
			
			if lowest_step_count == spore_step_count && lowest_step_count != shroom_step_count:
				var spore := spores[spore_index];
				
				if spore.step(region, shroom_destination):
					spore_destination.push_back(spore);
				
				spore_index += 1;
		
		drain_live_spores(live_spores);
		
		var swap_shrooms := shroom_destination;
		var swap_spores := spore_destination;
		
		shroom_destination = shrooms;
		spore_destination = spores;
		
		# Allocation is a tangible concern with larger grids.
		# If possible, reuse your arrays so that you don't have
		# to reallocate them every time this function runs.
		shroom_destination.clear();
		spore_destination.clear();
		
		shrooms = swap_shrooms;
		spores = swap_spores;
		
		region.queue_redraw();
