class_name FlowDrawer extends Node2D

## The width of the lines being drawn.
var line_width := 2.0;

var region: FlowField;

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		line_width += 0.5;
		queue_redraw();
	elif Input.is_action_just_pressed("ui_down"):
		line_width = move_toward(line_width, 1.0, 0.5);
		queue_redraw();
		

func _draw() -> void:
	var region_size := region.get_used_rect().size.length();
	
	for tile in region.get_used_cells():
		var flow_length := region.tile_flow_length(tile);
		
		if flow_length <= 0.0: continue;
		
		var pos := Vector2(tile) + Vector2(0.5, 0.5);
		var flow_pos := Vector2(region.tile_flow(tile)) + Vector2(0.5, 0.5);
		var tile_size := region.tile_set.tile_size;
		pos.x *= tile_size.x;
		pos.y *= tile_size.y;
		flow_pos.x *= tile_size.x;
		flow_pos.y *= tile_size.y;
		
		draw_line(pos, flow_pos, Color.from_ok_hsl(flow_length * 0.5 / region_size, 0.98, 0.5), line_width);
