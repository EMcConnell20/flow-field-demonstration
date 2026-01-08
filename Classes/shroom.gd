class_name Shroom extends Sprite2D

## A straightaway search agent.

#region Variables

var pos: Vector2i;
var heading: Vector2i;
var origin: Vector2i;
var flow_length: float;
var step_count: int;

#endregion

#region Functions

func initialize(new_position: Vector2i, new_heading: Vector2i, new_flow_length: float, new_step_count: int) -> void:
	pos = new_position;
	heading = new_heading;
	origin = new_position;
	flow_length = new_flow_length;
	step_count = new_step_count;
	
	match new_heading:
		Vector2i.UP: rotation = 0.0;
		Vector2i.RIGHT: rotation = PI / 2.0;
		Vector2i.DOWN: rotation = PI;
		Vector2i.LEFT: rotation = 3.0 * PI / 2.0;
		_: assert(false, "invalid heading");

## Takes one step forward; returns false if `self` needs to be deleted.[br][br]
## 
## [member region]: The region being stepped through.[br][br]
## 
## [member live_spores]: A list of [Spore]s that need to be added to the current step iteration.[br][br]
## 
## [member spore_destination]: A list of [Spore]s that will be added to the next step iteration.
func step(region: FlowField, live_spores: Array[Spore], spore_destination: Array[Spore]) -> bool:
	# Preparation #
	
	var tile_flow := region.tile_flow_length(pos);
	if tile_flow != flow_length:
		flow_length = tile_flow;
		origin = pos;
	
	var left_heading := Utility.left_shoulder(heading);
	var right_heading := Utility.right_shoulder(heading);
	
	var left_corner := pos + left_heading;
	var right_corner := pos + right_heading;
	
	# Origin Spores #
	
	if pos == origin:
		var left_side := pos + Utility.left_shoulder(left_heading);
		var right_side := pos + Utility.right_shoulder(right_heading);
		
		# If the side is a wall and the corner ahead is not a wall, send a spore out.
		# The spore will need to step in the same iteration as this shroom, so
		# we add it to "live_spores", since those will be processed this iteration.

		if region.tile_is_wall(left_side) && !region.tile_is_wall(left_corner):
			var spore := Spore.new();
			spore.initialize(pos, left_heading, flow_length, step_count);
			live_spores.push_back(spore);
	
		if region.tile_is_wall(right_side) && !region.tile_is_wall(right_corner):
			var spore := Spore.new();
			spore.initialize(pos, right_heading, flow_length, step_count);
			live_spores.push_back(spore);
	
	# Move Forward #
	
	pos += heading;
	flow_length += 1.0;
	
	# Visit The Next Tile #
	
	# If the new tile has a shorter flow length (or if it's a wall),
	# then the shroom can be deleted. At that point, the shroom has
	# a worse path (or an invalid path), so we don't need it anymore.
	if region.tile_has_shorter_flow(pos, flow_length):
		return false;
	
	# We set the new tile's flow to the shroom's origin
	# for one simple reason: you can't optimize a straight line.
	# The way that shrooms are created and spread out guarantees
	# that a straight line is the best option in that position.
	#
	# Well, maybe add an asterisk to that, since tiles can
	# have their flow values overwritten occasionally.
	#
	# Basically, it's because the search agents spread out
	# in a square shaped wave, it can behave a little off
	# when they converge on one point from multiple sides.
	#
	# Since the diagonal search agents travel further every
	# step, they can travel around an object faster than shrooms can.
	# However, the actual distance of their path is longer than
	# the shrooms's paths when they finally come around.
	#
	# So, the search agents branching off from the shroom
	# will overwrite the values of the tiles that were previously visited.
	#
	# Luckily, the number of tiles that have to be revisited
	# should be marginal, and I think there's a limit
	# to the number of times a tile will ever be overwritten, so it
	# isn't a big performance concern.
	#
	# Still, if anyone can figure out how to efficiently make
	# the search agents spread out in a circular wave, that
	# would prevent this issue. It might also be possible
	# with a perfect square wave (the entire wave steps in a
	# perfect square shape rather than forming multiple rectangular
	# segments as it hits obstacles), but that's a hypothesis
	# that I haven't looked into yet.
	region.set_flow(pos, origin, flow_length);
	
	# Spread Spores #
	
	if !region.tile_is_wall(pos + left_heading):
		var spore := Spore.new();
		spore.initialize(pos, left_heading, flow_length, step_count);
		spore_destination.push_back(spore);
	
	if !region.tile_is_wall(pos + right_heading):
		var spore := Spore.new();
		spore.initialize(pos, right_heading, flow_length, step_count);
		spore_destination.push_back(spore);
	
	# Continue #
	
	return true;

#endregion
