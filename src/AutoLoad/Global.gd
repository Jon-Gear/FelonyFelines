extends Node

onready var FRICTION = 0.1
onready var ACCEL = 0.1

var brother_1
var brother_2

var navigation

var entity_world
var main
var items
var enemies
var players
var projectiles
var misc
var misc_2
var root
var UI_layer

var final_score
var wave_survived


var points = 0
var wave_num = 0
var enemy_count = 0

var ITEM_DROP_WEIGHTS = {
	"weapons/melee/axe/Axe": 4,
#	"weapons/range/assault rifle/AssaultRifle": 2,
	"weapons/range/shotgun/Shotgun": 3,
	"medkit/Medkit": 5,
	"weapons/range/minigun/Minigun": 1,
	"weapons/range/revolver/Revolver": 5
}

signal all_dead

func _ready():
	enemy_count = 0
	wave_num = 0
	points = 0
	root = get_parent()
	normalize_item_drop_weights()
	
func frame_freeze(time_scale, duration):
	Engine.time_scale = time_scale
	yield(get_tree().create_timer(duration * time_scale), "timeout")
	Engine.time_scale = 1.0

func player_died():
	if Global.brother_1.health_manager.is_dead() and Global.brother_2.health_manager.is_dead():
		brother_1.respawn_radius.deactivate_respawn_radius()
		brother_2.respawn_radius.deactivate_respawn_radius()
		emit_signal("all_dead")

func reparent(child: Node, new_parent: Node):
	var old_parent = child.get_parent()
	old_parent.remove_child(child)
	new_parent.call_deferred("add_child", child)
#	new_parent.add_child(child)
	child.set_deferred("owner", new_parent.owner)

func random_vector2(n):
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return Vector2(rng.randf_range(-n, n), rng.randf_range(-n, n))


func get_all_enemies():
	var enemies_result = {
		"BALL":[],
		"GUNNER":[],
		"IMP": []
	}

	var enemy_names = enemies_result.keys()
	for entity in enemies.get_children():
		if not entity.is_in_group("ENTITY"):
			continue
		if entity.entity_name in enemy_names:
			enemies_result[entity.entity_name].append(entity)
	#print(enemies_result)
	return enemies_result

func normalize_item_drop_weights():
	ITEM_DROP_WEIGHTS = DropWeights.normalize(ITEM_DROP_WEIGHTS)


func get_closest_enemy(position: Vector2):
	var closest_enemy: KinematicBody2D
	var closest_distance = 999999999
	
	for enemy in enemies.get_children():
		var distance = (position - enemy.global_position).length()
		if distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance
	
	return closest_enemy

func get_brother():
	for player in players.get_children():
		if player.entity_type == "PLAYER":
			return player
		#if not player.is_in_group("PLAYER"): continue
	#for player in entity_world.get_children():

func get_closest_player(position: Vector2):
	var closest_player: KinematicBody2D
	var closest_distance = 999999999
	
	for player in players.get_children():
		if player.health_manager.is_dead(): continue
		
		var distance = (position - player.global_position).length()
		if distance < closest_distance:
			closest_player = player
			closest_distance = distance
	
	return closest_player

func get_farthest_player(position: Vector2):
	var farthest_player: KinematicBody2D
	var farthest_distance = 0

	for player in players.get_children():
		if player.health_manager.is_dead(): continue
		
		var distance = (position - player.global_position).length()
		if distance > farthest_distance:
			farthest_player = player
			farthest_distance = distance
	
	return farthest_player
