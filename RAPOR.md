# ALET SİSTEMİ (Bölüm 12) — Uygulama Raporu

Otonom mod. Branch: `alet-sistemi`. Kaynak doküman: `ALET_SISTEMI.md`.

---

## Adım 0 — Keşif bulguları

**Eldeki alet akışı:** `world3d._held_item` (canlı Türkçe id'ler: balta,
kazma, kurek, mizrak, toprak, kova, kova_dolu). 3D model
`world3d.TOOL_MODELS` → `player3d.set_held_tool()` ile takılıyor.

**Alet bağlantı noktası:** `player3d._tool_attach` — her kare el kemiğine
yapışan ölçek-1 ayna node (`_sync_attach_mirrors`). Alet modeli bunun
çocuğu. → Prosedürel animasyon için araya **ToolPivot** node ekledim;
tween'ler pivot'u döndürür, ayna eli takip etmeye devam eder.

**Etkileşim iki kapıdan geçiyor:** `_on_world_tapped` (hücreye dokunma) ve
`_on_action_pressed` (ana buton, baktığı yönde hasat). İkisi de korundu.

**Nesne canı zaten vardı:** `_object_hits` + `OBJECT_DEFS.hits` (ağaç 3,
kaya 4) + alet bonusu. 12.4 balta/kazma "can" mantığının çoğu mevcuttu;
üstüne animasyon + strike-anı-etki + partikül sarıldı.

**Nesneler MultiMesh ile toplu çiziliyor** (`_rebuild_objects`). Tek bir
örneği titretmek (12.6 hedef tepkisi) pratik değil → vuruş tepkisi için
o hücreye kısa ömürlü partikül + geçici proxy mesh kullandım.

**İki item sistemi var:** canlı oyun `items.gd`/`recipes.gd` (Türkçe);
`item_db.gd` GDD veri katmanı (İngilizce). Üretim menüsü canlı sistemi
kullanıyor → tüm yeni item/tarif canlı id'lerle eklendi.

**Hareket yavaşlatma kancası:** `player.water_factor` (su için) varken
aynı desende `player.action_factor` eklendi (eylem sırasında ×0.6).

## Kararlar (muhafazakâr; gerekçeli)

- **KARAR:** Kukla tarifi `4 odun + 2 ip` (doküman "4 wood + 2 fiber";
  canlı sistemde lif yok, en yakın bağlayıcı ip). Yeni item açmadım.
- **KARAR:** Yeni aletler/silahlar (bicak, cekic, sopa, kilic, yay,
  sapan, ok, mizrak zaten var) canlı `items.gd`+`recipes.gd`'ye eklendi;
  3D modelleri gömülü karakter silah havuzundan / basit prosedürel mesh.
- **KARAR:** Alet eylemleri artık tek merkezden (`_perform_tool_action`)
  geçiyor; hem tap hem ana buton buraya bağlanıyor. Kazı/kova/hasat
  davranışı AYNI, sadece "strike anında çağrılıyor" biçiminde sarmalandı.
