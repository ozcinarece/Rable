extends RefCounted
## ACILIS SAHNESI VERISI (acilis-sahnesi) — Gun 0 + Gun 1 akisinin TUM
## sureleri, metinleri ve garantileri. Metinler gorevden BIREBIR.

# --- MOD SECIMI --------------------------------------------------------
## Debug build: varsayilan HIZLI BASLAT (acilis atlanir — gelistirici
## girisi kurali). Release: acilis varsayilan. "--acilis" argumani ya da
## ayarlar > gelistirici > "Acilisi oynat" sinematigi zorlar.
const DEBUG_HIZLI_BASLAT := true
const ARGUMAN := "--acilis"

# --- GUN 0 -------------------------------------------------------------
const G0_ETIKET := "Gün 0"
const G0_ETIKET_SN := 2.0        # siyah ekranda yazi suresi
const G0_FADEIN_SN := 2.0        # geceye yavas acilma
const G0_BALON := "Neredeyim?"
const G0_BALON_SN := 3.0
const G0_TODO := "🔥 Ocağı yak"
const G0_DOKUNUS_BEKLE_SN := 1.0 # dokunus -> alev arasi duraklama
const G0_AYDINLANMA_SN := 3.0    # ortamin yavas aydinlanmasi
const G0_FISILTI := "…geldin."
const G0_FISILTI_SN := 4.0
const G0_TIK_SONRASI_SN := 2.0   # ✓ animasyonu -> siyah ekran

# --- GUN 1 -------------------------------------------------------------
const G1_ETIKET := "Gün 1"
const G1_ACLIK_GECIKME_SN := 5.0   # uyanis -> gurultu + bar dogumu
const G1_ACLIK_BASLANGIC := 60.0   # ac ama olmuyor (%)
const G1_TODO_YIYECEK := "🫐 Yiyecek bul (%d/3)"
const G1_YIYECEK_HEDEF := 3
const G1_TODO_ARASTIR := "🔍 Kampı araştır"
const G1_TODO_BALTA := "🪓 Balta yap"
const G1_TODO_SON := "Artık hazırsın."
const G1_SON_SN := 3.0
## Not defteri paneli metni (gorevden birebir)
const G1_DEFTER_METIN := ("Sayfaların çoğu yanmış. Arka kapakta aceleyle "
		+ "çizilmiş iki tarif: Balta (2 dal, 1 taş, 1 ip) — "
		+ "Kazma (2 dal, 2 taş).")
## Defterle acilan tarifler (arastirmasiz)
const DEFTER_TARIFLER := ["balta", "kazma"]

# --- SPAWN GARANTILERI (yalniz sinematik yeni oyunda) -------------------
const G_BERRY_ADET := 5          # kamp cevresi yabani berry calisi (4-5)
const G_BERRY_YARICAP := 7       # kac hucre icinde
const G_DAL_ADET := 4            # yerde dal (cubuk) — 3-4 garanti
const G_TAS_ADET := 3            # yerde tas — 2-3 garanti
const G_IP_ADET := 1             # yikik kulube onunde 1 ip
const G_YER_YARICAP := 5

# --- BAR DOGUMLARI ------------------------------------------------------
const BAR_KAYMA_SN := 0.5        # soldan kayma animasyonu
const BAR_NABIZ_SN := 1.2        # dogumda hafif nabiz
const SUSUZLUK_DOGUM_ESIK := 50.0  # damla bari ilk bu esigin altinda dogar

# --- DEBUG HIZLI BASLAT DURUMU -----------------------------------------
const HIZLI_ACLIK := 80.0        # hizli baslatta aclik %80

# --- FISILTI/G-01 -------------------------------------------------------
## G-01 hikaye kaydi: panel sonraki gorevde — simdilik bayrak.
const G01_BAYRAK := "g01_geldin"

# --- SLICETEST ----------------------------------------------------------
## Testte tum bekleme sureleri bu carpanla kisalir (await'ler veriden).
const TEST_SURE_CARPAN := 0.02
