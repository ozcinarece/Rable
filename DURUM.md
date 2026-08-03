# DURUM — Proje Envanteri (Mevcut Fonksiyonalite Denetimi)

Tarih: 2026-07-25 · Kaynak: KOD (origin/main + gorsel-tur dalı) ·
Kural: bir özellik ancak kodda çalışır halde varsa VAR sayıldı.
Durum değerleri: ÇALIŞIYOR / BRANCH'TE / YARIM / SADECE-PLAN / BOZUK.

## ENVANTER TABLOSU

| Modül | Özellik | Durum | Branch | Ana dosyalar | Bağımlılıklar | Bilinen sorunlar | Not |
|---|---|---|---|---|---|---|---|
| Dünya | 128×128 prosedürel ada (FastNoiseLite, seed) | ÇALIŞIYOR | main | map_gen.gd, world3d.gd | — | — | MAPTEST CI'da her koşuda |
| Dünya | Zemin türleri (çim/toprak/kum/su/kil) | ÇALIŞIYOR | main | world3d.gd (_ground_char) | harita | — | — |
| Dünya | Dekor (çiçek/mantar/çalı, GLB ağaçlar) | ÇALIŞIYOR | main | world3d.gd (_build_decor) | stil-vitrin (merged) | — | pine_tree GLB bağlı |
| Dünya | Çevre serpintisi (çakıl/dal, MultiMesh) | BRANCH'TE | gorsel-tur | world3d.gd (_build_env_scatter), env_models.gd | — | — | ot tutamı kaldırıldı; tür başına tek MultiMesh |
| Dünya | Aşınmış yol izi (zemin renk lekesi) | BRANCH'TE | gorsel-tur | world3d.gd (_cell_props, _add_path_strip) | — | — | yol taşları kapalı (PATH_STONES_ON) |
| Dünya | Zemin geçiş bandı (yama sınırları organik + harmanlı) | BRANCH'TE | gorsel-tur | world3d.gd (_build_edge_blend), map_gen.gd | — | — | sınırda serpinti 1.7x |
| Dünya | Spawn kampı (yerleşim PREFAB'ta: camp_start.tscn) | ÇALIŞIYOR | main | scenes/prefabs/camp_start.tscn, world3d.gd (_camp_load_items) | — | — | Godot editöründe elle düzenlenir; PREFABTEST + KAMPTEST CI'da; RAPOR_PREFAB.md |
| Tarım | Boş sürülü tarla göstergesi (planting_mound) | BRANCH'TE | gorsel-tur | world3d.gd (_update_mound_node) | tarım-3d | — | ekilince kaybolur, hasatta döner |
| Dünya | Taş yol (SERPİNTİ modeli, stone_scatter_a) | ÇALIŞIYOR | main | world3d.gd (_build_road_scatter), road_scatter.gd | — | moss_patch.glb yok → yosun hiç çizilmiyor | ROADTEST + SCATTERTEST CI'da; karo modeli TILE_MODE_ON=false ile kapalı |
| Araçlar | Yerleşim Editörü (oyun içi düzenleme + camp_layout.json) | ÇALIŞIYOR | main | layout_editor.gd, world3d.gd, hud.gd | taş yol | yalnız debug build; düzen dosyası henüz repoda yok | EDITORTEST CI'da; RAPOR_EDITOR.md |
| Keşif | Halka + sis + ışık kapısı (16.1-16.2) | BRANCH'TE | kesif | kesif_balance.gd, world3d.gd, hud.gd | — | görsel: vinyet+sis düzlemi placeholder | KESIFTEST CI'da; RAPOR_KESIF.md |
| Keşif | Kor taşları (6 ana + 3 yan, yakma + kalıcı temizlik) | BRANCH'TE | kesif | world3d.gd, kesif_balance.gd | halka+sis | taş görseli placeholder silindir | KORTEST CI'da |
| Keşif | Sefer/kamp + Ocak dalga simülasyonu + sabah raporu | BRANCH'TE | kesif | world3d.gd, hud.gd | kor taşları | Nefes UI yok (API hazır) | SEFERTEST CI'da |
| Keşif | Uyuyanlar (gündüz stealth) + fener kıs + HUD nabzı | BRANCH'TE | kesif | world3d.gd, hud.gd | halka+sis | heykel görseli placeholder | UYUTEST CI'da |
| Keşif | Uzak tehditler (sürü/avcı/dev + fırtına + damar çatlağı) | BRANCH'TE | kesif | creature_balance.gd, world3d.gd | halka+sis | GLB'ler dosya-bekler | UZAKTEST CI'da |
| Dünya | Orman ağaç seti (pinetree.glb aktif; küçük boy %40 slotu opsiyonel) | ÇALIŞIYOR | main | world3d.gd (TREE_SET, _tree_set_pool) | — | — | TREETEST CI'da; 2145 üçgen (eskisi 5214/4440), tüm orman tek MultiMesh; pine_tree_small.glb gelirse 60/40; RAPOR_AGAC.md |
| Dünya | Ağaç kesme + çalı yeniden büyüme | ÇALIŞIYOR | main | world3d.gd, gather_rules.gd | alet | — | balta tek vuruş |
| Dünya | Kaya kırma (taş/kömür/altın/bakır) | ÇALIŞIYOR | main | world3d.gd | kazma | — | — |
| Kazı | Kürekle kazı (derinlik 1–4) | ÇALIŞIYOR | main | world3d.gd (_depth), dig_rules.gd | kürek | — | — |
| Kazı | Toprak doldurma / zemin yükseltme (+2) | ÇALIŞIYOR | main | world3d.gd | toprak item | — | — |
| Kazı | Merdiven (derin çukurdan çıkış) | ÇALIŞIYOR | main | world3d.gd | muhendislik (merged) | — | — |
| Kazı | Çukur kazığı (düşme hasarı) | ÇALIŞIYOR | main | world3d.gd | — | yaratık hedefi yok (yaratık AI bekliyor) | — |
| Su | Su modeli (birleşik kaplar, seviye) | ÇALIŞIYOR | main | water_sim.gd, water_rules.gd | kazı | — | SUTEST CI'da |
| Su | Kova doldur / dök | ÇALIŞIYOR | main | world3d.gd | — | — | — |
| Su | Su içme (kenardan, susuzluk) | ÇALIŞIYOR | main | world3d.gd:3022, thirst.gd | — | — | — |
| Su | Boru ağı (aşağı/yana akış) | ÇALIŞIYOR | main | world3d.gd (pipe graf) | — | — | — |
| Su | Pompa (yukarı taşıma) | ÇALIŞIYOR | main | world3d.gd | boru | — | — |
| Su | Vana (aç/kapa) | ÇALIŞIYOR | main | world3d.gd | boru | — | — |
| Envanter | 16 slot + kilitli slotlar (çanta ile +4, maks 2) | ÇALIŞIYOR | main | inventory.gd, hud.gd | — | — | — |
| Envanter | Sırt Çantası UI (mockup: sekme/tutamaç/çift halka) | ÇALIŞIYOR | main | hud.gd, ui_slot.gd, ui_dots/handle.gd | — | — | CLICKTEST ✓ |
| Envanter | Hotbar (5 slot, dokun-al, atama) | ÇALIŞIYOR | main | hud.gd, inventory.gd | — | — | — |
| Envanter | Eşya at / yerden topla (uçan ikon) | ÇALIŞIYOR | main | world3d.gd, ground_item.gd | — | — | — |
| Envanter | Sandık (Al/Koy, Tümünü, sök) | ÇALIŞIYOR | main | hud.gd, world3d.gd (_chests) | — | overlay bugı 01:19 APK'da düzeltildi | iki-sütun UI |
| Envanter | Flavor metinleri (55 eşya) | ÇALIŞIYOR | main | items.gd (FLAVOR) | — | tohum metni "ekilir" diyor ama 3D'de ekim YOK | çelişki listesinde |
| Craft | Tarif kataloğu (Türkçe id'li, canlı) | ÇALIŞIYOR | main | recipes.gd | — | recipe_db.gd İKİNCİ katalog, hiçbir kod kullanmıyor | çelişki listesinde |
| Craft | Üretim paneli (raf + 3 durumlu kartlar + detay) | ÇALIŞIYOR | main | hud.gd, ui_info_strip.gd | araştırma, istasyon | — | mockup birebir, CLICKTEST ✓ |
| Craft | Üretim kuyruğu + ilerleme çubuğu | ÇALIŞIYOR | main | crafting.gd, hud.gd | — | — | — |
| Craft | İstasyon kapıları (tezgah/ocak yakınlığı) | ÇALIŞIYOR | main | crafting.gd (near_station/hearth) | yapı | — | detay şeridi 3 seste gösterir |
| Craft | Hotbara uçan üretim ikonu | ÇALIŞIYOR | main | hud.gd (_fly_to_hotbar) | — | — | — |
| Araştırma | Araştırma ağacı UI (dallar, düğümler) | ÇALIŞIYOR | main | ui_research.gd, research.gd | — | — | — |
| Araştırma | Düğüm satın alma (malzeme maliyeti) | ÇALIŞIYOR | main | research.gd | envanter | — | masa yanında |
| Araştırma | Tarif kilidi (is_recipe_unlocked) | ÇALIŞIYOR | main | research.gd, crafting.gd | — | — | üretim kartında kilit görünür |
| Araştırma | Gizli düğümler (???) | ÇALIŞIYOR | main | ui_research.gd | — | — | kil ile tetiklenir |
| Araştırma | Öz ile gizli araştırma harcaması | SADECE-PLAN | — | — | yaratık özü | öz düşüyor ama HARCANDIĞI yer yok | kanca boş |
| Alet/Silah | 3 fazlı sallama (windup/strike/recover) | ÇALIŞIYOR | main | player3d.gd, tool_profiles.gd | — | — | — |
| Alet/Silah | Alet bonusları (balta/kazma/kürek/bıçak/çekiç) | ÇALIŞIYOR | main | gather_rules.gd, world3d.gd | — | — | — |
| Alet/Silah | Silahlar: sopa 12 / kılıç 18+kombo / mızrak 30 | ÇALIŞIYOR | main | tool_profiles.gd, world3d.gd | — | hedef olarak yalnız kukla var (yaratık AI yok) | — |
| Alet/Silah | Menzilli: yay+ok, sapan+çakıl (basılı tut) | ÇALIŞIYOR | main | world3d.gd | — | — | — |
| Alet/Silah | Kukla (eğitim hedefi, take_hit arayüzü) | ÇALIŞIYOR | main | hittable_dummy.gd | — | — | yaratıklarla aynı arayüz |
| Alet/Silah | Zırh %40 / şapka %15 hasar azaltma | ÇALIŞIYOR | main | health.gd:15-18 | envanter | — | — |
| Alet/Silah | Meshy GLB aletler elde (balta/kazma/kürek) | ÇALIŞIYOR | main | player3d.gd (TOOL_HOLD/grip_pt) | karakter | — | veri-tabanlı kavrama |
| Alet/Silah | Alet bağlama ofsetleri veri + çoğalma fix | BRANCH'TE | alet-gorsel-fix | tool_profiles.gd (ATTACH) | — | TOOL_HOLD ile MUHTEMELEN BAYAT (22 Tem tabanlı) | merge etme; kapatılabilir |
| Yapı/Base | Yerleştirme modu (hayalet + döndür + onay) | ÇALIŞIYOR | main | world3d.gd, build_preview.gd | — | — | — |
| Yapı/Base | Modüler çit (kenar-bazlı; direk paylaşımı, kapı boşluğu, tarla koruma bayrağı) | ÇALIŞIYOR | cit-sistemi | world3d.gd, fence_balance.gd | yapı sistemi | söküm/tamir yok; fence_gate + ikon dosya-bekler | FENCETEST hızlı CI'da |
| Yapı/Base | Duvar/kapı/zemin/yatak/meşale/tuzak | ÇALIŞIYOR | main | world3d.gd (PLACE_MODELS) | — | tuzağın yaratık hedefi yok | — |
| Yapı/Base | Yapı canı + çekiçle sökme (malzeme iade) | ÇALIŞIYOR | main | world3d.gd (_structure_take_hit) | — | — | — |
| Yapı/Base | Tezgah (kullanıcı GLB'si) | ÇALIŞIYOR | main | world3d.gd | craft | — | h=0.6 oranlandı |
| Yapı/Base | Araştırma masası | ÇALIŞIYOR | main | world3d.gd | araştırma | — | — |
| Yapı/Base | Kamp evi (yeniden doğuş noktası) | ÇALIŞIYOR | main | world3d.gd | — | — | — |
| Yapı/Base | Ocak (öncelikli ışık + pişirme kapısı) | ÇALIŞIYOR | main | world3d.gd (get_hearth) | — | "Ocak hedefi" oyun amacı DEĞİL (plan) | HEARTHTEST CI'da |
| Yapı/Base | Savunma platformu | ÇALIŞIYOR | main | world3d.gd | — | — | — |
| Yapı/Base | Kapı aç/kapa (oyuncu geçer, yaratık geçemez) | ÇALIŞIYOR | main | world3d.gd | — | "yaratık geçemez" test edilemez (AI yok) | — |
| Yapı/Base | Çatı parçaları + görünürlük fade | BRANCH'TE | ev-cati | world3d.gd (branch) | — | ESKİ tabana dayalı (buggy HUD dönemi) — merge öncesi REBASE ŞART | 5 gerçek commit |
| Yapı/Base | İç mekan tespiti (flood-fill, is_indoor) | BRANCH'TE | ev-cati | world3d.gd (branch) | çatı | aynı rebase şartı | — |
| Yapı/Base | Ev hissi (rozet, yatak bonusu, kayıt) | BRANCH'TE | ev-cati | world3d.gd (branch) | iç mekan | aynı rebase şartı | — |
| Tarım | Tarla açma (çapa) | ÇALIŞIYOR | main | farming.gd, world3d.gd (_try_till) | araştırma (farming_basics) | — | tarif: 2 çubuk+2 taş+1 ip |
| Tarım | Tohum ekme | ÇALIŞIYOR | main | farming.gd, world3d.gd (_try_plant) | tarla | — | flavor çelişkisi kapandı |
| Tarım | Sulama (kap 4 kullanım + bitişik su otomatiği) | ÇALIŞIYOR | main | farming.gd, world3d.gd (_on_farm_dawn) | su sistemi | — | 11.7 kancası BAĞLANDI |
| Tarım | Büyüme tick + hasat (saçılan ürün) | ÇALIŞIYOR | main | farming.gd (day_tick), world3d.gd | gün döngüsü | ışık kuralı boş (planlı) | FARMTEST CI'da |
| Tarım | Kompost/korkuluk/sulama borusu | SADECE-PLAN | — | item_db.gd'de yalnız isim | — | — | — |
| Can-Açlık | Can + yenilenme + açlıkla erime | ÇALIŞIYOR | main | health.gd, player_stats.gd | — | — | — |
| Can-Açlık | Açlık + yeme (meyve/mantar/pişmiş et) | ÇALIŞIYOR | main | hunger.gd, survival_balance.gd | — | — | doyma değerleri UI ile tutarlı |
| Can-Açlık | Susuzluk + su içme | ÇALIŞIYOR | main | thirst.gd, world3d.gd | — | — | — |
| Can-Açlık | Çiğ et bulantısı (%20) | ÇALIŞIYOR | main | player_stats.gd | — | çiğ et DÜŞÜREN hayvan yok (yaratık fazı) | ancak debug ile denenir |
| Can-Açlık | Et pişirme (ocakta) | ÇALIŞIYOR | main | recipes.gd (station: ocak) | ocak | — | — |
| Can-Açlık | Ölüm + yeniden doğuş (+kararma) | ÇALIŞIYOR | main | player_stats.gd, hud.gd | kamp evi | — | — |
| Kayıt | Dünya+envanter+araştırma+gün kaydı/yükleme | ÇALIŞIYOR | main | save_manager.gd, world3d.gd | — | ev-cati'nin çatı kaydı branch'te | — |
| Kayıt | Devam Et / Yeni Oyun (2 adımlı onay) | ÇALIŞIYOR | main | hud.gd, save_manager.gd | — | — | — |
| Kayıt | "Kaydedildi" göstergesi | ÇALIŞIYOR | main | hud.gd (_on_saved) | — | — | — |
| Gündüz-Gece | Gün döngüsü + fazlar + gün sayacı pill | ÇALIŞIYOR | main | daynight.gd, hud.gd | — | — | — |
| Gündüz-Gece | Gece görseli (vinyet, ışıklar) | ÇALIŞIYOR | main | hud.gd, world3d.gd | — | — | — |
| Gündüz-Gece | Uyku (yatakta sabaha atla, +30 can) | ÇALIŞIYOR | main | world3d.gd, hud.gd | yatak | — | — |
| Gündüz-Gece | "Geliyorlar..." gece uyarısı | ÇALIŞIYOR | main | hud.gd | — | — | uyarı GERÇEK: dalga geliyor |
| Gündüz-Gece | night_started → yaratık dalga tetiği | ÇALIŞIYOR | main | world3d.gd (_on_night_started) | — | — | sefer gecesi simülasyona sapar (keşif) |
| Yaratık | Yaratık varlığı (can, take_hit, geri tepme) | ÇALIŞIYOR | main | creature.gd | — | — | gece dalgasıyla canlı |
| Yaratık | Öz düşürme | ÇALIŞIYOR | main | creature.gd | — | özün harcama yeri yok | — |
| Yaratık | AI çekirdeği (A* yol bulma + kır/dolaş kararı) | ÇALIŞIYOR | main | creature_ai.gd, world3d.gd (creature_break_cost) | gece dalgası | — | kırılabilir engel kapalı değil PAHALI; AITEST hızlı CI'da |
| Yaratık | Gece dalga sistemi (tek grup + tip karışımı) | ÇALIŞIYOR | main | world3d.gd (_spawn_night_wave), creature_balance.gd (wave_mix) | gün döngüsü | gruplu dalga (WAVE_*) hâlâ kullanılmıyor | NIGHTTEST CI'da; karışım kuralları YARATIKLAR.md |
| Yaratık | Yaratık tipleri (5 tip: normal/tırmanıcı/yüzücü/kırıcı/hızlı) | ÇALIŞIYOR | main | creature_balance.gd (TYPES), YARATIKLAR.md, YARATIKLAR.csv | AI, dalga | modelleri yok (aşağıdaki satır) | climb/swim hem yol bulmada hem harekette; YARATIKTIP hızlı CI'da |
| Yaratık | Yaratık GLB modelleri | YARIM | yaratik-gece | creature_2.glb (rig+yürüme animasyonu, normal tip) | — | diğer 4 tip dosya-bekler (prosedürel gövde) | boy AABB ölçümüyle 1.1 m; CREATUREMODEL CI'da |
| Yaratık | Tuzak/kazık yaratık tetiklenmesi | YARIM | main | world3d.gd | yaratık AI | yapılar yerleşiyor, hedefleri yok | Aşama 5 |
| Yaratık | Alev hendeği | SADECE-PLAN | — | creature_balance.gd:70 (FLAME_DPS), item_db kaydı | — | veri var, kod yok | — |
| Yaratık | Hedef: AGGRO menzilinde oyuncu, yoksa Ocak | ÇALIŞIYOR | yaratik-gece | world3d.gd (_tick_one_creature) | dalga | sabah ekonomisi/is_banked HÂLÂ YOK | sınırlı kovalamaca: menzilden çıkınca Ocak'a döner |
| Yaratık | Doğuş halkası (merkez 25-40, sis/orman ağırlıklı, görüş yasağı) | ÇALIŞIYOR | yaratik-gece | world3d.gd (_pick_spawn_cell), creature_balance.gd (SPAWN_RING_*) | keşif sisi | — | NIGHTTEST hızlı CI'da |
| Yaratık | Topraktan doğrulma efekti (kül-duman + 1sn doğrulma) | ÇALIŞIYOR | yaratik-gece | creature.gd (birth), world3d.gd | — | — | doğrulurken AI işlemez (daze) |
| Yaratık | Yürüme animasyonu (hız senkron, 0.15sn blend) | ÇALIŞIYOR | yaratik-gece | creature.gd (set_moving) | creature_2.glb | idle/saldırı klibi GLB'de yok (kanca hazır) | uzakta animasyon durur (mobil) |
| Yaratık | Çatlak ışıması (gece parlar, ışıkta söner) | ÇALIŞIYOR | yaratik-gece | creature.gd (emission), world3d.gd (_pos_in_light) | gündüz/gece | — | su/çim ailesiyle aynı gece kaynağı |
| Yaratık | Işıkta %10 yavaşlama (Işık Kuramı) | ÇALIŞIYOR | yaratik-gece | world3d.gd (_pos_in_light), creature_balance.gd (LIGHT_*) | Ocak/meşale | — | — |
| Yaratık | Şafak kül erimesi (2sn, öz düşmez) | ÇALIŞIYOR | yaratik-gece | creature.gd (melt), world3d.gd | — | — | "Gece N atlatıldı" pill |
| Yaratık | Çiğ et düşüren hayvan | SADECE-PLAN | — | — | — | — | yiyecek zinciri kapısı |
| UI | HUD (barlar, dock, ana/saldırı butonu, bağlam) | ÇALIŞIYOR | main | hud.gd | — | — | — |
| UI | Ayarlar (kalite/FPS/Yeni Oyun/Kapat) | ÇALIŞIYOR | main | hud.gd | — | Kapat taşması 01:19 APK'da düzeltildi | CLICKTEST ✓ |
| UI | Kamera ayar paneli (layer 4) | ÇALIŞIYOR | main | world3d.gd (_build_camera_ui) | — | — | — |
| UI | Başlangıç menüsü (Devam Et/Yeni Oyun) | ÇALIŞIYOR | main | world3d.gd/hud.gd | kayıt | — | — |
| UI | Gerçek-dokunuş testleri (CLICKTEST, CI) | ÇALIŞIYOR | main | world3d.gd (_run_click_tests) | screenshot.yml | sandık/yerleştirme henüz kapsam dışı | 4 panel kapsanıyor |
| UI | Gün sonu / ölüm özeti | SADECE-PLAN | — | — | — | — | UX raporu P2 |
| UI | Sol-el modu, ses/titreşim ayarı | SADECE-PLAN | — | — | — | — | UX raporu P2 |
| Karakter | Meshy karakter + animasyonlar (koşu/vuruş) | ÇALIŞIYOR | main | player3d.gd | — | Armature 0.01 kod ölçeğiyle çözülür (RAPOR_KARAKTER) | — |
| Karakter | Özel renk karakteri (Yuvarlak Mavi) | ÇALIŞIYOR | main | custom_character.gd | — | — | seçenek listesinde |
| Karakter | Şapka/yüz/saç aksesuarları | ÇALIŞIYOR | main | player3d.gd (set_hat/face/hair) | — | — | — |
| Karakter | Stil vitrini (CI karşılaştırma sahnesi) | ÇALIŞIYOR | main | style_showcase.gd | — | — | üretim değil, araç |
| Performans | Kalite kademeleri (Düşük/Orta/Yüksek) | ÇALIŞIYOR | main | perf_balance.gd, world3d.gd | — | — | Ayarlar'dan |
| Performans | FPS göstergesi | ÇALIŞIYOR | main | hud.gd/world3d.gd | — | — | — |
| Performans | Ölçüm altyapısı (probe + baseline) | BRANCH'TE | performans | perf probe (branch) | — | Aşama 1 kapanış commitleri açıkta | ölçüm aracı, oyun kodu değil |
| Performans | Hedefli optimizasyon (Aşama 2) | YARIM | main | — | ölçüm | görev listesinde in-progress | — |
| Ses | SFX çalar (vuruş/kırılma sesleri) | SADECE-PLAN | — | tool_profiles.gd'de sfx ADLARI veri olarak hazır | — | AudioStreamPlayer kodu HİÇ YOK | veri kancası hazır |
| Ses | Müzik | SADECE-PLAN | — | — | — | — | — |
| Hikâye/Keşif | KEŞİF çıkışı / harita hedefi | SADECE-PLAN | — | — | — | repo DOKÜMANLARINDA DA YOK (yalnız sohbet tasarımı) | yazılacak doküman gerek |
| Hikâye/Keşif | Ocak Nefesi | SADECE-PLAN | — | — | — | repo dokümanlarında yok | — |
| Hikâye/Keşif | Eşik Gecesi | SADECE-PLAN | — | — | — | repo dokümanlarında yok | — |
| Hikâye/Keşif | Hikâye teslimi / senaryo tetikleri | SADECE-PLAN | — | — | — | kodda hiçbir hikâye tetiği yok | — |
| Dünya | Harita maskesi v2 (biyom + yükseklik katmanı) | ÇALIŞIYOR | main | map_mask.gd, world3d.gd (_build_world) | üreteç | maske dosyaları henüz repoda yok (fallback: tam prosedürel) | MASKTEST CI'da; 7 sınıf + kara zorlama + oto kum bandı + tepe/normal |
| Araçlar | Harita Ressamı v2 (2 katman + zoom/pan + oto-3D) | ÇALIŞIYOR | main | scripts/tools/map_painter.gd | maske | masaüstü; mobil değil | kum + kara zorlama + yükseklik sekmesi + Tümünü Temizle; RAPOR_HARITA2.md |
| Araçlar | Test modu (sınırsız envanter + tüm eşyalar + kilitsiz araştırma) | ÇALIŞIYOR | main | test_mode.gd | — | KAPATMAK: TestMode.ENABLED=false | web'de de aktif |
| Araçlar | Grip Ayar Modu (aleti oyun içinde hizala) | ÇALIŞIYOR | main | hud.gd, player3d.gd | — | yalnız debug build (web'de yok) | user://grip_overrides.json |
| Legacy | 2D oyun (world.gd, World.tscn) | ÇALIŞIYOR | main | world.gd, player.gd | — | 3D ile İKİ AYRI OYUN; tarım+gece dalgası artık 3D'de de var | web kökünde yayında |

## SAYIM

| Durum | Adet |
|---|---|
| ÇALIŞIYOR | 85 |
| BRANCH'TE | 12 |
| YARIM | 3 |
| SADECE-PLAN | 13 |
| BOZUK | 0 |
| **TOPLAM** | **113** |

(BOZUK 0: bilinen iki cihaz hatası — Ayarlar Kapat taşması ve sandık
overlay'i — bu denetim sırasında düzeltilip 01:19 APK'da yayınlandı.)

## MERGE BEKLEYENLER

| Branch | İçerik | Merge etmeden önce test et |
|---|---|---|
| ev-cati (5 commit) | Çatı + iç mekan + ev hissi + kayıt | ÖNCE main'e REBASE (tabanı buggy-HUD dönemi); sonra CI boot + CLICKTEST + çatı fade'i ve kayıt/yükleme döngüsü |
| alet-gorsel-fix (2 commit) | ATTACH veri + alet çoğalma fixi | Muhtemelen BAYAT (TOOL_HOLD bunu ikame etti); önce main'de çoğalma bug'ı hâlâ var mı bak — yoksa branch'i kapat |
| performans (3 gerçek commit) | Perf probe kapanış + baseline | Ölçüm aracı; merge riski düşük ama screenshot akışını uzatıyor mu kontrol et (300sn sınırı) |
| harita-v2, karakter-*, kayit-sistemi, perf-*, stil-vitrin | YALNIZ bayat oto-screenshot commit'i | İçerik yok — silinebilirler (temizlik) |

## ÇELİŞKİ / ÇÖP LİSTESİ

1. **İki tarif/eşya kataloğu:** `recipes.gd`+`items.gd` (Türkçe id, CANLI) vs
   `recipe_db.gd`+`item_db.gd` (İngilizce id, GDD kataloğu). recipe_db'yi
   HİÇBİR kod kullanmıyor; item_db yalnız kategori/renk için okunuyor.
   Karar gerek: GDD kataloğuna geçiş mi, recipe_db silinsin mi?
2. **Tohum yalanı:** envanter metni "toprak zemine dokununca ekilir" diyor;
   3D oyunda ekim kodu yok (yalnız 2D legacy'de). Metin düzeltilmeli ya da
   tarım yapılmalı.
3. **"Geliyorlar..." uyarısı:** gece uyarı pill'i var ama gelen yok (dalga
   sistemi plan). Oyuncuya boş vaat.
4. **Boş kancalar (kodda hazır, bağlanmamış):**
   - `daynight.gd night_started` → 3D dalga tetiği bağlı değil (2D'de bağlı).
   - `oz` düşüyor ama hiçbir sistem harcamıyor (gizli araştırma planı).
   - `has_adjacent_water` (11.7 sulama kapısı) → tarla sistemi yok.
   - `tool_profiles.gd` sfx adları → ses çalar yok.
   - tuzak/kazık `take_hit` hedefi → yaratık AI yok.
   - `is_banked`, alev rengi sayacı, hikâye tetikleri → kodda HİÇ YOK
     (yalnız plan; creature_balance'ta FLAME_DPS/§15.7 sabitleri duruyor).
5. **İki oyun bir repoda:** 2D legacy (world.gd) web kökünde hâlâ yayında;
   3D ile özellik seti ayrıştı (2D'de tarım/dalga var). Kafa karışıklığı
   kaynağı — ya emekliye ayır ya "eski sürüm" olarak etiketle.
6. **Bayat branch'ler:** 8 branch yalnız oto-screenshot commit'i taşıyor.
7. **KEŞİF/Ocak Nefesi/Eşik Gecesi:** repo dokümanlarında bile yok — bu
   vizyon yalnız sohbetlerde; koda giden yolu açmak için önce kısa bir
   tasarım dokümanı yazılmalı.

## ÖNERİLEN SIRA (ilk 5 iş)

1. **Yaratık AI + gece dalgası (Aşama 2-3):** En büyük "içerik borcu".
   Tuzaklar, silahlar, "Geliyorlar..." uyarısı, öz ekonomisi — hepsi bunu
   bekliyor; mevcut altyapı (take_hit, spawn, sinyal) hazır.
2. **ev-cati'yi rebase edip merge et:** Bitmiş 4 aşamalık özellik rafta
   çürüyor; taban eskidikçe rebase maliyeti artıyor.
3. **Tarım dikey dilimi (tarla→ekim→büyüme→hasat):** Kancalar hazır
   (sulama kapısı, tohum item); GDD §7'nin ilk yarısı kısa işte oynanışa
   çevrilir + tohum metni yalanı kapanır.
4. **Katalog kararı (recipe_db vs recipes):** Yaratık/tarım içeriği
   eklemeden önce tek kataloğa inilmeli; sonra her içerik işi ikiye
   yazılmak zorunda kalıyor.
5. **Ses ilk adımı (vuruş/kırılma SFX):** Veri kancaları hazır; küçük işle
   oyun hissi büyük sıçrar (mobilde önemli). Branch temizliği de (bayat 8
   branch + alet-gorsel-fix kapanışı) bu arada 10 dakikalık iş.

---

## GÜNCEL DURUM NOTU (atmosfer-final sonrası)

Görsel atmosfer katmanı tamamlandı ve main'de:
- **Su v2.1**: 3 yönlü gerçek dalga + ince/kesikli/yarı saydam köpük +
  kıyı soluması; parlaklık kullanıcı isteğiyle 0'a yakın
  (RAPOR_SUSHADER.md).
- **Zemin çayır dokusu**: ground_meadow.gdshader zemin chunk'larında —
  benek/leke/sıcak-serin yalnız çayır maskesinde (vertex ALPHA);
  3D çim (yaprak tarlası/mikro-tutam) BAYRAKLA KAPALI, kod ve
  grass.gdshader arşivde duruyor (RAPOR_ATMOSFER.md).
- Gece tonu tek kaynaktan: su + zemin + çiçek + yaratık ışıması.

## GÜNCEL DURUM NOTU (tarim-2 sonrası)
Tarım çeşitliliği yayında: 6 ürün (gece büyüyen korotu, sulamasız
gölge mantarı dahil), 5 mutfak tarifi + Taş Dibek istasyonu, zamanlı
buff çerçevesi (çorba gece ışık halkası + sis direnci, lokma hız).
Ayrıntı RAPOR_TARIM2.md; sayılar tarim_balance.gd.

## DAL DENETİMİ (yaratik-ai + agac-kesim, kullanıcı isteği)
İki dal da main'e ÇOKTAN merge edilmiş — `origin/main..origin/yaratik-ai`
ve `origin/main..origin/agac-kesim` fark commit'i: 0 (rebase edilecek
yeni iş yok; yeniden merge boş işlem olurdu). İçerikleri yayında ve
main'in hızlı paketinde her push doğrulanıyor — bu denetimde de yeşil:
NIGHTTEST beklenen=4 dogan=4 daze/duvar/isik=true safak_kalan=0;
FELLTEST devrildi/hat/toplandi=true odun=3 eszamanli=5. İki dal artık
güvenle silinebilir (arşiv istenirse dursun).
