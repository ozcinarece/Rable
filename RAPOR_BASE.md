# BASE FONKSİYONLARI (Bölüm 14 — A Kısmı) — Uygulama Raporu

Otonom mod. Branch: `base-fonksiyonlari` (test-duzeltmeleri üstüne).
Kaynak: `BASE_SAVUNMA.md`. **Sadece A Kısmı** kodlandı; B Kısmı (savunma
stratejisi / yaratıklar) için yalnızca arayüz hazırlığı yapıldı
(`get_hearth`, `set_spawn`, `Crafting.near_hearth`) — B'ye ait davranış
kodu YAZILMADI.

## Adım 0 — Keşif bulguları

- **Yerleştirme sistemi hazır** (Bölüm 13): `PLACE_MODELS` (model/hp/behavior/
  rotatable), `_set_placed`/`_remove_placed`, `StructureManager` (yön/hp/durum
  sidecar), hayalet önizleme, çekiç tamir/söküm, `take_hit`/yıkım, kayıt.
  Dört yeni yapı bu boru hattına eklendi (yeniden yazım yok).
- **Sandık zaten vardı** ama `{esya:adet}` sözlük tabanlıydı (kapasite yok,
  tek panel liste). Doküman 16-slot + oyuncu envanteriyle AYNI altyapıyı
  istiyor → `Inventory` sınıfı örneklendi.
- **Yatak zaten vardı** (gece uyku + iyileşme) ama doğuş noktası yoktu.
- **Ocak/Platform yoktu.** Ekonomi malzemeleri: wood=odun, stone=taş,
  clay=kil, rope=ip mevcut; **hide/deri YOK** (yaratıklardan gelecek).

## Kararlar (muhafazakâr; gerekçeli)

- **Sandık deposu = `Inventory` örneği (14.1).** Autoload `Inventory`
  sınıfına `container_mode` bayrağı eklendi: true ise `_ready` başlangıç
  setini vermez. Her sandık, ağaca eklenen bir `Inventory` düğümüdür →
  slot/stack/`add_item`/`remove_item`/`to_save` **hepsi paylaşılır (kod
  tekrarı yok)**. Kapasite 16 (BASE_SLOTS, çantasız). Bu, dokümanın
  "Inventory sınıfı örneklenir" ilkesinin birebir karşılığı.
- **Çift panel UI → mobilde alt alta (doküman izin veriyor).** Mevcut tek
  ChestPanel iki bölüm (Sandıktakiler / Envanterin) + üstte **Tümünü Koy /
  Tümünü Al** butonları olarak sunuldu. Aktarım: bir yığına dokun → karşı
  tarafa taşınır (mobil için tek-dokunuş-tüm-yığın; "dokun-seç-hedefe-dokun"
  yerine sadeleştirme — belirsizlik/yanlış slot riski sıfır, CI'da test
  edilebilir). Sığmazsa "Sandık/Envanter dolu!" uyarısı, kayıp yok.
- **Recipe malzemeleri dokümana hizalandı, tezgahta üretim.** sandık=8 odun+
  1 ip, ocak=8 taş+4 kil+2 odun, platform=6 odun+2 ip. **Yatak=6 odun+2 ip+
  3 yaprak**: "3 hide" yerine muhafazakâr ikame (deri henüz yok; yaratık
  fazında gerçek tarif gelince güncellenir).
- **hp değerleri dokümana çekildi:** sandık 60, yatak 80, ocak 400 (en
  dayanıklı — kalp), platform 100. (Önceden sandık 120 / yatak 40 idi.)
- **Platform GLB yerine prosedürel.** 1.5 birim yüksek deck + 4 ayak + bir
  kenarda 3 basamak (kod ile). Böylece `ground_height` ile görsel BİREBİR
  eşleşir (oyuncu deck üstünde durur); hazır 1.5-birim platform GLB'si yok.
- **Platforma çıkış = `ground_height` yükseltmesi.** Platform hücresinde
  `ground_height` arazi+1.5 döner → oyuncu üstte durur, menzilli atış
  yüksekten (mermi zaten oyuncu konumundan çıkar). Düşme hasarı yok.
  Basit "pop" (ani yükseliş); pürüzsüz rampa görsel TODO (aşağıda).
