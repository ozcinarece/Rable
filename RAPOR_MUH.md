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

## Aşama 2 — Çukur kazığı (11.9)

**Kararlar:**
- **Tarif:** `kazik` = 3 taş + 2 çubuk, tezgah, Mühendislik kategorisi.
- **Yerleştirme:** `PLACE_MODELS.kazik` → `in_pit:true` + `pit_only:true`
  (kazılmış hücrenin **tabanına**; 13.3 istisnası). `solid:false`.
- **Görsel:** prosedürel sivri koniler (`_build_spikes_visual`), çukur
  tabanından yükselir (`SPIKE_VISUAL_HEIGHT`).
- **İşlev:** Oyuncu kazıklı hücreye girince **bir kez** küçük hasar
  (`_tick_spike_hit`, `Health.damage`); hücreden çıkınca sıfırlanır
  (tekrar girince yeniden). Değer `SPIKE_FALL_DAMAGE`.
- **Yaratık kancası (B kısmı):** `spike_damage(cell)` → düşen/hapsolan
  yaratığa uygulanacak hasarı verir. **Davranış kodu YOK** — kanca hazır.

**Denge:** `SPIKE_FALL_DAMAGE=8`, `SPIKE_VISUAL_HEIGHT=0.5`.

**CI:** `SPIKETEST: hook_hasar=8 ... hook_ok=true hasar_ok=true` — kazığa
giren oyuncu hasar alır, yaratık kancası doğru hasarı döner.

## Aşama 3 — Boru sistemi (11.8 altyapısı)

**Kararlar:**
- **Tarif:** `boru` = 1 taş + 1 kil → 2 boru, tezgah (GAME_DESIGN 8'de 1
  `metal_part`; metal işleme gelene kadar **muhafazakâr** malzeme, çok gerekir).
- **Yerleştirme:** `PLACE_MODELS.boru` → `in_pit:true`, pit_only DEĞİL (zemine
  ya da çukura konur). `solid:false`.
- **Otomatik bağlanma:** `_pipe_mask(cell)` 4-komşu bit maskesi → `_build_pipe_visual`
  merkez küp + açık yönlere kollar (düz/dirsek/T/haç **otomatik** çıkar).
  Yerleştirme/sökmede hücre + 4 komşu görseli tazelenir (`_refresh_pipe_neighborhood`).
- **Ağ = graf:** `_pipe_components()` bağlı boru/pompa/vana hücrelerini flood-fill
  bileşenlere ayırır. Her bileşende `_transfer_in_component` en yüksek **kaynağı**
  (göl `~` veya dolu havuz, boruya komşu) bulur, uygun **hedefe** (boş kapasiteli
  kazılmış havuz) taşır. Mevcut `add_water`/`take_water`/`pool_at` kapıları
  kullanılır — su fiziksel akmaz, **mantıksal** transfer (`NET_TICK_SECONDS`'ta bir).
- **YÜKSEKLİK KURALI:** `_cell_elevation` (−depth) ile kaynak yüksekliği ≥ hedef
  olmalı; su yalnız **aşağı/aynı** seviyeye akar. Yukarı taşıma pompa ister (Aşama 4).

**Denge:** `PIPE_TRANSFER_PER_SEC=2.0`, `NET_TICK_SECONDS=0.5`.

**CI:** `PIPETEST: down_akar=true up_engel=true ok=true` — kaynak yüksekse
(down) su akar; kaynak alçaksa (up) pompasız akmaz.
