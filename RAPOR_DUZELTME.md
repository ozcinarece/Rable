# TEST BULGULARI — 4 Düzeltme Raporu

Otonom mod. Branch: `test-duzeltmeleri` (yapi-sistemi üstüne).

## 4. AĞAÇ HATASI — KÖK NEDEN (teşhis önce)

**Belirti:** Tek ağaç olması gereken yerde 4-5 ağaç iç içe; bir kesim
hepsini götürüyor.

**Kök neden (b şıkkı):** Kullanılan model `quat2_tree02.glb`, GLB içinde
**tek bir birleşik mesh** olarak duran bir *grup* modeli
("Resource_PineTree_Group" — 4-5 çam tek mesh'e gömülü). `_model_pool`
GLB'nin üst-düzey mesh'li çocuklarını sayar; burada 1 parça görür →
`parts.size() <= 1` dalına düşer → `_merged_node_mesh(scene)` TÜM sahneyi
(bütün çam grubunu) tek mesh'e birleştirir. Sonra her ağaç hücresi bu
grup mesh'ini render eder → "4-5 ağaç iç içe". Kesim tek varlık (hücre)
olduğu için hepsi birden gider (c değil — kesim doğru çalışıyor; sorun
görselin çoklu ağaç içermesi).

**Doğrulama:** `quat2_tree02.glb` = 1 mesh (grup). Karşılaştırma:
`quat2_tree01.glb` = 5 ayrı mesh (NormalTree_1..5, pool düzgün çalışır),
Kenney `tree_pineDefaultA.glb` = 1 mesh ama **tek ağaç**.

**Düzeltme:**
1. Ağaç havuzu tek-ağaç çam modellerine geçirildi (Kenney
   `tree_pine*` — her biri tek ağaç); birkaç varyanttan havuz kurulup
   hücreye göre çeşitlilik korunur.
2. Harita yüklemede **min 1 boş hücre** kuralı: bir "T" hücresi, zaten
   yerleştirilmiş bir ağacın 8-komşuluğundaysa zemine çevrilir (spawn'da
   seyreltme). Böylece 1 hücre = en fazla 1 ağaç ve ağaçlar bitişmez.
3. Kesim zaten tek hücreyi etkiliyordu (değişmedi).

## 1. YERE DÜŞEN EŞYALAR — GÖRÜNÜR DÜNYA OBJESİ

**Sorun:** "At" ile bırakılan eşya minik billboard ikon (Sprite3D,
`pixel_size 0.014`) olarak konuyordu — dünyada zor seçiliyordu. Ağaç/kaya
kesiminde düşenler ise doğrudan envantere ışınlanıyordu; "dünyada eşya"
hissi yoktu.

**Yapıldı (tek sistem):**
- `_add_ground_item` artık **kategori renkli low-poly govde** üretir:
  kutu (varsayılan) veya küre (meyve/mantar/altın/bakır/çakıl). Renk
  eşya kategorisine göre (`_item_category_color`): ahşap kahve, taş gri,
  kömür koyu, altın sarı, bakır turuncu, yiyecek kırmızı…
- **Süzülme + yavaş dönme** animasyonu (`_tick_ground_items`, `_process`'te):
  her eşya kendi fazında hafifçe alçalıp yükselir ve döner (canlı his).
- **Ağaç/kaya hasadı artık envantere UÇMAZ — yere saçılır** (`_scatter_drops`,
  yıkımla aynı sistem). Oyuncu yaklaşıp **"al"** bağlam butonuyla toplar
  (toplama pop'u = partikül). Klasik survival döngüsü (kes → yerde gör → topla).
  Envanter dolu olsa da hasat olur; eşyalar yerde bekler.
- **Yapı yıkımı** zaten `_add_ground_item` kullanıyordu → yeni görsele
  otomatik geçti (üç kaynak tek sistem).
- **~100 eşya sınırı** (`GROUND_ITEM_LIMIT`): dolunca en eski silinir.
- **Dolu envanter toplamayı reddeder** (`_try_pickup_ground`): "Envanter dolu!"
  uyarısı, eşya yerde kalır (kayıp yok).
- Aynı id aynı hücreye düşerse **istiflenir** (görsel kalabalık azalır);
  saçılma boş komşu hücreleri tercih eder.
- Kayıt uyumlu: sadece cell/id/count kaydedilir; node/animasyon yüklemede
  yeniden üretilir.

## 2. ELDEKİ ALET GÖRÜNSÜN

**Yapıldı:** `set_held_tool(item_id)` artık **eşya id'sini** alır.
- Gerçek Kenney GLB'si varsa yüklenir (`TOOL_GLB`: balta→tool-axe,
  kazma→tool-pickaxe, kürek→tool-shovel, çekiç→tool-hammer, kova→bucket).
- Yoksa **prosedürel low-poly placeholder** (`_make_tool`): balta (sap+baş),
  kazma (çapraz baş), kürek (yassı baş), çekiç (kalın baş), bıçak, kılıç
  (kabza+siper), sopa, mızrak (sivri uç), yay, sapan, kova.
- **Sap = ahşap kahvesi**, **baş = alet kademesi rengi** (`_tool_head_color`:
  taş gri / bakır turuncu / demir açık gri / çelik mavi-gri). Şu an tek
  kademe (taş) var; üst kademe id'leri gelince otomatik renklenir.
- Boyut, GLB ve prosedürel için **aynı AABB normalizasyonu** ile ~0.5 m'ye
  ayarlanır (el boyutuna oturur). Alet değişince görsel anında değişir;
  sallama animasyonu aletle birlikte oynar.
- `world3d` içindeki ölü `TOOL_MODELS` sözlüğü kaldırıldı (tek kaynak: id).

## 3. VARSAYILAN ENVANTER 16 SLOT

**Yapıldı:** `Inventory.BASE_SLOTS` 8 → **16** (tek doğruluk kaynağı).
İleride "deri çanta" bu tabanın üstüne ekler (`SLOTS_PER_BAG * çanta`).
HUD envanter ızgarası mobilde **4×4** (`columns = 4`); slotlar
`TOTAL_SLOTS` kadar kurulur, `get_slot_count()` üstündekiler kilitli görünür.

## SENİN İÇİN TEST LİSTESİ
1. **At → yerde gör → topla:** Envanterden bir eşyayı "At". Önünde
   **renkli kutu/küre** süzülüp dönerek belirsin. Yaklaş → **"al"** butonu →
   topla (pop). Envanteri doldurup toplamayı dene → "Envanter dolu!", eşya
   yerde kalır.
2. **Alet kuşan → elde gör → salla:** Balta/kazma/kürek/kılıç… eline al.
   Sağ elde **3D model** görünsün (GLB varsa gerçek, yoksa renkli placeholder;
   baş = taş grisi). Alet değiştir → görsel anında değişsin. Salla → model
   birlikte hareket etsin.
3. **16 slot:** Envanteri aç → **4×4 = 16** açık slot. (Çanta yapınca +4.)
4. **Tek ağaç kes → tek ağaç düşsün:** Yeni harita. Ağaçlar **bitişik
   değil** (aralarında en az 1 boş hücre). Bir ağacı kes → **sadece o**
   gitsin, düşenler yere saçılsın (envantere değil), "al" ile topla.

---
*Otonom mod tamam: 4 madde, 4 ayrı commit. CI ile doğrulanacak.*

---

# EK DÜZELTME — Alet Görseli Bug'ı (branch `alet-gorsel-fix`, 2 commit)

## 1. ALET ÇOĞALMASI (öncelikli) — kök neden ve düzeltme
**Belirti:** Kuşanılan alet değiştikçe eldeki alet görselleri birikiyordu.

**İki ayrı kök neden bulundu (ikisi de düzeltildi):**
- **(a) Ertelemeli `queue_free()`** — `set_held_tool` eski pivot'u
  `queue_free()` ile siliyordu; ama bu ANINDA değil kare sonunda çalışır.
  Hotbar'dan hızlıca alet değiştirilince (aynı kare / arka arkaya kareler)
  eski pivot bir süre ağaçta kalıyordu. **Düzeltme:** önce
  `_tool_attach.remove_child(child)` ile ANINDA ağaçtan çıkar, sonra
  `queue_free()`. Böylece `get_children()`/render anında hep temiz.
- **(b) Ayna düğümü sızıntısı** — GLB karakter yolunda `_tool_attach` ve
  `_head_attach`, `_model_root`'un değil `_visual`'in doğrudan çocuğudur.
  `set_character` yalnız `_model_root`'u `queue_free()` edip aynaları
  `null`'a çekiyordu → eski pivot+alet/şapka görselleri `_visual` altında
  KALICI birikiyordu. **Düzeltme:** karakter değişiminde `_visual`'e bağlı
  eski aynalar da `queue_free()` edilir (custom karakterde ayna model_root
  altında olduğu için o dalda tekrar dokunulmaz — çift-free yok).

**İnvaryant:** ToolPivot'ta aynı anda **en fazla 1** alet görseli bulunur.
Equip akışı tek fonksiyonda (`set_held_tool`): temizle → yeni görsel ekle.
`hud.hold_requested` sinyali dünya kurulumunda **tek sefer** bağlanır
(world3d.gd:296) — doğrulandı, çift bağlanma yok.

**Regresyon testi (CI):** `TOOLDUP` — 20 kez hızlıca alet değiştir;
`max_pivot<=1`, alet varken `1` görsel, eli boşaltınca `0` görsel.
`player.debug_tool_counts()` sayaçları döndürür.
