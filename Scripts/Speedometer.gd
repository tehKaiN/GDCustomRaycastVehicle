extends Label

@export(NodePath) onready var vehicle = get_node(vehicle) as RigidBody3D

func _physics_process(delta: float) -> void:
	var speed : float = (vehicle.linear_velocity) * vehicle.global_transform.basis.z
	text = "%d KM/H" % [speed * 3.6]
