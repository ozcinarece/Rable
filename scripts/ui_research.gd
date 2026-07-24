extends Control
## ARASTIRMA AGACI EKRANI (UI_DESIGN.md 4.4) - tamamen kodla kurulur.
##
## - Tam ekran krem panel + cok soluk nokta deseni (el isi kagit hissi)
## - 4 dal yatay serit; seridin basinda dal adi + dal renginde pill
## - Dugum kartlari: AGILMIS (yesil onay) / ACILABILIR (maliyet seridi +
##   hafif nabiz) / KILITLI (soluk + kilit) / GIZLI ("???")
## - Dugumler arasi KAVISLI cizgiler; acilmis yol yesil kalinlasir
## - Dugume dokun -> altta bilgi seridi (actiklari + maliyet + Arastir)
## - Arastirma tamamlaninca pastel konfeti fiskirir
##
## Veri: Research autoload (NODES / can_research / do_research).
## Arastir butonu yalnizca yerlestirilmis Arastirma Masasi yanindayken
## aktiftir (Crafting.near_research - world3d gunceller).

const UIColors = preload("res://scripts/ui_colors.gd")
const ItemDb = preload("res://scripts/item_db.gd")
const Items = preload("res://scripts/items.gd")

signal closed

const BRANCH_LABELS := {
	"aletler": "Aletler",
	"insaat": "İnşaat & Savunma",
	"istasyonlar": "İstasyonlar",
	"muhendislik": "Mühendislik & Su",
}

var _cards: Dictionary = {}      # node_id -> kart Control
var _lines: Control              # kavisli baglantilar (kartlarin altinda)
var _strips_box: VBoxContainer
var _selected_node: String = ""
var _info_name: Label
var _info_desc: Label
var _info_cost: Label
var _info_cost_chips: HBoxContainer
var _research_btn: Button
var _hint_label: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Research.changed.connect(_refresh_all)
	Inventory.changed.connect(_refresh_all)
	_build()

func open() -> void:
	visible = true
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.96
	modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	_refresh_all()

func close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		closed.emit())

# --- Kurulum ---------------------------------------------------------------

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 12
	panel.offset_top = 30
	panel.offset_right = -12
	panel.offset_bottom = -12
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	# Soluk nokta deseni (el isi kagit)
	var dots := TextureRect.new()
	dots.texture = _make_dot_texture()
	dots.stretch_mode = TextureRect.STRETCH_TILE
	dots.set_anchors_preset(Control.PRESET_FULL_RECT)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.show_behind_parent = false
	panel.add_child(dots)
	panel.move_child(dots, 0)

	# Ust satir: kapat butonu
	var top := HBoxContainer.new()
	outer.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"  # CLICKTEST bu adla bulur
	close_btn.icon = preload("res://assets/ui/close_x.png")
	close_btn.custom_minimum_size = Vector2(48, 40)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	# Dallar (kaydirilabilir)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var lines_holder := Control.new()  # cizgiler + seritler ayni uzayda
	lines_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines_holder)
	# Cizgiler kartlardan ONCE eklenir: agac sirasi geregi altta cizilir
	# (z_index -1 kullanma - panel zemininin de altina duserdi)
	_lines = Control.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_connections)
	lines_holder.add_child(_lines)
	_strips_box = VBoxContainer.new()
	_strips_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strips_box.add_theme_constant_override("separation", 14)
	lines_holder.add_child(_strips_box)

	for branch in BRANCH_LABELS:
		_strips_box.add_child(_make_strip(branch))

	# Alt bilgi seridi
	var info := PanelContainer.new()
	info.theme_type_variation = "InnerPanel"
	outer.add_child(info)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info.add_child(info_box)
	_info_name = Label.new()
	_info_name.theme_type_variation = "BadgeLabel"
	info_box.add_child(_info_name)
	_info_desc = Label.new()
	_info_desc.theme_type_variation = "SubtleLabel"
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(_info_desc)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	info_box.add_child(info_row)
	_info_cost = Label.new()
	_info_cost.text = "Maliyet:"
	_info_cost.add_theme_font_size_override("font_size", 15)
	_info_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_info_cost)
	# R5: maliyet ikon+sayi CIPLERI (tasan metin yerine)
	_info_cost_chips = HBoxContainer.new()
	_info_cost_chips.add_theme_constant_override("separation", 10)
	_info_cost_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_cost_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_info_cost_chips)
	_hint_label = Label.new()
	_hint_label.theme_type_variation = "SubtleLabel"
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(_hint_label)
	_research_btn = Button.new()
	_research_btn.theme_type_variation = "PrimaryButton"
	_research_btn.text = "Araştır"
	_research_btn.pressed.connect(_on_research_pressed)
	info_row.add_child(_research_btn)
	_show_info("")

