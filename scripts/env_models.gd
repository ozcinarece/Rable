extends RefCounted
## ÇEVRE MODEL KAYITLARI — yol, serpinti, tarla göstergesi, yıkık yapılar.
## YALNIZ GÖRSEL bağlama verisi; mekanik yok.
##
## ÖLÇEK YÖNTEMİ: modeller Meshy'den ~1 birim küp içinde ve MERKEZLİ geliyor
## (ölçüldü, tablo aşağıda). Ölçek, GLB'nin KÖK düğümüne verilir; iç
## düğümlere (Armature vb.) ASLA dokunulmaz — karakterde rig'i bozan hata
## oydu. Bu propların hiçbiri skinned değil, kök ölçeği güvenli.
## (.import Root Scale kullanılmadı: proje .import dosyalarını repoda
## tutmuyor, CI'da üretiliyor.)
##
## y_min değerleri negatif = model merkezli; zemine oturtmak için AABB
## tabanından telafi edilir (kod bunu otomatik yapar).

## Hedef DÜNYA boyu (metre). Karakter ~1 birim = referans.
const SCALE := {
	# tarla göstergesi (hücreye sığar)
	"planting_mound": 0.92,
	# serpinti
	"grass_tuft": 0.33,      # ölçüldü h=0.90 -> ~30 cm ot tutamı
	"pebble_cluster": 0.18,  # ölçüldü w=1.90 -> ~34 cm çakıl öbeği
	"twig_debris": 0.40,     # ölçüldü w=0.99 -> ~40 cm dal parçası
	# yol taşı
	"path_stone": 0.45,
	"path_stone_mossy": 0.45,
	# yapılar (kulübe ~2.8 m: karakterin ~3 katı)
	"ruined_hut": 2.80,
	"repaired_hut": 2.80,
	"ruined_well": 1.20,
}

const PATHS := {
	"planting_mound": "res://assets/models/crops/planting_mound.glb",
	"grass_tuft": "res://assets/models/env/grass_tuft.glb",
	"pebble_cluster": "res://assets/models/env/pebble_cluster.glb",
	"twig_debris": "res://assets/models/env/twig_debris.glb",
	"path_stone": "res://assets/models/env/path_stone.glb",
	"path_stone_mossy": "res://assets/models/env/path_stone_mossy.glb",
	"ruined_hut": "res://assets/models/structures/ruined_hut.glb",
	"repaired_hut": "res://assets/models/structures/repaired_hut.glb",
	"ruined_well": "res://assets/models/structures/ruined_well.glb",
}

## MESHY TON ÇARPANI: dokular "ışık pişmiş" gibi çok AÇIK geliyor
## (ekinlerde CROP_TINT ile çözülmüştü). İlk CI karesinde ot tutamı sarı
## saman, çakıl bembeyaz çıktı -> albedo bu çarpanlarla sahne paletine
## çekilir. 1.0 = dokunma.
const TINT := {
	"grass_tuft": Color(0.66, 0.80, 0.52),      # sarıdan yeşile
	"pebble_cluster": Color(0.58, 0.55, 0.50),  # beyazdan sıcak griye
	"twig_debris": Color(0.78, 0.66, 0.52),     # ahşap kahveye
	# 4. CI karesinde taslar HALA bembeyaz lekeydi: dokusu neredeyse beyaz,
	# 0.80 carpani yetmiyor. Sicak griye sert cekildi.
	"path_stone": Color(0.56, 0.53, 0.49),
	"path_stone_mossy": Color(0.50, 0.55, 0.42),
	"planting_mound": Color(0.86, 0.80, 0.72),
	"ruined_hut": Color(0.86, 0.82, 0.76),
	"repaired_hut": Color(0.90, 0.86, 0.80),
	"ruined_well": Color(0.84, 0.82, 0.78),
}

static func tint_of(id: String) -> Color:
	return TINT.get(id, Color.WHITE)

## Doku gelmezse düz renk fallback paleti (görevdeki palet).
const FALLBACK_LEAF := Color(0.42, 0.52, 0.34)   # yaprak adaçayı
const FALLBACK_STONE := Color(0.55, 0.52, 0.48)  # taş sıcak gri
const FALLBACK_WOOD := Color(0.45, 0.33, 0.22)   # ahşap kahve

## Serpinti yoğunluğu kalite kademesine bağlı (mobil).
## tier -> hücre başına serpinti olasılığı çarpanı.
const SCATTER_TIER_MULT := {"dusuk": 0.35, "orta": 0.7, "yuksek": 1.0}

## Taban serpinti şansları (yüzde). Bağlam kuralı basit tutuldu:
## çimde ot tutamı, su/kaya kenarında çakıl, ağaç dibinde dal.
const CHANCE_TUFT := 22
const CHANCE_PEBBLE := 26
const CHANCE_TWIG := 30

## Serpinti varyasyonu
const SCATTER_SCALE_MIN := 0.8
const SCATTER_SCALE_MAX := 1.2
const SCATTER_OFFSET := 0.30   # hücre içi konum oynaması (m)

## YOL: soluk toprak lekesi + taş serpintisi
const PATH_TINT := Color(0.62, 0.55, 0.42)  # aşınmış toprak (zemin rengiyle harman)
const PATH_STONE_MISS := 30   # %30 taş eksik (aşınmışlık)
const PATH_MOSSY_CHANCE := 40 # %40 yosunlu varyant

static func path_of(id: String) -> String:
	return String(PATHS.get(id, ""))

static func scale_of(id: String) -> float:
	return float(SCALE.get(id, 1.0))

## Deterministik 0..1 gürültü (aynı hücre hep aynı serpintiyi alsın —
## dekor yeniden kurulunca otlar yer değiştirmesin).
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
