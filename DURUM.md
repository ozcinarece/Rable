# DURUM — Proje Envanteri (Mevcut Fonksiyonalite Denetimi)

Tarih: 2026-07-24 · Kaynak: KOD (origin/main @ CLICKTEST-fix sonrası) ·
Kural: bir özellik ancak kodda çalışır halde varsa VAR sayıldı.
Durum değerleri: ÇALIŞIYOR / BRANCH'TE / YARIM / SADECE-PLAN / BOZUK.

## ENVANTER TABLOSU

| Modül | Özellik | Durum | Branch | Ana dosyalar | Bağımlılıklar | Bilinen sorunlar | Not |
|---|---|---|---|---|---|---|---|
| Dünya | 128×128 prosedürel ada (FastNoiseLite, seed) | ÇALIŞIYOR | main | map_gen.gd, world3d.gd | — | — | MAPTEST CI'da her koşuda |
| Dünya | Zemin türleri (çim/toprak/kum/su/kil) | ÇALIŞIYOR | main | world3d.gd (_ground_char) | harita | — | — |
| Dünya | Dekor (çiçek/mantar/çalı, GLB ağaçlar) | ÇALIŞIYOR | main | world3d.gd (_build_decor) | stil-vitrin (merged) | — | pine_tree GLB bağlı |
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
| Tarım | Tarla açma (çapa) | BRANCH'TE | tarim-3d | farming.gd, world3d.gd (_try_till) | araştırma (farming_basics) | — | tarif: 2 çubuk+2 taş+1 ip |
| Tarım | Tohum ekme | BRANCH'TE | tarim-3d | farming.gd, world3d.gd (_try_plant) | tarla | — | flavor çelişkisi kapandı |
| Tarım | Sulama (kap 4 kullanım + bitişik su otomatiği) | BRANCH'TE | tarim-3d | farming.gd, world3d.gd (_on_farm_dawn) | su sistemi | — | 11.7 kancası BAĞLANDI |
| Tarım | Büyüme tick + hasat (saçılan ürün) | BRANCH'TE | tarim-3d | farming.gd (day_tick), world3d.gd | gün döngüsü | ışık kuralı boş (planlı) | FARMTEST CI'da |
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
| Gündüz-Gece | "Geliyorlar..." gece uyarısı | ÇALIŞIYOR | main | hud.gd | — | uyarı var ama GELEN YOK (dalga plan) | yanıltıcı olabilir |
| Gündüz-Gece | night_started → yaratık dalga tetiği | YARIM | main | daynight.gd:14 (sinyal) | yaratık AI | 3D'de KANCA BOŞ (yalnız 2D legacy bağlı) | daynight yorumunda "PLANLI" yazıyor |
| Yaratık | Yaratık varlığı (can, take_hit, geri tepme) | ÇALIŞIYOR | main | creature.gd | — | yalnız DEBUG spawn (K tuşu / test) | Aşama 1 |
| Yaratık | Öz düşürme | ÇALIŞIYOR | main | creature.gd | — | özün harcama yeri yok | — |
| Yaratık | AI (hedef seçimi, A*, yapı kırma) | SADECE-PLAN | — | creature_balance.gd'de sabitler | — | — | görev listesi Aşama 2 |
| Yaratık | Gece dalga sistemi | SADECE-PLAN | — | creature_balance.gd (night_damage_mult) | AI | — | Aşama 3 |
| Yaratık | Yaratık tipleri | SADECE-PLAN | — | — | dalga | — | Aşama 5 |
| Yaratık | Tuzak/kazık yaratık tetiklenmesi | YARIM | main | world3d.gd | yaratık AI | yapılar yerleşiyor, hedefleri yok | Aşama 5 |
| Yaratık | Alev hendeği | SADECE-PLAN | — | creature_balance.gd:70 (FLAME_DPS), item_db kaydı | — | veri var, kod yok | — |
| Yaratık | Ocak hedefi + sabah ekonomisi (is_banked) | SADECE-PLAN | — | creature_balance.gd §15.7 sabitler | dalga | is_banked kodda HİÇ YOK | — |
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
| Legacy | 2D oyun (world.gd, World.tscn) | ÇALIŞIYOR | main | world.gd, player.gd | — | 3D ile İKİ AYRI OYUN; 2D'de tarım+gece dalga bağlı, 3D'de yok | web kökünde yayında |

## SAYIM

| Durum | Adet |
|---|---|
| ÇALIŞIYOR | 73 |
| BRANCH'TE | 9 |
| YARIM | 3 |
| SADECE-PLAN | 16 |
| BOZUK | 0 |
| **TOPLAM** | **101** |

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
