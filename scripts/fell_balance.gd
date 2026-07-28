extends RefCounted
## AGAC KESIM SAHNESI VERISI (agac-kesim) — tum sayilar burada.
## Devrilme: kararsizlik sallanmasi -> hizlanan devrilme -> carpma
## (toz+yaprak+sarsinti+thud) -> kisa bekleme -> eriyerek yok olma;
## odunlar govde HATTINA sacilir.

const WOBBLE_SECONDS := 0.2    # kararsizlik sallanmasi suresi
const WOBBLE_DEG := 4.0        # sallanma genligi (derece)
const FALL_SECONDS := 1.2      # devrilme suresi (ease-in: hizlanir)
const FALL_END_DEG := 88.0     # tam 90 degil: zemine "oturmus" dursun
const LINGER_SECONDS := 0.6    # carpma -> erime baslangici
const MELT_SECONDS := 0.7      # alpha fade + hafif kuculme

## Carpma efekti
const DUST_COLOR := Color(0.62, 0.52, 0.40)   # toprak tozu
const LEAF_COLOR := Color(0.45, 0.65, 0.35)   # savrulan yapraklar
const DUST_COUNT_HIGH := 12    # kalite kademesine gore parcacik
const DUST_COUNT_LOW := 5
## Ekran sarsintisi: COK KISA; Dusuk kademede tamamen kapali
## (gorev: "mobilde kapatilabilir" — kalite kademesi anahtari).
const SHAKE_V := 0.07          # kamera v_offset genligi (m)
const SHAKE_SECONDS := 0.16

## Odun sacilimi: govde hattina LOG_MIN..LOG_MAX yigin (tek noktaya
## yigilmasin); dusen odun gorseli wood_log.glb, 2+ odunlu yiginda
## %30 wood_log_pair.glb (DOSYA-BEKLER: yoksa tek log).
const LOG_MIN := 2
const LOG_MAX := 4
const LOG_PAIR_CHANCE := 0.3
const LOG_GLB := "res://assets/models/test/wood_log.glb"
const LOG_PAIR_GLB := "res://assets/models/test/wood_log_pair.glb"
const LOG_LEN := 0.5           # yerdeki odun boyu (model X=1.0 -> olcek)
