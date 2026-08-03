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
// ENTEGRASYON: kenar gecisi yumusatma — maske 0-1 arasi interpolasyonda
// (zemin turu siniri) noise sallantisi, duz cizgi organiklesir.
uniform float mask_noise : hint_range(0.0, 0.6) = 0.25;

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
    // ÇİM MASKESİ (uyarlandı): bu projede zemin RENGİ vertex color
    // RGB'sinde yaşar (tür rengi + kazı kararması + falez boyası) —
    // COLOR.g rengin parçası, maske OLAMAZ. Maske, boşta duran ALPHA
    // kanalında taşınır (_build_chunk yazar: çayır=1, yol/kazı/falez=0).
    v_grass_mask = COLOR.a;
}

void fragment() {
    vec2 w = v_world.xz;
    // Taban renk VERTEX'ten (sözleşme: renk başka sistemden geliyorsa
    // onu kullan) — tür renkleri, kazı katmanları, ıslak bant, kenar
    // harmanı aynen korunur; base_color uniform'u yalnız yedek.
    vec3 col = COLOR.rgb;
    float m = v_grass_mask; // benekler yalnız çimde
    // Tür sınırında (maske 0-1 arası interpolasyon bandı) noise
    // sallantısı: düz vertex-geçişi organik kenara döner.
    if (m > 0.01 && m < 0.99) {
        m = clamp(m + (vnoise(w * 2.3 + 7.7) - 0.5) * mask_noise * 2.0,
                0.0, 1.0);
    }

    // --- İRİ LEKELER: yumuşak ton bulutları ---
    float blotch = vnoise(w * blotch_scale);
    col *= 1.0 + (blotch - 0.5) * 2.0 * blotch_amount * m;

    // --- SICAK-SERİN: çok geniş ölçekli renk kayması ---
    float wv = vnoise(w * warm_scale + 13.7);
    col.r *= 1.0 + (wv - 0.5) * 2.0 * warm_variation * m;
    col.b *= 1.0 - (wv - 0.5) * 1.2 * warm_variation * m;

    // --- İNCE BENEKLER: koyu + açık noktacıklar ---
    // ANTI-ALIAS: sert step yerine fwidth'li smoothstep (uzakta moire/
    // cizgi deseni yapmasin) + MESAFE SONUMU: benekler kameradan
    // uzaklastikca kaybolur (uzakta zaten secilemezler, aliasing biter)
    if (quality > 0) {
        float cam_d = length(v_world - CAMERA_POSITION_WORLD);
        float dist_fade = 1.0 - smoothstep(speckle_fade_start, speckle_fade_end, cam_d);
        if (dist_fade > 0.001) {
            float n1 = vnoise(w * speckle_scale);
            float n2 = vnoise(w * speckle_scale * 1.9 + 41.2);
            float aa1 = fwidth(n1) * 1.5;
            float aa2 = fwidth(n2) * 1.5;
            float th1 = 1.0 - speckle_density * 0.5;
            float th2 = 1.0 - speckle_density * 0.35;
            float dark_dot = smoothstep(th1 - aa1, th1 + aa1, n1);
            float lite_dot = smoothstep(th2 - aa2, th2 + aa2, n2);
            float k = speckle_amount * m * dist_fade;
            col *= 1.0 - dark_dot * k;
            col *= 1.0 + lite_dot * k * 1.2;
        }
    }

    // --- GECE ---
    col = mix(col, col * night_tint * 2.0, night_mix);

    ALBEDO = col;
}
