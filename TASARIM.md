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
- [ ] M5: Gece/gunduz dongusu + dusman dalgalari + can/savas
- [ ] M6: Kazma sistemi (grid terrain)
- [ ] M7: Su sistemi (borularla hacim aktarma)
- [ ] Prosedurel harita uretimi (ayni ASCII formatini ureten uretec)

## Teknik Notlar
- Harita: scripts/map_data.gd icinde ASCII grid; world.gd doser
- Tile tanimlari: world.gd TILE_DEFS (gorsel/carpisma/drops/hits)
- Esya tanimlari: scripts/items.gd (ad + ikon)
- Tarifler: scripts/recipes.gd (BUILD_RECIPES / CRAFT_RECIPES)
- Envanter: Inventory autoload; Uretim: Crafting autoload
- CI: her push'ta GitHub Actions APK uretip "latest-apk" release'ine koyar
