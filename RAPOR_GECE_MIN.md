# RAPOR — Gece Yaratık Dalgası (MİNİMAL SÜRÜM)

Dal: `yaratik-gece`. Amaç: gecenin **temel döngüsünü** kurmak — yaratıklar
gelsin, yapıya vursun, oyuncuya saldırsın, şafakta gitsin. A* yol bulma,
yaratık tipleri, tuzak tetiklenmesi ve öz harcama **kapsam dışı**.

## NE YAPILDI

| Parça | Nerede | Not |
|---|---|---|
| Gece tetiği | `world3d._on_night_started` | `DayNight.night_started` kancası artık boş değil |
| Doğuş | `world3d._spawn_night_wave` / `_pick_spawn_cell` | Kenar bandı + oyuncuya/Ocak'a min mesafe |
| Hareket + saldırı | `world3d._tick_one_creature` | Düz yönelme, A* yok |
| Yapı kırma | `_structure_take_hit` (mevcut) | Yeni kod değil — engele çarpınca çağrılıyor |
| Şafak temizliği | `world3d._on_dawn_clear_creatures` | `creature.melt()` — öz düşürmez |
| Davranış durumu | `creature.gd` (`attack_cd`, `stuck_time`, …) | Mantık world3d'de, sayaçlar yaratıkta |
| Sayılar | `creature_balance.gd` → `MIN_*` bloğu | Kod dokunmadan ayarlanır |

## DENGE TABLOSU

**Gece başına yaratık sayısı** — `min_wave_count(gece)`:

| Gece | 1 | 2 | 3 | 5 | 8 | 11+ |
|---|---|---|---|---|---|---|
| Yaratık | 2 | 3 | 4 | 6 | 9 | 12 (tavan) |

Formül: `MIN_BASE_COUNT(2) + MIN_PER_NIGHT(1) × (gece−1)`, `MIN_MAX_COUNT(12)`
ile kırpılır. Aynı anda sahnede en fazla `MIN_MAX_ACTIVE = 12`.

**Yaratık (tek tip: `normal`)** — mevcut `TYPES` verisinden:

| Değer | Taban | Gece ölçeği |
|---|---|---|
| Can | 10 | `night_hp_mult`: her gece +%6 → gece 10'da 15 can |
| Hız | 2.0 m/sn | sabit (oyuncudan yavaş) |
| Oyuncuya hasar | 6 | `night_damage_mult`: ilk 3 gece ×0.6 (=3.6), sonra her gece +%5 |
| Yapıya hasar | 12 / vuruş | `STRUCT_DAMAGE`, 0.9 sn arayla |
| Öz düşümü | 1 | yalnız **öldürülünce**; şafakta eriyende yok |

**Mesafe/zamanlama:**

| Sabit | Değer | Anlamı |
|---|---|---|
| `AGGRO_RANGE` | 7 m | Bu menzilde oyuncuyu, dışında Ocak'ı hedefler |
| `CONTACT_RANGE` | 0.9 m | Bu mesafede oyuncuya vurur |
| `ATTACK_COOLDOWN` | 1.2 sn | Oyuncuya vuruş arası |
| `STRUCT_ATTACK_COOLDOWN` | 0.9 sn | Yapıya vuruş arası |
| `STUCK_SECONDS` | 2.0 sn | Bu süre ilerleyemezse yana kayar |
| `SPAWN_MIN_DIST_PLAYER` | 10 hücre | Oyuncunun tepesinde doğmasın |
| `SPAWN_MIN_DIST_HEARTH` | 8 hücre | Ocak'ın dibinde doğmasın |
| `DAWN_MELT_SECONDS` | 0.5 sn | Şafakta erime süresi |

Gece 1'de 2 yaratık × 3.6 hasar = kasten kolay; ilk geceler öğretici.

## KARARLAR (ve nedenleri)

**1. A* yerine "düz git + engele vur".** Görev A*'ı kapsam dışı bıraktı, ama
düz yönelme tek başına duvara takılırdı. Çözüm: yaratık önündeki hücre
yürünemezse **durup o hücreye vuruyor**. Böylece duvar kırma davranışı yol
bulma olmadan kendiliğinden doğuyor — oyuncunun ördüğü duvar gerçekten
işlevsel oluyor. Yan fayda: A* eklendiğinde bu kod değişmeden kalır, sadece
yön seçimi akıllanır.

