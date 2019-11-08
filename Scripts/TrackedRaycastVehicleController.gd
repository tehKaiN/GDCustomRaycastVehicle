extends RigidBody

# control variables
export var enginePower : float = 300.0
var rayElements = []
var drivePerRay = enginePower

var leftTrackMat : SpatialMaterial
var rightTrackMat : SpatialMaterial

func handleTankDrive(delta) -> void:
	# skid steering (with neutral steer) setup
	for ray in rayElements:
		var dir = 0
		if Input.is_action_pressed("ui_up"):
			dir += 1
		if Input.is_action_pressed("ui_down"):
			dir -= 1
		if Input.is_action_pressed("ui_left"):
			if ray.transform.origin.x > 0: # ray is on the left side
				dir -= 1
			else:
				dir += 1
		if Input.is_action_pressed("ui_right"):
			if ray.transform.origin.x > 0: # ray is on the left side
				dir += 1
			else:
				dir -= 1
		ray.applyDriveForce(dir * global_transform.basis.z * drivePerRay * delta)


func _ready() -> void:
	leftTrackMat = $Visuals/TrackArmatureL/TrackL.mesh.surface_get_material(0)
	rightTrackMat = $Visuals/TrackArmatureR/TrackR.mesh.surface_get_material(0)
	# setup array of drive elements and setup drive power
	for node in get_children():
		if node is RayCast:
			rayElements.append(node)
	drivePerRay = enginePower / rayElements.size()
	print("Found ", rayElements.size(), " raycasts connected to vehicle, setting to provide ", drivePerRay, " power each.") 
	
	
func _physics_process(delta) -> void:
	handleTankDrive(delta)