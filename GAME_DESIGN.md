# OYUN TASARIM DOKÜMANI — Survival Sandbox (Godot 4)

Bu doküman oyunun içerik kataloğudur. Claude Code bu dosyayı her oturumda
referans alır. Sistemler (envanter, crafting) kodda; içerik (item, tarif,
düğüm) bu dokümandan veri dosyalarına aktarılır.

## Genel yapı

- Katmanlar: K0 (elle) → K1 (taş çağı) → K2 (fırın çağı) → K3 (demir çağı)
- İlerleme kuralı: her katmanın kazması bir sonraki cevheri açar.
- Tarifler ARAŞTIRMA AĞACINDAN açılır: düğümler malzeme harcayarak,
  Araştırma Masası başında satın alınır. Önkoşul düğümü açık olmalı.
- Araştırma dalları: Aletler / İnşaat+Savunma / İstasyonlar / Mühendislik+Su
- İstasyon düğümleri kavşaktır: Fırın açılmadan K2 tarifleri kilitli kalır.
- Gizli düğümler: bazı düğümler ilgili malzeme ilk kez toplanınca "???"
  olarak belirir (aşağıda işaretli).

---

## 1. HAMMADDELER

### Katman 0 — elle toplanır (alet gerekmez)
| id | Ad | Kaynak | max_stack |
|---|---|---|---|
| stick | Dal | Yerden, ağaç dibi | 64 |
| pebble | Çakıl taşı | Yerden | 64 |
| fiber | Bitki lifi | Çalılar | 64 |
| clay | Kil | Su kenarı (kürek ile daha verimli) | 64 |
| berry | Yaban meyvesi | Çalılar | 32 |

### Katman 1 — taş aletlerle
| id | Ad | Kaynak | Gerekli alet | max_stack |
|---|---|---|---|---|
| wood | Odun | Ağaç | Balta | 64 |
| stone | Taş | Kayalar | Kazma | 64 |
| sand | Kum | Su kenarı | Kürek | 64 |
| hide | Deri | Hayvan | Bıçak | 32 |
| raw_meat | Çiğ et | Hayvan | — | 32 |

### Katman 2 — fırın çağı
| id | Ad | Kaynak | Gerekli alet | max_stack |
|---|---|---|---|---|
| coal | Kömür | Yeraltı damarı | Taş kazma | 64 |
| copper_ore | Bakır cevheri | Yeraltı | Taş kazma | 64 |
| copper_ingot | Bakır külçe | Fırın (cevher+kömür) | — | 64 |
| brick | Tuğla | Fırın (kil) | — | 64 |
| glass | Cam | Fırın (kum) | — | 64 |

### Katman 3 — demir çağı
| id | Ad | Kaynak | Gerekli alet | max_stack |
|---|---|---|---|---|
| iron_ore | Demir cevheri | Derin yeraltı | Bakır kazma | 64 |
| iron_ingot | Demir külçe | Fırın | — | 64 |
| steel | Çelik | Yüksek fırın (demir+kömür) | — | 64 |
| metal_part | Metal parça | Örs (külçeden) | — | 64 |

### Özel
| id | Ad | Not |
|---|---|---|
| water | Su | Item DEĞİL, hacim: kova ile taşınır, oyuklara dolar, boruyla akar |
| essence | Yaratık özü | Gece yaratıklarından düşer. Tuzak malzemesi + gizli düğüm bedeli. max_stack 32 |
| rope | İp | Ara ürün: 3 fiber → 1 rope, elde craft. max_stack 64 |
| cooked_meat | Pişmiş et | Kamp ateşinde: raw_meat → cooked_meat. max_stack 32 |
| seed | Tohum | Çalı/meyveden şansla düşer. max_stack 64 |

---

## 2. ALETLER (Aletler dalı)

Kademeler: stone → copper → iron → steel. Kademe = hız + dayanıklılık artışı.
Her alet item olarak: `{malzeme}_{alet}` (örn. stone_axe, copper_pickaxe).
max_stack: 1 (tüm aletler).

