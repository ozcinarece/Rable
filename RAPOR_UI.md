# UI REVİZYON 1 — Uygulama Raporu

Otonom mod. Branch: `ui-revizyon-1`. Kaynak: `UI_REVIZYON_1.md` (UI_DESIGN.md
üstüne). **Yalnız UI katmanı** — oyun mantığı/veri/sistem davranışı
değişmedi (yeme mantığı aynı, sadece tetik yüzeyi; "Yeni Oyun" işlevi aynı,
sadece menüye taşındı). Aşama başına bir commit; oyun her commit'te açılır.

## Aşama 1 — R0 genel kural altyapısı (commit 1)

**Teşhis → çözüm:**
- **İkon doluluk (%65):** `ui_slot.gd` ikon kenar payı 14px → **10px**
  (`ICON_INSET`), 64px slotta ikon ~44px = **%69**. "Koca daire içinde
  minik ikon" kalktı.
- **Panel açıkken karartma + HUD gizleme:** `_setup_backdrop()` bir
  `overlay_dim` (`UIColors.OVERLAY_DIM`) ColorRect ekler; `_update_backdrop()`
  herhangi bir panel (envanter/üretim/araştırma/sandık) açılınca overlay'i
  aktif panelin ALTINA + her şeyin ÜSTÜNE alır ve **oyun HUD öğelerini
  gizler** (dock butonları, hotbar, ana/taşı butonları, Gün pill'i, stat
  paneli). Böylece Gün pill'i ↔ panel başlığı çakışması da çözüldü.
  Toggle'lara ve `show_chest`/`close_chest`'e bağlandı.
- **Kilit çipi:** Kilitli slotlar tek tek çizilmiyor; envanter ızgarası
  yalnız `get_slot_count()` kadar açık slot gösteriyor, ızgara sonunda tek
  kompakt çip: **"+N slot (deri çanta ile)"** (`_build_lock_chip`,
  `_refresh`'te güncellenir). Boş kilitli daire gürültüsü gitti.
- **Kırpık etiket taraması:** Kalan kırpık etiketler (kategori sekmesi
  "Tü/Ma", araştırma "Ar") yapısal olarak Aşama 2 (dock) ve Aşama 4
  (sekmeler) ile ikon+tam-etikete dönüşecek; envanter 2-harf placeholder'ı
  UI_DESIGN'ın izinli kuralı (ikon yoksa) — korunur.

**Değişen dosyalar:** `scripts/ui_slot.gd`, `scripts/hud.gd`.
