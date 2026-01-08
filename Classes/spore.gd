class_name Spore extends Sprite2D

## A diagonal search agent.

#region Variables

var pos: Vector2i;
var heading: Vector2i;
var flow_length: float;
var step_count: int;

#endregion

#region Functions

## Initializes the spore with the given values.
func initialize(new_position: Vector2i, new_heading: Vector2i, new_flow_length: float, new_step_count: int) -> void:
	pos = new_position;
	heading = new_heading;
	flow_length = new_flow_length;
	step_count = new_step_count;
	
	match new_heading:
		Vector2i.UP + Vector2i.RIGHT: rotation = PI / 4.0;
		Vector2i.RIGHT + Vector2i.DOWN: rotation = PI * 3.0 / 4.0;
		Vector2i.DOWN + Vector2i.LEFT: rotation = PI * 5.0 / 4.0;
		Vector2i.LEFT + Vector2i.UP: rotation = PI * 7.0 / 4.0;
		_: assert(false, "invalid spore heading");

## Takes one step forward; returns false if `self` needs to be deleted.[br][br]
## 
## [member region]: The region being stepped through.[br][br]
## 
## [member shroom_destination]: Shrooms that will be added to the next step iteration.
func step(region: FlowField, shroom_destination: Array[Shroom]) -> bool:
	# Check Sides #
	
	var left_heading := Utility.left_shoulder(heading);
	var right_heading := Utility.right_shoulder(heading);
	
	var left_corner := pos + left_heading;
	var right_corner := pos + right_heading;
	
	var has_wall_to_left := region.tile_is_wall(left_corner);
	var has_wall_to_right := region.tile_is_wall(right_corner);
	
	# In this case, the spore can't move forward, so we signal
	# to delete it by returning false.
	if has_wall_to_left && has_wall_to_right:
		return false;
	
	# Move Forward #
	
	pos += heading;
	step_count += 1;
	
	# If the new tile is a wall, we signal to delete this spore.
	if region.tile_is_wall(pos):
		return false;
	
	# Compute Flow #
	
	var flow := get_optimal_flow(region);
	flow_length = region.tile_flow_length(flow) + (pos - flow).length();
	
	# If the path is already shorter, then we can delete the spore.
	if region.tile_has_shorter_flow(pos, flow_length):
		return false;
	
	region.set_flow(pos, flow, flow_length);
	
	# Spore Spawning #
	
	if has_wall_to_left && !region.tile_is_wall(pos + left_heading):
		var shroom := Shroom.new();
		shroom.initialize(pos, left_heading, flow_length, step_count);
		shroom_destination.push_back(shroom);
	elif has_wall_to_right && !region.tile_is_wall(pos + right_heading):
		var shroom := Shroom.new();
		shroom.initialize(pos, right_heading, flow_length, step_count);
		shroom_destination.push_back(shroom);
	
	# Continue #
	
	return true;

