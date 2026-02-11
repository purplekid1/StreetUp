extends Node3D

const TEAM_SIZE := 7
const FIELD_HALF_LENGTH := 40.0
const FIELD_HALF_WIDTH := 20.0
const ENDZONE_DEPTH := 8.0
const PLAYER_SPEED := 6.5
const SPRINT_SPEED := 8.2
const BALL_SPEED := 23.0
const CATCH_RADIUS := 1.4
const TACKLE_DISTANCE := 1.4
const START_Y := 0.6
const PRE_SNAP_TIME := 0.8
const MAX_PLAYS_PER_DRIVE := 4
const FIRST_DOWN_YARDS := 12.0
const QB_THROW_TIME_MIN := 1.0
const QB_THROW_TIME_MAX := 2.6

const RECEIVER_INDICES := [1, 2, 3, 4]
const RB_INDEX := 5
const SLOT_INDEX := 6

var blue_team: Array[Node3D] = []
var red_team: Array[Node3D] = []
var ball: Node3D

var blue_score := 0
var red_score := 0

var possession := "blue"
var down := 1
var line_of_scrimmage_z := 0.0
var first_down_target_z := 0.0
var drive_start_z := 0.0

var offense_team: Array[Node3D] = []
var defense_team: Array[Node3D] = []
var offense_direction := 1.0

var ball_carrier_index := 0
var qb_index := 0
var play_type := "pass"
var play_phase := "pre_snap"
var play_clock := 0.0

var route_targets: Dictionary = {}
var receiver_progress: Dictionary = {}
var receiver_assignments: Dictionary = {}
var defender_assignments: Dictionary = {}

var ball_in_air := false
var ball_velocity := Vector3.ZERO
var ball_target_player := -1
var ball_target_pos := Vector3.ZERO
var pass_origin := Vector3.ZERO

func _ready() -> void:
	randomize()
	_setup_world()
	_spawn_teams()
	_spawn_ball()
	_start_drive("blue")

func _physics_process(delta: float) -> void:
	play_clock += delta
	if play_phase == "pre_snap":
		_run_presnap_alignment(delta)
		if play_clock >= PRE_SNAP_TIME:
			play_phase = "live"
			play_clock = 0.0
	elif play_phase == "live":
		_run_live_play(delta)
	_update_ball(delta)
	_check_play_end()

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

func _start_drive(team: String) -> void:
	possession = team
	down = 1
	line_of_scrimmage_z = -18.0 if possession == "blue" else 18.0
	drive_start_z = line_of_scrimmage_z
	first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
	_prepare_new_play()

func _prepare_new_play() -> void:
	offense_team = blue_team if possession == "blue" else red_team
	defense_team = red_team if possession == "blue" else blue_team
	offense_direction = offense_sign()
	play_phase = "pre_snap"
	play_clock = 0.0
	ball_in_air = false
	ball_velocity = Vector3.ZERO
	ball_target_player = -1
	route_targets.clear()
	receiver_progress.clear()
	receiver_assignments.clear()
	defender_assignments.clear()

	play_type = "run" if randf() < 0.35 else "pass"
	qb_index = 0
	ball_carrier_index = qb_index
	_assign_formations()

	print("%s | DOWN %d | LOS %.1f | TO GO %.1f | PLAY %s" % [possession.to_upper(), down, line_of_scrimmage_z, abs(first_down_target_z - line_of_scrimmage_z), play_type.to_upper()])

func _assign_formations() -> void:
	var base_x: Array[float] = [-8.0, -4.0, -1.5, 1.5, 4.0, 7.0, 10.0]
	for i in TEAM_SIZE:
		var x := base_x[i]
		var offense_z := line_of_scrimmage_z - offense_direction * 1.2
		offense_team[i].position = Vector3(x, START_Y, offense_z)
		if i == qb_index:
			offense_team[i].position.z = line_of_scrimmage_z - offense_direction * 3.4
		if i == RB_INDEX:
			offense_team[i].position = Vector3(-2.2, START_Y, line_of_scrimmage_z - offense_direction * 5.2)
		if i == SLOT_INDEX:
			offense_team[i].position = Vector3(2.6, START_Y, line_of_scrimmage_z - offense_direction * 2.2)

	for i in TEAM_SIZE:
		var x := base_x[i]
		var defense_z := line_of_scrimmage_z + offense_direction * 2.2
		defense_team[i].position = Vector3(x, START_Y, defense_z)

	for i in RECEIVER_INDICES:
		var route := _build_route_for(i)
		route_targets[i] = route
		receiver_progress[i] = 0

	_assign_coverage()

