# YARATIKLAR — Tip Tablosu

Bu sayfa DENGE/DURUM ailesinin yeni sayfasıdır: yaratık tiplerinin tek
listesi. Sayılar **kaynaktan** gelir — `scripts/creature_balance.gd`
içindeki `TYPES` sözlüğü tek doğrudur; bu tablo onun okunabilir hâlidir.

Bir tipi değiştirmek için `TYPES`'taki satırı düzenlemek yeterli: hız,
can, hasar, yetenek, ilk gece ve **model dosyası** oradan okunur. Kodun
hiçbir yerinde tip adı sabit yazılı değil (dalga karışımı dâhil), yani
yeni tip eklemek = tabloya bir satır eklemek.

## TABLO

| Tip | Ad | Can | Hız | Hasar | Öz | İlk gece | Yetenek | Yapı çarpanı | Ölçek | Göz | GLB | Rol |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| normal | Gölge | 10 | 2.0 | 6 | 1 | 1 | — | 1 | 1.00 | turkuaz | `creature_normal.glb` **VAR** | Omurga; tehdidin taban ölçüsü |
| tirmanici | Tırmanıcı | 6 | 2.2 | 4 | 1 | 4 | **climb** | 1 | 0.90 | mor | `creature_tirmanici.glb` | Duvarı kırmaz, aşar |
| yuzucu | Yüzücü | 8 | 1.8 | 5 | 1 | 5 | **swim** | 1 | 0.95 | turkuaz | `creature_yuzucu.glb` | Hendeği geçer |
| kirici | Kırıcı | 24 | 1.2 | 10 | 2 | 7 | — | **3** | 1.35 | turkuaz | `creature_kirici.glb` | Kuşatma; yavaş ama duvar yıkar |
| hizli | Hızlı | 4 | 4.0 | 4 | 1 | 10 | — | 1 | 0.80 | mor | `creature_hizli.glb` | Kâğıttan koşucu; ocağa ilk varan |

Aynı tablo makine tarafı için: **`YARATIKLAR.csv`**.

## SÜTUNLAR NE DEMEK

| Sütun | Anlamı |
|---|---|
| **Can** | Gece kademesiyle çarpılır (`night_hp_mult`: her gece +%6). |
| **Hız** | m/sn. Oyuncu koşu hızıyla karşılaştır: hızlı tip oyuncudan kaçamayacağın tek tip. |
| **Hasar** | Oyuncuya temas hasarı. İlk 3 gece ×0,6 (`EARLY_DAMAGE_MULT`). |
| **Öz** | Ölünce düşen `oz` adedi. |
| **İlk gece** | Bu tip hangi geceden itibaren dalgaya girer. |
| **Yetenek** | `climb` / `swim` — yol bulmayı **ve** hareketi değiştirir (aşağıya bak). |
| **Yapı çarpanı** | `struct_mult`: yapıya vuruş hasarı çarpanı (taban `STRUCT_DAMAGE = 12`). |
| **Göz** | Tek parlak gözün rengi: turkuaz (`EYE_COLOR`) / mor (`EYE_COLOR_ALT`). |

## YETENEKLER — nasıl çalışıyor

Yetenek **iki yerde birden** okunuyor; ikisi de gerekli:

1. **Yol bulma** (`world3d.creature_break_cost`) — aynı engel farklı
   yaratık için farklı maliyet:

   | Engel | Normal | Tırmanıcı | Yüzücü |
   |---|---|---|---|
   | Boş hücre | 1 | 1 | 1 |
   | Duvar / yapı / ağaç | 14 (`BREAK_COST`, kırar) | 3 (`CLIMB_COST`, aşar) | 14 |
   | Su | geçilmez | geçilmez | 4 (`SWIM_COST`) |
   | Plato / harita kenarı | geçilmez | geçilmez | geçilmez |

2. **Hareket** (`_tick_one_creature`) — yol oradan geçiriyorsa gövde de
   geçmeli. Yüzücü suda hız ×0,30 (`SWIM_SLOW`), tırmanıcı duvarda
   ×0,45 (`CLIMB_SLOW`). Yalnız yol bulmaya bağlansaydı yaratık suyun
   kıyısında takılır, "yolum var ama yürüyemiyorum" durumuna düşerdi.