## Finds the (genereally) optimal flow position from the current tile.[br][br]
##
## NOTE This implementation is intended for valid cases only. If the agent is inside of a wall,
##  	it will behave weirdly.
func get_optimal_flow(region: FlowField) -> Vector2i:
	## This is used for cutting corners. The value 0.5 will shift calculated slopes
	## to the corners of tiles, while setting it to 0.0 will keep all slopes calculations
	## at the center of the tile.
	##
	## I'd need a diagram to explain much more, so just play with it and
	## see what happens. Just know higher values = more corner cutting,
	## and lower values = less corner cutting.
	const CORNER_RADIUS := 0.5;
	
	# Preparation #
	
	var prev := pos - heading;
	var prev_flow := region.tile_flow(prev);
	var super_prev_flow := region.tile_flow(prev_flow);
	
	# Return early if the previous tile is the target.
	if prev == prev_flow: return prev;
	
	var lh := Utility.left_shoulder(heading);
	var rh := Utility.right_shoulder(heading);
	var left_pos := pos - rh;
	var right_pos := pos - lh;
	var left_flow := region.tile_flow(left_pos);
	var right_flow := region.tile_flow(right_pos);
	
	var has_wall_to_left := region.tile_is_wall(left_pos);
	var has_wall_to_right := region.tile_is_wall(right_pos);
	var has_wall_to_sides := has_wall_to_left || has_wall_to_right;
	
	## The slope from the previous tile's flow to the farthest out
	## corner of the previous tile, rotated relative to `heading`
	## as if `heading` was rotated into the positive quadrant.
	var prev_reoriented_slope := Utility.get_relative_slope(
		heading,
		prev_flow,
		prev,
		Vector2(CORNER_RADIUS, CORNER_RADIUS)
	);
	
	# -- Checks -- #
	
	# No Walls
	if !has_wall_to_sides:
		# If the tile to the left and right point to the same place,
		# then we can also point there. It's a simple rule, but it
		# does a lot of work.
		if left_flow == right_flow:
			return left_flow;
		
		# If the left tile points to the same spot as the tile that
		# the right tile points to, we might be able to cut the corner
		if prev_reoriented_slope > 1.0 && region.tile_flow(right_flow) == left_flow:
			# The slope of the flow from the left tile's flow
			# to the current position, rotated to the positive
			# quadrant and translated outward by corner radius.
			var pos_reoriented_slope := Utility.get_relative_slope(
				heading,
				left_flow,
				pos,
				Vector2(CORNER_RADIUS, CORNER_RADIUS)
			);

			# The slope of the flow from the left tile's flow
			# to the right tile's flow, rotated to the positive
			# quadrant and translated to the nearest corner.
			var max_reoriented_slope := Utility.get_relative_slope(
				heading,
				left_flow,
				right_flow,
				Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
			);

			if pos_reoriented_slope <= max_reoriented_slope:
				return left_flow;
			else:
				return right_flow;
		
		elif prev_reoriented_slope < 1.0 && right_flow == region.tile_flow(left_flow):
			# The slope of the flow from the right tile's flow
			# to the current position, rotated to the positive
			# quadrant and translated outward by corner radius.
			var pos_reoriented_slope := Utility.get_relative_slope(
				heading,
				right_flow,
				pos,
				Vector2(CORNER_RADIUS, CORNER_RADIUS)
			);

			# The slope of the flow from the right tile's flow
			# to the left tile's flow, rotated to the positive
			# quadrant and translated to the nearest corner.
			var min_reoriented_slope := Utility.get_relative_slope(
				heading,
				right_flow,
				left_flow,
				Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
			);

			if pos_reoriented_slope >= min_reoriented_slope:
				return right_flow;
			else:
				return left_flow;
	
	# Wall To Left
	if has_wall_to_left:
		if prev_reoriented_slope > 1.0:
			return prev;
		elif prev_reoriented_slope == 1.0:
			return prev_flow;
	
	# Wall to Right
	if has_wall_to_right:
		if prev_reoriented_slope < 1.0 && prev_reoriented_slope >= 0.0:
			return prev;
		elif prev_reoriented_slope == 1.0:
			return prev_flow;
	
	# -- Complex Check -- #
	
	if !has_wall_to_left:
		
		# Check 1
		if left_flow == prev_flow:
			var left_reoriented_slope := Utility.get_relative_slope(
				heading,
				left_flow,
				left_pos,
				Vector2(-CORNER_RADIUS, CORNER_RADIUS)
			);
			
			if left_reoriented_slope >= 1.0:
				return left_flow;
		
		# Checks 2-3
		if prev_reoriented_slope >= 1.0:
			
			# Check 2
			if super_prev_flow == left_flow:
				var max_reoriented_slope := Utility.get_relative_slope(
					heading,
					left_flow,
					prev_flow,
					Vector2(CORNER_RADIUS, CORNER_RADIUS)
				);
				
				var pos_reoriented_slope := Utility.get_relative_slope(
					heading,
					prev_flow,
					pos,
					Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
				);
				
				if pos_reoriented_slope <= max_reoriented_slope:
					return left_flow;
				else:
					return prev_flow;
			
			# Check 3
			elif prev_flow == region.tile_flow(left_flow):
				var max_reoriented_slope := Utility.get_relative_slope(
					heading,
					prev_flow,
					left_flow,
					Vector2(CORNER_RADIUS, CORNER_RADIUS)
				);
				
				var pos_reoriented_slope := Utility.get_relative_slope(
					heading,
					left_flow,
					pos,
					Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
				);
				
				if pos_reoriented_slope <= max_reoriented_slope:
					return left_flow;
				else:
					return prev_flow;
	
	
	
	if !has_wall_to_right:
		
		# Check 1
		if right_flow == prev_flow:
			var right_reoriented_slope := Utility.get_relative_slope(
				heading,
				right_flow,
				right_pos,
				Vector2(CORNER_RADIUS, -CORNER_RADIUS)
			);
			
			if right_reoriented_slope <= 1.0 && right_reoriented_slope >= 0.0:
				return right_flow;
		
		# Checks 2-3
		if prev_reoriented_slope <= 1.0 && prev_reoriented_slope >= 0.0:
			
			# Check 2
			if super_prev_flow == right_flow:
				var min_reoriented_slope := Utility.get_relative_slope(
					heading,
					right_flow,
					prev_flow,
					Vector2(CORNER_RADIUS, CORNER_RADIUS)
				);
				
				var pos_reoriented_slope := Utility.get_relative_slope(
					heading,
					prev_flow,
					pos,
					Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
				);
				
				if pos_reoriented_slope >= min_reoriented_slope:
					return right_flow;
				else:
					return prev_flow;
			
			# Check 3
			elif prev_flow == region.tile_flow(right_flow):
				var min_reoriented_slope := Utility.get_relative_slope(
					heading,
					prev_flow,
					right_flow,
					Vector2(CORNER_RADIUS, CORNER_RADIUS)
				);
				
				var pos_reoriented_slope := Utility.get_relative_slope(
					heading,
					right_flow,
					pos,
					Vector2(-CORNER_RADIUS, -CORNER_RADIUS)
				);
				
				if pos_reoriented_slope >= min_reoriented_slope:
					return right_flow;
				else:
					return prev_flow;
	
	# Default Case #
	
	return prev;
