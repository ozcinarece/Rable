# HARİTA MASTER PLANI — DURDU: KESIF.md YOK

Görev talimatı: "KESIF.md'yi OKU (halka yapısı 16.1, tehditler 16.6)
— bu görevin tasarım anayasası. Yoksa RAPOR'a yaz, dur."

**KESIF.md repoda yok.** Arama kapsamı: main dahil TÜM uzak dallar,
tam ağaç (alt klasörler dahil), büyük/küçük harf varyantları. Kök
dizindeki 36 .md dosyasının hiçbiri değil. DURUM.md'deki eski tespit
de aynı: "KEŞİF/Ocak Nefesi/Eşik Gecesi: repo dokümanlarında bile yok
— bu vizyon yalnız sohbetlerde."

Talimata uyup **hiçbir aşamaya başlamadım** — Aşama 0 ölçümü dahil.
Anayasasız üretilen halka mesafeleri/tehdit eşlemesi sonra iki kez
yazılırdı.

## DEVAM İÇİN GEREKEN

`KESIF.md` dosyasını repoya ekle (kök dizine). Görevin ihtiyaç
duyduğu asgari bölümler:

- **16.1 Halka yapısı:** merkez + H1/H2/H3 tanımları, her halkanın
  teması ve niyeti (görev metnindeki özet iskelet var ama anayasa
  metni bağlayıcı olan).
- **16.2 Sis / ışık-kapısı:** Aşama 4'ün "basit hali"nin neyin
  basiti olduğunu bilmek için tam mekanik tarifi.
- **16.6 Tehditler:** halka başına yaratık/tehdit listesi —
  ring_balance.gd'nin sayıları buradan türeyecek.

Dosya main'e düşer düşmez görev bu dalda (harita-master) kaldığı
yerden başlar: Aşama 0 (boyut/chunk/LOD ölçümü) → maskeler → halka
verisi → POI → sis v1 → doğrulama.

## HAZIR ZEMİN (dosya beklerken tespit)

Yeniden başlatma hızlı olsun diye mevcut altyapının görevle kesişimi:

- Harita bugün **128×128, tek parça** üretiliyor (chunk/LOD yok) —
  Aşama 0'ın ölçüp karar vereceği ana konu bu.
- **Maske altyapısı hazır:** `map_mask.png` (7 sınıf) +
  `height_mask.png` (3 kademe) üretimde okunuyor; boyama aracı
  (`scenes/tools/map_painter.tscn`) ikisini de düzenliyor.
  `fog_mask.png` üçüncü katman olarak aynı kalıba oturur (ressama
  yeni sekme + MapMask'e gri tonlama okuyucu).
- Tohum sabit (`MapBalance.SEED_DEFAULT`), taban harita kayda
  yazılmıyor → maske değişiklikleri deterministik, kayıt bozmaz.
- Gece dalga sistemi minimal ama kanca almaya uygun
  (`CreatureBalance.wave_mix` çağrısı tek noktada).
