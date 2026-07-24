extends RefCounted
## Esya kayit defteri: her esyanin gorunen adi ve ikonu.
## Yeni bir esya eklemek icin buraya bir satir ekle ve
## assets/items/ altina 32x32 bir ikon koy (yapilar tile gorselini kullanir).

const ITEMS: Dictionary = {
	"odun": {"name": "Odun", "icon": "res://assets/items/odun.png"},
	"yaprak": {"name": "Yaprak", "icon": "res://assets/items/yaprak.png"},
	"kalas": {"name": "Kalas", "icon": "res://assets/items/kalas.png"},
	"cubuk": {"name": "Çubuk", "icon": "res://assets/items/cubuk.png"},
	"ip": {"name": "İp", "icon": "res://assets/items/ip.png"},
	"tas": {"name": "Taş", "icon": "res://assets/items/tas.png"},
	# Kullanici render'i (tools_2d/axe_png.png'den kirpilip 256'ya indirildi)
	"balta": {"name": "Balta", "icon": "res://assets/items/balta_render.png"},
	"kazma": {"name": "Kazma", "icon": "res://assets/items/kazma_render.png"},
	"meyve": {"name": "Meyve", "icon": "res://assets/items/meyve.png"},
	"komur": {"name": "Kömür", "icon": "res://assets/items/komur.png"},
	"altin": {"name": "Altın", "icon": "res://assets/items/altin.png"},
	"cicek": {"name": "Çiçek", "icon": "res://assets/items/cicek.png"},
	"mantar": {"name": "Mantar", "icon": "res://assets/items/mantar.png"},
	"kurek": {"name": "Kürek", "icon": "res://assets/items/kurek_render.png"},
	"kova": {"name": "Kova", "icon": "res://assets/items/kova.png"},
	"kova_dolu": {"name": "Dolu Kova", "icon": "res://assets/items/kova_dolu.png"},
	"bicak": {"name": "Bıçak", "icon": "res://assets/items/bicak.png"},
	"cekic": {"name": "Çekiç", "icon": "res://assets/items/cekic.png"},
	"sopa": {"name": "Sopa", "icon": "res://assets/items/sopa.png"},
	"kilic": {"name": "Kılıç", "icon": "res://assets/items/kilic.png"},
	"yay": {"name": "Yay", "icon": "res://assets/items/yay.png"},
	"sapan": {"name": "Sapan", "icon": "res://assets/items/sapan.png"},
	"ok": {"name": "Ok", "icon": "res://assets/items/ok.png"},
	"cakil": {"name": "Çakıl", "icon": "res://assets/items/cakil.png"},
	"kukla": {"name": "Kukla", "icon": "res://assets/items/kukla.png"},
	"toprak": {"name": "Toprak", "icon": "res://assets/items/toprak.png"},
	"kil": {"name": "Kil", "icon": "res://assets/items/kil.png"},
	"bakir": {"name": "Bakır Cevheri", "icon": "res://assets/items/bakir.png"},
	"kum": {"name": "Kum", "icon": "res://assets/items/kum.png"},
	"canta": {"name": "Çanta", "icon": "res://assets/items/canta.png"},
	"mizrak": {"name": "Mızrak", "icon": "res://assets/items/mizrak.png"},
	"zirh": {"name": "Zırh", "icon": "res://assets/items/zirh.png"},
	"sapka": {"name": "Şapka", "icon": "res://assets/items/sapka.png"},
	"tohum": {"name": "Tohum", "icon": "res://assets/items/tohum.png"},
	# TARIM (tarim-3d): ikon PNG yuklenince baglanir (balta akisi gibi);
	# simdilik 2 harf placeholder kurali devrede.
	"capa": {"name": "Çapa", "icon": "res://assets/items/capa.png"},
	"sulama_kabi": {"name": "Sulama Kabı", "icon": "res://assets/items/sulama_kabi.png"},
	# Yapilar: uretilir, envanterde tasinir, elde tutulup yere konur
	"ahsap_duvar": {"name": "Ahşap Duvar", "icon": "res://assets/tiles/wood_wall.png"},
	"tas_duvar": {"name": "Taş Duvar", "icon": "res://assets/tiles/stone_wall.png"},
	"tezgah": {"name": "Tezgah", "icon": "res://assets/items/tezgah_render.png"},
	"arastirma_masasi": {"name": "Araştırma Masası", "icon": "res://assets/items/arastirma_masasi.png"},
	"kamp_evi": {"name": "Kamp Evi", "icon": "res://assets/tiles/ev.png"},
	"sandik": {"name": "Sandık", "icon": "res://assets/tiles/sandik.png"},
	"zemin": {"name": "Zemin", "icon": "res://assets/tiles/zemin.png"},
	"kapi": {"name": "Kapı", "icon": "res://assets/tiles/kapi.png"},
	"mesale": {"name": "Meşale", "icon": "res://assets/items/mesale.png"},
	"yatak": {"name": "Yatak", "icon": "res://assets/tiles/yatak.png"},
	"tuzak": {"name": "Tuzak", "icon": "res://assets/tiles/tuzak.png"},
	# BASE (Bolum 14)
	"ocak": {"name": "Ocak", "icon": "res://assets/items/ocak.png"},
	"platform": {"name": "Savunma Platformu", "icon": "res://assets/items/platform.png"},
	# YASAM (yiyecek): cig_et hayvandan (yaratik fazi), pismis_et ocakta pisirilir
	"cig_et": {"name": "Çiğ Et", "icon": "res://assets/items/cig_et.png"},
	"pismis_et": {"name": "Pişmiş Et", "icon": "res://assets/items/pismis_et.png"},
	# MUHENDISLIK (Bolum 11.5/11.8/11.9): merdiven, kazik, boru/pompa/vana
	"merdiven": {"name": "Merdiven", "icon": "res://assets/items/merdiven.png"},
	"kazik": {"name": "Çukur Kazığı", "icon": "res://assets/items/kazik.png"},
	"boru": {"name": "Boru", "icon": "res://assets/items/boru.png"},
	"pompa": {"name": "Pompa", "icon": "res://assets/items/pompa.png"},
	"vana": {"name": "Vana", "icon": "res://assets/items/vana.png"},
	"metal_kova": {"name": "Metal Kova", "icon": "res://assets/items/metal_kova.png"},
	# YARATIK (Bolum 15): oz = olen yaratigin dusurdugu ozut
	"oz": {"name": "Öz", "icon": "res://assets/items/oz.png"},
}

