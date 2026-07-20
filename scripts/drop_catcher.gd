extends Control
## Panelin bos alanlarina yapilan birakmalari "yutar".
## Boylece slotlar arasindaki bosluga birakilan esya yere dusmez;
## sadece panelin tamamen DISINA birakilanlar yere birakilir.

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("kind")

func _drop_data(_pos: Vector2, _data: Variant) -> void:
	pass  # hicbir sey yapma: surukleme sessizce iptal olur
