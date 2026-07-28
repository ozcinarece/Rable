# RAPOR — AĞAÇ KESİM SAHNESİ (branch: agac-kesim)

Önceki davranış: son vuruşta ağaç ANINDA yok oluyordu (partikül +
vuruş durması). Artık tatmin edici kesim sahnesi var. Tüm sayılar
`fell_balance.gd`'de.

## 1. DEVRİLME

- Son baltada ağaç MultiMesh'ten silinir (hücre ve çarpışma ANINDA
  açılır — altından yürünür, takılma yok) ve aynı yerde TEKİL
  animasyonlu kopya doğar (aynı mesh + aynı hücre-hash duruşu; geçiş
  görünmez).
- Yön: oyuncu→ağaç vektörü — ağaç OYUNCUDAN UZAĞA yatar.
- Zincir: 0.2 sn kararsızlık salınımı (önce hafif geri) → 1.2 sn
  ease-in devrilme (yavaş başlar, çarparken hızlanır; 88° — zemine
  oturmuş dursun) → çarpma → 0.6 sn bekleme → 0.7 sn erime.
- Çarpma anı: gövde hattı boyunca 3 noktada toprak tozu + taçta
  yaprak savrulması + ÇOK KISA ekran sarsıntısı (kamera v_offset —
  konum takibinden bağımsız; Düşük kalitede tamamen kapalı) +
  "thud" ses kancası.
- Erime: yüzey materyalleri yalnız bu kopya için kopyalanıp alpha
  fade + hafif küçülme + zemine gömülme. (Paylaşımlı MultiMesh
  materyaline dokunulmaz.)

## 2. ODUN DÜŞÜMÜ

- Erime anında odunlar GÖVDE HATTINA dizilir: 2-4 yığın (odun 3 →
  3 yığın; tek noktaya yığılmaz), pop-in zıplamasıyla düşer.
- Yerdeki odun görseli artık `wood_log.glb` (rastgele Y dönüşü);
  2+ odunlu yığında %30 `wood_log_pair.glb` — DOSYA-BEKLER (yoksa
  tek log). Yaprak vb. düşüşler taç hücresine.
- Toplama mevcut ground_item sistemiyle (yaklaş + al) — FELLTEST
  gerçek `_try_pickup_ground` çağrısıyla doğrular.

## 3. YENİ AĞAÇ SETİ

Kullanıcının yüklediği modeller esas set (veride):
pinetree_new (45) + polytree_new (35) + eski pinetree (20).
TREETEST'in 60/40 sabit karışım kontrolü VERİDEN türetilir oldu
(pay hedef ağırlığın ±10 puanı; set değişince test kendini uyarlar).

## 4. DOĞRULAMA

- FELLTEST (hızlı CI): `devrildi=true acik=true hat=true odun=3
  toplandi=true eszamanli=5` — 5 ağaç aynı anda devrildi (kuyruk
  yok kanıtı); hücre devrilme ANINDA yürünebilir.
- Ağır CI kare dizisi: sallanma → devrilme ortası → toz → odunlar
  (video/gif CI hattında yok — kare dizisi; telefonda akışkan).
- Kesim yarıda kalırsa (vuruş sayısı dolmadan) mevcut sallanma/hasar
  tepkisi aynen durur — devrilme yalnız SON vuruşta.

## BORÇLAR

- wood_log_pair.glb kancası (dosya gelince %30 varyant canlanır).
- thud ses dosyası (kanca hazır, ses paketi işi).
- Devrilen gövdenin çarptığı yerde küçük ot yatması (cila fikri).