## Elde tutulunca yere yerlestirilebilen yapilar: esya -> harita karakteri.
## (world.gd OBJECT_DEFS/GROUND_DEFS'te tanimli; "f" bir zemin turudur)
const PLACEABLE: Dictionary = {
	"ahsap_duvar": "W",
	"tas_duvar": "K",
	"tezgah": "B",
	"arastirma_masasi": "R",
	"kamp_evi": "E",
	"sandik": "S",
	"kapi": "D",
	"mesale": "L",
	"yatak": "Y",
	"tuzak": "Z",
	"zemin": "f",
	# BASE (Bolum 14): 3D yerlestirme PLACE_MODELS'ten gecer; buradaki kayit
	# yalniz "Yerleştir" butonunu gosterir (2D world.gd legacy, ana sahne degil).
	"ocak": "O",
	"platform": "P",
	# MUHENDISLIK: cukur ici/kenari yapilari (3D PLACE_MODELS'ten gecer)
	"merdiven": "M",
	"kazik": "X",
	"boru": "I",
	"pompa": "U",
	"vana": "V",
}

## Ele alinabilen esyalar - artik her esya ele alinabilir; bu liste
## alet bonusu olanlari isaretler (bilgi amacli)
const HOLDABLE: Array[String] = ["balta", "kazma", "kurek", "mizrak",
	"bicak", "cekic", "sopa", "kilic", "yay", "sapan", "kova", "kova_dolu"]

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
	"komur": "Komurlu kayadan cikar; ileride yakit olacak.",
	"altin": "Altinli kayadan cikar; degerli maden.",
	"cicek": "Cimlerden toplanir; ileride boya/sus yapiminda.",
	"mantar": "Yenir: +15 aclik.",
	"kurek": "Eline al: zemine dokununca kazar.",
	"kova": "Eline al: golden ya da havuzdan su doldur.",
	"kova_dolu": "Eline al: kazilmis cukura dokununca su doker.",
	"bicak": "Eline al: caliyi/bitkiyi hizli hasat eder (2x lif).",
	"cekic": "Eline al: yapiya vurunca soker (malzeme geri gelir).",
	"sopa": "Basit yakin dovus silahi: 12 hasar.",
	"kilic": "Yakin dovus: 18 hasar, pes pese basista 2'li kombo.",
	"yay": "Saldiri butonunu basili tut: gerdir, birak ok atar.",
	"sapan": "Saldiri butonunu basili tut: cakil firlatir.",
	"ok": "Yay muhimmati.",
	"cakil": "Sapan muhimmati.",
	"kukla": "Egitim kuklasi: silahlari uzerinde dene.",
	"toprak": "Eline al: cukuru doldurur ya da zemini yukseltir (en fazla +2).",
	"kil": "Sig kazidan cikar; firin cagi tugla/comlek malzemesi.",
	"bakir": "Derin kaya katmanindan cikar; demir cagina giden ilk maden.",
	"kum": "Ileride ise yarayacak...",
	"canta": "+4 envanter slotu (en fazla 2).",
	"mizrak": "Eline al: yaratiklara 30 hasar (yumruk 10).",
	"zirh": "Envanterdeyken hasari %40 azaltir.",
	"sapka": "Envanterdeyken hasari %15 azaltir.",
	"tohum": "Eline al: toprak zemine dokununca ekilir.",
	"ahsap_duvar": "Eline al ve yere koy: engel/savunma.",
	"tas_duvar": "Eline al ve yere koy: saglam engel.",
	"tezgah": "Yaninda karmasik tarifler acilir.",
	"arastirma_masasi": "Yaninda arastirma agaci acilir; dugumler burada satin alinir.",
	"kamp_evi": "Yeniden dogma noktasi.",
	"sandik": "Sinirsiz depolama; dokununca acilir.",
	"zemin": "Ev tabani; yurunebilir doseme.",
	"kapi": "Sen gecersin, yaratiklar gecemez. Dokununca acilir/kapanir.",
	"mesale": "Eline al ve yere koy: cevreyi sicak isikla aydinlatir.",
	"yatak": "Gece uyu: sabah olur (+30 can).",
	"tuzak": "Ustunden gecen yaratik hasar alir.",
	"merdiven": "Eline al: kazilmis cukura koy. Derin cukurdan (3-4) ancak merdivenle cikilir.",
	"kazik": "Eline al: kazilmis cukurun tabanina koy. Dusen hasar alir.",
	"oz": "Olen yaratigin ozutu; ileride yukseltme/ticaret malzemesi.",
	"boru": "Eline al ve yere/cukura koy: komsu borularla baglanir, su tasir (asagi/ayni seviye).",
	"pompa": "Boru hattina koy: suyu YUKARI tasir (yukseklik kuralini asar).",
	"vana": "Boru hattina koy: dokununca AC/KAPA. Kapaliyken o hattan su akmaz.",
	"metal_kova": "Metal kova: su tasir (ileride sicak sivi da).",
}

