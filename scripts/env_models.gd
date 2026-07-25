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
	"path_stone": 0.55,
	"path_stone_mossy": 0.55,
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
