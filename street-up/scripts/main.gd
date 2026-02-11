extends Node3D

const TEAM_SIZE := 7
const FIELD_HALF_LENGTH := 40.0
const FIELD_HALF_WIDTH := 20.0
const ENDZONE_DEPTH := 8.0
const BASE_PLAYER_SPEED := 6.8
const BASE_SPRINT_SPEED := 8.6
const BALL_SPEED := 23.0
const CATCH_RADIUS := 1.4
const TACKLE_DISTANCE := 1.45
const PLAYER_RADIUS := 0.58
const COLLISION_PUSH := 0.9
const CONTACT_SLOWDOWN := 0.65
const START_Y := 0.6
const PRE_SNAP_TIME := 1.2
const ROUTE_PREVIEW_TIME := 1.0
const ROUTE_MARKER_WIDTH := 0.26
const BALL_MARKER_SIZE := 0.9
const BALL_MARKER_HEIGHT := 0.04
const PUNT_HANG_TIME := 1.9
const PUNT_DISTANCE := 22.0
const PAT_SNAP_TIME := 0.7
const PAT_KICK_TIME := 1.2
const PAT_SUCCESS_WIDTH := 2.9
const MAX_PLAYS_PER_DRIVE := 4
const FIRST_DOWN_YARDS := 12.0
const QB_THROW_TIME_MIN := 1.0
const QB_THROW_TIME_MAX := 2.6
const CAMERA_HEIGHT := 35.0
const CAMERA_BACK_OFFSET := 26.0
const THROW_INTERCEPT_RADIUS := 1.15
const QB_SHADE_FACTOR := 1.25
const DEFENDER_SHADE_FACTOR := 0.68

const RECEIVER_INDICES := [0, 1, 5, 6]
const CENTER_INDEX := 2
const QB_INDEX := 3
const RB_INDEX := 4

var blue_team: Array[Node3D] = []
var red_team: Array[Node3D] = []
var all_players: Array[Node3D] = []
var ball: Node3D
var follow_camera: Camera3D

var los_marker: MeshInstance3D
var first_down_marker: MeshInstance3D

var player_stats: Dictionary = {}

var blue_score := 0
var red_score := 0

var possession := "blue"
var down := 1
var line_of_scrimmage_z := 0.0
var first_down_target_z := 0.0

var offense_team: Array[Node3D] = []
var defense_team: Array[Node3D] = []
var offense_direction := 1.0

var ball_carrier_index := 0
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
var ball_landing_marker: MeshInstance3D
var route_markers: Array[Node3D] = []
var ball_mode := "normal"
var turnover_return_active := false
var pat_target_z := 0.0
var pat_setup_team := ""

func _ready() -> void:
	randomize()
	_setup_world()
	_spawn_teams()
	_spawn_ball()
	_start_drive("blue")

func _physics_process(delta: float) -> void:
	play_clock += delta
	if play_phase == "pre_snap":
		_run_presnap_alignment()
		if play_clock >= PRE_SNAP_TIME:
			_clear_route_markers()
			play_phase = "live"
			play_clock = 0.0
	elif play_phase == "live":
		_run_live_play(delta)
	elif play_phase == "pat_setup":
		_run_pat_setup()
		if play_clock >= PAT_SNAP_TIME:
			play_phase = "pat_live"
			play_clock = 0.0
	elif play_phase == "pat_live":
		_run_pat_live(delta)

	_resolve_player_collisions()
	_update_ball(delta)
	_update_ball_landing_marker()
	_update_camera(delta)
	_check_play_end()

func _setup_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -40.0, 0.0)
	add_child(sun)

	follow_camera = Camera3D.new()
	follow_camera.position = Vector3(0.0, 52.0, 42.0)
	follow_camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	follow_camera.current = true
	add_child(follow_camera)

	_add_field()
	_add_goal_posts()
	_add_line_markers()
	_add_ball_landing_marker()

func _add_field() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, FIELD_HALF_LENGTH * 2.0)
	ground.mesh = ground_mesh
	ground.material_override = _make_material(Color(0.12, 0.45, 0.16, 1.0))
	add_child(ground)

	var blue_endzone := MeshInstance3D.new()
	var blue_mesh := PlaneMesh.new()
	blue_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, ENDZONE_DEPTH)
	blue_endzone.mesh = blue_mesh
	blue_endzone.position = Vector3(0.0, 0.01, -FIELD_HALF_LENGTH + ENDZONE_DEPTH * 0.5)
	blue_endzone.material_override = _make_material(Color(0.1, 0.28, 0.9, 1.0))
	add_child(blue_endzone)

	var red_endzone := MeshInstance3D.new()
	var red_mesh := PlaneMesh.new()
	red_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, ENDZONE_DEPTH)
	red_endzone.mesh = red_mesh
	red_endzone.position = Vector3(0.0, 0.01, FIELD_HALF_LENGTH - ENDZONE_DEPTH * 0.5)
	red_endzone.material_override = _make_material(Color(0.85, 0.12, 0.14, 1.0))
	add_child(red_endzone)

