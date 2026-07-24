extends RefCounted
## TEST MODU — tum fonksiyonlari denemek icin gecici kolaylik anahtari.
##
## ACIK oldugunda:
##   - Envanter kapasitesi pratikte SINIRSIZ (SLOTS slot, STACK yigin)
##   - Baslangicta katalogdaki TUM esyalar ve aletler verilir
##   - TUM arastirma dugumleri acik gelir (hicbir tarif kilitli degil)
##
## KAPATMAK icin tek satir yeter: ENABLED = false. Kapatinca oyun normal
## dengesine doner (16 slot + canta, 50'lik yiginlar, balta/kazma/kurek
## baslangic seti, arastirma agaci kilitli).
##
## NOT: bu mod DENGE.md'deki sayilari degistirmez; yalnizca oyuncunun neye
## sahip oldugunu ve kac slot gordugunu etkiler.
const ENABLED: bool = true

## Test modunda gorunen slot sayisi (katalogda 58 esya var; hepsi sigar
## ve toplamaya bol yer kalir).
const SLOTS: int = 96

## Test modunda yigin siniri (normalde 50).
const STACK: int = 9999

## Alet/silah/giyilebilir gibi TEK adet anlamli olan esyalar; kalan her sey
## ADET kadar verilir.
const SINGLE_ITEMS: Array[String] = [
	"balta", "kazma", "kurek", "capa", "sulama_kabi", "kova", "metal_kova",
	"bicak", "cekic", "sopa", "kilic", "yay", "sapan", "mizrak",
	"zirh", "sapka", "kukla",
]

## Yiginlanabilir esyalardan kac adet verilsin.
const AMOUNT: int = 99

## Canta sayisi (normal modda slot acar; test modunda zaten sinirsiz).
const BAGS: int = 2
