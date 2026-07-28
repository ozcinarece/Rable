extends RefCounted
## ÇİT DENGE VERİSİ (cit-sistemi) — TÜM sayılar burada, kod dokunmadan
## elle ayarlanır. Çit KENAR-bazlı yapıdır: hücreyi değil, iki hücre
## arasındaki kenarı kaplar (duvar hücre kaplar — fark bu).

## Kenar başına can. Duvardan bilerek ZAYIF (ahsap_duvar 80): çit ucuz
## ve hızlı kurulur, karşılığı dayanıksızlık.
const MAX_HP := 40

## Yaratık yol maliyeti (görev verisi: "çit: 5"). Kırılabilir kenar
## yola kapalı değil PAHALI — duvar mantığının kenar karşılığı.
const EDGE_COST := 5
## Tırmanıcı çiti kolayca aşar (alçak engel): maliyeti düşük.
const EDGE_COST_CLIMB := 2
## Yaratık çite vururken hasar (duvar vuruşuyla aynı taban; çitin canı
## az olduğu için 3-4 vuruşta kırılır).

## Modeller (kullanıcı yüklemesi, test/ altında).
const POST_GLB := "res://assets/models/test/fence_post.glb"
const RAIL_GLB := "res://assets/models/test/fence_rail.glb"

## Direk: model 1.9 birim boyunda (ölçüldü: y -0.95..0.95, origin
## merkezde) → hedef boy için tekdüze ölçek.
const POST_H := 0.85
## Ray: model X'te TAM 1.0 birim (ölçüldü: -0.5..0.5) = 1 hücre kenarı.
## TEK İSTİSNA (görev izni): uzunluk X ölçeğiyle esnetilir — kenar hep
## 1 m olduğundan bu sabittir, kesit (Y/Z) ayrı ölçeklenir ki ray
## uzarken kalınlaşmasın. Gerekçe RAPOR_CIT.md'de.
const RAIL_LEN_X := 1.0
const RAIL_SECTION := 0.85    # kesit ölçeği (model 0.28 kalın — inceltilir)
const RAIL_Y := 0.5           # rayın yerden yüksekliği (m)

## Meshy dokuları "ışık pişmiş" geliyor; ton yumuşatma (_tame ile).
const TINT := Color(0.92, 0.88, 0.82)
