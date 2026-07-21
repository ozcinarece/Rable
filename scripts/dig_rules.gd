extends RefCounted
## KAZI MODULU VERILERI (KAZI_SU_MODULU.md 11.1 + 11.3 + 11.4).
## Denge ayarlari TEK bu dosyadan yapilir - kod dokunmadan oranlar degisir.

## Bir derinlik seviyesinin metre karsiligi (gorsel)
const DEPTH_STEP := 0.30

## Toprak yigma ust siniri: duz hucre en fazla bu kadar yukselir
## (depth negatif tutulur: -2 = +2 seviye tumsek)
const MAX_RAISE := 2

## Bu derinlikten SONRASI kaya katmani: kurek islemez, kazma gerekir
## (0->1->2 kurekle toprak; 2->3->4 kazmayla kaya)
const ROCK_DEPTH := 2

## Kurek kademeleri -> kazabilecegi en derin seviye (11.1 tablosu).
## Mevcut oyunda tek kademe "kurek" (tas) var; ust kademeler alet
## kademesi sistemi gelince otomatik devreye girer.
const SHOVEL_LIMITS := {
	"kurek": 2,        # tas kurek
	"demir_kurek": 3,
	"celik_kurek": 4,
}

## Kazma kademeleri -> kayada inebilecegi en derin seviye
const PICKAXE_LIMITS := {
	"kazma": 3,        # tas kazma
	"demir_kazma": 4,
}

## Derinlige gore EK dususler (11.4). Temel dusus ayri: toprak
## katmaninda +1 toprak, kaya katmaninda +1 tas.
## Kayit: {"item": id, "chance": 0-1, "min": adet, "max": adet}
const DIG_LOOT := {
	1: [{"item": "kil", "chance": 0.30, "min": 1, "max": 1}],
	2: [{"item": "tas", "chance": 1.00, "min": 1, "max": 2}],
	3: [{"item": "komur", "chance": 0.35, "min": 1, "max": 2},
			{"item": "bakir", "chance": 0.20, "min": 1, "max": 1}],
	4: [{"item": "komur", "chance": 0.45, "min": 1, "max": 2},
			{"item": "bakir", "chance": 0.35, "min": 1, "max": 2}],
}

## Yeni derinlige inince dusen ek kaynaklar: {esya: adet}
static func roll_loot(new_depth: int) -> Dictionary:
	var out: Dictionary = {}
	for entry in DIG_LOOT.get(new_depth, []):
		if randf() <= entry["chance"]:
			var amount := randi_range(entry["min"], entry["max"])
			out[entry["item"]] = int(out.get(entry["item"], 0)) + amount
	return out