func _add_line_markers() -> void:
	los_marker = MeshInstance3D.new()
	var los_mesh := PlaneMesh.new()
	los_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, 0.6)
	los_marker.mesh = los_mesh
	los_marker.position = Vector3(0.0, 0.03, 0.0)
	los_marker.material_override = _make_material(Color(1.0, 0.92, 0.2, 1.0))
	add_child(los_marker)

	first_down_marker = MeshInstance3D.new()
	var first_mesh := PlaneMesh.new()
	first_mesh.size = Vector2(FIELD_HALF_WIDTH * 2.0, 0.6)
	first_down_marker.mesh = first_mesh
	first_down_marker.position = Vector3(0.0, 0.035, 0.0)
	first_down_marker.material_override = _make_material(Color(1.0, 0.8, 0.1, 1.0))
	add_child(first_down_marker)

func _update_line_markers() -> void:
	if los_marker == null or first_down_marker == null:
		return
	los_marker.position.z = line_of_scrimmage_z
	first_down_marker.position.z = first_down_target_z

func _spawn_teams() -> void:
	for i in TEAM_SIZE:
		var lane = lerp(-FIELD_HALF_WIDTH + 2.5, FIELD_HALF_WIDTH - 2.5, float(i) / float(max(1, TEAM_SIZE - 1)))
		var blue := _spawn_player(_player_color("blue", i), Vector3(lane, START_Y, -10.0), "blue", i)
		blue_team.append(blue)
		all_players.append(blue)

		var red := _spawn_player(_player_color("red", i), Vector3(lane, START_Y, 10.0), "red", i)
		red_team.append(red)
		all_players.append(red)

func _spawn_player(color: Color, spawn_position: Vector3, team_name: String, role_slot: int) -> Node3D:
	var body := Node3D.new()
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	mesh.mesh = capsule
	mesh.material_override = _make_material(color)
	body.add_child(mesh)
	body.position = spawn_position
	add_child(body)

	var stat := {
		"speed": randf_range(BASE_PLAYER_SPEED * 0.88, BASE_PLAYER_SPEED * 1.18),
		"sprint": randf_range(BASE_SPRINT_SPEED * 0.88, BASE_SPRINT_SPEED * 1.18),
		"tackle": randf_range(0.8, 1.25),
		"awareness": randf_range(0.75, 1.3),
		"role_slot": role_slot,
		"team": team_name
	}
	player_stats[body.get_instance_id()] = stat
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
	ball_mode = "normal"
	turnover_return_active = false
	ball_target_player = -1
	route_targets.clear()
	receiver_progress.clear()
	receiver_assignments.clear()
	defender_assignments.clear()

	if down == MAX_PLAYS_PER_DRIVE:
		play_type = _choose_fourth_down_call()
	else:
		play_type = "run" if randf() < 0.4 else "pass"
	ball_carrier_index = QB_INDEX
	_assign_formations()
	_update_line_markers()

	print("%s | DOWN %d | LOS %.1f | TO GO %.1f | PLAY %s" % [possession.to_upper(), down, line_of_scrimmage_z, abs(first_down_target_z - line_of_scrimmage_z), play_type.to_upper()])

func _assign_formations() -> void:
	var base_x: Array[float] = [-10.0, -5.0, 0.0, 0.0, -2.2, 5.0, 10.0]
	for i in TEAM_SIZE:
		var x := base_x[i]
		var offense_z := line_of_scrimmage_z - offense_direction * 1.0
		offense_team[i].position = Vector3(x, START_Y, offense_z)

	offense_team[CENTER_INDEX].position = Vector3(0.0, START_Y, line_of_scrimmage_z - offense_direction * 0.3)
	offense_team[QB_INDEX].position = Vector3(0.0, START_Y, line_of_scrimmage_z - offense_direction * 3.8)
	offense_team[RB_INDEX].position = Vector3(-2.2, START_Y, line_of_scrimmage_z - offense_direction * 6.0)
	offense_team[0].position = Vector3(-10.0, START_Y, line_of_scrimmage_z - offense_direction * 1.0)
	offense_team[1].position = Vector3(-5.0, START_Y, line_of_scrimmage_z - offense_direction * 1.4)
	offense_team[5].position = Vector3(5.0, START_Y, line_of_scrimmage_z - offense_direction * 1.4)
	offense_team[6].position = Vector3(10.0, START_Y, line_of_scrimmage_z - offense_direction * 1.0)

	var defense_x: Array[float] = [-8.5, -4.0, -1.5, 1.5, 4.0, 7.0, 0.0]
	for i in TEAM_SIZE:
		var defense_z := line_of_scrimmage_z + offense_direction * 2.0
		defense_team[i].position = Vector3(defense_x[i], START_Y, defense_z)

	defense_team[6].position = Vector3(0.0, START_Y, line_of_scrimmage_z + offense_direction * 8.0)

	for i in RECEIVER_INDICES:
		var route := _build_route_for(i)
		route_targets[i] = route
		receiver_progress[i] = 0

	_assign_coverage()