| Alet | İşlevler | Kademe özel yeteneği |
|---|---|---|
| axe (balta) | Ağaç kesme + zayıf silah | steel: tek vuruşta ağaç |
| pickaxe (kazma) | Taş/maden kazma | her kademe sonraki cevheri açar |
| shovel (kürek) | Toprak kazma/şekillendirme + kil/kum | iron: 3x3 alan kazma |
| knife (bıçak) | Lif 2x verim, deri yüzme, yemek hazırlama | steel: öz verimi +%50 |
| hammer (çekiç) | İnşa + tamir + yapı söküp malzeme İADE | iron: uzaktan tamir |
| bucket (kova) | Su taşıma | metal_bucket: sıcak sıvı |

## 3. SİLAHLAR (Aletler dalı alt kolu)

| id | Ad | Katman | Tarif | Mekanik |
|---|---|---|---|---|
| club | Sopa | 0 | 2 stick + 1 rope | İlk gece acil silahı |
| spear | Mızrak | 1 | 2 stick + 1 stone + 1 rope | Dürtme + FIRLATMA (yere düşer, geri alınır) + balık |
| sling | Sapan | 1 | 2 rope + 1 hide | Mühimmat: pebble |
| bow | Yay | 2 | 3 wood + 2 rope | Mühimmat: arrow |
| arrow | Ok | 2 | 1 stick + 1 fiber + 1 pebble | max_stack 32 |
| steel_sword | Çelik kılıç | 3 | 2 steel + 1 wood + 1 hide | En yüksek hasar |

## 4. İSTASYONLAR (İstasyonlar dalı — ağacın omurgası)

Açılma sırası:
| id | Ad | Katman | Tarif | İşlev |
|---|---|---|---|---|
| campfire | Kamp ateşi | 0 | 5 stick + 3 pebble | Pişirme, ışık, küçük gece caydırıcılığı |
| workbench | Çalışma masası | 1 | 8 wood | Temel craft istasyonu |
| research_table | Araştırma masası | 1 | 6 wood + 4 stone + 2 rope | Araştırma ağacı burada açılır |
| furnace | Fırın | 2 | 10 stone + 4 clay | Eritme, tuğla, cam |
| tannery | Tabakhane | 2 | 6 wood + 4 hide | Deri işleme, zırh yolu (opsiyonel yan istasyon) |
| anvil | Örs | 3 | 4 iron_ingot | Metal parça, alet dövme |
| blast_furnace | Yüksek fırın | 3 | 12 brick + 4 metal_part | Çelik üretimi |

## 5. TUZAKLAR (İnşaat+Savunma dalı)

Tasarım ilkesi: her tuzağın gücü + zaafı var; eğlence KOMBİNASYONDAN gelir.
| id | Ad | K | Tarif | Mekanik | Zaaf |
|---|---|---|---|---|---|
| spikes | Sivri kazıklar | 1 | 4 wood + 2 rope | Geçen hasar alır + yavaşlar | 3 tetiklemede kırılır, tamir ister |
| pit_trap | Çukur tuzağı | 1 | kazılmış çukur + 6 stick | Yaratık düşer, çıkamaz; sabah öz hasadı | Kamuflaj tek kullanımlık |
| trip_alarm | Gerilmiş ip alarmı | 1 | 2 rope + 1 stone | Hasar yok; yön bildirimi (ses) | Sadece bilgi |
| moat | Su hendeği | 2 | kazı + su | Yaratıklar %60 yavaşlar | Su kaynağı gerekir (boru!) |
| log_crusher | Ezici kütük | 2 | 2 wood + 4 rope + 1 metal_part | Kapı önü sarkacı, yüksek hasar | Tetiklenince yeniden kurulmalı |
| fire_trench | Alev hendeği | 3 | tuğla kanal + coal + çakmaktaşı | Kanalda sürekli yanma hasarı | Gece başına kömür tüketir |
| essence_lamp | Öz lambası | 3 | 2 glass + 3 essence | Yaratıkları ÇEKER (yönlendirme) | Hasar vermez; kırılırsa özler kaybolur |

GİZLİ DÜĞÜM: essence_lamp ve fire_trench, ilk essence toplandığında belirir.

Geç oyun kombosu (hedeflenen deneyim): moat (yavaşlat) → essence_lamp
(yönlendir) → fire_trench (yak).

