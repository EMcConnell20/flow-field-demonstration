extends Node

const UP := Vector2i.UP;
const RIGHT := Vector2i.RIGHT;
const DOWN := Vector2i.DOWN;
const LEFT := Vector2i.LEFT;

const UP_RIGHT := UP + RIGHT;
const DOWN_RIGHT := DOWN + RIGHT;
const UP_LEFT := UP + LEFT;
const DOWN_LEFT := DOWN + LEFT;

## Provides a handful of utility functions.

## Returns the heading 45° to the left of given heading.
func left_shoulder(heading: Vector2i) -> Vector2i:
	match heading:
		UP_LEFT: return LEFT;
		UP: return UP_LEFT;
		UP_RIGHT: return UP;
		RIGHT: return UP_RIGHT;
		DOWN_RIGHT: return RIGHT;
		DOWN: return DOWN_RIGHT;
		DOWN_LEFT: return DOWN;
		LEFT: return DOWN_LEFT;
		_: assert(false, "invalid heading");
	
	return UP_LEFT;

## Returns the heading 45° to the right of given heading.
func right_shoulder(heading: Vector2i) -> Vector2i:
	match heading:
		UP_LEFT: return UP;
		UP: return UP_RIGHT;
		UP_RIGHT: return RIGHT;
		RIGHT: return DOWN_RIGHT;
		DOWN_RIGHT: return DOWN;
		DOWN: return DOWN_LEFT;
		DOWN_LEFT: return LEFT;
		LEFT: return UP_LEFT;
		_: assert(false, "invalid heading");
	
	return UP_LEFT;

## When given a diagonal heading, will rotate [member vec] from the heading's
## quadrant (on a graph) to the positive quadrant (DOWN_RIGHT).[br][br]
func rotate_from_heading(heading: Vector2i, vec: Vector2) -> Vector2:
	match heading:
		UP_LEFT: return Vector2(-vec.x, -vec.y);
		UP_RIGHT: return Vector2(-vec.y, vec.x);
		DOWN_RIGHT: return vec;
		DOWN_LEFT: return Vector2(vec.y, -vec.x);
		_: return vec;

func get_relative_slope(heading: Vector2i, from: Vector2, to: Vector2, offset: Vector2) -> float:
	var vec := rotate_from_heading(heading, to - from);
	vec += offset;
	return vec.y / vec.x;