func _assign_coverage() -> void:
	var defenders := [1, 2, 3, 4]
	for idx in RECEIVER_INDICES.size():
		var receiver_id = RECEIVER_INDICES[idx]
		var defender_id = defenders[idx % defenders.size()]
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

func _run_presnap_alignment() -> void:
	for i in TEAM_SIZE:
		offense_team[i].position.y = START_Y
		defense_team[i].position.y = START_Y

	if play_clock <= ROUTE_PREVIEW_TIME:
		_draw_route_markers()

	if ball_carrier_index == QB_INDEX:
		ball.position = offense_team[QB_INDEX].position + Vector3(0.0, 0.85, 0.0)

func _run_live_play(delta: float) -> void:
	_run_offense_ai(delta)
	_run_defense_ai(delta)

func _run_offense_ai(delta: float) -> void:
	var qb := offense_team[QB_INDEX]
	if play_type == "punt":
		_move_qb_for_pass(qb, delta)
		_move_receivers(delta)
		_move_off_ball_support(delta)
		if play_clock >= 0.9 and not ball_in_air:
			_start_punt()
	elif play_type == "pass":
		_move_qb_for_pass(qb, delta)
		_move_receivers(delta)
		_move_off_ball_support(delta)
		if play_clock >= QB_THROW_TIME_MIN and not ball_in_air:
			_try_qb_throw()
		if play_clock >= QB_THROW_TIME_MAX and not ball_in_air:
			ball_carrier_index = QB_INDEX
			_move_runner(QB_INDEX, delta, true)
	else:
		if play_clock < 0.6:
			_move_qb_for_handoff(qb, delta)
			_move_receivers(delta)
		else:
			if ball_carrier_index == QB_INDEX:
				ball_carrier_index = RB_INDEX
			_move_runner(ball_carrier_index, delta, false)
			_move_receivers(delta)
		_move_off_ball_support(delta)

func _move_qb_for_pass(qb: Node3D, delta: float) -> void:
	var target := Vector3(0.0, START_Y, line_of_scrimmage_z - offense_direction * 6.3)
	qb.position = qb.position.move_toward(target, _player_speed(qb, false) * delta)
	if ball_carrier_index == QB_INDEX and not ball_in_air:
		ball.position = qb.position + Vector3(0.0, 0.85, 0.0)

func _move_qb_for_handoff(qb: Node3D, delta: float) -> void:
	var target := Vector3(-1.2, START_Y, line_of_scrimmage_z - offense_direction * 4.6)
	qb.position = qb.position.move_toward(target, _player_speed(qb, false) * delta)
	ball.position = qb.position + Vector3(0.0, 0.85, 0.0)

func _move_off_ball_support(delta: float) -> void:
	var carrier := offense_team[ball_carrier_index]
	var carrier_is_receiver := ball_carrier_index in RECEIVER_INDICES
	for i in TEAM_SIZE:
		if i == ball_carrier_index:
			continue
		if i in RECEIVER_INDICES and not carrier_is_receiver:
			continue
		var helper := offense_team[i]
		var nearest_defender_idx := _nearest_specific_defender_to(helper.position)
		var target := helper.position + Vector3(0.0, 0.0, offense_direction * 2.0)
		if nearest_defender_idx != -1:
			var defender := defense_team[nearest_defender_idx]
			var protect_pos := carrier.position.lerp(defender.position, 0.5)
			target = Vector3(protect_pos.x, START_Y, protect_pos.z)
		helper.position = helper.position.move_toward(target, _player_speed(helper, false) * 0.85 * delta)