func _assign_coverage() -> void:
	var defenders := [1, 2, 3, 4]
	for idx in RECEIVER_INDICES.size():
		var receiver_id := RECEIVER_INDICES[idx]
		var defender_id := defenders[idx % defenders.size()]
		receiver_assignments[receiver_id] = defender_id
		defender_assignments[defender_id] = receiver_id

func _build_route_for(receiver_index: int) -> Array:
	var start := offense_team[receiver_index].position
	var route_depth := randf_range(8.0, 17.0)
	var inside_break := randf_range(-5.0, 5.0)
	var route_choice := randi_range(0, 2)
	if route_choice == 0:
		return [Vector3(start.x, START_Y, line_of_scrimmage_z + offense_direction * route_depth)]
	if route_choice == 1:
		return [
			Vector3(start.x, START_Y, line_of_scrimmage_z + offense_direction * (route_depth * 0.6)),
			Vector3(clamp(start.x + inside_break, -FIELD_HALF_WIDTH + 2.0, FIELD_HALF_WIDTH - 2.0), START_Y, line_of_scrimmage_z + offense_direction * route_depth)
		]
	return [
		Vector3(clamp(start.x + inside_break * 0.6, -FIELD_HALF_WIDTH + 2.0, FIELD_HALF_WIDTH - 2.0), START_Y, line_of_scrimmage_z + offense_direction * (route_depth * 0.4)),
		Vector3(clamp(start.x + inside_break * 1.2, -FIELD_HALF_WIDTH + 2.0, FIELD_HALF_WIDTH - 2.0), START_Y, line_of_scrimmage_z + offense_direction * route_depth)
	]

func _run_presnap_alignment(delta: float) -> void:
	for i in TEAM_SIZE:
		offense_team[i].position.y = START_Y
		defense_team[i].position.y = START_Y

	if ball_carrier_index == qb_index:
		ball.position = offense_team[qb_index].position + Vector3(0.0, 0.85, 0.0)

func _run_live_play(delta: float) -> void:
	_run_offense_ai(delta)
	_run_defense_ai(delta)

func _run_offense_ai(delta: float) -> void:
	var qb := offense_team[qb_index]
	if play_type == "pass":
		_move_qb_for_pass(qb, delta)
		_move_receivers(delta)
		_move_support_blockers(delta)
		if play_clock >= QB_THROW_TIME_MIN and not ball_in_air:
			_try_qb_throw()
		if play_clock >= QB_THROW_TIME_MAX and not ball_in_air:
			ball_carrier_index = qb_index
			_move_runner(qb_index, delta, true)
	else:
		if play_clock < 0.6:
			_move_qb_for_handoff(qb, delta)
			_move_receivers(delta)
		else:
			if ball_carrier_index == qb_index:
				ball_carrier_index = RB_INDEX
			_move_runner(ball_carrier_index, delta, false)
			_move_receivers(delta)
		_move_support_blockers(delta)

func _move_qb_for_pass(qb: Node3D, delta: float) -> void:
	var target := Vector3(qb.position.x, START_Y, line_of_scrimmage_z - offense_direction * 6.4)
	qb.position = qb.position.move_toward(target, PLAYER_SPEED * delta)
	if ball_carrier_index == qb_index and not ball_in_air:
		ball.position = qb.position + Vector3(0.0, 0.85, 0.0)

func _move_qb_for_handoff(qb: Node3D, delta: float) -> void:
	var target := Vector3(-1.2, START_Y, line_of_scrimmage_z - offense_direction * 4.6)
	qb.position = qb.position.move_toward(target, PLAYER_SPEED * delta)
	ball.position = qb.position + Vector3(0.0, 0.85, 0.0)