## 6. YAPILAR (İnşaat+Savunma dalı)

| id | Ad | K | Tarif |
|---|---|---|---|
| wood_wall | Ahşap duvar | 1 | 4 wood |
| wood_door | Ahşap kapı | 1 | 6 wood |
| fence | Çit | 1 | 2 wood + 1 rope |
| stone_wall | Taş duvar | 2 | 4 stone |
| brick_wall | Tuğla sur | 2 | 4 brick |
| window | Pencere | 2 | 2 wood + 1 glass |
| steel_door | Çelik kapı | 3 | 2 steel + 1 metal_part |
| torch | Meşale | 1 | 1 stick + 1 coal |

Çekiç ile sökülen yapı malzemesinin %100'ünü iade eder (deneme özgürlüğü).

## 7. TARIM (Mühendislik+Su dalı)

| id | Ad | K | Tarif | Not |
|---|---|---|---|---|
| hoe | Çapa | 1 | 2 stick + 2 stone + 1 rope | Toprağı tarlaya çevirir (kürek kazar, çapa ekilebilir yapar) |
| watering_pot | Sulama kabı | 1 | 3 clay (fırında pişmiş: çömlek) | Elle sulama — BİLİNÇLİ olarak zahmetli |
| compost_bin | Kompost fıçısı | 2 | 6 wood + 2 rope | Bitki artığı → gübre, büyüme + |
| scarecrow | Bostan korkuluğu | 2 | 4 stick + 1 hide + 2 fiber | Ekin koruması + dekor |
| irrigation_pipe | Sulama borusu | 3 | 2 metal_part | Boru sistemine bağlı tarla kendini sular — otomasyon ödülü |

## 8. MÜHENDİSLİK + SU (Mühendislik+Su dalı)

| id | Ad | K | Tarif | Not |
|---|---|---|---|---|
| bucket | Kova (ahşap) | 1 | 4 wood + 1 rope | Su taşıma |
| metal_bucket | Metal kova | 3 | 2 metal_part | Sıcak sıvı |
| pipe | Boru | 3 | 1 metal_part | Su aktarımı: oyuk→oyuk hacim transferi |
| pump | Pompa | 3 | 3 metal_part + 1 copper_ingot | Suyu yukarı taşır |
| valve | Vana | 3 | 1 metal_part | Akışı aç/kapa |

Su modeli: gerçek akışkan simülasyonu YOK. Hücre bazlı hacim + boru
bağlantıları mantıksal transfer (Terraria tarzı cellular yaklaşım).

## 9. ARAŞTIRMA AĞACI DÜĞÜMLERİ

Kural: node = { id, dal, önkoşul_node, maliyet (malzeme listesi),
açtığı tarifler, gizli_mi }

Örnek başlangıç düğümleri (tam liste veri dosyasında genişletilir):
- research_basics (kök, otomatik açık): club, campfire, rope
- stone_tools (Aletler, önkoşul: kök, maliyet: 5 stick + 3 pebble):
  stone_axe, stone_pickaxe
- basic_building (İnşaat, önkoşul: kök, maliyet: 8 wood): wood_wall,
  wood_door, fence
- workbench_node (İstasyonlar, önkoşul: kök, maliyet: 6 wood): workbench
- furnace_node (İstasyonlar, önkoşul: workbench_node, maliyet:
  10 stone + 4 clay): furnace  ← K2 KAVŞAĞI
- farming_basics (Mühendislik, önkoşul: workbench_node, maliyet:
  4 wood + 2 stone): hoe, watering_pot
- (gizli) brick_making (İstasyonlar, tetik: ilk clay, önkoşul:
  furnace_node): brick, brick_wall
- (gizli) essence_tech (Savunma, tetik: ilk essence, önkoşul:
  furnace_node): essence_lamp, fire_trench

## 10. GECE EKONOMİSİ

- Yaratıklar geceleri saldırır, her gece dalga gücü kademeli artar.
- Yaratık özü (essence) sadece geceden gelir → gece = risk + kaynak.
- Atlatılan her gecenin sabahı: küçük araştırma indirimi VEYA malzeme
  iadesi (denge testinde karar verilecek).
