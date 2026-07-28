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

---

# V2 GÜNCELLEMESİ (su-shader-v2)

Kullanıcı `water.gdshader`'ı v2 ile güncelledi (commit "Add files via
upload"); bu tur shader'ı oyuna bağladı ve doğruladı.

## V2'DE NE DEĞİŞTİ (shader tarafı)

- **Gerçek dalga**: vertex'te 3 yönlü sinüs üst üste
  (`wave_amplitude=0.09`, `wave_frequency=1.9`, `wave_time_scale=1.45`
  — prototip değerleri, sayılar SHADER varsayılanlarında). Eski
  `bob_amplitude/bob_frequency` kabartısı kaldırıldı.
- **Dalga eğimi normale katılıyor**: `v_wave_h` varying'i fragment'ta
  normal haritasına ekleniyor — dalga tepeleri ışığı farklı kırıyor.
- **Parıltı sıklaştı**: sparkle_threshold 0.965→0.950,
  intensity 0.55→0.85; normal_strength 0.25→0.38, kayma hızları arttı.

## 4.7 DERLEME DÜZELTMESİ (v1 dersinin geri işlenmesi)

Yüklenen v2, akış yönünü fragment'ta `CUSTOM0.xy`'den okuyordu.
Godot 4.7'de CUSTOM0 yalnız vertex aşamasında okunabilir (v1 turunda
yaşanan aynı tuzak). `v_flow_dir` varying düzeltmesi v2'ye geri
işlendi; başka değişiklik yapılmadı. xvfb+opengl3 ile derleme temiz
(SHADER ERROR yok).

## MESH YOĞUNLUĞU KONTROLÜ (görev madde 2)

Vertex dalgası mesh bölünmesine muhtaç. İki su yüzeyi de ZATEN hücre
başına **4x4 bölünmeli** (0.25 m karolar; `res := 4`):
- `_build_lake_surface` — v1 turunda köpük bandı pürüzsüzlüğü için
  seçilmişti, v2 dalga şartını karşılıyor.
- `_build_pool_mesh` — aynı çözünürlük.

Yeterlilik hesabı: en kısa dalga bileşeni λ≈1.27 m (freq×2.6) →
0.25 m ızgarada ~5 vertex/dalga boyu. **Yandan alçak açı xvfb
karesiyle doğrulandı**: v2'de su silueti gözle görülür kabarıyor,
v1 aynı kadrajda dümdüz çizgi. Ek bölünme GEREKMEDİ.

Düşük kademe notu: shader'da dalga zaten `quality=0`'da kapalı.
Mesh kalite değişiminde yeniden kurulmadığından bölünme sabit kalır;
Düşük'te tek quad'a inmek köpük bandını da bozacağı için yapılmadı
(bölünmenin asıl sahibi köpük — gerekçe kodda).

## FPS ÖNCE/SONRA

Telefon yok; ölçüm iki kanaldan:
- **xvfb yazılımsal GL A/B** (vertex shader CPU'da koşar, vertex
  maliyeti birebir görünür): 56x56 quad'lık yüzeyde v1=12.32 ms,
  v2=12.20 ms/kare — fark gürültü payında.
- **Analiz**: vertex sayısı DEĞİŞMEDİ (mesh aynı); v2'nin ek yükü
  quality=1'de vertex başına 3 sinüs + fragment'ta 2 çarpma.
  Düşük kademede ek yük SIFIR (dalga bloğu quality=0'da atlanır).
  Telefonda hissedilir fark beklenmez.

## KARELER (v2 kadraj değişikliği)

`3d_su_golet.png` artık **YANDAN ALÇAK AÇI**: kamera su çizgisinin
~0.5 m üstünde, kıyıdan göl merkezine bakar — dalgalar karşı kıyı
fonunda SİLUETTE görünür (görev şartı). Kamera zemin altına düşmesin
diye `ground_height+0.35` tabanı var. Gece Ocak yansıması ve akan
kanal kareleri önceki kadrajda.

## DOĞRULAMA

- Yerel hızlı paket TÜM testler yeşil; WATERCOLORTEST v2 ile tutuyor
  (bant renkleri/eşikleri v2'de DEĞİŞMEDİ — CPU replikası geçerli).
- Mesh sözleşmesi (COLOR/UV/CUSTOM0 + v1_encode) aynen korundu.

## CI KARE İNCELEMESİ (v2 turu, run 230)

- `3d_su_golet.png`: yeni alçak açı kadraj — yüzeyde v2'nin parıltı
  kıvrımları ve dalga hacmi belirgin; karşı kıyı su çizgisi düzgün
  değil, dalgalı (siluet şartı). Eski yüksek açı karede su neredeyse
  hareketsiz görünüyordu.
- `3d_su_golet_gece.png`: alçak açıda gece; meşale solda, suda sıcak
  leke kamera dibinde (alçak açının bedeli — yansıma lekesi kadrajın
  alt kenarına düşüyor). Kabul edildi; istenirse kadraj meşaleye
  döndürülebilir.
- `3d_su_kanal.png` / `3d_su_hendek.png`: kompozisyon öncekiyle aynı
  (kadraj değişmedi) — gerileme yok, iç su v2 ile çiziliyor.
