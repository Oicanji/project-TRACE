class_name HitBurst
extends Node2D

@onready var _ring: Sprite2D = $Ring
@onready var _particles: CPUParticles2D = $Particles
@onready var _cleanup_timer: Timer = $CleanupTimer

var _tint: Color = Color(0.45, 0.95, 1.0, 1.0)
var _burst_scale: float = 1.0
var _particle_count: int = 14


func configure(tint: Color, burst_scale: float = 1.0, particle_count: int = 14) -> void:
	_tint = tint
	_burst_scale = burst_scale
	_particle_count = particle_count
	if is_node_ready():
		_play()


func _ready() -> void:
	_play()


func _play() -> void:
	if is_instance_valid(_particles):
		_particles.amount = maxi(4, _particle_count)
		_particles.color = _tint
		_particles.scale_amount_min = 2.0 * _burst_scale
		_particles.scale_amount_max = 5.0 * _burst_scale
		_particles.initial_velocity_min = 70.0 * _burst_scale
		_particles.initial_velocity_max = 210.0 * _burst_scale
		_particles.restart()

	if is_instance_valid(_ring):
		_ring.modulate = Color(_tint.r * 1.25, _tint.g * 1.25, _tint.b * 1.25, 0.95)
		_ring.scale = Vector2(0.18, 0.18) * _burst_scale
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ring, "scale", Vector2(1.15, 1.15) * _burst_scale, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_ring, "modulate:a", 0.0, 0.24).set_ease(Tween.EASE_IN)

	if is_instance_valid(_cleanup_timer):
		_cleanup_timer.start(0.55)


func _on_cleanup_timer_timeout() -> void:
	queue_free()
