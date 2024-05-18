class_name SuspensionAnimator
extends MeshInstance3D

# public variables
@export var trackThickness : float = 0.05
@export var returnSpeed : float = 6.0
@export var boneName : String
@export var raycast: DriveElement
@export var track_skeleton : Skeleton3D

# private variables
var track_bone
var track_offset : Vector3 = Vector3(0, trackThickness, 0)

func _ready() -> void:
	# setup references
	track_bone = track_skeleton.find_bone(boneName)
	if boneName == null:
		boneName = self.name

func _physics_process(delta) -> void:
	# set the wheel position
	if raycast.is_colliding():
		transform.origin.y = (raycast.to_local(raycast.get_collision_point())).y
	else:
		transform.origin.y = lerp(transform.origin.y, raycast.castTo.y, returnSpeed * delta)
	# deform the track based on wheel position
	var track_bone_pos = track_skeleton.get_bone_global_pose(track_bone)
	track_bone_pos.origin = (global_transform.origin + track_offset) * track_skeleton.global_transform
	track_skeleton.set_bone_global_pose_override(track_bone, track_bone_pos, 1.0, true)

