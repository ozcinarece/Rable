# BÖLÜM 13 — YAPI YERLEŞTİRME / BASE BUILDING

Doküman ailesinin parçası (GAME_DESIGN, UI_DESIGN, KAZI_SU_MODULU,
ALET_SISTEMI ile birlikte okunur). Craftlanmış yapıların dünyaya
yerleştirilmesi, yapı durumları, kapı/meşale davranışları ve çekiç
entegrasyonu. Yaratık davranışı YOK — ama yapılar ALET_SISTEMI'ndeki
take_hit arayüzünü kullanır ki yaratıklar geldiğinde duvarlara
saldırabilsinler (hazır kapı).

---

## 13.1 TEMEL MODEL

- Yerleşim HÜCRE BAZLI: bir yapı bir hücreyi kaplar (kazı grid'iyle
  aynı sistem). Çok hücreli yapılar (ileride) dikdörtgen ayak izi.
- Akış: ÖNCE CRAFT (mevcut tarif sistemi, envanterde item) → SONRA
  YERLEŞTİR. Anında-inşa yok.
- Yerleştirilebilir kategoriler (item database'den): structure, station,
  trap, farming. Kategoriye "placeable: true/false" alanı ekle.
- Yapı örneği (instance) verisi: { yapi_id, hücre, yön (0/90/180/270),
  hp, max_hp, durum }. Dünyadaki tüm yapılar StructureManager'da.

## 13.2 YERLEŞTİRME AKIŞI (mobil öncelikli)

1. Envanterde yerleştirilebilir item'a dokun → "Yerleştir" seçeneği.
2. YERLEŞTİRME MODU: yarı saydam HAYALET önizleme öndeki hücrede;
   karakter yürüdükçe takip eder. Hücreye dokunarak da hedef seçilir
   (menzil: max 3 hücre).
3. Hayalet renkleri: geçerli = success yeşili, geçersiz = danger +
   neden rozeti.
4. Üç buton (sağ altta): ONAYLA / DÖNDÜR 90° / İPTAL. Onayla → item
   düşer, yapı yerleşir, pop + toz. Mod açık kalır (seri dizme); item
   bitince/İptal'de kapanır.
5. Klavye: R döndür, Sol tık onay, Esc iptal.

## 13.3 GEÇERLİLİK KURALLARI

- Hücre dolu → "dolu"; Su hücresi → "su" (placeable_on_water false);
  Kazılmış (depth≥1) → geçersiz, İSTİSNA trap placeable_in_pit;
  Oyuncu/kukla hücresi → "meşgul"; Yükseltilmiş hücre → geçerli.

## 13.4 YAPI DURUMLARI VE ÇEKİÇ

- max_hp: fence 40, wood_wall 80, stone_wall 160, brick_wall 240,
  steel_door 320 (veride).
- take_hit(damage, dir): ALET_SISTEMI 12.5 arayüzü + sarsıntı/partikül.
- hp<%50: hasarlı görünüm. hp 0: yıkılır, malzemenin %25'i saçılır.
- ÇEKİÇ: TAMİR (vuruş başına +hp, malzeme düşer) / SÖKME (0.8 sn tut,
  %100 iade).

## 13.5 ÖZEL DAVRANIŞLAR

- KAPILAR: aç/kapa (0.2 sn tween + gıcırtı). Açık geçilir, kapalı katı.
- MEŞALE: OmniLight3D sıcak turuncu, flicker; max ~8 aktif ışık, fazlası
  sönük görsele düşer.
- İSTASYONLAR: yakınlık craft sistemi otomatik tanır (doğrula).
- TUZAKLAR: sadece yerleştirme (13.3 çukur istisnası). Tetik TODO.
- Dekor-işlev yapıları: yerleşir, işlev ileride bağlanır.

## 13.6 KAYIT NOTU

StructureManager to_save_data()/from_save_data() ÇALIŞIR yazılsın; kayıt
sistemi geldiğinde bağlanır.
