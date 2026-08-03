// =============================================================
// SON KOR — ZEMİN ÇAYIR DOKUSU (ground_meadow.gdshader)
// Godot 4.x / spatial. Prototipte (zemin_v2.html) seçilen değerler:
// yoğunluk 0.25 / boyut 14 / kontrast 0.10 / leke 0.50, 0.11 /
// sıcak-serin 0.16
//
// ENTEGRASYON SÖZLEŞMESİ (Claude Code):
// - Zemin chunk materyaline uygulanır. Mevcut zemin türü sistemi
//   (çim/toprak/kum/tarla — vertex color ya da hangi mekanizmaysa)
//   KORUNUR: bu shader'ın benek/leke katmanları YALNIZ ÇİM bölgesinde
//   tam güçte çalışmalı. Zemin türü bilgisi vertex'ten geliyorsa
//   grass_mask olarak oku (COLOR kanallarından uygun olanı) ve
//   katmanları grass_mask ile çarp — toprak/kum/tarla beneksiz kalır
//   (ya da çok hafif: *0.2). Mekanizma farklıysa uyarla, RAPOR'a yaz.
// - night_mix: su/çim ailesiyle AYNI kaynaktan.
// - base_color mevcut çim renginden (#8CC06E) — zemin rengi başka
//   sistemden geliyorsa uniform yerine o rengi kullan, katmanları
//   üstüne uygula.
// - Dünya koordinatı bazlı (UV değil) — chunk sınırlarında dikişsiz.
// - quality 0: ince benek kapalı (yalnız leke + sıcak-serin kalır).
// =============================================================
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.549, 0.753, 0.431); // #8CC06E

// ---- İNCE BENEKLER (prototip: yoğunluk 0.25, boyut 14, kontrast 0.10) ----
uniform float speckle_density : hint_range(0.0, 1.0) = 0.25;
uniform float speckle_scale = 14.0;
uniform float speckle_amount : hint_range(0.0, 0.3) = 0.10;

// ---- İRİ LEKELER (prototip: ölçek 0.50, şiddet 0.11) ----
uniform float blotch_scale = 0.50;
uniform float blotch_amount : hint_range(0.0, 0.3) = 0.11;

// ---- SICAK-SERİN BÖLGESEL VARYASYON (prototip: 0.16) ----
uniform float warm_variation : hint_range(0.0, 0.25) = 0.16;
uniform float warm_scale = 0.06;

// ---- GECE ----
uniform float night_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint : source_color = vec3(0.30, 0.36, 0.55);

uniform int quality : hint_range(0, 1) = 1;

varying vec3 v_world;
varying float v_grass_mask;

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
    v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // ÇİM MASKESİ: zemin türü vertex color'daysa buradan oku.
    // Varsayılan: COLOR.g kanalı "çimlik" oranı varsayıldı —
    // Claude Code gerçek mekanizmaya göre bu satırı uyarlar.
    v_grass_mask = COLOR.g;
}

void fragment() {
    vec2 w = v_world.xz;
    vec3 col = base_color;
    float m = v_grass_mask; // benekler yalnız çimde

    // --- İRİ LEKELER: yumuşak ton bulutları ---
    float blotch = vnoise(w * blotch_scale);
    col *= 1.0 + (blotch - 0.5) * 2.0 * blotch_amount * m;

    // --- SICAK-SERİN: çok geniş ölçekli renk kayması ---
    float wv = vnoise(w * warm_scale + 13.7);
    col.r *= 1.0 + (wv - 0.5) * 2.0 * warm_variation * m;
    col.b *= 1.0 - (wv - 0.5) * 1.2 * warm_variation * m;

    // --- İNCE BENEKLER: koyu + açık noktacıklar ---
    if (quality > 0) {
        float n1 = vnoise(w * speckle_scale);
        float n2 = vnoise(w * speckle_scale * 1.9 + 41.2);
        float dark_dot = step(1.0 - speckle_density * 0.5, n1);
        float lite_dot = step(1.0 - speckle_density * 0.35, n2);
        col *= 1.0 - dark_dot * speckle_amount * m;
        col *= 1.0 + lite_dot * speckle_amount * 1.2 * m;
    }

    // --- GECE ---
    col = mix(col, col * night_tint * 2.0, night_mix);

    ALBEDO = col;
}
