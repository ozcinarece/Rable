# BÖLÜM 15 — YARATIK SİSTEMİ — Uygulama Raporu

Otonom mod. Branch: `yaratiklar` (**muhendislik** üstüne — 15.5/15.6 çevre ve
tuzaklar merdiven/kazık/derinlik/su sistemlerine dayandığı için, o modülün
zaten kurulu olduğu daldan türetildi). Denge sayıları
`scripts/creature_balance.gd`'de. Aşama başına commit; oyun her commit'te açılır.

## KEŞİF — Kapanacak "yaratık" TODO/kancaları (zorunlu tarama)

Kod tabanında bulunan yaratık kancaları ve hangi aşamada kapanır:

| Kanca / TODO | Yer | Kapanış |
|---|---|---|
| `DayNight.night_started` (dalga kancası) | daynight.gd:14 | Aşama 3 |
| `DayNight.dawn_started` (şafak temizliği) | daynight.gd | Aşama 3 |
| `Hud._morning_reward()` BOŞ | hud.gd:952 | Aşama 6 |
| Gece pill "Gece N — Geliyorlar" bekleyen metin | hud.gd:940 | Aşama 6 |
| `world.get_hearth()` (gece hedefi) | world3d.gd | Aşama 2/6 |
| `take_hit` arayüzü (kukla = yaratık) | hittable_dummy.gd:82 | **Aşama 1 ✓** |
| `_apply_hitbox` "hedef = kukla; yaratıklar aynı yol" | world3d.gd | **Aşama 1 ✓** |
| `_structure_take_hit` "yaratıklar da bu yolu kullanacak" | world3d.gd | Aşama 2 |
| `can_step` derin çukur (yaratık tırmanma kancası) | world3d.gd:1138 | Aşama 4 |
| `spike_damage(cell)` yaratık kancası | world3d.gd:1165 | Aşama 5 |
| `is_swimmable` "yaratıklar da kullanacak" TODO | world3d.gd:2990 | Aşama 4 |
| player3d su/tırmanma "11.6 ile gelecek" | player3d.gd:21 | Aşama 4 |
| Ocak bedel/sabah bonusu (14.6/14.9) | BASE_SAVUNMA B | Aşama 6 |
| `cig_et` "yaratıktan gelecek" | items.gd:56 | Aşama 3 (öz + et düşümü opsiyonel) |

> Not: `YARATIK_SISTEMI.md` dosyası projede yoktu; görev metni (Bölüm 15)
> girdi olarak alındı, bu rapor uygulamayı belgeliyor.

## Aşama 1 — Yaratık varlığı (15.1)

**Kararlar:**
- **`scripts/creature.gd`** (Node3D): soğuk palet placeholder — mor-gri
  yuvarlak gövde + **TEK parlak göz** (turkuaz/mor emissive + dar göz ışığı).
  `assets/models/creatures/<tip>.glb` varsa onu yükler (Meshy hattı hazır).
- **`take_hit(damage, dir)`** — kukla ile **BİREBİR AYNI** arayüz: can, hasar
  flaşı (beyaz), knockback (elastik), ölümde küçük dağılma. → **tüm silahlar
  gün-1'de çalışır** (yakın dövüş `_apply_hitbox` + menzilli mermi tick'i
  yaratığı öncelikli hedef olarak tarar).
- **Ölüm (15.1):** `died` sinyali → world **öz (`oz`)** dünya item'ı düşürür
  (yere, tip başına adet veride) + dağılma partikülü. `oz` item + ikon eklendi.
- **Debug spawn:** `K` tuşu → oyuncunun 2 hücre önüne bir yaratık (elle test).
  `spawn_creature(cell, tip, can_çarpanı)` API'si (Aşama 2-3 dalga bunu çağırır).
- **Denge (`creature_balance.gd`):** 4 tip statı (can/hız/hasar/öz/ilk-gece),
  görsel renkler, dalga eğrisi, çevre (11.1) süreleri, tuzak, Ocak, performans
  sayıları — hepsi tek dosyada (15.8 anayasa). Aşama 1 yalnız varlığı kullanır.

**CI:** `CREATURETEST: hasar=true melee=true oldu=true oz_dustu=true ok=true`
— spawn → take_hit hasar verir → melee `_apply_hitbox` yaratığa ulaşır (kılıç)
→ öldürülünce öz düşer.
