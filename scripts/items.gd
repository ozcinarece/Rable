extends RefCounted
## Esya kayit defteri: her esyanin gorunen adi ve ikonu.
## Yeni bir esya eklemek icin buraya bir satir ekle ve
## assets/items/ altina 32x32 bir ikon koy.
##
## Buradaki sira, envanter cubugundaki gosterim sirasidir.

const ITEMS: Dictionary = {
	"odun": {"name": "Odun", "icon": "res://assets/items/odun.png"},
	"yaprak": {"name": "Yaprak", "icon": "res://assets/items/yaprak.png"},
	"kalas": {"name": "Kalas", "icon": "res://assets/items/kalas.png"},
	"cubuk": {"name": "Çubuk", "icon": "res://assets/items/cubuk.png"},
	"ip": {"name": "İp", "icon": "res://assets/items/ip.png"},
	"tas": {"name": "Taş", "icon": "res://assets/items/tas.png"},
	"balta": {"name": "Balta", "icon": "res://assets/items/balta.png"},
	"kazma": {"name": "Kazma", "icon": "res://assets/items/kazma.png"},
	"meyve": {"name": "Meyve", "icon": "res://assets/items/meyve.png"},
	"kurek": {"name": "Kürek", "icon": "res://assets/items/kurek.png"},
	"toprak": {"name": "Toprak", "icon": "res://assets/items/toprak.png"},
	"kum": {"name": "Kum", "icon": "res://assets/items/kum.png"},
	"canta": {"name": "Çanta", "icon": "res://assets/items/canta.png"},
	"mizrak": {"name": "Mızrak", "icon": "res://assets/items/mizrak.png"},
	"zirh": {"name": "Zırh", "icon": "res://assets/items/zirh.png"},
	"sapka": {"name": "Şapka", "icon": "res://assets/items/sapka.png"},
}

## Ele alinabilen esyalar (envanter panelindeki "Eline Al" butonu)
const HOLDABLE: Array[String] = ["balta", "kazma", "kurek", "mizrak"]

## Envanter panelinde gosterilen kisa aciklamalar
const DESCRIPTIONS: Dictionary = {
	"odun": "Agactan gelir; kalasa cevrilir.",
	"yaprak": "Ip yapiminda kullanilir.",
	"kalas": "Insaatin temel malzemesi.",
	"cubuk": "Alet saplarinda kullanilir.",
	"ip": "Alet ve yapi baglamada kullanilir.",
	"tas": "Saglam yapi ve alet malzemesi.",
	"balta": "Eline al: agaclar tek vurusta kesilir.",
	"kazma": "Eline al: kayalar 2 vurusta kirilir.",
	"meyve": "Yenir: +25 aclik.",
	"kurek": "Eline al: zemine dokununca kazar.",
	"toprak": "Cukurlari doldurur.",
	"kum": "Ileride ise yarayacak...",
	"canta": "+4 envanter slotu (en fazla 2).",
	"mizrak": "Eline al: yaratiklara 30 hasar (yumruk 10).",
	"zirh": "Envanterdeyken hasari %40 azaltir.",
	"sapka": "Envanterdeyken hasari %15 azaltir.",
}

static func description(item_id: String) -> String:
	return DESCRIPTIONS.get(item_id, "")

static func display_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id]["name"]
	return item_id
