extends MeshInstance3D

# public variables
@export var roadWheelPaths : Array
@export var sprocketPath: NodePath
@export var idlerPath: NodePath
@export var wheelSpeedScaling : float = 1.0
@export var sprocketSpeedScaling : float = 1.6
@export var idlerSpeedScaling : float = 1.5
@export var trackUVScaling : float = 1.0

# private variables
var roadWheels : Array
var sprocket : MeshInstance3D
var idler : MeshInstance3D
var trackMat : StandardMaterial3D
var lastPos : Vector3 = Vector3()

func _ready() -> void:
	# setup references
	sprocket = get_node(sprocketPath)
	idler = get_node(idlerPath)
	for wheel in roadWheelPaths:
		roadWheels.append(get_node(wheel))
	trackMat = mesh.surface_get_material(0)

func _physics_process(delta) -> void:
	# obtain velocity of the track
	var instantV = (global_transform.origin - lastPos) / delta
	var ZVel = (instantV * global_transform.basis).z
	lastPos = global_transform.origin
		
	# animate wheels
	# NOTE: The rotation is bugged in 3.1, it's fixed in 3.2 Beta 1
	for wheel in roadWheels:
		wheel.rotate_x(ZVel * wheelSpeedScaling * delta)
		
	# animate drive sprocket and idler
	sprocket.rotate_x(ZVel * sprocketSpeedScaling * delta)
	idler.rotate_x(ZVel * idlerSpeedScaling * delta)
	
	# animate track texture
	trackMat.uv1_offset.y += (ZVel * trackUVScaling) * delta
	
	# clamp UV offset of tracks	
	if trackMat.uv1_offset.y > 1.0 or trackMat.uv1_offset.y < -1.0:
		trackMat.uv1_offset.y = 0.0
