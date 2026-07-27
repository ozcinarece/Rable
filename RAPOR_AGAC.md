# RAPOR — ORMAN AĞAÇLARI YENİ MODELLER (agac-degisim)

## DURUM: MODEL DOSYALARI REPODA YOK

`pine_tree_v2.glb` ve `pine_tree_small.glb` **hiçbir dalda bulunamadı**
(tüm dallar tarandı). Görev "eklendi" diyor ama yükleme repoya
düşmemiş — muhtemelen tamamlanmadı ya da başka bir yere gitti.

**Sistem yine de tamamen kuruldu ve dosya-bekler hâlde:** iki dosya
`assets/models/env/` altına düştüğü anda kod değişikliği olmadan
devreye girer (yaratık GLB'leriyle aynı kalıp). O zamana kadar orman
eski pinetree1/2 ile çiziliyor — davranış birebir eski hâli.

## KURULAN SİSTEM

- **`TREE_SET`** (world3d.gd): iki boylu ağırlıklı karışım —
  `pine_tree_v2` (%60, boy 3.1) + `pine_tree_small` (%40, boy 2.3).
  Seçim hücreden deterministik hash ile; tek dosya gelirse %100 o,
  hiçbiri yoksa eski havuz.
- **Ölçek kuralı:** node scale YOK — mesh, hedef boya göre AABB'den
  normalize edilip tek ArrayMesh'e pişiriliyor (mevcut
  `_merged_node_mesh` hattı, karakter 1 birim referans).
- **Z-up sigortası:** model yatık gelirse (derinlik > boy × 1.4)
  yükleyici −90° X ile dikeltir — yol taşlarında ölçülen Meshy
  standardına karşı otomatik koruma. Dosyalar gelince ilk CI karesi
  yön/ölçeği gösterir; gerekirse inceltilir.
- **Varyans:** örnek başına rastgele Y-dönüş + **%70–130** ölçek bandı
  (`_tree_variance`). `_cell_variance`'a dokunulmadı — o taş/çalı/çiçekle
  ortak; bandı orada genişletmek kayaları da şişirirdi.
- **Kesme davranışı değişmedi:** kesim hücre tabanlı (`_try_harvest` →
  partikül + saçılan odun + görsel yeniden kurulum); model yalnız
  MultiMesh'in mesh'i. Ayrı bir devrilme tween'i bugünkü oyunda yok —
  kesimde partikül patlaması + anında kalkma; bu tur onu değiştirmedi.

## ÖLÇÜM — TREETEST (hızlı CI, her push)

`TREETEST` satırı basıyor: dosyalar VAR/YOK, aktif varyant sayısı,
**varyant başına üçgen sayısı** (poligon bütçesi), haritadaki gerçek
dağılım yüzdeleri ve toplam örnek. Yeni set tam olduğunda 60/40 karışımı
%50–70 bandının dışına çıkarsa CI kırmızı yanar.

Mevcut koşu (fallback): `pine_tree_v2.glb=YOK pine_tree_small.glb=YOK
yeni_set=false varyant=2` + pinetree1/2 üçgen sayıları.

**FPS önce/sonra:** CI yazılım rasterizasyonunda FPS 1.0'a sabit —
dürüst metrik çizim çağrısı + üçgen. Fallback aktifken önce=sonra
(aynı modeller). Dosyalar gelince aynı TREETEST satırı yeni üçgen
sayılarını, perf sondası da çizim çağrısını verecek; karşılaştırma
o commit'in CI logunda hazır olacak. **MultiMesh doğrulandı:** varyant
başına tek MultiMesh düğümü (2 varyant = 2 çizim çağrısı, ağaç sayısından
bağımsız).

## KARELER

`3d_agac_orman.png`, `3d_agac_tek.png` + gece eşleri (ağır CI, her
koşuda). Şu an fallback modelleriyle; dosyalar gelince aynı kareler
yeni ormanı gösterecek.

## SENİN YAPMAN GEREKEN

`pine_tree_v2.glb` (ve varsa `pine_tree_small.glb`) dosyalarını GitHub
web'den **`assets/models/env/`** klasörüne yükle (Add file → Upload
files). Başka hiçbir şey gerekmiyor — sonraki CI koşusunda TREETEST
`yeni_set=true` diyecek ve kareler yeni modelle gelecek.