- **Ocak ışığı meşale bütçesinden bağımsız.** Kendi `OmniLight3D`'si her
  zaman yanar (geniş menzil 7.5, hafif titreşim). Tek aktif ocak: yenisi
  konunca eskisinin ışığı söner (yapı durur).
- **2D `world.gd` legacy** (ana sahne 3D). `PLACEABLE`'a ocak/platform
  eklendi ki HUD "Yerleştir" butonu çıksın; gerçek yerleştirme 3D'de
  `PLACE_MODELS`'ten geçer.

## Aşama aşama ne yapıldı

**Aşama 1 — Sandık (14.1).** `inventory.gd`+`container_mode`. `_chests[cell]`
artık `Inventory` örneği. `_new_chest_store`/`_chest_display`/`_chest_is_empty`/
`_clear_chests`. Aktarım (`_on_chest_transfer`) + hızlı butonlar
(`_on_chest_transfer_all`, HUD sinyali + iki buton). Dolu sandık **sökülmez**
("önce boşalt"). **Yıkılınca** içerik komşu hücrelere saçılır (dünya item
sistemi). Kayıt: `store.to_save()` (slots); yükleme yeni slots + eski düz
sözlük ikisini de okur (geriye uyum).

**Aşama 2 — Yatak (14.2).** `set_spawn(cell)`/`get_spawn()`/`_respawn_cell()`
arayüzü. Son yerleştirilen yatak aktif doğuş noktası (yerleştirmede otomatik).
Gündüz dokunuş → "Ev burası oldu" (doğuş ata); gece → uyku (mevcut). `_home_bed`
kayda dahil (yüklemede `set_spawn` çağrılmadığından açıkça saklanır).

**Aşama 3 — Ocak (14.3).** `behavior:"hearth"`, hp 400. `_activate_hearth`:
tek aktif kural (eskisi pasifleşir) + bütçesiz öncelikli `OmniLight3D` (geniş,
titreşimli). `get_hearth()` global sorgu (B kısmı gece hedefi için). Yakınında
`Crafting.near_hearth=true` (pişirme istasyonu arayüzü; tarifler yaratık/yiyecek
fazında).

**Aşama 4 — Platform (14.4).** `behavior:"platform"`, solid=false, hp 100,
döndürülebilir. `_build_platform_visual` (prosedürel, 1.5 birim). `_platform_cells`
+ `ground_height` yükseltmesi → üstüne çıkılır. Platformdan menzilli atış
(mermi oyuncunun yükselmiş konumundan çıkar). İniş güvenli (hasar yok).

**Aşama 5 — Cila + kayıt + self-test.** Yerleşme pop'u/partikül mevcut sistemden
gelir. Kayıt taslağına (13.6) sandık slotları + `home_bed` dahil; ocak/platform
`_placed`'den yeniden kurulur. `_release_structure_cell` ortak temizleme yolu
(söküm+yıkım): sandık düğümü, ocak ışığı, platform yüksekliği burada bırakılır.
CI self-test (`_run_base_selftest`) dört yapıyı kurar, davranışları doğrular,
`3d_base.png` karesini alır.

## CI doğrulaması (self-test çıktıları)
CI log satırları (screenshot.yml):
- `CHESTTEST` — sandık dolu slot/adet, boş değil
- `CHESTLOCK` — dolu sandık sökülmedi (hâlâ duruyor)
- `CHESTSPILL` — yıkımda içerik yere saçıldı (yer eşyası arttı)
- `BEDTEST` — get_spawn == yatak hücresi
- `HEARTHTEST` — get_hearth == ocak hücresi, ışık aktif
- `PLATFORMTEST` — yükseklik farkı ~1.5
- `PLATFORMSHOT` — platformdan mermi fırlatıldı, oyuncu_y yükselmiş
- `SAVELOAD: PASS` — dört yapı + sandık içeriği + ev yatağı reload'da korunur

## Değişen / eklenen dosyalar
- **Yeni:** `BASE_SAVUNMA.md`, `RAPOR_BASE.md`, `assets/items/ocak.png`,
  `assets/items/platform.png`