## ENVANTER-MOCKUP "flavor" alani: bilgi seridindeki TEK SATIR kisilikli
## metin (kisa, oyunun sesiyle; kuru veri degil). Mockup'taki metinler
## baslangic seti; kalanlar ayni seste yazildi. Sayilar oyun degerleriyle
## dogrulandi (FOOD_SATIATION, hasar/koruma tablolari). description()
## ONCE buraya bakar; olmayan id eski DESCRIPTIONS'a duser.
const FLAVOR: Dictionary = {
	# --- kaynaklar
	"odun": "Her şeyin başı. Yapı, alet, yakıt.",
	"yaprak": "3 yaprak = 1 ip. Bıçakla 2 kat verim.",
	"kalas": "Odunun terbiye görmüş hali. İnşaatın bel kemiği.",
	"cubuk": "İnce ama vazgeçilmez — her sapın içinde bir çubuk var.",
	"ip": "Bağla, ger, sık. Dağılmasın diye.",
	"tas": "Sağlam duvarların hammaddesi.",
	"cakil": "Sapanın dişleri. Cebinde şıngırdar.",
	"toprak": "Çukur doldurur, zemin yükseltir (en fazla +2).",
	"kil": "Sığ kazının armağanı. Fırın çağının kapısı.",
	"kum": "Şimdilik sadece kum. Ama camı hayal et...",
	"bakir": "Derinlerin ilk parıltısı. Demir çağına giden yol.",
	"komur": "Kara elmas. Ateşi uzun tutar.",
	"altin": "Parlar ama karın doyurmaz. Şimdilik.",
	"cicek": "Güzel diye topladın, değil mi? Olsun.",
	# --- yiyecek / tarim
	"meyve": "Atıştırmalık — doygunluk +12.",
	"mantar": "Şüpheli görünüyor ama iş görür — doygunluk +10.",
	"cig_et": "Pişir. Cidden, pişir (%20 mide bulantısı).",
	"pismis_et": "Ocakta pişti. Tok tutar — doygunluk +40.",
	"tohum": "Çapalı tarlaya ek, sula. Sabrın meyvesi.",
	"capa": "Toprağı tarlaya çevirir. Hasadın ilk adımı.",
	"sulama_kabi": "4 kullanımlık depo. Gölden doldur, tarlana boşalt.",
	# --- aletler
	"balta": "Ağaçların korkulu rüyası. Tek vuruş, tek ağaç.",
	"kazma": "Kayaya inat, iki vuruşta yol açar.",
	"kurek": "Toprağa dokun, çukur olsun.",
	"bicak": "Hassas işlerin aleti — bitkiden 2 kat lif.",
	"cekic": "Yanlış yaptıysan geri söker. Malzeme ziyan olmaz.",
	"kova": "Boş kova. Göle uzat, dolsun.",
	"kova_dolu": "1 birim su taşıyor. Çukura dök.",
	"metal_kova": "Ahşabın taşıyamadığını taşır. Sıcak işler için.",
	# --- silahlar
	"sopa": "İlk savunma hattı. Basit ama elin boş değil (12 hasar).",
	"kilic": "18 hasar; peş peşe bas — ikinci kesik daha çabuk.",
	"mizrak": "Mesafeni koru: 30 hasar, uzun erişim.",
	"yay": "Basılı tut, ger, bırak. Ok uçar.",
	"sapan": "Çakıl fırlatır. Gürültüsüz, masrafsız.",
	"ok": "Yaysız işe yaramaz. Yayla ölümcül.",
	"zirh": "Sırtında dursun yeter — hasarı %40 keser.",
	"sapka": "Şıklık + %15 koruma. İkisi bir arada.",
	"kukla": "Vur, kırılmaz. Alışman için burada.",
	# --- yapilar / istasyonlar
	"canta": "+4 slot. Sırtın genişledi (en fazla 2).",
	"ahsap_duvar": "Dört duvar bir yuva. Savunmanın ilk adımı.",
	"tas_duvar": "Ahşap dayanmazsa taş konuşur.",
	"kapi": "Sen geçersin, onlar geçemez.",
	"zemin": "Ev hissi ayaktan başlar.",
	"tezgah": "Yanındayken elin ustalaşır — karmaşık tarifler açılır.",
	"arastirma_masasi": "Bilginin başladığı yer. Düğümler burada çözülür.",
	"kamp_evi": "Dönülecek bir yer. Yeniden doğuş noktası.",
	"sandik": "Sırtın taşımazsa sandık taşır.",
	"mesale": "Karanlık geri çekilsin.",
	"yatak": "Uyu, sabahı getir (+30 can).",
	"tuzak": "Üstüne basanın gecesi kötü biter.",
	"ocak": "Ateş yanar, et pişer, ev ısınır.",
	"platform": "Yüksekten bakan kazanır.",
	# --- muhendislik
	"merdiven": "Derin çukurdan çıkış. Gece çekmeyi unutma.",
	"kazik": "Çukurun dibinde sivri bir sürpriz.",
	"boru": "Suyu aşağı ve yana taşır. Ağın damarı.",
	"pompa": "Suya 'yukarı' demenin tek yolu.",
	"vana": "Aç, kapa. Akışın hâkimi sensin.",
	# --- ozel
	"oz": "Geceden hasat. Gizli araştırmaların anahtarı.",
}

static func description(item_id: String) -> String:
	if FLAVOR.has(item_id):
		return String(FLAVOR[item_id])
	return DESCRIPTIONS.get(item_id, "")

static func display_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id]["name"]
	return item_id
