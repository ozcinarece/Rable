# RAPOR — SU SHADER V1 ENTEGRASYONU (branch: su-shader-v1)

`assets/models/env/water.gdshader` (yüklenen ad `water_1.gdshader` idi,
sözleşme başlığındaki ada çevrildi) oyunun İKİ su yüzeyine de bağlandı:
göl + kazılmış havuzlar. Eski yol silinmedi:
`DigWaterVisual.SU_SHADER_V1 = false` tek satırla birebir geri döner.

## SÖZDİZİMİ DÜZELTMESİ (görevin "hata varsa düzelt" maddesi)

Shader 4.7'de derlenmiyordu: **`CUSTOM0` fragment aşamasında okunamaz**
(yalnız vertex'te var). `varying vec2 v_flow_dir` eklendi; vertex'te
`CUSTOM0.xy` oraya yazılır, fragment akış yönünü varying'den okur.
Başka değişiklik yok — renkler/uniform'lar dosyadaki gibi.

## VERİ SÖZLEŞMESİ UYGULAMASI (mesh üretimi)

Tek kaynak: `DigWaterVisual` C2 bloğu (`v1_encode`, ölçek sabitleri).

| Sözleşme | Uygulama |
|---|---|
| COLOR.r = derinlik 0..1 | `derinlik_m / V1_DEEP_M (0.60)` — araziden ölçülür, kıyı kavisi doğal |
| COLOR.g = kıyı 0..1 | `1 − derinlik_m / V1_SHORE_M (0.22)` — eski köpük rampasıyla aynı ölçek |
| COLOR.b = akış | göl 0; kazılmış hücrede boru transferi tazeyse 0.8 (`_flow_dirs`) |
| UV = dünya xz / ölçek | `xz / V1_UV_OLCEK (8.0)` — desen hücre yereli değil |
| CUSTOM0.xy = akış yönü | `SurfaceTool.set_custom(0, ...)`; göl (0,0), akan hücrede boru→hücre yönü |

- **noise_tex**: kodla üretilen `NoiseTexture2D` (FastNoiseLite
  SIMPLEX_SMOOTH, `seamless=true`, 256²) — dosya dokusu yok, her
  platformda aynı.
- **night_mix**: mevcut gündüz/gece kancası (`_update_water_night`)
  aynı parametre adını kullanıyor — kare başına tek setter, değişmedi.
- **warm_lights[4]**: `_update_water_warm_lights` — aktif Ocak +
  meşale/sefer ateşlerinden SUYA en yakın 4'ü. Yalnız ışık değişiminde
  çağrılır (Ocak aktifleşince, meşale konunca/sökülünce) — her kare DEĞİL.
- **quality**: kalite kademesinden — Düşük'te 0 (yalnız bant+köpük),
  Orta/Yüksek 1 (`_apply_water_tier`).
- **Akış verisi gerçek yoldan**: `_transfer_in_component` su bastığı
  hücreye yön+zaman damgası yazar; havuz mesh'i seviye değişiminde
  zaten yeniden kurulur ve işareti okur (4 sn tazelik).

## WATERCOLORTEST — SÖZLEŞME BEKÇİSİ GÜNCELLENDİ

Eski test CPU'da pişirilen ekran rengini okuyordu; v1'de vertex COLOR
artık VERİ (r=derinlik!). Test şimdi encoder + shader bant hesabının
CPU replikası (`v1_band_color`) üzerinden EKRAN rengini doğruluyor —
beklenen değerler değişmedi: köpük #EAF7F7, sığ #7FD4D8, orta #5AA9E6,
derin #3B7DC4, kırmızı asla baskın değil. Shader bant sabitleri
değişirse replika uyuşmaz, CI kırmızı yanar (kırmızı-su sınıfının
v1 sigortası).

## FPS ÖNCE/SONRA (telefon profili) — DÜRÜST ÇERÇEVE

CI yazılım rasterizasyonunda GPU maliyeti ölçülemez. Değişmeyenler:
mesh'ler ve düğüm sayısı AYNI (aynı iki yüzey, aynı vertex sayısı,
2 materyal) — fark yalnız fragment işi. Kademeler:
- **Düşük (quality=0)**: bant+köpük — eski shader'la aynı sınıf maliyet.
- **Orta/Yüksek (quality=1)**: +2 noise örneklemesi ×2 katman + fresnel
  + parıltı; 128 haritadaki su alanında telefon için makul, ama söz
  ölçümün: **cihazda FPS göstergesi** (Ayarlar → FPS) ile gölet başında
  Düşük↔Yüksek karşılaştır; fark hissedilirse quality eşiği veriden
  bir kademe kaydırılır. CI karelerindeki görünüm kanıtı aşağıda.

## KARELER (ağır CI, docs/screens/)

`3d_su_golet.png` (gündüz), `3d_su_golet_gece.png` (gece + kıyıda sıcak
ışık yansıması), `3d_su_hendek.png` (gerçek kazıyla açılmış su dolu
hendek), `3d_su_kanal.png` (akış işaretli kanal). Not: gece karesinde
"Ocak kıyısında" niyeti sıcak yansımadır — Ocak'ı göle taşımak kamp
merkezini (halkalar/prefab) bozacağından aynı sıcak-ışık yolunu
kullanan meşale konuldu.

## BİLİNEN SINIRLAR

- Kanal karesindeki akış işareti elle beslenir (veri yolu aynı);
  oyun içinde gerçek akış pompa/boru transferinde görünür.
- NoiseTexture2D ilk karede asenkron üretilir (hint_default_black):
  açılışta ~yarım saniye düz su görülebilir.
- bob_amplitude vertex kabartısı kıyıda COLOR.g ile söndürülüyor
  (shader'ın kendi tasarımı) — köpük bandı titremez.