# Dal seridi: solda renkli dal pili, sagda dugum kartlari
func _make_strip(branch: String) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 12)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.branch_color(branch)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", sb)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pl := Label.new()
	pl.text = BRANCH_LABELS[branch]
	pl.add_theme_font_size_override("font_size", 15)
	pl.add_theme_color_override("font_color", UIColors.INK_DARK)
	pill.add_child(pl)
	pill.custom_minimum_size = Vector2(130, 0)
	strip.add_child(pill)
	# Dugumler onkosul derinligine gore siralanir
	var nodes := _branch_nodes_sorted(branch)
	for node_id in nodes:
		var card := _make_card(node_id)
		strip.add_child(card)
		_cards[node_id] = card
	return strip

func _branch_nodes_sorted(branch: String) -> Array:
	var ids: Array = []
	for node_id in Research.NODES:
		if Research.NODES[node_id]["branch"] == branch:
			ids.append(node_id)
	ids.sort_custom(func(a, b): return _depth(a) < _depth(b))
	return ids

func _depth(node_id: String) -> int:
	var d := 0
	var cur := node_id
	while cur != "" and Research.NODES.has(cur):
		cur = Research.NODES[cur]["prereq"]
		d += 1
	return d

# Dugum karti: ikon dairesi + ad + (durumuna gore) rozet/maliyet
func _make_card(node_id: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(132, 118)
	card.pressed.connect(func(): _show_info(node_id))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -6
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(48, 48)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# R5: dugum ikonu (actigi ilk tarifin ikonu) — %65 doluluk, bos daire yok.
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(icon)
	box.add_child(circle)
	var name_label := Label.new()
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", 13)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)
	card.set_meta("circle", circle)
	card.set_meta("icon", icon)
	card.set_meta("name_label", name_label)
	card.set_meta("badge", badge)
	return card

# R5: dugumun actigi ilk tarifin ikonu (yoksa null -> renkli daire kalir).
func _unlock_icon(node_id: String) -> Texture2D:
	var unlocks: Array = Research.NODES[node_id]["unlocks"]
	if unlocks.is_empty():
		return null
	var p := String(Items.ITEMS.get(unlocks[0], {}).get("icon", ""))
	if p != "" and ResourceLoader.exists(p):
		return load(p)
	return null

# --- Durum yenileme ---------------------------------------------------------

func _refresh_all() -> void:
	if not visible:
		return
	for node_id in _cards:
		_refresh_card(node_id)
	_lines.queue_redraw()
	_show_info(_selected_node)

func _refresh_card(node_id: String) -> void:
	var card: Button = _cards[node_id]
	var node: Dictionary = Research.NODES[node_id]
	var circle: Panel = card.get_meta("circle")
	var icon: TextureRect = card.get_meta("icon")
	var name_label: Label = card.get_meta("name_label")
	var badge: Label = card.get_meta("badge")
	var branch_col: Color = UIColors.branch_color(node["branch"])
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(999)
	var visible_node: bool = Research.is_visible(node_id)
	name_label.text = _node_title(node_id) if visible_node else "???"
	# R5: dugum ikonu — gizliyse yok; kilitliyse soluk (desature hissi).
	if not visible_node:
		icon.texture = null
	else:
		icon.texture = _unlock_icon(node_id)
		var active := Research.is_unlocked(node_id) \
				or Research.can_research(node_id) or _only_cost_missing(node_id)
		icon.modulate = Color.WHITE if active else Color(0.5, 0.5, 0.5, 0.85)
	card.modulate = Color.WHITE
	if Research.is_unlocked(node_id):
		sb.bg_color = branch_col
		badge.text = "✓ Açık"
		badge.add_theme_color_override("font_color", UIColors.SUCCESS.darkened(0.3))
	elif not visible_node:
		sb.bg_color = UIColors.PANEL_CREAM_DARK
		badge.text = "?"
		badge.add_theme_color_override("font_color", UIColors.INK_FAINT)
		card.modulate = Color(1, 1, 1, 0.65)
	elif Research.can_research(node_id) or _only_cost_missing(node_id):
		# R5: dugumde uzun maliyet metni YOK -> kisa durum; tam maliyet
		# alt bilgi bandinda ikon+sayi cipleri olarak yasar.
		sb.bg_color = branch_col
		badge.text = "Hazır" if Research.can_research(node_id) else "Malzeme"
		badge.add_theme_color_override("font_color",
				UIColors.SUCCESS.darkened(0.3) if Research.can_research(node_id)
				else UIColors.DANGER)
	else:
		# Kilitli: onkosul acilmamis
		sb.bg_color = UIColors.PANEL_CREAM_DARK
		badge.text = "Kilitli"
		badge.add_theme_color_override("font_color", UIColors.INK_FAINT)
		card.modulate = Color(1, 1, 1, 0.55)
	circle.add_theme_stylebox_override("panel", sb)

# Onkosul tamam, sadece malzeme mi eksik? (kart tam renk kalir)
func _only_cost_missing(node_id: String) -> bool:
	var node: Dictionary = Research.NODES[node_id]
	var prereq: String = node["prereq"]
	if prereq != "" and not Research.is_unlocked(prereq):
		return false
	return Research.is_visible(node_id) and not Research.is_unlocked(node_id)

func _node_title(node_id: String) -> String:
	var unlocks: Array = Research.NODES[node_id]["unlocks"]
	var names: Array[String] = []
	for r in unlocks.slice(0, 2):
		names.append(ItemDb.display_name(r))
	return ", ".join(names) + ("..." if unlocks.size() > 2 else "")

func _cost_short(node_id: String) -> String:
	var cost: Dictionary = Research.NODES[node_id]["cost"]
	if cost.is_empty():
		return "Bedava"
	var parts: Array[String] = []
	for item_id in cost:
		parts.append("%d %s" % [cost[item_id], ItemDb.display_name(item_id)])
	return " + ".join(parts)

# R5: alt bilgi bandinda maliyet ikon+sayi cipleri (yeterlilik renkli).
func _set_cost_chips(node_id: String) -> void:
	for c in _info_cost_chips.get_children():
		c.queue_free()
	if node_id == "" or not Research.NODES.has(node_id):
		_info_cost.visible = false
		return
	var cost: Dictionary = Research.NODES[node_id]["cost"]
	_info_cost.visible = not cost.is_empty()
	for item_id in cost:
		var need: int = cost[item_id]
		var have := Inventory.get_count(item_id)
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		var p := String(Items.ITEMS.get(item_id, {}).get("icon", ""))
		if p != "" and ResourceLoader.exists(p):
			var ic := TextureRect.new()
			ic.texture = load(p)
			ic.custom_minimum_size = Vector2(22, 22)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip.add_child(ic)
		var lbl := Label.new()
		lbl.text = "%d/%d" % [have, need]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color",
				UIColors.SUCCESS.darkened(0.25) if have >= need else UIColors.DANGER)
		chip.add_child(lbl)
		_info_cost_chips.add_child(chip)

