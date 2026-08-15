extends Placeable
## 木栅栏：放置后形成围栏，阻挡玩家与动物

const FENCE_TILES: Array[Vector2i] = [
	Vector2i(0, 25), Vector2i(1, 25), Vector2i(2, 25), Vector2i(3, 25), Vector2i(4, 25),
]
const TOWN_TEX = preload("res://Art/maps/spring_town.zh-CN.png")

func _ready() -> void:
	super()
	# 随机栅栏瓦片变体
	var tile: Vector2i = FENCE_TILES.pick_random()
	var atlas := AtlasTexture.new()
	atlas.atlas = TOWN_TEX
	atlas.region = Rect2(tile.x * 16, tile.y * 16, 16, 16)
	sprite_2d2.texture = atlas
