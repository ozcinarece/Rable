# YAPI SİSTEMİ (Bölüm 13) — Uygulama Raporu

Otonom mod. Branch: `yapi-sistemi` (alet-sistemi üstüne — take_hit gerekli).
Kaynak: `YAPI_SISTEMI.md`.

## Adım 0 — Keşif bulguları

**Mevcut yerleştirme (zaten var):** `_placed` (hücre→item_id), `_placed_nodes`
(hücre→Node3D), `_set_placed`/`_try_place`/`_remove_placed`, `PLACE_MODELS`
sözlüğü (model+h/long+solid+extra). Akış: elde item → hücreye dokun → anında
kurulur. Hayalet/döndürme/hp YOK.

**take_hit arayüzü** ALET_SISTEMI'nde `hittable_dummy.gd`'de tanımlı; yapılar
aynı imzayı kullanacak.

**Çekiç** zaten söküme bağlı (`_describe_target` cekic+placed → dismantle →
`_remove_placed`, %100 iade). Tamir eklenecek.

**Kayıt sistemi VAR:** Önceki görevde `_save_game_3d`/`_load_game_3d` eklendi;
`_placed`+`_chests` zaten kaydediliyor. Doküman "kayıt yok" varsayıyor — bu bir
uyumsuzluk (aşağıda karar).

## Kararlar (muhafazakâr; gerekçeli)

- **KARAR:** `_placed`/`_placed_nodes` KORUNUR (istasyon yakınlık, çekiç, katılık,
  sandık, kayıt hepsi buna bağlı — refactor riskli). StructureManager bunların
  YANINA per-instance meta (yön, hp, max_hp, durum) tutan sidecar olur; `_set_placed`/
  `_remove_placed` ile senkron kalır. Tek doğruluk: StructureManager metası + `_placed` id.
- **KARAR:** placeable/max_hp/rotatable/placeable_on_water/placeable_in_pit/behavior
  alanları `PLACE_MODELS`'e eklenir (canlı sistemin tek yerleştirme kaynağı).
  item_db.gd (İngilizce GDD katmanı) canlı sistemde kullanılmadığından dokunulmaz.
- **KARAR:** Kayıt VAR olduğundan, StructureManager.to_save_data/from_save_data
  YAZILIR (13.6) ve tutarlılık için mevcut `_save_game_3d`'ye BAĞLANIR (yön/hp
  kaydedilsin; yoksa hasarlı duvar reload'da iyileşirdi = regresyon). Doküman
  "bağlama" dese de mevcut kayıt sistemiyle tutarlılık öncelikli — tek satırlık
  bağlama, gerekçe bu.
- **KARAR:** max_hp eşlemesi: ahsap_duvar(wood_wall)=80, tas_duvar(stone_wall)=160,
  kapi(wood_door)=80, tuzak=30, zemin=40, diğer istasyonlar(tezgah/sandik/…)=120.

*(Aşama raporları ve test senaryosu dosya sonunda — iş ilerledikçe dolar.)*
