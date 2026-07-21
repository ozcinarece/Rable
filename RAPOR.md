# ALET SİSTEMİ (Bölüm 12) — Uygulama Raporu

Otonom mod. Branch: `alet-sistemi`. Kaynak doküman: `ALET_SISTEMI.md`.

---

## Adım 0 — Keşif bulguları

**Eldeki alet akışı:** `world3d._held_item` (canlı Türkçe id'ler: balta,
kazma, kurek, mizrak, toprak, kova, kova_dolu). 3D model
`world3d.TOOL_MODELS` → `player3d.set_held_tool()` ile takılıyor.

**Alet bağlantı noktası:** `player3d._tool_attach` — her kare el kemiğine
yapışan ölçek-1 ayna node (`_sync_attach_mirrors`). Alet modeli bunun
çocuğu. → Prosedürel animasyon için araya **ToolPivot** node ekledim;
tween'ler pivot'u döndürür, ayna eli takip etmeye devam eder.

**Etkileşim iki kapıdan geçiyor:** `_on_world_tapped` (hücreye dokunma) ve
`_on_action_pressed` (ana buton, baktığı yönde hasat). İkisi de korundu.

**Nesne canı zaten vardı:** `_object_hits` + `OBJECT_DEFS.hits` (ağaç 3,
kaya 4) + alet bonusu. 12.4 balta/kazma "can" mantığının çoğu mevcuttu;
üstüne animasyon + strike-anı-etki + partikül sarıldı.

**Nesneler MultiMesh ile toplu çiziliyor** (`_rebuild_objects`). Tek bir
örneği titretmek (12.6 hedef tepkisi) pratik değil → vuruş tepkisi için
o hücreye kısa ömürlü partikül + geçici proxy mesh kullandım.

**İki item sistemi var:** canlı oyun `items.gd`/`recipes.gd` (Türkçe);
`item_db.gd` GDD veri katmanı (İngilizce). Üretim menüsü canlı sistemi
kullanıyor → tüm yeni item/tarif canlı id'lerle eklendi.

**Hareket yavaşlatma kancası:** `player.water_factor` (su için) varken
aynı desende `player.action_factor` eklendi (eylem sırasında ×0.6).

## Kararlar (muhafazakâr; gerekçeli)

- **KARAR:** Kukla tarifi `4 odun + 2 ip` (doküman "4 wood + 2 fiber";
  canlı sistemde lif yok, en yakın bağlayıcı ip). Yeni item açmadım.
- **KARAR:** Yeni aletler/silahlar (bicak, cekic, sopa, kilic, yay,
  sapan, ok, mizrak zaten var) canlı `items.gd`+`recipes.gd`'ye eklendi;
  3D modelleri gömülü karakter silah havuzundan / basit prosedürel mesh.
- **KARAR:** Alet eylemleri artık tek merkezden (`_perform_tool_action`)
  geçiyor; hem tap hem ana buton buraya bağlanıyor. Kazı/kova/hasat
  davranışı AYNI, sadece "strike anında çağrılıyor" biçiminde sarmalandı.
- **KARAR:** Hedef vurgusu tek bir paylaşılan halka mesh; her kare
  hedefe taşınır (yeni node spam'i yok — mobil).
- **KARAR:** Ses dosyası yok → ses kancaları isim taşıyor ama dosya
  yoksa sessiz geçiliyor (hata yok).

*(Aşama raporları ve test senaryosu dosyanın sonunda — iş ilerledikçe
dolduruluyor.)*