# --- Kavisli baglantilar -----------------------------------------------------

func _draw_connections() -> void:
	for node_id in _cards:
		var prereq: String = Research.NODES[node_id]["prereq"]
		if prereq == "" or not _cards.has(prereq):
			continue
		var from_card: Control = _cards[prereq]
		var to_card: Control = _cards[node_id]
		var p1: Vector2 = _lines.get_global_transform().affine_inverse() * \
				(from_card.global_position + from_card.size * Vector2(1.0, 0.5))
		var p2: Vector2 = _lines.get_global_transform().affine_inverse() * \
				(to_card.global_position + to_card.size * Vector2(0.0, 0.5))
		var opened := Research.is_unlocked(node_id)
		var col := UIColors.SUCCESS if opened else UIColors.INK_FAINT
		var width := 4.0 if opened else 2.5
		var mid_x := (p1.x + p2.x) / 2.0
		var points := PackedVector2Array()
		for i in 17:
			var t := float(i) / 16.0
			var a := p1.lerp(Vector2(mid_x, p1.y), t)
			var b := Vector2(mid_x, p2.y).lerp(p2, t)
			points.append(a.lerp(b, t))
		_lines.draw_polyline(points, col, width, true)

# --- Bilgi seridi + arastirma ------------------------------------------------