**2. Takılma çözümü minimal.** 2 saniye ilerleyemeyen yaratık 0.8 saniye
**yana** kayıyor (rastgele yön). Köşe/ağaç gibi engellerde sonsuza kadar
itmeyi önlüyor. Gerçek çözüm A* — bu bir köprü.

**3. Şafakta erime öz DÜŞÜRMEZ.** `melt()` ayrı bir yol; `_die()` çağrılsaydı
oyuncu hiçbir şey yapmadan her sabah öz toplardı. Öz yalnız öldürmenin ödülü.

**4. Yaratık AI'ı world3d'de, sayaçlar creature.gd'de.** `creature.gd`'nin
kendi başlığı "AI/dalga davranışı DIŞARIDA; bu dosya VARLIK" diyordu; ona
uydum. Yaratığa yalnız durum alanları (`attack_cd`, `stuck_time`…) ve görsel
yardımcılar (`lunge`, `melt`, `face_direction`, `set_simplified`) eklendi.

**5. Doğuş kuralı kademeli gevşiyor.** Sabit "10 hücre uzakta" kuralı küçük
haritada hiç uygun hücre bulamayıp geceyi boş geçirebilirdi. 40 denemede
mesafe eşiği doğrusal olarak 0'a iniyor: önce ideal, olmazsa kabul edilebilir.

**6. `cr` parametreleri bilerek tipsiz.** `cr: Node3D` yazılırsa creature.gd
üyeleri (`attack_cd`, `lunge`) Node3D'de bulunamaz ve **tüm dosya parse
hatası** verir (bu oturumda bir kez düşüldü, koda da not düşüldü).

## TEST SENARYOSU (telefonda)

1. **Geceyi bekle.** Ekranda "Gece N — Geliyorlar" pill'i çıkmalı. Bu uyarı
   artık gerçek: aynı anda yaratıklar haritanın kenarında doğuyor.
2. **Gelsinler.** Uzakta turkuaz gözler görünmeli. Ocak kurduysan Ocak'a,
   yanlarına gidersen sana yönelirler (7 m).
3. **Duvar ördür.** Aralarına ahşap duvar koy — durup vurmaya başlamalılar;
   duvar önce hasarlı görünüme geçip sonra yıkılmalı.
4. **Kılıçla öldür.** Vuruşta beyaz flaş + geri sekme, ölünce dağılma ve
   yere **öz** düşmeli (envanterine al).
5. **Şafağı gör.** Gündüz gelince kalan yaratıklar erimeli, ekranda
   "Gece N atlatıldı" pill'i çıkmalı, gündüz hiç yaratık kalmamalı.

## CI DOĞRULAMASI

`NIGHTTEST` (world3d `_run_night_test`) — her ekran görüntüsü koşusunda:
geceyi tetikler, doğan sayıyı beklenenle karşılaştırır, 40 kare ilerletip
yaratıkların Ocak'a **toplam uzaklığının azaldığını** ölçer, sonra şafağı
çağırıp sahnenin temizlendiğini doğrular. Sonuç `docs/screens/nighttest.txt`
ve log'da. Ayrıca `_gece_yaratik.png` karesi üretilir.

## BİLİNEN SINIRLAR (sonraki turlar)

- **Yol bulma yok.** U şeklinde bir duvarın içine sıkışan yaratık, duvarın
  kenarından dolaşmak yerine duvarı kırmayı seçer. Tasarım gereği kabul
  edilebilir ama A* gelince daha akıllı olur.
- **Tek tip.** `TYPES` içinde tırmanıcı/kırıcı/hızlı hazır ama minimal sürüm
  yalnız `normal` doğuruyor.
- **Tuzaklar tetiklenmiyor.** Kazık/alev sabitleri duruyor, bağlanmadı.
- **Su/ışık/çukur etkileri yok.** `SWIM_SLOW`, `LIGHT_SLOW`, `CLIMB_SECONDS`
  okunmuyor.
- **Gece ortası yeniden doğuş yok.** Tek grup, tek sefer; gruplu dalga
  (`WAVE_GROUPS_*`) sonraki tur.
- **Ocak yıkılırsa özel sonuç yok.** `HEARTH_BREAK_NEXT_WAVE_MULT` bağlanmadı.
- **Ses yok.** Projede ses çalar henüz yok.
