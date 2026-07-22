# MÜHENDİSLİK PAKETİ — Uygulama Raporu

Otonom mod. Branch: `muhendislik` (main üstüne). Kaynaklar: KAZI_SU_MODULU
11.2/11.5/11.8/11.9, GAME_DESIGN 8, YAPI_SISTEMI 13.3, BASE_SAVUNMA B (yaratık
davranışı KOD YOK — yalnız kancalar). Denge sayıları
`scripts/engineering_balance.gd`'de. Aşama başına commit; oyun her commit'te açılır.

## Aşama 1 — Merdiven (11.5)

**Kararlar:**
- **Tarif:** `merdiven` = 4 odun + 1 ip, tezgahta (`recipes.gd`, yeni
  **Mühendislik** kategorisi — turkuaz). İkon PIL ile üretildi.
- **Yerleştirme:** `PLACE_MODELS.merdiven` → `in_pit:true` + **`pit_only:true`**
  (YALNIZ kazılmış çukura konur; düz zemine "çukur gerek"). `rotatable:true`
  ile hangi kenara yaslanacağı seçilir (döndürme butonu). `_place_valid`'e
  `pit_only` kuralı eklendi (YAPI_SISTEMI 13.3 istisna hattı).
- **Görsel:** prosedürel merdiven (`_build_ladder_visual`) — çukur tabanından
  yükselen iki ray + basamaklar, +z kenara yaslı.
- **Tırmanma kuralı (ALET_SISTEMI TODO AKTİF):** `world.can_step(from,to)` —
  `depth >= LADDER_DEEP_MIN(3)` çukurdan daha sığ hücreye **çıkmak** merdiven
  erişimi ister; depth 1-2 serbest. `player3d._try_move` her eksende buna
  danışır. Merdiven erişimi = merdiven o hücrede veya 4-komşusunda.
- **Sökme:** merdiven standart yerleştirilmiş yapı → çekiçle sökülür/taşınır
  (mevcut sistem; ek kod yok).
- **Yaratık kancası (B kısmı):** `can_step` yaratık hareketine de bağlanabilir
  ("gece merdiveni çek" gerilimi) — kod YOK, kanca hazır.

**Denge (`engineering_balance.gd`):** `LADDER_DEEP_MIN=3`,
`LADDER_ADJACENT_OK=true`.

**CI:** `LADDERTEST: derin_merdivensiz=false sig_serbest=true merdivenli=true
ok=true` — derin çukurdan merdivensiz çıkılamaz, sığ serbest, merdiven konunca açılır.
