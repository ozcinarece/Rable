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

## Aşama aşama ne yapıldı

**Aşama 1 — Veri modeli.** `structure_manager.gd` (yön/hp/max_hp/durum örnek
defteri + apply_damage/apply_repair/hp_ratio + to_save_data/from_save_data).
`PLACE_MODELS`'e behavior/max_hp/rotatable/in_pit/on_water alanları. `_set_placed`
yön parametresi + `_structures` senkronu. Yön/hp mevcut kayda bağlandı.

**Aşama 2 — Yerleştirme modu.** Envanterde "Yerleştir" butonu; yarı saydam
**hayalet** önizleme öndeki hücreyi takip eder; geçerli=yeşil / geçersiz=kırmızı
+ neden rozeti (dolu/su/çukur/meşgul/sınır/zemin). Sağ altta **Onayla / Döndür
90° / İptal** (normal butonları gizler). Seri dizme (item bitince kapanır).
Klavye R/Esc. Eski hold+tap yerleştirme korundu.

**Aşama 3 — HP / take_hit / hasar / yıkım + çekiç.** Yapılar `take_hit(damage,
dir)` alır (yaratıklar aynı yolu kullanacak); sarsıntı + partikül; hp<%50 eğik
görünüm; hp 0 → yıkım (malzemenin %25'i saçılır). Silah hitbox'ı artık yapıları
da vurur. Çekiç: hasarlı→TAMİR (vuruş başına +hp, malzeme düşer), sağlam→SÖKME.

**Aşama 4 — Özel davranışlar.** Kapı aç/kapa (0.2 sn tween, açık geçilir+dönük,
kapalı katı; durum kayıtta). Meşale OmniLight3D + flicker + **ışık bütçesi**
(en yakın 8 yanar, fazlası söner). İstasyon yakınlığı zaten `_placed`'den
çalışıyor (doğrulandı). Tuzak çukur-içi istisnası `_place_valid`'de hazır.

**Aşama 5 — Cila.** Yerleşme pop'u + toz partikülü, yıkım/yerleşme/kapı/vuruş
ses kancaları (dosya yoksa sessiz), geçersizlik rozetleri.

## CI doğrulaması (self-test çıktıları)
`HASARTEST hp_ratio=0.50`, `YIKIMTEST placed 7→6 (duvar yıkıldı)`,
`DOORTEST kapali_kati=true acik_kati=false`, `SAVELOAD PASS` — hasar, yıkım,
kapı katılığı ve kalıcılık doğrulandı. (Bir ara turda envanterin CI'da dolması
`add_item`'ı engellemişti; yerleştirme testinden önce `Inventory.reset()`
eklendi — ürün kodu değil, test senaryosu düzeltmesi.)

## Değişen / eklenen dosyalar
- **Yeni:** `scripts/structure_manager.gd`, `YAPI_SISTEMI.md`, `RAPOR_YAPI.md`,
  `assets/items/mesale.png`
- **Değişen:** `scripts/world3d.gd` (yerleştirme modu, hayalet, hp/take_hit/
  yıkım, çekiç tamir, kapı, meşale ışığı, kayıt), `scripts/hud.gd` (Yerleştir
  butonu + yerleştirme kontrolleri), `scripts/items.gd`+`recipes.gd` (mesale)

## SENİN İÇİN TEST SENARYOSU (sırayla)
1. **Ahşap duvar üret** (2 kalas). Envanterde ona dokun → bilgi şeridinde
   **"Yerleştir"** butonu çıkar, bas.
2. **Yerleştirme modu açılır:** önünde yarı saydam yeşil duvar hayaleti;
   yürüdükçe önündeki hücreyi takip eder. Sağ altta Onayla/Döndür/İptal.
3. **Döndür'e bas** → hayalet 90° döner. **Bir ağaca/duvara bak** → hayalet
   kırmızı olur + "dolu" rozeti (geçersiz).
4. **Boş bir hücreye bakıp Onayla** → duvar kurulur (pop + toz), mod açık kalır.
   Yana yürüyüp **peş peşe birkaç duvar diz** (seri).
5. **İptal**'e bas (veya duvar bitsin) → mod kapanır.
6. **Kapı üret** (3 kalas + 1 ip), yerleştir. Üstüne bak → ana buton "aç/kapa";
   bas → kapı döner (açık); tekrar bas → kapanır. Kapalıyken içinden geçemezsin.
7. **Kılıç'ı eline al, kurduğun bir duvara vur** → duvar sarsılır + kıymık;
   birkaç vuruşta **eğilir (hasarlı)**, sonra **yıkılır** (malzemenin çeyreği
   yere saçılır).
8. **Çekiç yap, hasarlı bir duvara vur** → tamir olur (malzeme düşer, vuruş
   başına can dolar). **Sağlam bir yapıya çekiçle vur** → sökülür (malzeme
   %100 geri).
9. **Meşale üret** (1 çubuk + 1 odun), yerleştir → sıcak turuncu ışık + hafif
   titreşim. Çok sayıda koyarsan en uzaktakiler söner (ışık bütçesi).
10. **Tümsek/sur üstüne çit diz** (toprak yığınının üstü geçerli) — savunma
    duvarı kur.
11. **Su hücresine / kazılmış çukura yerleştirmeyi dene** → "su"/"çukur" rozeti
    (geçersiz). Tuzak ise çukura konabilir.
12. **Sandık/tezgâh koy, yanına git** → craft menüsü onları tanır (yakınlık).
13. **Oyunu kapat-aç** → yapılar, yönleri ve (varsa) hasarları yerinde kalır.

## Bilinen sorunlar / TODO'lar
- **Meşale ışığı gündüz sönük görünür:** world3d'de gerçek gece karartması yok
  (gece şimdilik sadece HUD vinyeti). Gece aydınlatması gelince meşale çok daha
  belirgin olur. Yakıt mekaniği de o zaman (13.5 TODO, şimdilik sonsuz).
- **Çekiç SÖKME "0.8 sn basılı tut" göstergesi yok:** ana buton basılı-tut
  UI'si olmadığından söküm tek dokunuşta (yine %100 iade). Hold-gauge ileride
  eklenebilir.
- **Çok hücreli yapılar** yok (13.1 "ileride"): her yapı tek hücre.
- **Tuzak tetikleme / kapı-yaratık davranışı:** yaratıklar gelince (take_hit
  ve door zaten hazır kapı).
- **Hasarlı görünüm** basit (eğim + alçalma); çatlak dekali GLB'de zor, atlandı.
- **Cila ince ayar:** yerleşme tozu partikül sayısı (`_place_confirm` 7),
  pop süresi (`_place_pop` 0.22), ışık bütçesi (`MAX_TORCHES` 8) veriden ayarlanır.
