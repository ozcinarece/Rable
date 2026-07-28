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

## Direk: model 1.9 birim boyunda (ölçüldü) → hedef boy KARAKTERİN
## BELİ (~1.35 m karakterde 0.75). cit-fix turu: 0.85'ten indirildi;
## mesh bake hattıyla (node scale yok — ağaçlarla aynı normalize yolu).
const POST_H := 0.62  # kullanici istegi: bel'den biraz daha kucuk
## Ray: model X'te TAM 1.0 birim (ölçüldü: -0.5..0.5) = 1 hücre kenarı.
## TEK İSTİSNA (görev izni): uzunluk X ölçeğiyle esnetilir — kenar hep
## 1 m olduğundan bu sabittir, kesit (Y/Z) ayrı ölçeklenir ki ray
## uzarken kalınlaşmasın. Gerekçe RAPOR_CIT.md'de.
const RAIL_LEN_X := 1.0
const RAIL_SECTION := 0.55    # kesit ölçeği — direkle orantılı inceltildi
const RAIL_Y := 0.34          # rayın yerden yüksekliği (bel boyu direğe göre)

# --- CIT-FIX kuralları (kullanıcı geri bildirimi) -------------------------
## Eski "kenara direk+ray çifti" yerleştirme yolu: KAPALI bayrak
## (kod silinmedi — göreve göre bayrakla kapatıldı).
const EDGE_PLACEMENT := false
## Otomatik ray çekme: TAMAMEN KAPALI — ray yalnız kullanıcı isteğiyle
## bağlanır (görev başlığı). Kod _auto_baglama_dene'de duruyor.
const AUTO_BAGLAMA := false
## Ray bağlama bedeli ve sökme iadesi (%50). 1 dalda %50 tanımsız
## olurdu; bedel 2 çubuk yapıldı ki iade tam yarı olsun (RAPOR'da).
const RAY_COST := {"cubuk": 2}
const RAY_IADE := {"cubuk": 1}

## Meshy dokuları "ışık pişmiş" geliyor; ton yumuşatma (_tame ile).
const TINT := Color(0.92, 0.88, 0.82)
