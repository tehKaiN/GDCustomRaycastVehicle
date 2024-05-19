class_name TrackAnimator
extends MeshInstance3D

# public variables
@export var road_wheels : Array[DriveElement]
@export var sprocket : MeshInstance3D
@export var idler : MeshInstance3D
@export var wheelSpeedScaling : float = 1.0
@export var sprocketSpeedScaling : float = 1.6
@export var idlerSpeedScaling : float = 1.5
@export var trackUVScaling : float = 1.0
@export var animate_track_texture := true

# private variables
var track_material : StandardMaterial3D
var last_position := Vector3.ZERO

func _ready() -> void:
	# setup references
	track_material = mesh.surface_get_material(0)

func _physics_process(delta: float) -> void:
	# obtain velocity of the track
	var instant_velocity := (global_transform.origin - last_position) / delta
	var velocity_z := (instant_velocity * global_transform.basis).z
	last_position = global_transform.origin

	# animate wheels
	for wheel: DriveElement in road_wheels:
		wheel.rotate_x(velocity_z * wheelSpeedScaling * delta)

	# animate drive sprocket and idler
	sprocket.rotate_x(velocity_z * sprocketSpeedScaling * delta)
	idler.rotate_x(velocity_z * idlerSpeedScaling * delta)

	if animate_track_texture:
		# animate track texture
		track_material.uv1_offset.y += (velocity_z * trackUVScaling) * delta

		# clamp UV offset of tracks
		if track_material.uv1_offset.y > 1.0 or track_material.uv1_offset.y < -1.0:
			track_material.uv1_offset.y = 0.0