- **KARAR:** Hedef vurgusu tek bir paylaşılan halka mesh; her kare
  hedefe taşınır (yeni node spam'i yok — mobil).
- **KARAR:** Ses dosyası yok → ses kancaları isim taşıyor ama dosya
  yoksa sessiz geçiliyor (hata yok).

## Aşama aşama ne yapıldı

**Aşama 1 — Girdi + hedefleme.** Bağlam-duyarlı ana buton (elde+hedef →
ikon: kes/kaz/dök/doldur/topla/aç/saldırı); koşullu **saldırı butonu**
(sadece silahla görünür, yumuşak fade; kısa dokunma = saldırı, basılı tut
= nişan). `_acquire_target`/`_describe_target` ile öndeki ~90° koni hedef
seçimi; paylaşılan **hedef vurgu halkası** (geçerli=yeşil, geçersiz=amber).

**Aşama 2 — Eylem çerçevesi.** `tool_profiles.gd` (alet başına
windup/strike/recover + poz + menzil + ses kancaları). `player3d`'de
**ToolPivot** ara-node + `play_swing()` üç fazlı Tween oynatıcı; **ETKİ
strike callback'inde** uygulanır (buton anında değil). Balta ve kürek bu
çerçeveye bağlandı — kazı/hasat davranışı aynı, sadece sarmalandı.
Eylemde hareket %40 yavaşlar (`action_factor`).

**Aşama 3 — Alet mantıkları.** Kazma cevher-kilidi (kayaya yalnız kazma;
yanlışta "Tink!" + kıvılcım, hasar 0). Bıçak: bitkiyi tek vuruşta hasat +
2× verim. Çekiç: yapıya vurunca **söküm** (malzeme %100 iade). Kova
doldur/dök çerçeveye bağlı. Prosedürel silah modelleri (bıçak/sopa/kılıç/
yay/sapan) + çekiç→tool-hammer, kova→bucket GLB.

**Aşama 4 — Kukla + yakın dövüş.** `hittable_dummy.gd`:
**`take_hit(damage, knockback_dir)` arayüzü** (yaratıklar aynı imzayı
kullanacak), can barı, sarsılma/knockback, 0 canda devrilme + 3 sn
yenilenme. `_apply_hitbox` strike anında menzil boyunca ilk kuklaya
`take_hit`. Kılıç 2'li kombo (peş peşe basışta ters yön + 0.3 ileri adım),
mızrak dürtme (push_z, menzil 2).

**Aşama 5 — Menzilli.** Mızrak fırlatma (nişan göstergesi → parabol →
saplanma → yerden alma, +%50 hasar), sapan (çakıl), yay (0-1 sn gerdirme
hız+hasarı ölçekler; ok %60 geri toplanır). Mühimmat kontrolü + tüketimi.

**Aşama 6 — His.** Vuruş durması (kısa `Engine.time_scale` dip, gerçek-
zamanlı geri alma), malzeme partikülleri (odun/taş/toprak/bitki), ses
kancaları (dosya yoksa sessiz), buton pop + geçersizde sallanma.

## Değişen / eklenen dosyalar

- **Yeni:** `scripts/tool_profiles.gd`, `scripts/hittable_dummy.gd`,
  `ALET_SISTEMI.md`, `RAPOR.md`, 6 UI ikonu (`assets/ui/pick|fill|pour|
  grab|attack|open.png`), 9 item ikonu (`assets/items/bicak|cekic|sopa|
  kilic|yay|sapan|ok|cakil|kukla.png`)
- **Değişen:** `scripts/world3d.gd` (hedefleme, eylem çerçevesi, alet
  mantıkları, hitbox, mermiler, juice, kayıt/yükleme'ye kukla),
  `scripts/player3d.gd` (ToolPivot + play_swing + prosedürel silahlar +
  action_factor), `scripts/hud.gd` (bağlam butonu + saldırı butonu +
  pop/shake), `scenes/HUD.tscn` (AttackButton), `scripts/items.gd`,
  `scripts/recipes.gd`

## SENİN İÇİN TEST SENARYOSU (sırayla)

1. **Tezgâh yap ve yanına git** (yoksa: 4 kalas + 2 çubuk). Üretim
   menüsünde artık yeni aletler görünmeli.
2. **Balta'yı eline al, bir ağaca yaklaş.** Ana buton "kes" ikonuna
   dönmeli, ağacın altında yeşil halka belirmeli. Bas → balta üç fazlı
   sallanır, **vuruş anında** odun kıymığı fışkırır; birkaç vuruşta ağaç
   kırılır (vuruş durması hissedilir).
3. **Kazma'yı al, bir taşa vur.** "kaz" ikonu + kırılınca taş. Şimdi
   **kürek'i al, aynı taşa/kayaya vurmayı dene** → "Tink!" + kıvılcım,
   hasar yok (kilit çalışıyor).
4. **Kürek ile düz zemine bas** → kazar (kazı davranışı eskisi gibi ama
   artık sallanma animasyonlu, toprak partikülü). Derinleştir; taş
   katmanına inince kürek "Tink" verir, kazma gerekir.
5. **Bıçak yap (1 çubuk + 1 taş), çiçeğe/mantara vur** → tek hızlı kesik,
   2× toplama.
6. **Çekiç yap, bir ahşap duvara vur** → söküm, malzeme geri gelir.
7. **Kukla yap (4 odun + 2 ip), boş bir hücreye koy** (elinde kukla +
   dokun). Direk + can barı görünür.
8. **Sopa yap (2 kalas), eline al.** Sağ altta **saldırı butonu** belirir
   (ana butonun üstünde). Kuklaya bakıp saldırı butonuna bas → kukla
   sarsılır, can barı düşer.
9. **Kılıç yap (1 kalas + 3 taş + 1 ip).** Kuklaya **peş peşe** saldır →
   ikinci kesik ters yönden gelir + küçük ileri adım (kombo).
10. **Mızrak'ı al, saldırı butonunu BASILI TUT** → önünde soluk nişan
    çizgisi. Bırak → mızrak parabol çizerek uçar, kuklaya saplanır (uzak
    bir kukla koyup dene). Yere düşen mızrağın üstüne git → geri alınır.
11. **Yay yap (2 kalas + 2 ip) + ok yap (1 çubuk + 1 taş = 4 ok).** Yayı
    al, saldırı butonunu basılı tut → gerdirme dolar; bırak → ok fırlar.
    Uzun gerdirme daha hızlı/güçlü. Ok bazen yere saplanıp geri toplanır.
12. **Sapan yap (1 kalas + 2 ip) + çakıl yap (1 taş = 3 çakıl).** Basılı
    tut → bırak → çakıl fırlar. Mühimmat biterse "Çakıl yok" uyarısı.
13. **Kuklanın canını sıfırla** → devrilir, ~3 sn sonra ayağa kalkar.
14. **Elini boşalt (hotbar'da boş slota bas), bir ağaca vur** → yumruk
    sallanır (whoosh), yine de hasat eder.
15. **Oyunu kapat-aç** → kurduğun kuklalar, yapılar, kazılar yerinde
    olmalı (kalıcılık kuklaları da kaydeder).

## Bilinen sorunlar / TODO'lar / juice ince ayar

- **Ekran sarsıntısı (çekiç 2px):** bilerek eklenmedi — kamera her kare
  oyuncuyu takip ettiği için tek-kare offset kamerayla çatışıyordu.
  İstenirse takip lerp'ine kısa bir sarsıntı ofseti eklenebilir.
- **Ses:** `assets/sfx/` boş — tüm ses kancaları sessiz geçiyor. Dosya
  (ör. `hit_wood.ogg`) eklenince otomatik çalışır, kod değişmez.
- **Çekiç TAMİR modu:** yapıların can/hasar sistemi yok, o yüzden sadece
  SÖKME uygulandı. Yapı-HP sistemi gelince tamir buraya eklenir
  (TODO(yapi-hasar)).
- **Bıçak "leş→deri":** leş/karkas sistemi (yaratıklar) olmadığından
  yalnız bitki hasadı bağlandı (TODO(yaratik)).
- **Mızrak balık:** su hücresine nişan → balık sistemi gelince bağlanacak
  (TODO işaretli, kod yok).
- **His ayarı (juice) önerileri:** vuruş durması süresi `_hit_stop`'ta
  (şu an 0.05 sn / 0.5 ölçek) — daha ağır his için 0.06-0.07 denenebilir.
  Partikül sayıları `_spawn_particles` çağrılarında (5 vuruş / 9 kırılma).
  Kukla sarsılma büyüklüğü `hittable_dummy._react` (0.12 itiş) — kalibre
  noktası burası.
- **Prosedürel silah modelleri** yer tutucu (basit primitifler);
  `TOOL_MODELS`'te yolu bir GLB ile değiştirmek yeterli.
- **Not (şeffaflık):** Aşama 4 commit'inde CI test bloğunda bir değişken
  adı çakışması (`pc`) geçici olarak scripti derlenemez yapmıştı; Aşama
  5+6 commit'inde düzeltildi. Branch ucu temiz derleniyor.
