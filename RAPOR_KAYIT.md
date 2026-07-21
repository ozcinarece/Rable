# KAYIT / YÜKLEME SİSTEMİ — Uygulama Raporu

Otonom mod. Branch: `kayit-sistemi` (harita-v2 üstüne). **Yeni oyun özelliği
DEĞİL:** mevcut her sistemin durumunu tek çatıda (SaveManager) toplayıp diske
yazma/okuma. Sistemlerin davranışı DEĞİŞMEZ; sadece serileştirme eklenir.

## AŞAMA 1 — Kaydedilecek durum envanteri (keşif)

### Mevcut durum (keşif)
- `SaveManager` (autoload) sadece ince JSON yazıcı/okuyucuydu; asıl 3D kayıt
  `world3d._save_game_3d()` **tek dev fonksiyonda** toplanıyordu (save3d.json).
- `Research` KENDİ dosyasına yazıyordu (research.json) — tek çatı dışında.
- Ayarlar (kamera/karakter) `cam3d.json`'da ayrı (bunlar OYUN durumu değil,
  tercih — kayıt kapsamı dışında bırakıldı, gerekçe aşağıda).
- Nesneler (`_objects`) TAMAMI kaydediliyordu (128×128'de ~1000+ hücre) —
  büyük dosya. Taban harita zaten kaydedilmiyordu (seed'den üretiliyor).

### Kaydedilecek TÜM durumlar (tam liste)
**Dünya (world3d sahne durumu — `World.to_save_data`):**
| Alan | Tip | Kayıt stratejisi |
|---|---|---|
| harita seed | int | doğrudan (taban harita seed'den üretilir) |
| harita boyutu (w,h) | int | doğrudan (uyumsuzsa kayıt reddedilir) |
| `_depth` (kazı/yığma) | cell→int | **sadece değişen hücreler** (seed'de 0) |
| `_water_level` | cell→float | değişen hücreler |
| `_objects` (ağaç/kaya/çalı/çiçek/mantar/kütük) | cell→str | **DIFF**: seed tabanına göre silinen + değişen hücreler |
| `_object_hits` (kısmi hasat) | cell→int | değişen hücreler |
| `_regrow`/`_regrow_type` | cell→float/str | yeniden büyüme zamanlayıcıları |
| `_ground_char` | cell→str | **kaydedilmez** (seed'den birebir; oyunda değişmiyor) |
| `_clay_cells` | set | **kaydedilmez** (seed'den) |
| `_placed` (yapılar) | cell→id | doğrudan |
| StructureManager (`_structures`) | liste | `to_save_data`: yön/hp/max_hp/durum/kapı-açık |
| Sandık içerikleri (`_chests`) | cell→Inventory | her sandık `to_save` (slot/stack) |
| Yerdeki item'lar (`_ground_items`) | liste | cell/id/count |
| Test kuklaları (`_dummies`) | liste | cell |
| `_home_bed` (doğuş noktası) | cell | doğrudan (14.2) |
| aktif Ocak (`_hearth_cell`) | cell | `_placed`'ten türetilir (ocak yerleşince aktif) |
| platform hücreleri | set | `_placed`'ten türetilir |
| oyuncu konumu | x,z | doğrudan |
| kuşanılan alet (`_held_item`) | str | doğrudan |

**Autoload sistemleri (her biri kendi `to_save_data`/`from_save_data`):**
| Sistem | Durum |
|---|---|
| Inventory | slotlar + hotbar (`to_save`) |
| Crafting | üretim kuyruğu (`to_save`) |
| Research | açılmış düğümler + görünür gizli düğümler → **artık tek çatıda** |
| Health | can değeri |
| Hunger | açlık değeri |
| Thirst | susuzluk değeri |
| PlayerStats | ölüm sayısı (+ ileride) |
| DayNight | gün, gece-mi, döngü-süresi (+ ileride saat alanı) |

### Kayıt kapsamı DIŞI (gerekçeli)
- **Ayarlar** (kamera zoom/pitch, karakter/şapka/saç): oyun DURUMU değil
  cihaz/oyuncu TERCİHİ; ayrı `cam3d.json`'da kalır (yeni oyunda sıfırlanmamalı).
- **Taban harita** (`_ground_char`, ağaçların ilk yeri): seed'den üretilir;
  yalnız oyuncunun DEĞİŞTİRDİĞİ hücreler yazılır (dosya küçük kalır).

*(Aşama 2-4 aşağıda; iş ilerledikçe dolar.)*