func _show_info(node_id: String) -> void:
	_selected_node = node_id
	if node_id == "" or not Research.NODES.has(node_id):
		_info_name.text = "Bir düğüme dokun"
		_info_desc.text = "Düğümler tarif açar; maliyeti ödeyip araştırırsın."
		_set_cost_chips("")
		_hint_label.text = ""
		_research_btn.visible = false
		return
	if not Research.is_visible(node_id):
		_info_name.text = "???"
		_info_desc.text = "Bu bilgi henüz keşfedilmedi. İlgili malzemeyi ilk kez topladığında görünür."
		_set_cost_chips("")
		_hint_label.text = ""
		_research_btn.visible = false
		return
	var node: Dictionary = Research.NODES[node_id]
	_info_name.text = _node_title(node_id)
	var unlock_names: Array[String] = []
	for r in node["unlocks"]:
		unlock_names.append(ItemDb.display_name(r))
	_info_desc.text = "Açtıkları: " + ", ".join(unlock_names)
	_set_cost_chips(node_id)
	if Research.is_unlocked(node_id):
		_research_btn.visible = false
		_hint_label.text = "Araştırıldı ✓"
		return
	_research_btn.visible = true
	# Arastirma noktasi: yerlestirilmis Arastirma Masasi'nin yani
	var near: bool = Crafting.near_research
	_research_btn.disabled = not (Research.can_research(node_id) and near)
	if not near:
		_hint_label.text = "Araştırma Masası yanına git"
	elif not Research.can_research(node_id):
		_hint_label.text = "Malzeme eksik"
	else:
		_hint_label.text = ""

func _on_research_pressed() -> void:
	if _selected_node == "" or not Research.do_research(_selected_node):
		return
	# Konfeti: dugumden 8 minik pastel yildiz fiskirir (UI_DESIGN 4.4)
	var card: Control = _cards.get(_selected_node)
	if card != null:
		_burst_confetti(card.global_position + card.size / 2.0)

func _burst_confetti(center: Vector2) -> void:
	var palette := [UIColors.SUCCESS, UIColors.WARNING,
			UIColors.CATEGORY_COLORS["trap"], UIColors.CATEGORY_COLORS["weapon"],
			UIColors.CATEGORY_COLORS["structure"]]
	for i in 8:
		var dot := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = palette[i % palette.size()]
		sb.set_corner_radius_all(999)
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size = Vector2(10, 10)
		dot.global_position = center
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		var angle := TAU * float(i) / 8.0 + randf() * 0.4
		var dist := 60.0 + randf() * 40.0
		var target := center + Vector2(cos(angle), sin(angle)) * dist
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(dot, "global_position", target, 0.6)
		tween.parallel().tween_property(dot, "modulate:a", 0.0, 0.6)
		tween.tween_callback(dot.queue_free)

# Cok soluk nokta deseni dokusu (24x24, tek nokta)
func _make_dot_texture() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dot_col := Color(UIColors.INK_FAINT.r, UIColors.INK_FAINT.g,
			UIColors.INK_FAINT.b, 0.25)
	for dx in 2:
		for dy in 2:
			img.set_pixel(11 + dx, 11 + dy, dot_col)
	return ImageTexture.create_from_image(img)
