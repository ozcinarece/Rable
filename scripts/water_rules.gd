extends RefCounted
## SU MODELI VERILERI (KAZI_SU_MODULU.md 11.2).
## Denge ayarlari TEK bu dosyadan yapilir - kod dokunmadan degisir.

## Bir dolu kovanin tasidigi su: 1 birim = 1 hucrede 1 seviye su.
## (Hucre hacmi birimi "seviye x hucre": derinlik 2 cukur 2 birim alir.)
const BUCKET_UNITS := 1.0

## Yuzulebilirlik esigi (11.2 hazirlik): su sutunu, hucre derinliginin
## en az bu orani kadarsa hucre "yuzulur" sayilir.
const SWIM_MIN_RATIO := 0.5

## Suda hareket carpani. Simdilik yalniz oyuncuya uygulanir;
## yaratik davranisi (tirmanamama vb.) 11.6 ile gelecek.
const SWIM_SPEED_FACTOR := 0.7
