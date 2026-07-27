# RAPOR — ORMAN AĞAÇLARI YENİ MODEL (agac-degisim → main)

## SONUÇ: pinetree.glb GELDİ, ORMAN YENİ MODELDE ✅

27 Tem: `assets/models/env/pinetree.glb` (5.1MB) main'e yüklendi.
Dosya-bekler sistem kod değişikliği olmadan devreye girdi:

- **Hızlı CI yeşil** (yükleme commit'inin kendi koşusu) — model
  yüklenemese roster kırmızı yanardı.
- **Kareler doğrulandı** (`3d_agac_orman/tek` + gece eşleri, ağır CI):
  model dik (Z-up düzeltmesi gerekmedi), zemine oturuyor, parlaklık
  doğal (soluk-Meshy sorunu yok), orman genelinde boy/dönüş varyansı
  görünüyor.
- **Poligon ÖNCE/SONRA:** pinetree1 **5.214** / pinetree2 **4.440**
  üçgen → pinetree.glb **2.145** üçgen. Ağaç başına ~%55–60 azalma.
- **Çizim çağrısı:** eski 2 varyant = 2 MultiMesh → şimdi tek varyant
  = **tüm orman 1 MultiMesh, 1 çizim çağrısı** (ağaç sayısından
  bağımsız). CI yazılım rasterizasyonunda FPS sabit 1.0 olduğundan
  dürüst metrik bu ikisi; cihazda fark hissedilir yönde.
- Not: yeni dosya 5.1MB (eskiler 2.4/2.1) — üçgen değil doku büyük.
  APK/web boyut turu (Meshy dokuları 2048→512) bu dosyayı da kapsamalı.

`pine_tree_small.glb` (%40'lık küçük boy slotu) hâlâ opsiyonel:
yüklenirse karışım kendiliğinden 60/40 olur, TREETEST dağılım bekçisi
o zaman devreye girer. Şimdilik %100 büyük boy.

## KURULAN SİSTEM (kalıcı davranış)

- **`TREE_SET`** (world3d.gd): iki boylu ağırlıklı karışım —
  `pinetree.glb` (%60, boy 3.1) + `pine_tree_small.glb` (%40, boy 2.3 —
  opsiyonel). Seçim hücreden deterministik hash; tek dosya = %100 o,
  hiçbiri yoksa eski pinetree1/2 havuzu (fallback, dosyalar SİLİNMEDİ —
  sis bölgesi Retexture varyantı adayı).
- **Çözümleyici:** önce tablodaki yol (`env/`), yoksa
  `assets/models/test/` — web yüklemeleri nereye düşerse düşsün bulunur.
- **Ölçek kuralı:** node scale YOK — mesh, hedef boya göre AABB'den
  normalize edilip tek ArrayMesh'e pişiriliyor (`_merged_node_mesh`,
  karakter 1 birim referans).
- **Z-up sigortası:** model yatık gelirse (derinlik > boy × 1.4)
  yükleyici −90° X ile dikeltir. (Bu dosyada gerekmedi.)
- **Varyans:** örnek başına rastgele Y-dönüş + **%70–130** ölçek
  (`_tree_variance`). `_cell_variance`'a dokunulmadı — taş/çalı/çiçekle
  ortak; bandı orada genişletmek kayaları da şişirirdi.
- **Kesme davranışı değişmedi:** kesim hücre tabanlı; model yalnız
  MultiMesh'in mesh'i.

## ÖLÇÜM — TREETEST (hızlı CI, her push)

`TREETEST` satırı basıyor: dosyalar VAR/YOK, aktif varyant sayısı,
varyant başına üçgen, haritadaki gerçek dağılım yüzdesi. İki dosya da
tamken 60/40 karışımı %50–70 bandının dışına çıkarsa CI kırmızı.
(Satır artık CI adımında ayrıca grep'leniyor — log tail'inde uyarı
seli arasında kaybolmasın diye.)

## KARELER

`3d_agac_orman.png`, `3d_agac_tek.png` + gece eşleri (docs/screens,
her ağır koşuda tazelenir) — şu an yeni modelle.
