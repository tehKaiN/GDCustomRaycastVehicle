class_name DriveElement
extends Node3D

# control variables
@export var shape: Shape3D
@export_flags_3d_physics var mask: int = 1
@export var castTo: Vector3 = Vector3(0, -1, 0)
@export var springMaxForce: float = 300.0
@export var springForce: float = 180.0
@export var stiffness: float = 0.85
@export var damping: float = 0.05
@export var Xtraction: float = 1.0
@export var Ztraction: float = 0.15
@export var staticSlideThreshold: float = 0.005
@export var massKG: float = 100.0
@export var equilibrium_offset := Vector3(0, 0, 0)

# public variables
var instant_linear_velocity: Vector3

# private variables
@onready var _parent_body: RigidBody3D = get_parent()
@onready var _previous_distance: float = absf(castTo.y)
@onready var _collision_point: Vector3 = castTo
var _previous_hit: ShapeCastResult = ShapeCastResult.new()
var _is_grounded: bool = false
var _cast_params: PhysicsShapeQueryParameters3D

# shape cast result storage class
class ShapeCastResult:
	var is_hit: bool
	var hit_distance: float
	var hit_position: Vector3
	var hit_normal: Vector3
	var hit_point_velocity: Vector3
	var hit_body: PhysicsBody3D

# function to do sphere casting
func shape_cast(origin: Vector3, offset: Vector3) -> ShapeCastResult:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state as PhysicsDirectSpaceState3D

	# cast motion to get max motion possible with this cast
	_cast_params.transform.origin = origin - offset
	_cast_params.motion = offset * 2
	var castResult = space.cast_motion(_cast_params)

	var result: ShapeCastResult = ShapeCastResult.new()

	result.hit_distance = (-1 + 2 * castResult[0]) * offset.length()
	result.hit_position = origin - offset + 2 * offset * castResult[0]

	# offset the params to the cast hit point and get rest info for more information
	_cast_params.transform.origin += 2 * offset * castResult[1]
	var collision = space.get_rest_info(_cast_params)

	result.hit_normal = collision.get("normal", Vector3.ZERO)
	result.hit_point_velocity = Vector3.ZERO
	result.hit_body = null

	# if a valid object has been hit
	if collision.get("rid"):
		# get the reference to the actual PhysicsBody that we are in contact with
		result.hit_body = instance_from_id(PhysicsServer3D.body_get_object_instance_id(collision.get("rid")))
		# get the velocity of the hit body at point of contact
		var hitBodyState := PhysicsServer3D.body_get_direct_state(collision.get("rid"))
		var hitBodyPoint: Vector3 = collision.get("point")
		result.hit_point_velocity = hitBodyState.get_velocity_at_local_position(hitBodyPoint * hitBodyState.transform)
		if GameState.debugMode:
			DrawLine3D.DrawRay(result.hit_position, result.hit_point_velocity, Color(0, 0, 0))

	return result

# getter for collision point
func get_collision_point() -> Vector3:
	return _collision_point

# getter for collision check
func is_colliding() -> bool:
	return _is_grounded

# set forward friction (braking)
func apply_brake(amount: float=0.0) -> void:
	Ztraction = maxf(0.0, amount)

# function for applying drive force to parent body (if _is_grounded)
func apply_force(force: Vector3) -> void:
	if is_colliding():
		_parent_body.apply_force(force, get_collision_point() - _parent_body.global_transform.origin)

func _ready() -> void:
	_cast_params = PhysicsShapeQueryParameters3D.new()
	_cast_params.collision_mask = mask
	_cast_params.set_shape(shape)
	_cast_params.transform = transform
	# exclude parent body!
	_cast_params.exclude = [_parent_body]

func _physics_process(delta: float) -> void:
	# perform sphere cast
	var equilibrium_point := global_transform.origin + equilibrium_offset
	var cast_result = shape_cast(equilibrium_point, castTo)
	_collision_point = cast_result.hit_position
	if GameState.debugMode:
		DrawLine3D.DrawCube(equilibrium_point - castTo, 0.1, Color.DARK_MAGENTA)
		DrawLine3D.DrawCube(equilibrium_point, 0.1, Color.MAGENTA)
		DrawLine3D.DrawCube(equilibrium_point + castTo, 0.1, Color.DARK_MAGENTA)

	if cast_result.hit_distance < absf(castTo.y):
		# if grounded, handle forces
		_is_grounded = true
		if GameState.debugMode:
			DrawLine3D.DrawCube(cast_result.hit_position, 0.04, Color.CYAN)
			DrawLine3D.DrawRay(cast_result.hit_position, cast_result.hit_normal, Color(255, 255, 255))

		# obtain instantaneaous linear velocity
		instant_linear_velocity = (_collision_point - _previous_hit.hit_position) / delta

		# apply spring force with damping force
		var current_distance: float = cast_result.hit_distance
		var spring_force := stiffness * (absf(castTo.y) - current_distance)
		var damp_force := damping * (_previous_distance - current_distance) / delta
		var suspension_force := clampf((spring_force + damp_force) * springForce, 0, springMaxForce)
		var suspension_force_vec: Vector3 = cast_result.hit_normal * suspension_force

		# obtain axis velocity
		var local_velocity: Vector3 = (instant_linear_velocity - cast_result.hit_point_velocity) * global_transform.basis

		# axis deceleration forces based on this drive elements mass and current acceleration
		var acceleration_x := (-local_velocity.x * Xtraction) / delta
		var acceleration_z := (-local_velocity.z * Ztraction) / delta
		var force_x := global_transform.basis.x * acceleration_x * massKG
		var force_z := global_transform.basis.z * acceleration_z * massKG

		# counter sliding by negating off axis suspension impulse at very low speed
		var velocity_limit: float = instant_linear_velocity.length_squared() * delta
		if velocity_limit < staticSlideThreshold:
#			suspensionForceVec = Vector3.UP * suspensionForce
			force_x.x -= suspension_force_vec.x * _parent_body.global_transform.basis.y.dot(Vector3.UP)
			force_z.z -= suspension_force_vec.z * _parent_body.global_transform.basis.y.dot(Vector3.UP)

		# final impulse force vector to be applied
		var final_force = suspension_force_vec + force_x + force_z

		# draw debug lines
		if GameState.debugMode:
			DrawLine3D.DrawRay(get_collision_point(), suspension_force_vec / GameState.debugRayScaleFac, Color(0, 255, 0))
			DrawLine3D.DrawRay(get_collision_point(), force_x / GameState.debugRayScaleFac, Color(255, 0, 0))
			DrawLine3D.DrawRay(get_collision_point(), force_z / GameState.debugRayScaleFac, Color(0, 0, 255))

		# apply forces relative to parent body
		_parent_body.apply_force(final_force, get_collision_point() - _parent_body.global_transform.origin)

		# apply forces to body affected by this drive element (action = reaction)
		if cast_result.hit_body is RigidBody3D:
			cast_result.hit_body.apply_force(-final_force, get_collision_point() - cast_result.hit_body.global_transform.origin)

		# set the previous values at the very end, after they have been used
		_previous_distance = current_distance
		_previous_hit = cast_result
	else:
		# not _is_grounded, set prev values to fully extended suspension
		_is_grounded = false
		_previous_hit = ShapeCastResult.new()
		_previous_hit.hit_position = equilibrium_point + castTo
		_previous_hit.hit_distance = absf(castTo.y)
		_previous_distance = _previous_hit.hit_distance
		instant_linear_velocity = Vector3.ZERO
