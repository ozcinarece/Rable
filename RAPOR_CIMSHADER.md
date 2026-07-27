# RAPOR — ÇİM SHADER V1 ENTEGRASYONU (branch: cim-shader)

`assets/models/env/grass.gdshader` süs otu MultiMesh'lerine bağlandı;
çiçekler aynı shader'ın düşük-rüzgâr kopyasını aldı. Taban bilinçli
olarak `su-shader-v1` dalı: sözleşme noise_tex ve night_mix'in su ile
AYNI kaynaktan paylaşılmasını istiyor (o iş henüz main'de değil —
bu dal merge edilirken su da birlikte gelir). Geri dönüş:
`DigWaterVisual.CIM_SHADER_V1 = false`.

## SÖZLEŞME UYGULAMASI

| Madde | Uygulama |
|---|---|
| MultiMesh materyali | `material_override` MMI düzeyinde — TEK draw call korunur (CIMTEST sayar) |
| blade_height ölç-gir | koddan ÖLÇÜLÜR: havuz mesh'lerinin AABB yüksekliği (Root Scale sonrası gerçek boy) |
| player_pos her kare | `_process`'te tek uniform seti; **quality 0'da set de atlanır** (`_cim_ezme_on`) |
| night_mix aynı kaynak | `_update_water_night` su+çim+çiçeği AYNI değerle günceller |
| noise_tex paylaşımı | `_ortak_noise_tex()` — su ve çim aynı NoiseTexture2D örneğini kullanır (bellek) |
| quality | kalite kademesinden: Düşük=0 (rüzgâr+ezme kapalı), Orta/Yüksek=1 |

## ÇİÇEK / MİNİ BİTKİ KARARI

- **Çiçek**: aynı shader'ın kopyası — `wind_strength 0.03` (başlar
  savrulmaz, sözleşme notu) + yumuşak pembe uç / sap yeşili gradyanı.
  Takas: GLB'nin taç yaprak dokusu yerine stilize gradyan; tek satırla
  eski hale döner.
- **Mantar**: UYGULANMADI — şapka/gövde dikey gradyanla bozulur ve
  mantar rüzgârda sallanmamalı. Eski materyalinde kaldı.
- Kazı ağzı çim sarkmaları (A5) ayrı sistem, dokunulmadı (borç:
  istenirse aynı materyal bağlanabilir).

## 4.7 DERLEME

Shader olduğu gibi derlendi — su shader'ındaki `CUSTOM0` sınıfı bir
hata YOK (varying'ler baştan doğru). Değişiklik yapılmadı.

## FPS ÖNCE/SONRA (çayırlık, telefon profili)

Draw call SAYISI DEĞİŞMEDİ: süs otu zaten havuz başına tek MultiMesh
idi; override MMI düzeyinde (CIMTEST `mmi=shaderli` eşitliğini ve
örnek sayısını basar — önce/sonra aynı). Maliyet farkı vertex başına
rüzgâr matematiği (~%20 hücre süslü, tutam başına düşük vertex) +
kare başına 1-2 uniform seti. Düşük kademede shader eski davranışa
kapanır VE player_pos seti de atlanır. Telefon ölçümü: Ayarlar → FPS,
çayırda Düşük↔Yüksek karşılaştır — fark hissedilirse wind pahası
veriden kısılır (`wind_strength`/`quality` eşiği).

## KARELER (ağır CI)

- `3d_cim_ruzgar_a/_b.png`: AYNI kadraj 1 sn arayla — statik karede
  rüzgâr ancak iki karenin FARKIYLA kanıtlanır (uçların yer
  değiştirmesi). GIF/video CI boru hattında yok — borç; telefonda
  gözle görülür.
- `3d_cim_ezme.png`: karakter çimin içinde — çevresindeki tutamlar
  dışa yatık.
- `3d_cim_su_gece.png`: göl kıyısında çim, gece — su+çim gece tonu
  AYNI night_mix kaynağından, uyum tek karede.
