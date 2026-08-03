# ATMOSFER FİNAL — Su v2.1 + Zemin Çayır Dokusu (atmosfer-final)

## PARÇA 1 — SU V2.1: ÖNCEDEN ENTEGRE (belgeleme)

Kökteki water.gdshader, önceki turlarda entegre edilen v2.1'in HAM
hali. Oyundaki sürüm (assets/models/env/water.gdshader) onun üzerine
kullanıcı istekli üç rötuş taşıyor:
1. `v_flow_dir` varying — CUSTOM0 4.7'de fragment'ta okunamaz
   (yoksa shader derlenmez; her sürümde yeniden işleniyor),
2. `sparkle_intensity=0.05` + `spec_strength=0.05` (parlaklık turu:
   "gündüz çok parlak → 0'a yakın"),
3. kıyı soluması (`shore_lap_*` — "dalga kıyıya vursun" isteği).
Görev maddeleri önceki turlarda kapatıldı: subdivision iki su
yüzeyinde de 4x4/hücre (xvfb siluet A/B kanıtlı), veri sözleşmesi
değişmedi (WATERCOLORTEST yeşil), FPS notu RAPOR_SUSHADER'da.
Kökteki kopya olduğu gibi bırakıldı (kaynak/arşiv).

## PARÇA 2 — ZEMİN ÇAYIR DOKUSU (ground_meadow.gdshader)

- Dosya assets/models/env/'e taşındı, zemin chunk materyaline bağlandı
  (`ZEMIN_SHADER_ON` bayrağı — kapatınca eski StandardMaterial yolu
  birebir geri; sayılar shader varsayılanlarında: prototip
  zemin_v2.html seçimleri .25/14/.10, .50/.11, .16).
- 3D ÇİM TAMAMEN KAPALI: `CIM_FIELD_ON=false` (cim-10x mikro-tutam
  dahil; kod silinmedi, grass.gdshader kökte arşiv). Çiçek/çakıl/dal
  mini dekorları duruyor.

### v_grass_mask UYARLAMASI (sözleşmedeki "mekanizma farklıysa")
Bu projede zemin RENGİ vertex COLOR.RGB'de yaşıyor (tür rengi + kazı
katman kararması + falez boyası + ıslak bant + kenar harmanı) —
COLOR.g rengin parçası olduğundan maske OLAMAZDI. Maske, boşta duran
ALPHA kanalında taşınıyor: `_build_chunk` her vertex'e `_zemin_mask_at`
yazar (çayır "."/"h" = 1; yol/kazı/falez/toprak-kum = 0). `base_color`
uniform'u yerine fragment vertex rengini okuyor — kazı/falez/ıslak
görselleri aynen korunur.

### Kenar geçişleri
Paylaşımlı vertex'ler maskeyi 0.25 m çözünürlükte doğrusal harmanlıyor;
üstüne shader'da yalnız 0-1 arası bantta çalışan noise sallantısı
eklendi (`mask_noise=0.25`, veri: ZEMIN_MASK_NOISE) — tür sınırı düz
çizgi değil organik kenar.

### night_mix + quality
Zemin materyali `_update_water_night` zincirine eklendi — su/çim/
çiçek/yaratıkla AYNI kaynak (ZEMINTEST doğrular: gece 0.16). Kalite:
`_apply_zemin_tier` — Düşük'te ince benek kapalı (shader quality=0).

### FPS
3D çim kapandı: önceki sürüm her karede ~636k instance kuyruğu
(ekranda chunk culling sonrası yüz binlerce vertex) çiziyordu; zemin
dokusu SIFIR ek geometri — aynı zemin mesh'inde birkaç noise örneği.
Net kazanç: çim render maliyetinin tamamı geri geldi (telefonda en
belirgin Yüksek kademede). Doku maliyeti fragment'ta 4-5 vnoise —
Düşük'te 2'ye iner.

### Doğrulama
- ZEMINTEST (hızlı CI'ya eklendi): `shader=true cim=1 kazi=0 falez=0
  yol=0 gece_mix=0.16` — materyal ataması, maske mantığı, gece zinciri.
- CIMTEST 3D-çim-kapalı durumuna uyarlandı (boy ölçümü yalnız çim
  materyali kullanımdayken).
- Kareler: gündüz çayır (benek/leke görünür, yol temiz), gece su+zemin
  ton uyumu. NOT: görevdeki ref_softlook.png depoda YOK — (e) yan yana
  kıyası dosya yüklenince yapılabilir.
