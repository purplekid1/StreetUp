extends Node3D

const TEAM_SIZE := 7
const FIELD_HALF_LENGTH := 40.0
const FIELD_HALF_WIDTH := 20.0
const ENDZONE_DEPTH := 8.0
const PLAYER_SPEED := 6.0
const BALL_CARRIER_SPEED := 7.5
const TACKLE_DISTANCE := 1.6
const START_Y := 0.6

var blue_team: Array[Node3D] = []
var red_team: Array[Node3D] = []
var ball: Node3D
var blue_score := 0
var red_score := 0
var possession := "blue"
var ball_carrier_index := 0

func _ready() -> void:
	_setup_world()
	_spawn_teams()
	_spawn_ball()
	_reset_play("blue")

func _physics_process(delta: float) -> void:
	_update_ai(delta)
	_update_ball()
	_check_tackle()
	_check_score()

func _setup_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -40.0, 0.0)
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 52.0, 42.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.current = true
	add_child(camera)

	_add_field()

func _add_field() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, FIELD_HALF_LENGTH * 2.0)
	ground.mesh = ground_mesh
	ground.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	ground.material_override = _make_material(Color(0.12, 0.45, 0.16, 1.0))
	add_child(ground)

	var blue_endzone := MeshInstance3D.new()
	var blue_mesh := PlaneMesh.new()
	blue_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, ENDZONE_DEPTH)
	blue_endzone.mesh = blue_mesh
	blue_endzone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	blue_endzone.position = Vector3(0.0, 0.01, -FIELD_HALF_LENGTH + ENDZONE_DEPTH * 0.5)
	blue_endzone.material_override = _make_material(Color(0.1, 0.28, 0.9, 1.0))
	add_child(blue_endzone)

	var red_endzone := MeshInstance3D.new()
	var red_mesh := PlaneMesh.new()
	red_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, ENDZONE_DEPTH)
	red_endzone.mesh = red_mesh
	red_endzone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	red_endzone.position = Vector3(0.0, 0.01, FIELD_HALF_LENGTH - ENDZONE_DEPTH * 0.5)
	red_endzone.material_override = _make_material(Color(0.85, 0.12, 0.14, 1.0))
	add_child(red_endzone)

func _spawn_teams() -> void:
	for i in TEAM_SIZE:
		var lane := lerp(-FIELD_HALF_WIDTH + 2.5, FIELD_HALF_WIDTH - 2.5, float(i) / float(max(1, TEAM_SIZE - 1)))
		var blue := _spawn_player(Color(0.2, 0.4, 1.0, 1.0), Vector3(lane, START_Y, -10.0))
		blue_team.append(blue)

		var red := _spawn_player(Color(1.0, 0.2, 0.2, 1.0), Vector3(lane, START_Y, 10.0))
		red_team.append(red)

func _spawn_player(color: Color, spawn_position: Vector3) -> Node3D:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.mid_height = 1.2
	capsule.radius = 0.45
	body.mesh = capsule
	body.material_override = _make_material(color)
	body.position = spawn_position
	add_child(body)
	return body

func _spawn_ball() -> void:
	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	(ball as MeshInstance3D).mesh = sphere
	(ball as MeshInstance3D).material_override = _make_material(Color(0.95, 0.85, 0.25, 1.0))
	add_child(ball)

func _update_ai(delta: float) -> void:
	var offense := blue_team if possession == "blue" else red_team
	var defense := red_team if possession == "blue" else blue_team
	var direction := 1.0 if possession == "blue" else -1.0

	for i in offense.size():
		var player := offense[i]
		if i == ball_carrier_index:
			var forward_target := Vector3(player.position.x, START_Y, player.position.z + direction * 5.0)
			player.position = player.position.move_toward(forward_target, BALL_CARRIER_SPEED * delta)
		else:
			var lane_target := Vector3(player.position.x, START_Y, player.position.z + direction * 1.5)
			player.position = player.position.move_toward(lane_target, PLAYER_SPEED * delta)

	for i in defense.size():
		var defender := defense[i]
		var target := offense[ball_carrier_index].position
		defender.position = defender.position.move_toward(Vector3(target.x, START_Y, target.z), PLAYER_SPEED * delta)

func _update_ball() -> void:
	var offense := blue_team if possession == "blue" else red_team
	if offense.is_empty():
		return
	var carrier := offense[ball_carrier_index]
	ball.position = carrier.position + Vector3(0.0, 0.85, 0.0)

func _check_tackle() -> void:
	var offense := blue_team if possession == "blue" else red_team
	var defense := red_team if possession == "blue" else blue_team
	var carrier := offense[ball_carrier_index]

	for defender in defense:
		if defender.position.distance_to(carrier.position) <= TACKLE_DISTANCE:
			_reset_play("red" if possession == "blue" else "blue")
			return

func _check_score() -> void:
	var offense := blue_team if possession == "blue" else red_team
	var carrier := offense[ball_carrier_index]

	if possession == "blue" and carrier.position.z >= FIELD_HALF_LENGTH - ENDZONE_DEPTH:
		blue_score += 1
		print("BLUE TD | SCORE %d - %d" % [blue_score, red_score])
		_reset_play("red")
	elif possession == "red" and carrier.position.z <= -FIELD_HALF_LENGTH + ENDZONE_DEPTH:
		red_score += 1
		print("RED TD | SCORE %d - %d" % [blue_score, red_score])
		_reset_play("blue")

func _reset_play(new_possession: String) -> void:
	possession = new_possession
	ball_carrier_index = randi_range(0, TEAM_SIZE - 1)

	for i in TEAM_SIZE:
		var lane := lerp(-FIELD_HALF_WIDTH + 2.5, FIELD_HALF_WIDTH - 2.5, float(i) / float(max(1, TEAM_SIZE - 1)))
		blue_team[i].position = Vector3(lane, START_Y, -10.0)
		red_team[i].position = Vector3(lane, START_Y, 10.0)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
