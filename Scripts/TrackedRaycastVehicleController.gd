class_name TrackedRaycastVehicleController
extends RigidBody3D

enum DriveMode {
	DOUBLE_DIFF,
	BRAKED_DIFF,
	DIRECT_FORCES,
}

@export var driveTrainMode: DriveMode = DriveMode.DOUBLE_DIFF
@export var invertSteerWhenReverse := false

@export var enginePower: float = 150
@export var torqueCurve: Curve

@export var maxSpeedKph := 65.0
@export var maxReverseSpeedKph := 20.0

@export var trackBrakePercent := 0.1
@export var trackBrakingSpeed := 0.1
@export var rollingResistance := 0.02

@export var autoStopSpeedMS := 1.0

@export var left_track: TrackAnimator
@export var right_track: TrackAnimator

var _drive_per_ray := enginePower
var _current_drive_power := 0.0
var _current_steer_brake_power := 0.0
var _current_speed := 0.0
var _last_steer_value := 0.0

func _handle_physics(delta) -> void:
	# get throttle and steering input
	var forward_drive := Input.get_axis("reverse", "forward")
	var steering := Input.get_axis("steer_left", "steer_right")

	# Invert steering when reversing if enabled
	if forward_drive < 0 && invertSteerWhenReverse:
		steering *= - 1

	# calculate speed interpolation
	var speed_interp: float
	# forward, use forward max speed
	if forward_drive > 0:
		speed_interp = remap(absf(_current_speed), 0.0, maxSpeedKph / 3.6, 0.0, 1.0)
	# reverse, use reverse max speed
	elif forward_drive < 0:
		speed_interp = remap(absf(_current_speed), 0.0, maxReverseSpeedKph / 3.6, 0.0, 1.0)
	# steering drive (always at start of curve)
	elif forward_drive == 0 && steering != 0:
		speed_interp = 0

	# get force from torque curve (based on current speed)
	_current_drive_power = torqueCurve.sample_baked(speed_interp) * _drive_per_ray

	# handle drive and braking for tracks depending on mode
	if driveTrainMode == DriveMode.DOUBLE_DIFF:
		# double differential setup (steer with control of drive force)
		var left_force := Vector3.ZERO
		var right_force := Vector3.ZERO
		var braking := rollingResistance

		# calculate drive forces
		var left_drive_factor := forward_drive + steering
		var right_drive_factor := forward_drive + steering * - 1
		left_force = global_transform.basis.z * _current_drive_power * left_drive_factor
		right_force = global_transform.basis.z * _current_drive_power * right_drive_factor

		# no brakes during normal driving
		if left_drive_factor != 0 || right_drive_factor != 0:
			braking = 0

		# slow down if input opposite drive direction
		if signf(_current_speed) != signf(forward_drive):
			braking = trackBrakePercent * absf(forward_drive)

		# apply parking brake if sitting still
		if forward_drive == 0 && steering == 0 && absf(_current_speed) < autoStopSpeedMS:
			braking = trackBrakePercent

		# finally apply all forces and braking
		for element: DriveElement in left_track.road_wheels:
			element.apply_force(left_force)
			element.apply_brake(braking)

		for element: DriveElement in right_track.road_wheels:
			element.apply_force(right_force)
			element.apply_brake(braking)

	elif driveTrainMode == DriveMode.BRAKED_DIFF:
		# braked differential setup (steer with braking)
		var drive_force := Vector3.ZERO
		var left_braking := rollingResistance
		var right_braking := rollingResistance

		# calculate drive force
		drive_force = global_transform.basis.z * _current_drive_power * forward_drive

		# reset steering if opposite input used
		if signf(steering) != signf(_last_steer_value):
			_current_steer_brake_power = 0
		# gradually increase steering brake and decay if no steering applied
		if steering != 0:
			var target_brake_power := absf(steering) * trackBrakePercent
			_current_steer_brake_power = move_toward(_current_steer_brake_power, target_brake_power, trackBrakingSpeed * delta)
		else:
			_current_steer_brake_power = move_toward(_current_steer_brake_power, 0, trackBrakingSpeed * delta)
		# set last steer value
		_last_steer_value = steering

		# calculate steering brake
		if steering < 0:
			left_braking = _current_steer_brake_power * absf(steering)
			right_braking = 0
		else:
			left_braking = 0
			right_braking = _current_steer_brake_power * absf(steering)

		# slow down if input opposite drive direction
		if signf(_current_speed) != signf(forward_drive):
			left_braking = trackBrakePercent * absf(forward_drive)
			right_braking = trackBrakePercent * absf(forward_drive)

		# apply parking brake if sitting still
		if forward_drive == 0 && steering == 0 && absf(_current_speed) < autoStopSpeedMS:
			left_braking = trackBrakePercent
			right_braking = trackBrakePercent

		# finally apply all forces and braking
		for element: DriveElement in left_track.road_wheels:
			element.apply_force(drive_force)
			element.apply_brake(left_braking)

		for element: DriveElement in right_track.road_wheels:
			element.apply_force(drive_force)
			element.apply_brake(right_braking)

	elif driveTrainMode == DriveMode.DIRECT_FORCES:
		# Drive and turn using direct forces on vehicle body
		# recalculate engine power
		if signf(_current_speed) != signf(forward_drive):
			speed_interp = 0
		_current_drive_power = torqueCurve.interpolate_baked(speed_interp) * enginePower / 2

		# calculate track forces
		var left_drive_force := global_transform.basis.z * _current_drive_power * (forward_drive + steering)
		var right_drive_force := global_transform.basis.z * _current_drive_power * (forward_drive + steering * - 1)

		# check grounded status
		var is_left_track_grounded := false
		var is_right_track_grounded := false
		for element: DriveElement in left_track.road_wheels:
			if element.grounded:
				is_left_track_grounded = true
		for element: DriveElement in right_track.road_wheels:
			if element.grounded:
				is_right_track_grounded = true

		# apply track forces
		if is_left_track_grounded:
			apply_force(left_drive_force, to_global(Vector3(1.5, -0.2, 0)) - global_transform.origin)
		if is_right_track_grounded:
			apply_force(right_drive_force, to_global(Vector3( - 1.5, -0.2, 0)) - global_transform.origin)

func _ready() -> void:
	# setup arrays of drive elements and setup drive power
	_drive_per_ray = enginePower / (left_track.road_wheels.size() + right_track.road_wheels.size())
	print("Found %d track elements connected to vehicle. Each driveElement providing %.2f force each." % [left_track.road_wheels.size() + right_track.road_wheels.size(), _drive_per_ray])

func _physics_process(delta) -> void:
	# calculate forward speed
	_current_speed = (linear_velocity * global_transform.basis).z
	_handle_physics(delta)
