class_name GameConfig
extends Resource

@export_range(2, 4, 1) var player_count: int = 4
## 0 = random shuffle. Non-zero is useful for reproducing a deal.
@export var rng_seed: int = 0
