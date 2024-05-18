class_name TrackDriveElement
extends DriveElement

# public variables
@export var trackThickness : float = 0.05
@export var returnSpeed : float = 6.0
@export var boneName : String
@export var track_skeleton : Skeleton3D

# private variables
var _track_bone: int
var _track_offset := Vector3(0, trackThickness, 0)

func _ready() -> void:
	super()
	# setup references
	if boneName == null:
		boneName = self.name
	_track_bone = track_skeleton.find_bone(boneName)

func _physics_process(delta: float) -> void:
	super(delta)
	# set the wheel position
	if is_colliding():
		position.y = get_parent_node_3d().to_local(get_collision_point()).y
	else:
		position.y = lerp(position.y, castTo.y, returnSpeed * delta)
	# deform the track based on wheel position
	var track_bone_pos = track_skeleton.get_bone_global_pose(_track_bone)
	track_bone_pos.origin = (global_position + _track_offset) * track_skeleton.global_transform
	track_skeleton.set_bone_global_pose_override(_track_bone, track_bone_pos, 1.0, true)

