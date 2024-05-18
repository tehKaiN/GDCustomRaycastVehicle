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

@export var left_drive_elements: Array[DriveElement] = []
@export var right_drive_elements: Array[DriveElement] = []

var _drive_per_ray := enginePower
var _current_drive_power := 0.0
var _current_steer_brake_power := 0.0
var _current_speed := 0.0
var _last_steer_value := 0.0

func _handle_physics(delta) -> void:
	# get throttle and steering input
	var forwardDrive := Input.get_axis("reverse", "forward")
	var steering := Input.get_axis("steer_left", "steer_right")

	# Invert steering when reversing if enabled
	if forwardDrive < 0 && invertSteerWhenReverse:
		steering *= - 1

	# calculate speed interpolation
	var speedInterp: float
	# forward, use forward max speed
	if forwardDrive > 0:
		speedInterp = remap(absf(_current_speed), 0.0, maxSpeedKph / 3.6, 0.0, 1.0)
	# reverse, use reverse max speed
	elif forwardDrive < 0:
		speedInterp = remap(absf(_current_speed), 0.0, maxReverseSpeedKph / 3.6, 0.0, 1.0)
	# steering drive (always at start of curve)
	elif forwardDrive == 0 && steering != 0:
		speedInterp = 0

	# get force from torque curve (based on current speed)
	_current_drive_power = torqueCurve.sample_baked(speedInterp) * _drive_per_ray

	# handle drive and braking for tracks depending on mode
	if driveTrainMode == DriveMode.DOUBLE_DIFF:
		# double differential setup (steer with control of drive force)
		var leftForce := Vector3.ZERO
		var rightForce := Vector3.ZERO
		var braking := rollingResistance

		# calculate drive forces
		var LDriveFac := forwardDrive + steering
		var RDriveFac := forwardDrive + steering * - 1
		leftForce = global_transform.basis.z * _current_drive_power * LDriveFac
		rightForce = global_transform.basis.z * _current_drive_power * RDriveFac

		# no brakes during normal driving
		if LDriveFac != 0 || RDriveFac != 0:
			braking = 0

		# slow down if input opposite drive direction
		if signf(_current_speed) != signf(forwardDrive):
			braking = trackBrakePercent * absf(forwardDrive)

		# apply parking brake if sitting still
		if forwardDrive == 0 && steering == 0 && absf(_current_speed) < autoStopSpeedMS:
			braking = trackBrakePercent

		# finally apply all forces and braking
		for element in left_drive_elements:
			element.apply_force(leftForce)
			element.apply_brake(braking)

		for element in right_drive_elements:
			element.apply_force(rightForce)
			element.apply_brake(braking)

	elif driveTrainMode == DriveMode.BRAKED_DIFF:
		# braked differential setup (steer with braking)
		var driveForce := Vector3.ZERO
		var leftBraking := rollingResistance
		var rightBraking := rollingResistance

		# calculate drive force
		driveForce = global_transform.basis.z * _current_drive_power * forwardDrive

		# reset steering if opposite input used
		if signf(steering) != signf(_last_steer_value):
			_current_steer_brake_power = 0
		# gradually increase steering brake and decay if no steering applied
		if steering != 0:
			var desiredBrakePower := absf(steering) * trackBrakePercent
			_current_steer_brake_power = move_toward(_current_steer_brake_power, desiredBrakePower, trackBrakingSpeed * delta)
		else:
			_current_steer_brake_power = move_toward(_current_steer_brake_power, 0, trackBrakingSpeed * delta)
		# set last steer value
		_last_steer_value = steering

		# calculate steering brake
		if steering < 0:
			leftBraking = _current_steer_brake_power * absf(steering)
			rightBraking = 0
		else:
			leftBraking = 0
			rightBraking = _current_steer_brake_power * absf(steering)

		# slow down if input opposite drive direction
		if signf(_current_speed) != signf(forwardDrive):
			leftBraking = trackBrakePercent * absf(forwardDrive)
			rightBraking = trackBrakePercent * absf(forwardDrive)

		# apply parking brake if sitting still
		if forwardDrive == 0 && steering == 0 && absf(_current_speed) < autoStopSpeedMS:
			leftBraking = trackBrakePercent
			rightBraking = trackBrakePercent

		# finally apply all forces and braking
		for element in left_drive_elements:
			element.apply_force(driveForce)
			element.apply_brake(leftBraking)

		for element in right_drive_elements:
			element.apply_force(driveForce)
			element.apply_brake(rightBraking)

	elif driveTrainMode == DriveMode.DIRECT_FORCES:
		# Drive and turn using direct forces on vehicle body
		# recalculate engine power
		if signf(_current_speed) != signf(forwardDrive):
			speedInterp = 0
		_current_drive_power = torqueCurve.interpolate_baked(speedInterp) * enginePower / 2

		# calculate track forces
		var leftDriveForce := global_transform.basis.z * _current_drive_power * (forwardDrive + steering)
		var rightDriveForce := global_transform.basis.z * _current_drive_power * (forwardDrive + steering * - 1)

		# check grounded status
		var leftTrackGrounded := false
		var rightTrackGrounded := false
		for element in left_drive_elements:
			if element.grounded:
				leftTrackGrounded = true
		for element in right_drive_elements:
			if element.grounded:
				rightTrackGrounded = true

		# apply track forces
		if leftTrackGrounded:
			apply_force(leftDriveForce, to_global(Vector3(1.5, -0.2, 0)) - global_transform.origin)
		if rightTrackGrounded:
			apply_force(rightDriveForce, to_global(Vector3( - 1.5, -0.2, 0)) - global_transform.origin)

func _ready() -> void:
	# setup arrays of drive elements and setup drive power
	_drive_per_ray = enginePower / (left_drive_elements.size() + right_drive_elements.size())
	print("Found %d track elements connected to vehicle. Each driveElement providing %.2f force each." % [left_drive_elements.size() + right_drive_elements.size(), _drive_per_ray])

func _physics_process(delta) -> void:
	# calculate forward speed
	_current_speed = (linear_velocity * global_transform.basis).z
	_handle_physics(delta)