func _move_support_blockers(delta: float) -> void:
	for i in [0, SLOT_INDEX]:
		if i == qb_index and play_type == "pass":
			continue
		if i == ball_carrier_index:
			continue
		var push_target := offense_team[i].position + Vector3(0.0, 0.0, offense_direction * 3.0)
		offense_team[i].position = offense_team[i].position.move_toward(push_target, PLAYER_SPEED * 0.7 * delta)

func _move_receivers(delta: float) -> void:
	for receiver_id in RECEIVER_INDICES:
		var route: Array = route_targets.get(receiver_id, [])
		if route.is_empty():
			continue
		var step := int(receiver_progress.get(receiver_id, 0))
		if step >= route.size():
			var continue_target := offense_team[receiver_id].position + Vector3(0.0, 0.0, offense_direction * 4.0)
			offense_team[receiver_id].position = offense_team[receiver_id].position.move_toward(continue_target, SPRINT_SPEED * delta)
			continue
		var target: Vector3 = route[step]
		offense_team[receiver_id].position = offense_team[receiver_id].position.move_toward(target, SPRINT_SPEED * delta)
		if offense_team[receiver_id].position.distance_to(target) < 0.8:
			receiver_progress[receiver_id] = step + 1

func _move_runner(runner_index: int, delta: float, scramble_mode: bool) -> void:
	var runner := offense_team[runner_index]
	var nearest := _nearest_defender_to(runner.position)
	var evade_x := 0.0
	if nearest != -1:
		evade_x = clamp(runner.position.x - defense_team[nearest].position.x, -1.0, 1.0)
	var forward := offense_direction * 5.0
	var side := evade_x * (2.0 if scramble_mode else 3.4)
	var target := runner.position + Vector3(side, 0.0, forward)
	target.x = clamp(target.x, -FIELD_HALF_WIDTH + 1.2, FIELD_HALF_WIDTH - 1.2)
	runner.position = runner.position.move_toward(target, SPRINT_SPEED * delta)
	if ball_carrier_index == runner_index and not ball_in_air:
		ball.position = runner.position + Vector3(0.0, 0.85, 0.0)

func _run_defense_ai(delta: float) -> void:
	var rushers := [0, 6]
	for defender_id in TEAM_SIZE:
		var defender := defense_team[defender_id]
		var target := defender.position
		if defender_id in rushers:
			var qb_target := offense_team[qb_index].position
			if ball_carrier_index != qb_index:
				qb_target = offense_team[ball_carrier_index].position
			target = Vector3(qb_target.x, START_Y, qb_target.z)
		else:
			var receiver_id := int(defender_assignments.get(defender_id, -1))
			if receiver_id != -1:
				var receiver := offense_team[receiver_id]
				var trail := receiver.position - Vector3(0.0, 0.0, offense_direction * 1.6)
				target = Vector3(trail.x, START_Y, trail.z)
			else:
				var deep := line_of_scrimmage_z + offense_direction * 13.0
				target = Vector3(defender.position.x, START_Y, deep)
		defender.position = defender.position.move_toward(target, PLAYER_SPEED * delta)

func _try_qb_throw() -> void:
	var best_receiver := -1
	var best_score := -9999.0
	for receiver_id in RECEIVER_INDICES:
		var receiver := offense_team[receiver_id]
		var score := receiver.position.z * offense_direction
		var defender_id := int(receiver_assignments.get(receiver_id, -1))
		if defender_id != -1:
			var separation := receiver.position.distance_to(defense_team[defender_id].position)
			score += separation * 3.0
		if abs(receiver.position.x) > FIELD_HALF_WIDTH - 2.0:
			score -= 2.5
		if score > best_score:
			best_score = score
			best_receiver = receiver_id

	if best_receiver == -1:
		return

	var qb := offense_team[qb_index]
	ball_in_air = true
	pass_origin = qb.position + Vector3(0.0, 0.9, 0.0)
	ball.position = pass_origin
	ball_target_player = best_receiver
	var lead := Vector3(0.0, 0.0, offense_direction * 2.8)
	ball_target_pos = offense_team[best_receiver].position + lead
	ball_velocity = (ball_target_pos - ball.position).normalized() * BALL_SPEED
	print("%s QB THROW -> WR%d" % [possession.to_upper(), best_receiver])

