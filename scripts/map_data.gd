extends RefCounted
## El yapimi ASCII harita verisi.
## Her karakter bir tile'a karsilik gelir:
##   .  cim     (yurunebilir)
##   d  toprak  (yurunebilir)
##   s  kum     (yurunebilir)
##   ~  su      (engel)
##   #  tas     (engel - kazma ile kirilir)
##   T  agac    (engel - odun + yaprak verir)
##   m  meyve calisi (engel - meyve verir, bir sure sonra yeniden buyur)
##   P  oyuncunun baslangic noktasi (altina cim doselenir)
##
## Haritayi degistirmek icin sadece asagidaki satirlari duzenlemek yeterli.
## Tum satirlar ayni uzunlukta olmali ve haritada tam bir tane P olmali.
## Ileride prosedurel uretime gecildiginde ayni format kullanilacak:
## ureteci fonksiyon da boyle bir String dizisi dondurecek.

const MAP: Array[String] = [
	"########################################",
	"#..TTTT..............hhhhhhh...........#",
	"#.TTTTTT............hhhhhhhhh..###.....#",
	"#.TTTTT.T..........hhhhhhhhhh.#####....#",
	"#..TTT..............hhhhhhhh..######...#",
	"#...T.................hhhhh....####....#",
	"#.........mm.....................##....#",
	"#....sss...............................#",
	"#...ss~~ss.............d...............#",
	"#..ss~~~~ss............d...............#",
	"#..s~~~~~~s............d........TT.....#",
	"#..s~~~~~~ss...........d.......TTTT....#",
	"#..ss~~~~~~s.....P.....d........TT.....#",
	"#...ss~~~~ss...........d...............#",
	"#....ss~~ss............d...............#",
	"#.....ssss.............d...............#",
	"#......................d.....mm........#",
	"#......ddddddddddddddddd...............#",
	"#......d...........m...................#",
	"#......d.........TT....................#",
	"#......d........TTTT...................#",
	"#......d.........TT....................#",
	"#......d...............................#",
	"#......d.....................sss.......#",
	"#............................s~ss......#",
	"########################################",
]