**Kırılabilir engel kapalı değil, PAHALI.** Bu yüzden "kır mı, dolaş mı"
diye ayrı bir karar mantığı yok: 14 hücreden kısa bir dolambaç varsa
yaratık dolaşır, yoksa kırar. Duvarını nasıl tasarladığın doğrudan
davranışı belirliyor.

## HEDEF: HER ZAMAN OCAK

Yaratıklar oyuncuyu kovalamaz — **düz Ocak'a yürür**. Oyuncu yalnızca
temas menzilindeyse (`CONTACT_RANGE = 0,9 m`) vurulur; bu bir hedef
değişimi değil, temas tepkisidir. Önceki hâlde yaratıklar oyuncunun
peşine takılıyordu ve gecenin derdi "kaç" oluyordu; şimdi dert
"Ocağı koru".

## DALGA KARIŞIMI

`CreatureBalance.wave_mix(gece, adet)` üretir. Üç kural:

- Bir tip **`first_night`'tan önce çıkmaz**. Gece 1-3 yalnız normal
  (`EARLY_EASY_NIGHTS`), hasar da ×0,6.
- Bir tip **açıldığı gece mutlaka görünür** — yeni tehdit sessizce
  değil, fark edilerek girsin.
- **Özel tipler geceyi ele geçirmez**: en fazla %50 (`MIX_SPECIAL_MAX`).
  Kalanı ağırlıklı çekilişle dolar (`MIX_WEIGHT`).

Örnek ilerleme (gece → o gece açılan): 1 normal · 4 tırmanıcı ·
5 yüzücü · 7 kırıcı · 10 hızlı.

## MODELLER — 1/5 GELDİ

`creature_normal.glb` **yüklendi ve kullanılıyor** (ölçüldü: 0,830 ×
1,000 × 0,740 — Y-up, ~1 birim boyunda, gövde merkezli). Kalan dört
tip hâlâ prosedürel gövde (küre + tek parlak göz) ile çiziliyor; kod
bunu hata saymıyor.

**Klasör esnek:** kod önce tablodaki yola, bulamazsa
`assets/models/test/` altına bakıyor (`creature.gd::_resolve_glb`).
GitHub web arayüzünden yükleme pratikte `test/` altına düştüğü için
bu gerekliydi — dosya hangisine düşerse düşsün bulunur.

Kalan dosyalar:

```
creature_tirmanici.glb
creature_yuzucu.glb
creature_kirici.glb
creature_hizli.glb
```

Model isterleri (diğer Meshy varlıklarıyla aynı hat):

- **~1 birim** yüksekliğinde. Merkezli gelmesi sorun değil: kod
  AABB'nin alt kenarını ölçüp modeli yere oturtuyor (merkezli model
  olduğu gibi eklenseydi yaratığın yarısı zeminin altında kalırdı —
  `creature_normal` tam olarak öyle geldi). Ölçek tablodaki `scale`
  ile **kök düğüme** verilir; iç düğümlere asla dokunulmaz.
- Karakterle aynı üslup: düşük poligon, sade siluet, **soğuk palet**.
  Ayırt edicilik silüetten gelsin: tırmanıcı ince/uzun kollu, kırıcı
  iri ve ağır, hızlı küçük ve dar.
- **Tek parlak göz** kimliğin özü. Model kendi gözünü getirse bile
  emissive olmalı; gelmezse prosedürel göz eklenmiyor (GLB yolu
  gövdenin tamamını devralıyor).

Model geldiğinde CI'daki `YARATIKTIP` satırında `glb_eksik` listesi
kendiliğinden kısalır.

## TEST

`YARATIKTIP` (hızlı CI katmanı, her push) şunları doğruluyor:

- tablodaki her satırın alanları tam mı, GLB var mı (yoksa listeler),
- **yetenek gerçekten davranışa bağlı mı**: aynı su şeridinde yüzücü
  hedefe varıyor, normal varamıyor; aynı kısa duvarda tırmanıcının
  yolu normalinkinden kısa çıkıyor,
- dalga karışımı üç kurala uyuyor mu.

İkinci madde bilinçli: yeteneği tabloya yazmak kolay, davranışa
bağlamak zor — kopukluk sessizce oluşur.