func _move_receivers(delta: float) -> void:
	if ball_in_air and ball_mode == "pass":
		var chase_id := _closest_offense_receiver_to(ball_target_pos)
		if chase_id != -1 and chase_id != ball_carrier_index:
			var chase_target := Vector3(ball_target_pos.x, START_Y, ball_target_pos.z)
			offense_team[chase_id].position = offense_team[chase_id].position.move_toward(chase_target, _player_speed(offense_team[chase_id], true) * delta * 1.12)

	for receiver_id in RECEIVER_INDICES:
		if receiver_id == ball_carrier_index:
			continue
		var route: Array = route_targets.get(receiver_id, [])
		if route.is_empty():
			continue
		var step := int(receiver_progress.get(receiver_id, 0))
		if step >= route.size():
			var continue_target := offense_team[receiver_id].position + Vector3(0.0, 0.0, offense_direction * 4.0)
			offense_team[receiver_id].position = offense_team[receiver_id].position.move_toward(continue_target, _player_speed(offense_team[receiver_id], true) * delta)
			continue
		var target: Vector3 = route[step]
		offense_team[receiver_id].position = offense_team[receiver_id].position.move_toward(target, _player_speed(offense_team[receiver_id], true) * delta)
		if offense_team[receiver_id].position.distance_to(target) < 0.8:
			receiver_progress[receiver_id] = step + 1

func _move_runner(runner_index: int, delta: float, scramble_mode: bool) -> void:
	var runner := offense_team[runner_index]
	var nearest := _nearest_defender_to(runner.position)
	var evade_x := 0.0
	var contact_penalty := 1.0
	if nearest != -1:
		var nearest_pos := defense_team[nearest].position
		evade_x = clamp(runner.position.x - nearest_pos.x, -1.0, 1.0)
		if runner.position.distance_to(nearest_pos) < PLAYER_RADIUS * 2.0:
			contact_penalty = CONTACT_SLOWDOWN
	var forward := offense_direction * 5.2 * contact_penalty
	var side := evade_x * (2.0 if scramble_mode else 3.6)
	var target := runner.position + Vector3(side, 0.0, forward)
	target.x = clamp(target.x, -FIELD_HALF_WIDTH + 1.2, FIELD_HALF_WIDTH - 1.2)
	runner.position = runner.position.move_toward(target, _player_speed(runner, true) * delta)
	if ball_carrier_index == runner_index and not ball_in_air:
		ball.position = runner.position + Vector3(0.0, 0.85, 0.0)

func _run_defense_ai(delta: float) -> void:
	var carrier_pos := offense_team[ball_carrier_index].position
	var ball_past_los := (carrier_pos.z - line_of_scrimmage_z) * offense_direction > 0.5
	var rushers := [0, 6]
	for defender_id in TEAM_SIZE:
		var defender := defense_team[defender_id]
		var target := defender.position
		if ball_past_los or ball_carrier_index != QB_INDEX:
			target = carrier_pos
		elif defender_id in rushers:
			target = offense_team[QB_INDEX].position
		else:
			var receiver_id := int(defender_assignments.get(defender_id, -1))
			if receiver_id != -1:
				var receiver := offense_team[receiver_id]
				var trail := receiver.position - Vector3(0.0, 0.0, offense_direction * 1.6)
				target = Vector3(trail.x, START_Y, trail.z)
			else:
				target = carrier_pos
		defender.position = defender.position.move_toward(Vector3(target.x, START_Y, target.z), _defender_chase_speed(defender) * delta)

func _try_qb_throw() -> void:
	var best_receiver := -1
	var best_score := -99999.0
	var best_target := Vector3.ZERO
	var qb := offense_team[QB_INDEX]
	for receiver_id in RECEIVER_INDICES:
		var receiver := offense_team[receiver_id]
		var throw_distance := qb.position.distance_to(receiver.position)
		var travel_time := clamp(throw_distance / BALL_SPEED, 0.12, 0.95)
		var lead_distance = clamp(_player_speed(receiver, true) * travel_time * 1.12, 1.4, 7.2)
		var route_dir := _receiver_route_direction(receiver_id)
		var candidate_target := receiver.position + route_dir * lead_distance
		candidate_target.x = clamp(candidate_target.x, -FIELD_HALF_WIDTH + 1.0, FIELD_HALF_WIDTH - 1.0)
		candidate_target.z = clamp(candidate_target.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 0.5, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 0.5)

		var score := candidate_target.z * offense_direction
		var defender_id := int(receiver_assignments.get(receiver_id, -1))
		if defender_id != -1:
			var assigned_defender := defense_team[defender_id]
			var projected_separation := candidate_target.distance_to(assigned_defender.position)
			score += projected_separation * 4.2 * _player_awareness(qb)

		var closest_contest := _closest_defender_distance_to(candidate_target)
		score += closest_contest * 2.3
		if closest_contest < CATCH_RADIUS * 1.7:
			score -= 45.0

		var lane_penalty := _pass_lane_penalty(qb.position, candidate_target)
		score -= lane_penalty
		if abs(receiver.position.x) > FIELD_HALF_WIDTH - 2.0:
			score -= 2.5
		if lane_penalty >= 1000.0:
			score -= 50.0
		if score > best_score:
			best_score = score
			best_receiver = receiver_id
			best_target = candidate_target

	if best_receiver == -1:
		return

	if _pass_lane_penalty(qb.position, best_target) >= 1000.0:
		return

	ball_in_air = true
	ball_mode = "pass"
	ball.position = qb.position + Vector3(0.0, 0.9, 0.0)
	ball_target_player = best_receiver
	ball_target_pos = best_target
	ball_velocity = (ball_target_pos - ball.position).normalized() * BALL_SPEED
	print("%s QB THROW -> WR%d" % [possession.to_upper(), best_receiver])