- **Değişen:** `scripts/world3d.gd` (sandık deposu, ocak, platform, yatak
  doğuş, kayıt, self-test), `scripts/inventory.gd` (container_mode),
  `scripts/hud.gd` (Tümünü Koy/Al + sinyal), `scripts/crafting.gd`
  (near_hearth), `scripts/items.gd` (ocak/platform + PLACEABLE),
  `scripts/recipes.gd` (4 tarif)

## SENİN İÇİN TEST SENARYOSU (sırayla)
1. **Sandık üret** (tezgah yanında: 8 odun + 1 ip). Eline al → **Yerleştir**
   → boş hücreye kur.
2. **Sandığa dokun** → panel açılır (Sandıktakiler / Envanterin + üstte
   **Tümünü Koy / Tümünü Al**).
3. **Bir eşyaya dokun** (envanter tarafında) → sandığa geçer. Sandık
   tarafında dokun → sana döner.
4. **Tümünü Koy** → eşleşen tüm yığınlar sandığa (16 slot dolunca "Sandık
   dolu!"). **Tümünü Al** → geri.
5. **Çekiçle dolu sandığa vur/sök** → "Önce sandığı boşalt!" (reddedilir).
   **Boşalt, sonra sök** → geri alınır.
6. **Sandığı kılıçla yık** (dolu) → içindeki her şey yere saçılır (renkli
   kutular), "al" ile topla — kayıp yok.
7. **Yatak üret** (6 odun + 2 ip + 3 yaprak), yerleştir → "Ev burası oldu"
   (doğuş noktası). **Gündüz dokun** → tekrar ev yapar; **gece dokun** →
   uyu (+can).
8. **İkinci yatak** yerleştir → doğuş noktası ona geçer (son yatak aktif).
9. **Ocak üret** (8 taş + 4 kil + 2 odun), yerleştir → büyük **sıcak turuncu
   ışık** (gece belirgin), hafif titreşim.
10. **İkinci ocak** koy → uyarı ("yeni aktif, eski pasif"); eski ocağın ışığı
    söner.
11. **Ocak yanına git** → pişirme istasyonu sayılır (yakınlık; pişirme
    tarifleri ileride).
12. **Platform üret** (6 odun + 2 ip), yerleştir → **döndürerek** basamak
    yönünü seç.
13. **Platforma çık** (basamaktan) → yükselirsin; üstünde dururken **yay/
    sapan/mızrak** ile aşağıdaki kuklaya at → yüksekten isabet.
14. **Platformdan in** → düşme hasarı yok.
15. **Duvar bitişiğine platform** kur → sur arkası atış pozisyonu. **Toprak
    yükseltisi üstüne** platform → çift yükseklik.
16. **Oyunu kapat-aç** → sandıklar (içerikleriyle), ev yatağı, ocak (ışık),
    platform yerinde kalır.

## Bilinen sorunlar / TODO'lar
- **Platforma çıkış "pop"** (ani 1.5 birim yükseliş); pürüzsüz rampa
  interpolasyonu görsel TODO (fonksiyonel olarak sorunsuz, düşme hasarı yok).
- **Sandık UI slot-ızgara değil, tür-satırı** (yığın başına satır) + tek
  dokunuş tüm-yığın aktarım. Doküman "16 slot + dokun-seç-dokun" diyor;
  kapasite 16 gerçekten enforce ediliyor (Inventory), ama UI slot çizmiyor.
  Gerçek slot-ızgara + iki-dokunuş hedef-slot ileride cilalanabilir.
- **Pişirme tarifleri yok** (14.3 "pişirme istasyonu sayılır"): `near_hearth`
  bayrağı hazır; yiyecek/pişirme yaratık faziyla gelecek.
- **Uyku 2-3 gece sınırı** (14.2 tasarım notu) ve **hide/deri tarifi** yaratık
  faziyle. Şimdilik uyku her gece açık, yatak ipe/yaprağa üretiliyor.
- **B Kısmı** (yol bulma maliyeti, aggro, yaratık tipleri, tuzak tetik, denge)
  bilinçli olarak KODLANMADI — yaratık göreviyle gelecek; `get_hearth`/
  `set_spawn`/`near_hearth` arayüzleri hazır bekliyor.
