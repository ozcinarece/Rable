# RAPOR — Karakter Ölçek + Balta Kavrama

Branch: `karakter-duzelt`. Amaç: Meshy skinned karakteri doğru boya getirmek
ve baltayı elde (sapından) görünür kılmak.

## Sorun
`character_animated_2.glb` (Meshy) **Armature node'u 0.01 ölçekli** geliyor →
skinned mesh native ~0.017 m render oluyor. Ayrıca balta el kemiğine takılırken
görünmez kalıyordu.

## Denenen "doğru" yöntem (bu ortamda ÇALIŞMADI)
- **GLB import Root Scale** (`.import` → `apply_root_scale` + `root_scale`):
  Headless CI, el-yapımı `.import`'u tanımadı (geçersiz `uid` → Godot varsayılanla
  yeniden üretti) → karakter görünmez kaldı.
- **GLB'ye armature ölçek gömme** (Python ile node scale 0.01→0.8): Godot,
  import'ta iskeleti yeniden "bake" ettiği için node-scale değişimi skinning'e
  yansımadı → yine görünmez.
- Sonuç: Blender olmadan, bu CI'da import-zamanı ölçek güvenilir değil.

## Uygulanan çözüm (çalışıyor)
1. **Ölçek** — kod tarafı: `_visual_aabb` ile kaba ölçek + bir kare sonra
   **kemik-pozundan kesin ölçek** (`_fix_skinned_scale`). Skinned + Armature 0.01
   için bu ŞART (yoksa görünmez). Karakter → ~1.35 m.
2. **Balta görünürlüğü** — asıl bug: `s = 0.5/(size × _node_world_scale(el))`
   telafisi skinned el kemiğinde baltayı minik yapıyordu. **`TOOL_HOLD.scale`**
   ile sabit ölçek kullanılınca (`_node_world_scale` telafisi atlanır) balta
   görünür oldu.
3. **Kavrama** — veri tabanlı `TOOL_HOLD` (elle ayarlanır, oto-tahmin yok):

```gdscript
const TOOL_HOLD := {
    "balta": {"axis": 1, "grip": 0.15, "scale": 0.6,
              "rot_deg": Vector3(0,0,0), "extra": Vector3(0,0,0)},
}
```
   - `axis` 1 = baltanın uzun ekseni (Y; ölçüldü).
   - `grip` 0→1 = elin balta üzerindeki tutuş noktası (0=Y min, 1=Y max).
   - `scale` = sabit balta boyu (m); `_node_world_scale` telafisini atlar.
   - `rot_deg` / `extra` = elde döndürme + ince kaydırma.
   Bu 4 sayı render'a/canlıya bakıp ayarlanır (kullanıcı yön verir).

## Yeni Meshy modeli için referans
- Skinned Meshy modeller Armature 0.01 ile gelir → kod ölçeği (`_fix_skinned_
  scale`) devrede kalmalı. Alet için `TOOL_HOLD.scale` ile sabit ölçek kullan.
- İdeal (ileride Blender olursa): GLB'de **Apply All Transforms** → Armature 1.0,
  boy ~1.7 m; o zaman kod ölçeği ve sabit-ölçek hilesi gerekmez.

## Balta duruşu — ÇÖZÜLDÜ (el kemiği yöneliminden hesap)
Sorun: balta el kemiğinin yönelimini miras alıyordu → **yatay, öne doğru**
duruyordu (sap gövdeye gömülü). Built-in aletler kısa olduğu için sorun
olmuyordu; uzun balta yatayken kötü görünüyordu.

Çözüm (oto-tahmin yerine ÖLÇÜM):
1. `player3d.debug_hand_orientation()` — el kemiğinin eksenlerini karakter
   gövde çerçevesinde `docs/screens/handdbg.txt`'e yazar (yalnız screenshot).
2. O veriden, baltanın **uzun ekseni (yerel +Y = kafa) gövde-yukarı**, bıçak
   öne gelecek `rot_deg` hesaplandı:
   `rot_deg = Vector3(11.2, 60.4, -125.4)` (Euler YXZ, Godot varsayılanı).
3. `grip = 0.12` → el sapın en dibinde. Sonuç: **bıçak yukarı, sap aşağı,
   el sapın altında** (kullanıcı seçimi "A").

**Yeni GLB alet eklerken:** aleti dik/sap-aşağı ver; screenshot'ta
`handdbg.txt` zaten el eksenini verir → aynı formülle `rot_deg` hesaplanır.

## Bilinen / açık
- Balta boşta (idle) hafif dışa yatık görünebilir — idle pozunun el açısı;
  yürürken kol zaten sallanır. `scale`/`rot_deg` istenirse ince ayarlanır.
- Karakterin "kırmızı yuvarlak kafa" görünümü modelin tasarımı (Meshy avatarı);
  teknik değil.