func _closest_defender_distance_to(target_pos: Vector3) -> float:
	var best := 9999.0
	for defender in defense_team:
		var dist := defender.position.distance_to(target_pos)
		if dist < best:
			best = dist
	return best

func _pass_lane_penalty(from_pos: Vector3, to_pos: Vector3) -> float:
	var lane := to_pos - from_pos
	var lane_len := lane.length()
	if lane_len <= 0.001:
		return 1000.0
	var lane_dir := lane / lane_len
	var penalty := 0.0
	for defender in defense_team:
		var defender_offset := defender.position - from_pos
		var along := defender_offset.dot(lane_dir)
		if along <= 0.3 or along >= lane_len - 0.3:
			continue
		var closest := from_pos + lane_dir * along
		var lateral := defender.position.distance_to(closest)
		if lateral < THROW_INTERCEPT_RADIUS * 0.55:
			return 1000.0
		if lateral < THROW_INTERCEPT_RADIUS * 1.8:
			penalty += (THROW_INTERCEPT_RADIUS * 1.8 - lateral) * 8.0
	return penalty

func _resolve_player_collisions() -> void:
	for i in all_players.size():
		for j in range(i + 1, all_players.size()):
			var a := all_players[i]
			var b := all_players[j]
			var diff := a.position - b.position
			diff.y = 0.0
			var dist := diff.length()
			var min_dist := PLAYER_RADIUS * 2.0
			if dist <= 0.001:
				diff = Vector3(0.05, 0.0, 0.0)
				dist = 0.05
			if dist < min_dist:
				var overlap := min_dist - dist
				var push_dir := diff / dist
				var push := push_dir * overlap * 0.5 * COLLISION_PUSH
				a.position += Vector3(push.x, 0.0, push.z)
				b.position -= Vector3(push.x, 0.0, push.z)
	_clamp_players_to_field()

func _clamp_players_to_field() -> void:
	for player in all_players:
		player.position.x = clamp(player.position.x, -FIELD_HALF_WIDTH + 0.6, FIELD_HALF_WIDTH - 0.6)
		player.position.z = clamp(player.position.z, -FIELD_HALF_LENGTH + 0.5, FIELD_HALF_LENGTH - 0.5)
		player.position.y = START_Y

func _update_ball(delta: float) -> void:
	if ball_in_air:
		ball.position += ball_velocity * delta
		if ball_mode == "punt" and ball.position.distance_to(ball_target_pos) <= CATCH_RADIUS:
			_resolve_punt_landing()
		elif ball_mode == "pass" and ball.position.distance_to(ball_target_pos) <= CATCH_RADIUS:
			_resolve_pass_target()
	else:
		var carrier := offense_team[ball_carrier_index]
		ball.position = carrier.position + Vector3(0.0, 0.85, 0.0)

func _update_ball_landing_marker() -> void:
	if ball_landing_marker == null:
		return
	if ball_in_air:
		ball_landing_marker.visible = true
		ball_landing_marker.position = Vector3(ball_target_pos.x, 0.02, ball_target_pos.z)
	else:
		ball_landing_marker.visible = false

func _update_camera(delta: float) -> void:
	if follow_camera == null or ball == null:
		return
	var lateral_sway := sin(Time.get_ticks_msec() * 0.0014) * 3.0
	var forward_hint := -offense_direction if possession == "blue" else offense_direction
	var height := CAMERA_HEIGHT + (4.0 if ball_in_air else 0.0)
	var desired := ball.position + Vector3(lateral_sway, height, CAMERA_BACK_OFFSET * forward_hint)
	follow_camera.position = follow_camera.position.lerp(desired, clamp(delta * 2.6, 0.0, 1.0))
	var look_target := ball_target_pos if ball_in_air else ball.position
	follow_camera.look_at(look_target, Vector3.UP)

