# RAPOR — YERLEŞİM EDİTÖRÜ (geliştirici aracı)

Oyun içinde canlı düzenleme modu: kampı/yolları elle kur, sonucu veri
dosyası olarak dışa aktar, dünya üretimi o dosyayı okusun.
Branch: `yerlesim-editoru` (tabanı `tas-yol-scatter` — §2'deki "Yol:
scatter hücresi" o dala bağlı).

## DOSYALAR

| Dosya | Ne |
|---|---|
| `scripts/layout_editor.gd` | **YENİ** — veri katmanı: JSON okuma/yazma, araç adları, kategoriler, sınırlar. Oyun mantığı içermez. |
| `scripts/world3d.gd` | editör durumu, araç işlemleri, dışa/içe aktarım, dünya üretimi kancası, EDITORTEST |
| `scripts/hud.gd` | editör çubuğu + Ayarlar'daki anahtar |
| `data/` | boş klasör — `camp_layout.json` buraya taşınacak |

## 1. YAYIN SÜRÜMÜNE SIZMAMA

Anahtar, mevcut Grip Ayarı ile **aynı kapının** ardında:

```gdscript
if OS.is_debug_build() or TestMode.ENABLED:
    ...
    _editor_check = CheckButton.new()
```

Bu blok yayın sürümünde hiç çalışmıyor → anahtar **oluşturulmuyor** →
sinyal hiç yayınlanmıyor → `editor_set_enabled` hiç çağrılmıyor. Editör
kodu derlemede duruyor ama erişim yolu yok. (`TestMode.ENABLED=false`
yapmak web sürümünden de kaldırır — grip aracında kullanılan aynı
mekanizma.)

## 2. MOD GİRİŞİ

Açılınca:

- **HUD sadeleşir**: dock, hotbar, barlar, gün hapı gizlenir. Ayrı bir
  gizleme mantığı yazılmadı — panel açılışlarında zaten kullanılan
  `_hud_game_nodes()` yardımcısı yeniden kullanıldı.
- **Üstte ince editör çubuğu**: 3 satır (araçlar / kategori+öğe /
  eylemler) + durum satırı. UI dilinde: mevcut buton stilleri, ayrı bir
  "editör teması" yok.
- **Zaman donuk**: `DayNight` ve `Thirst` işlem döngüsü kapatılır
  (`process_mode = DISABLED`), yaratıklar temizlenir. Açlık/gece/hasar
  durur.
- **Işık önizlemesi**: çubukta 🌙 / ☀ butonları. `jump_to_night/day`
  işlem döngüsünden bağımsız olduğu için zaman donukken de çalışır.

## 3. ARAÇLAR

| Araç | Davranış |
|---|---|
| **Yerleştir** | Kategori listesi (Yapılar / Yol / Dekor / Tarla). Yapılarda mevcut **hayalet önizleme** sistemi kullanılıyor. |
| **Seç / Taşı** | İlk dokunuş seçer (altın halka), ikinci dokunuş seçiliyi oraya taşır. Aynı hücreye ikinci dokunuş seçimi bırakır. |
| **Sil** | Onay yok. Geri-al var. |
| **Yol Fırçası** | Basılı tut-sürükle → geçilen hücrelere yol. **Silgi** anahtarıyla ters yön. |

Ek kontroller: **90° Döndür** (hayaleti ve seçili öğeyi döndürür),
**Ölçek** kaydırıcısı (±%10), **↶ Geri Al** (son 10 işlem).

**Ölçek yalnız dekorda etkin.** Yapılar hücreye oturuyor; ölçekleri
değişirse çarpışma (hücre) ile görsel ayrışır ve editörde doğru görünen
şey oyunda yanlış olur. Kaydırıcı yapı seçilince soluklaşıp kilitleniyor.

**Fırça ve uç kuralları:** fırça yalnızca hücre ekler/çıkarır. Yolun
uçlarındaki küçülme rampası `_build_road()` içinde otomatik hesaplanıyor
— yani fırçayla çizilen yol da "dağılarak" bitiyor, ayrı bir kural yok.

### Maliyet bypass, kural bypass DEĞİL

Editör `_place_valid()` ile doğruluyor — oyunun kendi kuralı: sınır,
doluluk, su, çukur, zemin türü. **Atlanan tek şey malzeme maliyeti.**

Bu bilinçli: ayrı bir editör-doğrulaması yazılsaydı iki kural seti
oluşurdu ve editörde kurulan kamp oyunda geçersiz olabilirdi. Görevdeki
"aynı hücreye iki yapı konamaz" şartı da buradan geliyor — ayrıca
kodlanmadı, `_place_valid` zaten reddediyor.

## 4. KAYIT GÜVENLİĞİ

- Editör açıkken **otomatik kayıt kapalı** (`_dirty and not _editor_on`).
- Uygulama arka plana alınınca yapılan **çıkış kaydı da kapalı**.
- Editörden çıkınca kayıt varsa **dünya kayıttan yeniden yüklenir**.

Yani editörde yapılan hiçbir şey normal oyun kaydına yazılmıyor. Düzeni
saklamanın tek yolu **Dışa Aktar**.

## 5. DOSYA BİÇİMİ

`user://camp_layout.json` — girintili, `tür` ve hücre sırasına göre
dizili (elle bakılacak dosya). Örnek:

```json
{
  "surum": 1,
  "aciklama": "Kamp yerlesimi (yerlesim editoru)",
  "merkez_not": "Hucreler kamp merkezine GORE ofsettir; disa aktarim aninda merkez (59,62) idi.",
  "ogeler": [
    { "tur": "yapi", "id": "ocak", "hucre": [0, 0], "rot": 0 },
    { "tur": "yapi", "id": "sandik", "hucre": [-4, 4], "rot": 90 },
    { "tur": "yol",  "id": "yol_hucresi", "hucre": [0, 1], "rot": 0 },
    { "tur": "dekor","id": "grass_tuft", "hucre": [2, 3], "rot": 45, "olcek": 1.05 },
    { "tur": "tarla","id": "tarla_hucresi", "hucre": [5, -1], "rot": 0 }
  ]
}
```

**Hücreler GÖRELİ** — kamp merkezine göre ofset. Kamp merkezi tohuma
bağlı, her dünyada başka bir hücrede. Mutlak hücre yazılsaydı dışa
aktarılan düzen **tek tohuma hapsolurdu**. `"olcek": 1.0` gibi
varsayılan değerler dosyaya yazılmıyor (gürültü olmasın).

## 6. DÜNYA ÜRETİMİ

`res://data/camp_layout.json` **varsa** başlangıç kampı ondan kurulur:

```
_build_spawn_camp()        # kodlanmış kamp (fallback) — ÖNCE
_kamp_duzenini_uygula()    # data/camp_layout.json — ÜSTÜNE
```

Kodlanmış kamp **silinmedi**. Dosya opsiyonel bir **katman**: dosyada
olmayan şeyler (kulübe, kuyu, tarla dekoru) yerinde kalır, dosyada
olanlar eklenir. Dosya yoksa hiçbir şey olmaz.

Yükleme başarılı olursa loga şu satır düşer:
`KAMPDUZEN: res://data/camp_layout.json okundu, N oge kuruldu (merkez X,Y)`

## 7. DÜZENİ REPOYA ALMA — ADIM ADIM

Bu, senin yapacağın akış:

1. Oyunu **debug sürümde** aç (masaüstü Godot ya da web sürümü —
   `TestMode.ENABLED` açıkken web'de de çıkar).
2. **Ayarlar → Yerleşim Editörü** anahtarını aç.
3. Kampı kur. İstediğin an **Yükle** ile önceki düzeni açıp üstünde
   devam edebilirsin.
4. **Düzeni Dışa Aktar**'a bas. Durum satırı dosya yolunu yazar; ayrıca
   loga tam yol düşer:
   `EDITOR: disa aktarildi ogeler=N dosya=/gerçek/yol/camp_layout.json`
   - Masaüstü Linux: `~/.local/share/godot/app_userdata/<proje>/`
   - Windows: `%APPDATA%\Godot\app_userdata\<proje>\`
   - Web: tarayıcı depolamasında; oradan indirmek gerekir.
5. Dosyayı bana ver (GitHub web'den yüklemen en pratiği).
6. Ben `data/camp_layout.json` olarak commit'lerim.
7. **Yeni Oyun** → kamp o düzenden kurulur.

## 8. EDITORTEST (hızlı CI, her push)

Görevdeki doğrulama zinciri kod tarafında koşuyor: editörde kamp kur →
geri al çalışıyor mu → dışa aktar → dosyayı oku → temiz dünyaya uygula →
öğeler birebir aynı mı.

Karşılaştırma **ekran görüntüsüyle değil**, `tür:id@ofset` listeleriyle
yapılıyor — "birebir kuruldu mu" sorusunun cevabı göz kararı olmamalı.

Son koşu:

```
EDITORTEST: kuruldu=5/5 undo_ok=true disa_aktarilan=4
geri_kurulan=4 birebir=true kayit_kapali=true
```

5 öğe kuruldu, geri-al birini geri aldı (dışa aktarılan 4), dosyadan
kurulan 4 öğe orijinaliyle **birebir aynı**.

Neden "Yeni Oyun" açmıyor: yeni oyun sahneyi baştan kuruyor ve testi
beklemeye zorluyor (ağır CI katmanına düşerdi). Aynı sahnede öğeler
kaldırılıp dosyadan yeniden kuruluyor; ölçülen şey aynı — "dışa
aktarılan dosya dünyayı aynı hâle getiriyor mu".

## 9. BİLİNÇLİ SINIRLAR

- **Dekor tek tek Node3D** (MultiMesh değil): taşınabilmesi,
  döndürülebilmesi, ölçeklenebilmesi gerekiyor. Sayıları onlarca
  mertebesinde olduğu için kabul edilebilir. Dünya üretimindeki serpinti
  hâlâ MultiMesh.
- **Geri-al 10 işlem** (görevde belirtilen). Fırçayla sürüklerken aynı
  hücre tekrar tekrar işlenmiyor, yoksa tek sürükleyişte yığın dolardı.
- **Kategori listesi sabit bir alt küme** — `layout_editor.gd`'de. Yeni
  model kaydı tanımlamıyor, mevcut kayıtlardan (PLACE_MODELS /
  EnvModels) seçiyor.
