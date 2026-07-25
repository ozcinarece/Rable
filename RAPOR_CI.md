# RAPOR — CI Süre Optimizasyonu

Tarih: 2026-07-25 · Branch: `tas-yol-fix`

---

## 1. Ölçüm: adım süre dökümü

GitHub Actions'ın kendi adım zaman damgalarından (`actions_list` →
`list_workflow_jobs`), `screenshot.yml`'nin iki gerçek koşusu:

| Adım | Koşu A (30161234998) | Koşu B (30162141531) |
|---|---:|---:|
| Set up job | 1 sn | 1 sn |
| Repoyu al | 9 sn | 10 sn |
| Godot indir | 2 sn | 2 sn |
| Sanal ekran kur | 7 sn | 8 sn |
| **Projeyi içe aktar** | **172 sn** | **189 sn** |
| **Oyunu çalıştır** | **300 sn** | **480 sn** |
| Görüntüyü commit'le | 4 sn | 4 sn |
| **Toplam** | **8 dk 17 sn** | **11 dk 38 sn** |

### En pahalı üç adım

1. **Oyunu çalıştır — 300–480 sn.** Her koşuda tam görsel akış: ~40 kare,
   vitrin, kamp/yol testleri, gece dalgası, perf sondası. İki kez
   `timeout`'a dayandı (300 ve 480), yani gerçek maliyet tavana yaslanmış
   durumda. Kök neden: CI sanal ekranda **yazılım rasterleştirme** ile
   koşuyor, kare başına ~1 saniye — her `await ... timeout` bir kareden
   fazlasına mal oluyor.
2. **Projeyi içe aktar — 172–189 sn.** Her koşuda sıfırdan. Oysa assetler
   commit'lerin çoğunda hiç değişmiyor (yalnız `scripts/**` değişiyor).
3. **Sanal ekran kur — 7–8 sn.** `apt-get update` + xvfb kurulumu.
   Diğer ikisinin yanında önemsiz; üçüncü sırada olması ilk ikisinin ne
   kadar baskın olduğunu gösteriyor.

---

## 2. Import önbelleği

`.godot/` klasörü `actions/cache@v4` ile önbelleğe alınıyor:

```yaml
key: godot-import-${{ env.GODOT_TAG }}-${{ hashFiles('assets/**', 'project.godot') }}
restore-keys: godot-import-${{ env.GODOT_TAG }}-
```

Anahtar asset klasörlerinin ve proje ayarlarının hash'i. Asset
değişmediğinde içe aktarma adımı **~180 sn → birkaç saniye**. Asset
değişirse anahtar tutmaz, `restore-keys` ile en yakın önbellek geri
yüklenir ve Godot yalnız **değişen** dosyaları yeniden içe aktarır —
yani "hepsi baştan" durumu asset eklendiğinde bile oluşmaz.

Godot sürümü anahtarın içinde: sürüm yükselince önbellek bilinçli olarak
geçersiz oluyor (içe aktarma formatı sürüme bağlı).

---

## 3. Test katmanlama

| Katman | Nerede koşar | Ne koşar | Süre |
|---|---|---|---|
| **Hızlı / mantık** | `ci-fast.yml` — her push | MAPTEST, CAMTEST, TIMETEST, MÜHENDİSLİK, YARATIK, KAYIT/YÜKLEME + GDScript parse kontrolü | saniyeler |
| **Ağır / görsel** | `screenshot.yml` — PR + elle | Tüm kareler, vitrin, CLICKTEST, KAZI/SU/TARIM, KAMPTEST, ROADTEST, NIGHTTEST, PERFTEST | 5–8 dk |

Hızlı katman oyunu **gerçek `--headless`** ile çalıştırıyor: xvfb yok,
OpenGL yok, kare alma yok, `await` yok. `RABLE_TEST_LEVEL=hizli` ortam
değişkeni `_setup_screenshot`'ta erken dallanıp `_run_fast_tests()`
çağırıyor ve çıkıyor.

