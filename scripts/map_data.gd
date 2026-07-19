extends RefCounted
## El yapimi ASCII harita verisi.
## Her karakter bir tile'a karsilik gelir:
##   .  cim     (yurunebilir)
##   d  toprak  (yurunebilir)
##   s  kum     (yurunebilir)
##   ~  su      (engel)
##   #  tas     (engel - ileride kazilabilir olacak)
##   T  agac    (engel - ileride odun kaynagi olacak)
##   P  oyuncunun baslangic noktasi (altina cim doselenir)
##
## Haritayi degistirmek icin sadece asagidaki satirlari duzenlemek yeterli.
## Tum satirlar ayni uzunlukta olmali ve haritada tam bir tane P olmali.
## Ileride prosedurel uretime gecildiginde ayni format kullanilacak:
## ureteci fonksiyon da boyle bir String dizisi dondurecek.

const MAP: Array[String] = [
	"########################################",
	"#..TTTT................................#",
	"#.TTTTTT.......................###.....#",
	"#.TTTTT.T.....................#####....#",
	"#..TTT........................######...#",
	"#...T..........................####....#",
	"#................................##....#",
	"#....sss...............................#",
	"#...ss~~ss.............d...............#",
	"#..ss~~~~ss............d...............#",
	"#..s~~~~~~s............d........TT.....#",
	"#..s~~~~~~ss...........d.......TTTT....#",
	"#..ss~~~~~~s.....P.....d........TT.....#",
	"#...ss~~~~ss...........d...............#",
	"#....ss~~ss............d...............#",
	"#.....ssss.............d...............#",
	"#......................d...............#",
	"#......ddddddddddddddddd...............#",
	"#......d...............................#",
	"#......d.........TT....................#",
	"#......d........TTTT...................#",
	"#......d.........TT....................#",
	"#......d...............................#",
	"#......d.....................sss.......#",
	"#............................s~ss......#",
	"########################################",
]