func _resolve_pass_target() -> void:
	var receiver := offense_team[ball_target_player]
	for defender in defense_team:
		if defender.position.distance_to(ball.position) <= CATCH_RADIUS:
			ball_in_air = false
			ball_mode = "normal"
			ball_carrier_index = defense_team.find(defender)
			_turnover_after_interception(defense_team[ball_carrier_index].position)
			return

	if receiver.position.distance_to(ball.position) <= CATCH_RADIUS * 1.25:
		ball_in_air = false
		ball_mode = "normal"
		ball_carrier_index = ball_target_player
		return

	ball_in_air = false
	ball_mode = "normal"
	_end_play_at(ball.position, "incomplete")

func _turnover_after_interception(intercept_spot: Vector3) -> void:
	print("INTERCEPTION BY %s DEFENSE" % [possession.to_upper()])
	var old_offense := offense_team
	offense_team = defense_team
	defense_team = old_offense
	possession = "red" if possession == "blue" else "blue"
	offense_direction = offense_sign()
	line_of_scrimmage_z = clamp(intercept_spot.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
	first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
	down = 1
	turnover_return_active = true
	play_type = "run"

func _check_play_end() -> void:
	if play_phase != "live":
		return

	var carrier := offense_team[ball_carrier_index]
	if _carrier_scored(carrier.position):
		return

	if ball_in_air or play_phase == "pat_setup" or play_phase == "pat_live":
		return

	for defender in defense_team:
		var tackle_power := _player_tackle(defender)
		if defender.position.distance_to(carrier.position) <= TACKLE_DISTANCE * tackle_power:
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

	if turnover_return_active:
		down = 1
		turnover_return_active = false
		first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
		_update_line_markers()
		print("RETURN END: %s | NEW LOS %.1f" % [reason, line_of_scrimmage_z])
		_prepare_new_play()
		return

	if _is_safety(spot):
		_award_safety_to_defense()
		return

	if line_of_scrimmage_z * offense_direction >= first_down_target_z * offense_direction:
		down = 1
		first_down_target_z = line_of_scrimmage_z + offense_direction * FIRST_DOWN_YARDS
		print("%s FIRST DOWN" % possession.to_upper())
	else:
		down += 1

	_update_line_markers()
	print("PLAY END: %s | GAIN %.1f | DOWN %d" % [reason, gained, down])

	if down > MAX_PLAYS_PER_DRIVE:
		print("TURNOVER ON DOWNS")
		possession = "red" if possession == "blue" else "blue"
		down = 1
		line_of_scrimmage_z = clamp(line_of_scrimmage_z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
		first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
		turnover_return_active = false

	_prepare_new_play()

func _is_safety(spot: Vector3) -> bool:
	if possession == "blue" and spot.z <= -FIELD_HALF_LENGTH + ENDZONE_DEPTH:
		return true
	if possession == "red" and spot.z >= FIELD_HALF_LENGTH - ENDZONE_DEPTH:
		return true
	return false

func _award_safety_to_defense() -> void:
	if possession == "blue":
		red_score += 2
		print("SAFETY RED | SCORE %d - %d" % [blue_score, red_score])
		_start_drive("red")
	else:
		blue_score += 2
		print("SAFETY BLUE | SCORE %d - %d" % [blue_score, red_score])
		_start_drive("blue")

func _carrier_scored(carrier_pos: Vector3) -> bool:
	if possession == "blue" and carrier_pos.z >= FIELD_HALF_LENGTH - ENDZONE_DEPTH:
		blue_score += 6
		print("BLUE TD | SCORE %d - %d" % [blue_score, red_score])
		_start_pat_attempt("blue")
		return true
	if possession == "red" and carrier_pos.z <= -FIELD_HALF_LENGTH + ENDZONE_DEPTH:
		red_score += 6
		print("RED TD | SCORE %d - %d" % [blue_score, red_score])
		_start_pat_attempt("red")
		return true
	return false

func _add_goal_posts() -> void:
	for z_sign in [-1.0, 1.0]:
		var crossbar := MeshInstance3D.new()
		var cross_mesh := BoxMesh.new()
		cross_mesh.size = Vector3(5.8, 0.22, 0.22)
		crossbar.mesh = cross_mesh
		crossbar.position = Vector3(0.0, 3.0, z_sign * (FIELD_HALF_LENGTH - ENDZONE_DEPTH + 1.2))
		crossbar.material_override = _make_material(Color(1.0, 0.88, 0.2, 1.0))
		add_child(crossbar)

		for x in [-2.9, 2.9]:
			var upright := MeshInstance3D.new()
			var up_mesh := BoxMesh.new()
			up_mesh.size = Vector3(0.2, 5.4, 0.2)
			upright.mesh = up_mesh
			upright.position = Vector3(x, 5.7, z_sign * (FIELD_HALF_LENGTH - ENDZONE_DEPTH + 1.2))
			upright.material_override = _make_material(Color(1.0, 0.88, 0.2, 1.0))
			add_child(upright)

func _add_ball_landing_marker() -> void:
	ball_landing_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = BALL_MARKER_SIZE
	marker_mesh.bottom_radius = BALL_MARKER_SIZE
	marker_mesh.height = BALL_MARKER_HEIGHT
	ball_landing_marker.mesh = marker_mesh
	ball_landing_marker.material_override = _make_material(Color(1.0, 1.0, 1.0, 0.75))
	ball_landing_marker.visible = false
	add_child(ball_landing_marker)

func _draw_route_markers() -> void:
	_clear_route_markers()
	for receiver_id in RECEIVER_INDICES:
		var route: Array = route_targets.get(receiver_id, [])
		if route.is_empty():
			continue
		var prev := offense_team[receiver_id].position
		for point in route:
			var marker := MeshInstance3D.new()
			var seg := BoxMesh.new()
			var target: Vector3 = point
			var dir := target - prev
			seg.size = Vector3(ROUTE_MARKER_WIDTH, 0.05, max(0.7, dir.length()))
			marker.mesh = seg
			marker.material_override = _make_material(Color(1.0, 1.0, 1.0, 0.55))
			marker.position = Vector3((prev.x + target.x) * 0.5, 0.05, (prev.z + target.z) * 0.5)
			add_child(marker)
			marker.look_at(Vector3(target.x, marker.position.y, target.z), Vector3.UP)
			route_markers.append(marker)

			var arrow := MeshInstance3D.new()
			var arr_mesh := CylinderMesh.new()
			arr_mesh.top_radius = 0.02
			arr_mesh.bottom_radius = 0.22
			arr_mesh.height = 0.2
			arrow.mesh = arr_mesh
			arrow.material_override = _make_material(Color(1.0, 1.0, 0.9, 0.8))
			arrow.position = Vector3(target.x, 0.08, target.z)
			add_child(arrow)
			route_markers.append(arrow)
			prev = target

func _clear_route_markers() -> void:
	for marker in route_markers:
		if marker != null:
			marker.queue_free()
	route_markers.clear()

func _choose_fourth_down_call() -> String:
	var to_go := abs(first_down_target_z - line_of_scrimmage_z)
	var dist_to_td := (FIELD_HALF_LENGTH - ENDZONE_DEPTH - line_of_scrimmage_z) if possession == "blue" else (line_of_scrimmage_z + FIELD_HALF_LENGTH - ENDZONE_DEPTH)
	if to_go <= 2.5 or dist_to_td <= 9.0:
		return "pass"
	if dist_to_td > 26.0:
		return "punt"
	return "run"

func _receiver_route_direction(receiver_id: int) -> Vector3:
	var route: Array = route_targets.get(receiver_id, [])
	var step := int(receiver_progress.get(receiver_id, 0))
	if not route.is_empty() and step < route.size():
		var target: Vector3 = route[step]
		var dir := target - offense_team[receiver_id].position
		if dir.length() > 0.001:
			return dir.normalized()
	return Vector3(0.0, 0.0, offense_direction)

func _closest_offense_receiver_to(target_pos: Vector3) -> int:
	var best_id := -1
	var best_dist := 9999.0
	for receiver_id in RECEIVER_INDICES:
		if receiver_id == ball_carrier_index:
			continue
		var dist := offense_team[receiver_id].position.distance_to(target_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = receiver_id
	return best_id

func _start_punt() -> void:
	var qb := offense_team[QB_INDEX]
	ball_in_air = true
	ball_mode = "punt"
	ball.position = qb.position + Vector3(0.0, 1.0, 0.0)
	ball_target_player = -1
	ball_target_pos = qb.position + Vector3(0.0, 0.2, offense_direction * PUNT_DISTANCE)
	ball_target_pos.x = clamp(ball_target_pos.x, -FIELD_HALF_WIDTH + 1.2, FIELD_HALF_WIDTH - 1.2)
	ball_target_pos.z = clamp(ball_target_pos.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 0.8, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 0.8)
	ball_velocity = (ball_target_pos - ball.position) / max(PUNT_HANG_TIME, 0.1)
	print("%s PUNT" % possession.to_upper())

func _resolve_punt_landing() -> void:
	ball_in_air = false
	ball_mode = "normal"
	line_of_scrimmage_z = clamp(ball_target_pos.z, -FIELD_HALF_LENGTH + ENDZONE_DEPTH + 1.0, FIELD_HALF_LENGTH - ENDZONE_DEPTH - 1.0)
	possession = "red" if possession == "blue" else "blue"
	down = 1
	first_down_target_z = line_of_scrimmage_z + offense_sign() * FIRST_DOWN_YARDS
	_prepare_new_play()

func _run_pat_setup() -> void:
	if pat_setup_team == "":
		return
	var pat_dir := 1.0 if pat_setup_team == "blue" else -1.0
	var spot := pat_target_z - pat_dir * 7.0
	for i in TEAM_SIZE:
		offense_team[i].position = Vector3(-8.0 + i * 2.5, START_Y, spot - pat_dir * 0.8)
		defense_team[i].position = Vector3(-8.0 + i * 2.5, START_Y, spot + pat_dir * 1.2)
	offense_team[QB_INDEX].position = Vector3(0.0, START_Y, spot - pat_dir * 2.4)
	ball.position = offense_team[QB_INDEX].position + Vector3(0.0, 0.9, 0.0)

func _run_pat_live(delta: float) -> void:
	if play_clock < PAT_KICK_TIME:
		var target := offense_team[QB_INDEX].position + Vector3(0.0, 0.0, offense_direction * 2.0)
		offense_team[QB_INDEX].position = offense_team[QB_INDEX].position.move_toward(target, _player_speed(offense_team[QB_INDEX], false) * delta)
		ball.position = offense_team[QB_INDEX].position + Vector3(0.0, 0.9, 0.0)
		return
	_resolve_pat_kick()

func _start_pat_attempt(scoring_team: String) -> void:
	pat_setup_team = scoring_team
	possession = scoring_team
	offense_team = blue_team if possession == "blue" else red_team
	defense_team = red_team if possession == "blue" else blue_team
	offense_direction = offense_sign()
	pat_target_z = FIELD_HALF_LENGTH - ENDZONE_DEPTH + 1.2 if scoring_team == "blue" else -FIELD_HALF_LENGTH + ENDZONE_DEPTH - 1.2
	play_phase = "pat_setup"
	play_clock = 0.0
	ball_in_air = false
	ball_mode = "normal"
	_clear_route_markers()

func _resolve_pat_kick() -> void:
	if play_phase != "pat_live":
		return
	var kick_x := offense_team[QB_INDEX].position.x + randf_range(-0.8, 0.8)
	var blocked := false
	for defender in defense_team:
		if defender.position.distance_to(offense_team[QB_INDEX].position) < 1.8 and randf() < 0.15:
			blocked = true
			break
	if not blocked and abs(kick_x) <= PAT_SUCCESS_WIDTH:
		if pat_setup_team == "blue":
			blue_score += 1
		else:
			red_score += 1
		print("%s PAT GOOD | SCORE %d - %d" % [pat_setup_team.to_upper(), blue_score, red_score])
	else:
		print("%s PAT NO GOOD" % pat_setup_team.to_upper())
	var next_drive := "red" if pat_setup_team == "blue" else "blue"
	pat_setup_team = ""
	_start_drive(next_drive)

func _nearest_defender_to(pos: Vector3) -> int:
	var best_idx := -1
	var best_dist := 9999.0
	for i in defense_team.size():
		var dist := defense_team[i].position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func _nearest_specific_defender_to(pos: Vector3) -> int:
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

func _player_stat(player: Node3D, key: String, fallback: float) -> float:
	var stat = player_stats.get(player.get_instance_id(), {})
	return float(stat.get(key, fallback))

func _player_speed(player: Node3D, sprint: bool) -> float:
	if sprint:
		return _player_stat(player, "sprint", BASE_SPRINT_SPEED)
	return _player_stat(player, "speed", BASE_PLAYER_SPEED)

func _defender_chase_speed(player: Node3D) -> float:
	var sprint := _player_speed(player, true)
	var awareness := _player_awareness(player)
	return sprint * (1.0 + (awareness - 1.0) * 0.25)

func _player_tackle(player: Node3D) -> float:
	return _player_stat(player, "tackle", 1.0)

func _player_awareness(player: Node3D) -> float:
	return _player_stat(player, "awareness", 1.0)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _player_color(team_name: String, role_slot: int) -> Color:
	var base := Color(0.2, 0.4, 1.0, 1.0) if team_name == "blue" else Color(1.0, 0.2, 0.2, 1.0)
	if role_slot == QB_INDEX:
		return base.lightened(clamp(QB_SHADE_FACTOR - 1.0, 0.0, 0.9))
	if role_slot in RECEIVER_INDICES:
		return base
	return base.darkened(clamp(1.0 - DEFENDER_SHADE_FACTOR, 0.0, 0.9))