**Kapsam bilinçli olarak dar.** Kazı/su/tarım/UI testleri kare alma ve
`await` ile iç içe yazılmış; onları ayırmak testlerin kendisini yeniden
yazmak demekti ve bu turun kapsamı değildi. Ağır katmanda kaldılar.

**Hızlı katman kırmızı yanıyor.** Önceki kurulumda her şey `|| true` ile
yutuluyordu; GDScript parse hatası olunca oyun sessizce hiç çalışmıyor ve
CI yine de yeşil görünüyordu — bu tuzağa bu projede dört kez düşüldü.
Artık `Parse Error` / `SCRIPT ERROR` görülürse ya da `FASTTESTS: bitti`
satırı basılmazsa iş **başarısız** oluyor.

---

## 4. Path filtresi

Her iki iş de yalnız işi ilgilendiren dosyalar değiştiğinde koşuyor:

```yaml
paths: ["scripts/**", "assets/**", "project.godot", "*.tscn"]
```

`docs/**` ve `*.md` değişiklikleri (rapor/DURUM güncellemeleri, CI'nın
kendi ekran görüntüsü commit'leri) artık hiçbir koşu tetiklemiyor. Bu
aynı zamanda **sonsuz döngüyü** de kapatıyor: `screenshot.yml`
`docs/screens`'e commit atıyor, o commit yeni bir koşu tetikleyebilirdi.

---

## 5. Görsel testlerde çözünürlük

1280×720 → **960×540** (`--resolution 960x540`). İşlenen piksel %44
azaldı.

**Önemli ayrıntı:** xvfb ekran boyutunu küçültmek tek başına hiçbir şey
kazandırmaz — kare `get_viewport().get_texture()`'dan alınıyor, ekran
boyutundan değil. Godot `project.godot`'taki 1280×720 viewport'u küçük
ekranda da aynen oluştururdu. Kazanç `--resolution` ile geliyor; xvfb
ekranı sadece ona uydurulmuş durumda.

Kareler piksel karşılaştırması için değil, **görsel karar** için
bakılıyor; 960×540 bunun için yeterli. Bir maliyeti var ve açıkça
yazıyorum: ince ayrıntı (derz gölgesi, doku bandı) incelemek biraz
zorlaşıyor. Gerekirse tek bir koşuda `--resolution` elle yükseltilebilir.

---

## 6. Önce / sonra

| Senaryo | Önce | Sonra |
|---|---:|---:|
| Yalnız `scripts/**` değişti, push | 8–11 dk (tam akış) | **~30 sn** (hızlı katman, import önbellekli) |
| Yalnız `docs/**` / `*.md` değişti | 8–11 dk | **0** (koşu tetiklenmiyor) |
| PR / elle tam doğrulama, asset değişmemiş | 8–11 dk | **~4–6 dk** (import ~180 sn düştü + %44 daha az piksel) |
| Asset eklendi, tam doğrulama | 8–11 dk | **~6–8 dk** (kısmi içe aktarma) |

Gündelik döngüde (kod değiştir → push → gör) beklenen kazanç en büyüğü:
her seferinde 8+ dakika yerine yarım dakika.

---

## 7. Ölçülmemiş / açık kalan

- **Sonuç rakamları tahmini değil, ölçülmüş temele dayanıyor** ama
  önbelleğin ilk isabetli koşusu bu rapor yazılırken henüz oluşmadı
  (önbellek ancak bir koşu onu doldurduktan sonra işe yarar). İlk
  push'tan sonraki ikinci koşu gerçek rakamı verecek.
- **Oyunu çalıştır adımı hâlâ ağır katmanın tavanı.** Asıl kazanç
  oradan gelir ama bunun için testlerin kare almadan koşabilecek şekilde
  yeniden yazılması gerekiyor (yukarıdaki kapsam notu). Ayrı bir iş.
- Godot ikili dosyası her koşuda indiriliyor (2 sn) — önbelleğe almaya
  değmez.
