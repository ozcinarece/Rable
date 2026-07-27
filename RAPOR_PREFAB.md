# RAPOR — KAMP YERLEŞİMİ PREFAB'A TAŞINDI

Başlangıç kampı artık koddaki koordinat tablosundan değil,
**`scenes/prefabs/camp_start.tscn`** sahnesinden kuruluyor.
Branch: `kamp-prefab` → main'e merge edildi.

## NE DEĞİŞTİ

| Önce | Sonra |
|---|---|
| `CAMP_OFF` sözlüğü + `CAMP_TORCHES` listesi (kodda koordinat) | **Silindi.** Konum/dönüş sahnedeki düğümlerden okunuyor |
| Öğe eklemek/taşımak = kod değişikliği | Godot editöründe düğümü sürükle, F5 |
| Yerleşim tek kişinin (kodun) elinde | Sahne dosyası — sen elle düzenliyorsun |

**Değişmeyenler:** yol hücreleri sahneye girmedi (ayrı sistem,
`CAMP_ROADS` kodda kaldı); kamp açıklığı/düzleme mantığı kodda;
görseller hâlâ mevcut prop hattıyla çiziliyor (ton, devrik duruş,
zemine oturtma — tek görsel kaynak, sahneyle oyun ayrışamaz).

## SAHNE YAPISI

```
KampBaslangic
├─ Ocak              (oge="ocak")   — Onizleme: ancient_heart
├─ YikikKulube       (oge="hut")    — Onizleme: ruined_hut
├─ Kuyu              (oge="well")   — Onizleme: ruined_well
├─ ArastirmaMasasi   (oge="masa")
├─ DevrikSandik      (oge="sandik")
├─ Kabak             (oge="kabak")
├─ Tarla / Tumsek1-4       (oge="tarla")
└─ MesaleDirekleri / Mesale1-4  (oge="mesale")
```

- **1 birim = 1 hücre = 1 m.** Sahne kökü = kamp merkezi; dünya
  üretimi sahneyi doğuş noktasına göre okur (tohum değişse de düzen
  aynı kalır).
- **Düğümler sabit yolla DEĞİL, `metadata/oge` ile bulunur** (görev 5).
  Düğümü yeniden adlandır, başka bir konteynıra taşı, sıralamayı boz —
  hiçbir şey kırılmaz. Kulübe onarım kancası ileride `oge=="hut"`
  düğümünü aynı yolla bulacak.
- `get_hearth()` davranışı değişmedi: kamptaki Ocak **dekor** (sönük),
  oyuncu kendi ocağını kurunca `get_hearth()` onu döner. Yaratıkların
  ocaksız hedefi artık **Ocak işaretinin hücresi** — sahnede Ocak'ı
  taşırsan yaratıklar yeni yerine yürür.

## ÖLÇEK KURALI (görev 3)

Node scale **yok**. Kulübe ve kuyu için `.glb.import` dosyaları
commit'lendi, ölçek **import Root Scale** ile:

| Model | Ölçülen boy (Y) | Hedef | Root Scale |
|---|---|---|---|
| `ruined_hut.glb` | 0,928 | 2,80 m | **3.0172** |
| `ruined_well.glb` | 0,676 | 1,20 m | **1.7751** |
| `ancient_heart.glb` | uzun eksen 1,000 | 1,00 m | 1.0 (import dosyası gerekmedi) |

`.import` yol karması doğrulanarak yazıldı (kaynak yolunun md5'i —
mevcut bir png/import çiftiyle test edildi). Oyun kodu AABB'den
normalize ettiği için import ölçeği değişse bile oyun boyutu sabit
kalır (çifte ölçek oluşmaz — kod `hedef/ölçülen` çarpanını her zaman
yeniden hesaplar).

## DOĞRULAMA (görev 6)

Bu ortamda masaüstü Godot yok; "elle taşı + F5" testinin **otomatik
eşdeğeri** yazıldı ve her push'ta koşuyor:

- **PREFABTEST** (hızlı CI): prefab yükleniyor mu, 8 öğe tipi doğru
  adette mi; sonra sahne bellekte açılıp `DevrikSandik` +2 hücre
  taşınıyor ve kayıt yeniden toplanıyor — kayıt (2,0) kaymalı.
  Kanıtladığı şey F5 akışının kanıtladığı şeyin aynısı: **konum
  sahneden okunuyor, koddan değil.** Sonuç:
  `PREFABTEST: oge_eksik=[] tasima_yansidi=true`
- **KAMPTEST** (ağır CI): kamp karesi + yerleşim doğrulamaları
  (doğuş kulübe önünde, kapı açık, 4 yol yönü, mekanik sızması yok,
  tarla 4 hücre). Prefab öncesiyle aynı değerler — kamp birebir
  kuruluyor.

## GODOT'TA KAMPI DÜZENLEME REHBERİ (5 madde)

1. **Sahneyi aç:** Godot'ta projeyi aç → sol alttaki FileSystem
   panelinde `scenes/prefabs/camp_start.tscn` → çift tıkla. Kulübe,
   kuyu ve ocak önizlemeli gelir; diğerleri adlı boş düğümdür
   (seçince gizmo'su görünür).
2. **Snap'i kur:** 3D görünümün üstündeki mıknatıs simgesini aç,
   yanındaki ⋮ menüden **Snap Settings → Translate Snap = 1.0**
   (hücre boyu 1 m). Oyun konumu zaten en yakın hücreye yuvarlıyor;
   1'lik adımlarla taşırsan gördüğün = oyundaki olur. **Y'ye dokunma**
   — zemin yüksekliğini oyun kendisi ayarlıyor.
3. **Taşı / döndür:** düğümü seç, ok gizmo'suyla X/Z'de sürükle.
   Döndürme yalnız **Y ekseni** (yeşil halka); masa/sandık/kuyu
   açıları buradan. Kaydet (Ctrl+S) → oyunu çalıştır (F5) → yeni yer.
4. **Yeni öğe ekle:** aynı tipten çoğaltmak için mevcut düğümü seç →
   **Ctrl+D** (metadata/oge kopyalanır) → taşı. Meşale ve tümsek
   serbestçe çoğalır/azalır (tarla, tümsek sayısı kadar hücre olur).
   Ocak/kulübe/kuyu/masa/sandık/kabak **tekil** — test her birinden 1
   bekler. Yepyeni bir öğe TİPİ eklemek kod işi (bana söyle).
5. **Dokunma:** `Onizleme` alt düğümleri (salt editör görseli — oyun
   bunları kullanmaz, tonları da oyundakinden açıktır, normal);
   düğümlerin **Scale** alanı (ölçek import Root Scale'de, node scale
   yasak); `metadata/oge` değerleri; yol hücreleri (sahneye yol
   ekleme — o ayrı sistem, editördeki Yol Fırçası'nın işi).
