extends RigidBody3D

# control variables
@export var enginePower: float = 150.0
@export var torqueCurve: Curve

@export var maxSpeedKph: float = 100.0
@export var maxReverseSpeedKph: float = 20.0

@export var maxBrakingCoef: float = 0.05
@export var rollingResistance: float = 0.001

@export var steeringAngle: float = 30.0
@export var steerSpeed: float = 15.0
@export var maxSteerLimitRatio: float = 0.95
@export var steerReturnSpeed: float = 30.0

@export var autoStopSpeedMS: float = 1.0

@onready var frontLeftElement: Node3D = $FL_ray
@onready var frontRightElement: Node3D = $FR_ray

var driveElements : Array = []
var drivePerRay : float = enginePower

var currentDrivePower : float = 0.0
var currentSteerAngle : float = 0.0
var maxSteerAngle : float = steeringAngle

var currentSpeed : float = 0.0

func _handle_physics(delta) -> void:
	# 4WD with front wheel steering
	for driveElement in driveElements:
		var finalForce : Vector3 = Vector3.ZERO
		var finalBrake : float = rollingResistance
		
		# get throttle axis
		var forwardDrive : float = Input.get_axis("reverse", "forward")
		# get steering axis
		var steering : float = Input.get_axis("steer_left", "steer_right")
		
		# steer wheels gradualy based on steering input
		if steering != 0:
			var desiredAngle : float = steering * steeringAngle
			currentSteerAngle = move_toward(currentSteerAngle, -desiredAngle, steerSpeed * delta)
		else:
			# return wheels to center with wheel return speed
			if !is_equal_approx(currentSteerAngle, 0.0):
				if currentSteerAngle > 0.0:
					currentSteerAngle -= steerReturnSpeed * delta
				else:
					currentSteerAngle += steerReturnSpeed * delta
			else:
				currentSteerAngle = 0.0
		
		# limit steering based on speed and apply steering
		var maxSteerRatio : float = remap(currentSpeed * 3.6, 0, maxSpeedKph, 0, maxSteerLimitRatio)
		maxSteerAngle = (1 - maxSteerRatio) * steeringAngle
		currentSteerAngle = clamp(currentSteerAngle, -maxSteerAngle, maxSteerAngle)
		frontRightElement.rotation_degrees.y = currentSteerAngle
		frontLeftElement.rotation_degrees.y = currentSteerAngle

		# no braking if we are driving
		if forwardDrive != 0:
			finalBrake = 0

		# brake if movement opposite indended direction
		if sign(currentSpeed) != sign(forwardDrive) && !is_zero_approx(currentSpeed) && forwardDrive != 0:
			finalBrake = maxBrakingCoef * abs(forwardDrive)
			
		# no drive inputs, apply parking brake if sitting still
		if forwardDrive == 0 && steering == 0 && abs(currentSpeed) < autoStopSpeedMS:
			finalBrake = maxBrakingCoef
		
		# calculate motor forces
		var speedInterp : float
		if forwardDrive > 0:
			speedInterp = remap(abs(currentSpeed), 0.0, maxSpeedKph / 3.6, 0.0, 1.0)
		elif forwardDrive < 0:
			speedInterp = remap(abs(currentSpeed), 0.0, maxReverseSpeedKph / 3.6, 0.0, 1.0)
		currentDrivePower = torqueCurve.sample_baked(speedInterp) * drivePerRay
		
		finalForce = global_transform.basis.z * currentDrivePower * forwardDrive
		
		# apply drive force and braking
		driveElement.apply_force(finalForce)
		driveElement.apply_brake(finalBrake)

func _ready() -> void:
	# setup array of drive elements and setup drive power
	for node in get_children():
		if node is DriveElement:
			driveElements.append(node)
	drivePerRay = enginePower / driveElements.size()
	print("Found %d drive elements connected to wheeled vehicle, setting to provide %.2f force each." % [driveElements.size(), drivePerRay]) 
	
func _physics_process(delta) -> void:
	# calculate forward speed
	currentSpeed = (linear_velocity * global_transform.basis).z
	_handle_physics(delta)
