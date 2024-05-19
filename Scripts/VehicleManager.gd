class_name VehicleManager
extends Node

@export var vehiclePath: NodePath

var vehicle : RigidBody3D
var vehicleStartTransform : Transform3D

func _ready():
	vehicle = get_node(vehiclePath)
	vehicleStartTransform = vehicle.global_transform

func _physics_process(delta):
	if Input.is_action_pressed("reset_vehicle"):
		vehicle.linear_velocity = Vector3()
		vehicle.angular_velocity = Vector3()
		vehicle.global_transform = vehicleStartTransform
