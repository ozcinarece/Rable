# Survival Sandbox — Tasarım Belgesi

2D top-down mobil survival sandbox (Godot 4). Bu belge oyunun "anayasası";
sistemler eklendikce guncellenir.

## Vizyon
- Gunduz kaynak toplama, uretim (crafting), alet yapimi
- Base building / savunma
- Grid tabanli terrain kazma
- Basitlestirilmis su sistemi (borularla hacim aktarma)
- Gece yaratik saldirilari, her gece zorlasan dalga sistemi
- Platform: Android (dokunmatik oncelikli)

## Kaynak Zinciri

### Ham kaynaklar (dunyadan toplanir)
| Kaynak | Kaynagi | Vurus | Verdigi |
|---|---|---|---|
| Odun | Agac | 3 (balta: 1) | +3 odun, +2 yaprak |
| Yaprak | Agac (yan urun) | - | - |
| Tas | Kaya | 4 (kazma: 2) | +2 tas |
| Meyve | Meyve calisi | 1 | +2 meyve; cali 60 sn sonra yeniden buyur |

### Aclik
- 100'den baslar, saniyede 0.25 azalir (~6.5 dk)
- Meyve ye: +25 (HUD'daki "Ye" butonu)
- Sifira inince oyuncu yari hizda yurur (olum M5'te can sistemiyle)

### Envanter
- Slot mantigi: her esya turu 1 slot, yigin limiti 50
- Baslangic 8 slot; Canta (3 ip + 4 yaprak [tezgah]) +4 slot, en fazla 2
- Envanter dolunca toplama/kazma/uretim reddedilir ("Envanter dolu!")
- Envanter paneli: slot izgarasi, esya detayi, panelden meyve yeme
- Sandiklar sinirsiz: depolamanin amaci bu

### Kazma (kurek gerekir)
- Kazma modu: sag ustteki kurek butonu; acikken dokunma/aksiyon kazar
- Cim ve toprak kazilinca +1 toprak, kum kazilinca +1 kum verir
- Kazilan hucre cukur olur: gecilemez (hendek savunmasi)
- Cukur suya komsuysa suyla dolar ve su bagli tum cukurlara yayilir
  (kanal mekanigi - su sisteminin temeli)
- Cukur, insa cubugundaki "Doldur" ile 1 toprak karsiligi kapatilir
- Kurek: 2 cubuk + 1 ip + 1 kalas [tezgah]

### Kayit
- Her 8 saniyede + uygulama arka plana alininca otomatik kayit (user://save.json)
- Harita durumu, envanter, aclik, respawn ve oyuncu konumu saklanir
- Harita boyutu degisen guncellemede eski kayit yok sayilir
- Sag ustteki "Yeni Oyun" butonu kaydi silip bastan baslatir

### Basit uretim (elde, her yerde)
| Urun | Tarif |
|---|---|
| Kalas x2 | 1 odun |
| Cubuk x2 | 1 kalas |
| Ip x1 | 3 yaprak |

### Karmasik uretim (Calisma Tezgahi yaninda) — M4c/M4d
| Urun | Tarif | Etkisi |
|---|---|---|
| Balta | 2 cubuk + 1 ip + 1 tas | Agac 3 -> 1 vurus |
| Kazma | 2 cubuk + 1 ip + 2 tas | Tas 4 -> 2 vurus |

## Yapilar
| Yapi | Maliyet | Islev |
|---|---|---|
| Ahsap duvar | 2 kalas | Engel/savunma (sokulunce iade) |
| Tas duvar | 2 tas | Saglam engel |
| Calisma Tezgahi | 4 kalas + 2 cubuk | Yaninda karmasik tarifler acilir |
| Kamp Evi / Base | 6 kalas + 2 ip + 4 yaprak | Yeniden dogma noktasi; ileride depo/uyku |
| Sandik | 4 kalas + 1 ip | Depolama: dokununca panel acilir, yigin tasima; sadece bosken sokulur |

## Arayuz
- Sol ust: dinamik envanter cubugu (sahip olunan kaynaklar otomatik listelenir)
- Sol alt: "Uretim" butonu -> tarif paneli (ikon + maliyet + Uret)
- Alt orta: insa cubugu (tariflerden dinamik)
- Sag alt: baglamsal aksiyon butonu (yumruk / balta / cekic)

## Kontroller
- Surukle: hareket (sanal joystick), kisa dokunus: tile etkilesimi
- Aksiyon butonu: bakilan yondeki hucreye vur / insa et

## Gorunum
- 3/4 perspektif (Animal Crossing / Stardew tarzi): nesnelerin hem ustu
  hem on yuzu gorunur; ekranda asagida olan one cizilir (Y-sort)
- Zemin duz TileMap; nesneler (agac/kaya/yapilar) 32x64 gorselli,
  Y-sirali sprite'lar - oyuncu agacin arkasindan gecebilir
- Karakter 4 yone bakar (asagi/yukari/yan+ayna)

## Buyuk Fazlar (oncelik sirasi)
1. [x] Gorsel temel: 3/4 perspektif + Y-sort + karakter yonleri
2. [~] Envanter altyapisi: envanter paneli (slot/detay) [x] + canta
   (kapasite) [x] -> eline esya alma/ekipman (elde gorunur alet) ->
   yapi tasima
3. [ ] Savas cagi: mizrak/zirh/sapka + gece-gunduz + dusman dalgalari +
   can/savas + tuzaklar
4. [ ] Yerlesik hayat: cok tile'li ev/base insaati (oda mantigi, gorsel +
   stratejik) + tarim (su kanallariyla sulama)
5. [ ] Ilerleme: seviye/yetenekler/tarif kilitleri (XP kaynaklari
   olgunlasinca)
Surekli: gorsel iyilestirme her fazda dozunda; cit vb. kucuk icerikler
uygun faza serpistirilir.

## Yol Haritasi
- [x] M1: Tile dunya + hareket + kamera
- [x] M2: Kaynak toplama + envanter + HUD
- [x] M3: Insa sistemi (duvarlar)
- [x] M3.5: Coklu vurus, ikonlu aksiyon butonu, carpisma duzeltmeleri
- [x] M4a: Yaprak, agacin cift urunu, dinamik envanter HUD'i
- [x] M4b: Uretim sistemi (el tarifleri + uretim paneli)
- [x] M4c: Aletler (balta/kazma, vurus azaltma)
- [x] M4d: Calisma tezgahi + kamp evi (base) + respawn noktasi
- [x] M4e: Kaydetme sistemi (otomatik JSON kayit + Yeni Oyun butonu)
- [x] M4f: Aclik + meyve calisi (yeniden buyuyen kaynak)
- [x] M4g: Depo sandigi (esya tasima paneli, sandik basina depolama)
- [x] M4h: Kazma sistemi (kurek, cukur/hendek, su kanali, doldurma)
- [ ] M5: Gece/gunduz dongusu + dusman dalgalari + can/savas
- [ ] M7: Su sistemi genisletme (borular, hacim aktarma, pompa)
- [ ] Prosedurel harita uretimi (ayni ASCII formatini ureten uretec)

## Teknik Notlar
- Harita: scripts/map_data.gd icinde ASCII grid; world.gd doser
- Tile tanimlari: world.gd TILE_DEFS (gorsel/carpisma/drops/hits)
- Esya tanimlari: scripts/items.gd (ad + ikon)
- Tarifler: scripts/recipes.gd (BUILD_RECIPES / CRAFT_RECIPES)
- Envanter: Inventory autoload; Uretim: Crafting autoload
- CI: her push'ta GitHub Actions APK uretip "latest-apk" release'ine koyar