func _update_ball(delta: float) -> void:
	if ball_in_air:
		ball.position += ball_velocity * delta
		if ball.position.distance_to(ball_target_pos) <= CATCH_RADIUS:
			_resolve_pass_target()
	else:
		var carrier := offense_team[ball_carrier_index]
		ball.position = carrier.position + Vector3(0.0, 0.85, 0.0)

func _resolve_pass_target() -> void:
	var receiver := offense_team[ball_target_player]
	for defender in defense_team:
		if defender.position.distance_to(ball.position) <= CATCH_RADIUS:
			ball_in_air = false
			ball_carrier_index = defense_team.find(defender)
			_turnover_after_interception(defense_team[ball_carrier_index].position)
			return

	if receiver.position.distance_to(ball.position) <= CATCH_RADIUS * 1.25:
		ball_in_air = false
		ball_carrier_index = ball_target_player
		return

	ball_in_air = false
	_end_play_at(ball.position, "incomplete")

func _turnover_after_interception(intercept_spot: Vector3) -> void:
	print("INTERCEPTION BY %s DEFENSE" % [possession.to_upper()])
	possession = "red" if possession == "blue" else "blue"
	line_of_scrimmage_z = clamp(intercept_spot.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
	drive_start_z = line_of_scrimmage_z
	first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
	down = 1
	_prepare_new_play()

func _check_play_end() -> void:
	if play_phase != "live":
		return

	var carrier := offense_team[ball_carrier_index]
	if _carrier_scored(carrier.position):
		return

	if ball_in_air:
		return

	for defender in defense_team:
		if defender.position.distance_to(carrier.position) <= TACKLE_DISTANCE:
			_end_play_at(carrier.position, "tackle")
			return

	if abs(carrier.position.x) >= FIELD_HALF_WIDTH - 0.9:
		_end_play_at(carrier.position, "out_of_bounds")

func _end_play_at(spot: Vector3, reason: String) -> void:
	play_phase = "dead"
	var old_los := line_of_scrimmage_z
	line_of_scrimmage_z = clamp(spot.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
	var gained := (line_of_scrimmage_z - old_los) * offense_direction

	if reason == "incomplete":
		line_of_scrimmage_z = old_los
		gained = 0.0

	if line_of_scrimmage_z * offense_direction >= first_down_target_z * offense_direction:
		down = 1
		first_down_target_z = line_of_scrimmage_z + offense_direction * FIRST_DOWN_YARDS
		print("%s FIRST DOWN" % possession.to_upper())
	else:
		down += 1

	print("PLAY END: %s | GAIN %.1f | DOWN %d" % [reason, gained, down])

	if down > MAX_PLAYS_PER_DRIVE:
		print("TURNOVER ON DOWNS")
		possession = "red" if possession == "blue" else "blue"
		down = 1
		line_of_scrimmage_z = clamp(line_of_scrimmage_z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
		first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
	_prepare_new_play()

func _carrier_scored(carrier_pos: Vector3) -> bool:
	if possession == "blue" and carrier_pos.z >= FIELD_HALF_LENGTH - ENDZONE_DEPTH:
		blue_score += 6
		print("BLUE TD | SCORE %d - %d" % [blue_score, red_score])
		_start_drive("red")
		return true
	if possession == "red" and carrier_pos.z <= -FIELD_HALF_LENGTH + ENDZONE_DEPTH:
		red_score += 6
		print("RED TD | SCORE %d - %d" % [blue_score, red_score])
		_start_drive("blue")
		return true
	return false

func _nearest_defender_to(pos: Vector3) -> int:
	var best_idx := -1
	var best_dist := 9999.0
	for i in defense_team.size():
		var dist := defense_team[i].position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func offense_sign() -> float:
	return 1.0 if possession == "blue" else -1.0

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
