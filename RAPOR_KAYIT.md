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

## AŞAMA 2 — Altyapı
- **SaveManager (autoload) TEK ÇATI oldu:** `save()` / `load_game()` /
  `has_save()`. JSON, `user://save3d.json`, tek slot. Dosyada `"version"` +
  `_migrate()` kancası (ileride sürüm geçişi). Her sistemin
  `to_save_data()`/`from_save_data()`'sını **toplar/dağıtır** — merkezi dev
  serileştirme YOK.
- **Eklenen serileştiriciler:** Research, DayNight, PlayerStats, Health,
  Hunger, Thirst (Inventory/Crafting/StructureManager'da zaten vardı).
- **world3d:** `_save_game_3d`/`_load_game_3d` → `to_save_data()`/
  `from_save_data()` (yalnız SAHNE durumu; autoload'lar SaveManager'da).
  Yükleme sırası: **autoload'lar önce** (dünya, eldeki aleti envanterden
  doğrular), **sahne en son**.
- **Nesne DIFF (dosya küçük):** `_objects` tamamı değil, seed tabanına
  (`_base_objects`) göre **fark** yazılır: `obj_removed` (kesilen ağaç/kaya) +
  `obj_changed` (yeniden büyüme/kütük). Yüklemede taban + diff. Taban harita
  (`_ground_char`, kil) hiç yazılmaz — seed'den üretilir.

## AŞAMA 3 — Tetikleyiciler + UI
- **Otomatik kayıt: her 2 dk** (`AUTOSAVE_INTERVAL=120`, yalnız `_dirty`) +
  **app arka plana** (`NOTIFICATION_APPLICATION_PAUSED` — mobilde kritik) +
  **çıkış** (`WM_CLOSE_REQUEST`/`GO_BACK`). Hepsi `SaveManager.save()`.
- **Açılış "Devam Et / Yeni Oyun"** ekranı (kayıt varsa): iki pill buton
  (theme_main). "Yeni Oyun" eski kaydın üstüne yazmadan **onay ister** →
  `delete_save()` + tüm autoload reset (taze dünya zaten kurulu).
- **Kayıt işareti:** `SaveManager.saved` sinyali → HUD köşesinde 0.5 sn
  "✓ Kaydedildi" (sonra söner).

## AŞAMA 4 — Doğrulama (round-trip)
CI self-test (`_run_save_load_selftest`): zengin durum kur (kazı+yapı+dolu
sandık+araştırma) → **save1** → belleği boz (envanter/can/nesne sıfırla) →
**load** → **save2** → iki JSON **derin (sırasız) eşitlik** (`_first_diff`;
sözlük anahtar sırası önemsiz, dizi sırası korunur, float toleransı). Eşleşmezse
ilk farklı yol yazdırılır (`SAVELOAD_MISMATCH`). CI: `SAVELOAD: PASS`.

## Dosya boyutu (örnek)
Taban harita (128×128, ~1000 nesne) **yazılmaz** (seed'den üretilir). Kayıt
yalnız değişenleri tutar: birkaç kazı hücresi + yapı + sandık + envanter +
autoload durumları. Boş-yakını başlangıçta dosya ~birkaç KB; yoğun oynamada
(çok kazı/yapı) onlarca KB. CI log'unda `bytes=` gösterir.

## Bilinen sınırlar
- **Tek slot** (v1). Çoklu slot ileride (SaveManager path'i parametrik yapılır).
- **Eski format kayıtlar** (`"v":1` düz 3D veya 40×25) `version`/boyut
  kontrolünden geçemez → yeni oyun (migration yalnız ileri sürümler için).
- **Ayarlar** (kamera/karakter) hâlâ ayrı `cam3d.json` (tercih, oyun durumu
  değil). **Research legacy** `research.json` self-save korundu (anlık
  kalıcılık); tek kaynak yüklemede SaveManager verisidir.
- **Seed sabit** (harita-v2 kararı): taban harita determinist; seed alanı
  kayıtta var, ileride random-per-newgame'e hazır.

## TEST SENARYOSU (senin için)
1. **Zengin durum kur:** birkaç yer kaz (su çıkar), duvar/sandık/ocak yerleştir,
   sandığı doldur, bir araştırma düğümü aç, birkaç ağaç kes.
2. **Bekle** (2 dk otomatik kayıt → köşede "✓ Kaydedildi") veya oyundan çık.
3. **Uygulamayı TAMAMEN kapat-aç** (mobilde arka plana at) → açılışta
   **"Devam Et / Yeni Oyun"**. **Devam Et** → her şey aynı: kazılar, su,
   yapılar, dolu sandık, araştırma, can/açlık, eldeki alet, ölüm sayısı.
4. **Yeni Oyun** → **onay sorar**; onaylarsan taze harita (aynı seed) + boş
   envanter; eski kayıt silinir.
5. Kesilen ağaçlar kesik, kazılan çukurlar dolu/derin kalır (nesne diff).
