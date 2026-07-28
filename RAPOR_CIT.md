# RAPOR — MODÜLER ÇİT SİSTEMİ (branch: cit-sistemi)

`fence_post.glb` + `fence_rail.glb` oyuna KENAR-bazlı yapı olarak
bağlandı. Çit hücre kaplamaz: iki hücre arasındaki kenarı kaplar —
projedeki İLK kenar-bazlı öğe (duvar/kapı hücre-bazlıdır).

## VERİ (fence_balance.gd — tüm sayılar)

| Sabit | Değer | Not |
|---|---|---|
| MAX_HP | 40 | duvardan zayıf (ahşap duvar 80) |
| EDGE_COST | 5 | yaratık yol maliyeti (görev verisi "çit: 5") |
| EDGE_COST_CLIMB | 2 | tırmanıcı alçak çiti kolay aşar |
| POST_H | 0.85 | direk boyu (model 1.9 ölçüldü → ölçek) |
| RAIL_SECTION | 0.85 | ray kesiti (X'ten bağımsız) |
| Tarif | 2 çubuk + 1 ip | recipes.gd ("dal" = çubuk) |

## 1. KENAR IZGARASI

- Anahtar `Vector3i(x, y, eksen)`: eksen 0 = hücrenin KUZEY kenarı,
  eksen 1 = BATI kenarı. Güney/doğu = komşunun kuzey/batısı olarak
  yazılır → her fiziksel kenarın TEK anahtarı var (çift kayıt imkânsız;
  FENCETEST `norm` bunu ölçer).
- **Direk paylaşımı:** direkler kenar UÇLARINDAKİ ızgara köşelerine
  refcount ile dikilir — komşu çit kenarı aynı köşeye gelince sayaç
  artar, ikinci direk dikilmez (FENCETEST: 2 kenar → 3 direk). Köşe
  dönüşü ve T-birleşim kendiliğinden doğru görünür.
- **Ray ölçekleme — TEK İSTİSNA:** ray modeli X'te tam 1.0 birim
  (ölçüldü) = 1 hücre kenarı; X ölçeğiyle esnetilir, kesit (Y/Z) AYRI
  ölçeklenir. Gerekçe: kenar uzunluğu sabit 1 m olduğundan bu esnetme
  de sabittir ve uzarken kalınlaşma yaratmaz — Root Scale tek başına
  kesiti de şişirirdi.

## 2. YERLEŞTİRME

- "Çit" eşyası yerleştirme modunda hayalet KENARA oturur: oyuncuya
  dönük kenar (oyuncu-hedef bitişikse aradaki kenar). Ne görürsen onu
  kurarsın; seri dizme (art arda kenar) çalışır.
- **Kapı boşluğu:** bir kenar boş bırakılınca iki uçtaki direkler
  komşu çitlerden zaten dikili — doğal geçit. [TODO kancası:
  fence_gate.glb gelirse boşluğa kapanır kapı.]

## 3. ENGEL + YARATIK

- Oyuncu: `can_step` kenar kontrolü — çitli kenardan geçilmez
  (merdiven kuralıyla aynı kancadan).
- Yaratık adımı: çitli kenara gelen yaratık durup ÇİTE vurur
  (struct_mult işler; kırıcı çiti tek-iki vuruşta söker). Tırmanıcı
  aşar (yavaşlayarak).
- A*: kenar bedeli hücre maliyetine EKLENİR (`creature_edge_cost`) —
  "kır ya da dolaş" kararı çitte de aynı dille çalışır. Çit ucuz
  (5) olduğu için tek sıra çit yaratığı DURDURMAZ, yavaşlatır —
  duvardan zayıf olmasının davranış karşılığı.

## 4. TARLA KORUMASI (görevdeki FİKİR → uygulandı)

4 kenarı da çitli tarla hücresi `korunakli` VERİ BAYRAĞI alır
(Farming.plots içinde; çit kurulup söküldükçe güncellenir). Şimdilik
oyun kuralı yok — ileride kuş/zararlı sistemi gelirse kanca hazır.

## 5. KAYIT

`fences` dizisi olarak (x, y, eksen, hp) kaydedilir; yüklemede
görseller ve paylaşımlı direkler yeniden kurulur. Dünya sıfırlamada
temizlenir.

## DOĞRULAMA

- FENCETEST (hızlı CI): `norm=true engel=true direk3=true
  kirilma=true koruma=true` — kırılma testi yaratığı 4 kenarı çitli
  hücreye kapatır: her çıkış çitten geçer, mecburen vurur.
- Ağır CI karesi: 3x3 tarla + çevre çiti + güneyde kapı boşluğu.
- ci-fast push_error ağı onarımı bu dala da taşındı; FENCETEST
  grep listesinde.

## BORÇLAR

- "cit" eşya ikonu yok — ahşap duvar ikonu emanet.
- fence_gate.glb kancası (kapı boşluğuna gerçek kapı).
- Oyuncunun çiti sökmesi/tamiri yok (yapı sök akışı hücre-bazlı;
  kenar sökme ayrı iş).
- yaratik-gece dalıyla birleşince: çite vuran yaratıkta yeni vuruş
  animasyonu kancası otomatik çalışır (aynı struct yolunu kullanıyor).
