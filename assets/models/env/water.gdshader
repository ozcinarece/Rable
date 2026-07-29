// =============================================================
// SON KOR — SU SHADER'I (water.gdshader)
// Godot 4.x / spatial. Hücre-bazlı su mesh'i için tasarlandı.
//
// MESH'TEN BEKLENEN VERİ (Claude Code entegrasyonu):
//   COLOR.r  = derinlik faktörü 0..1  (0=sığ, 1=en derin)
//   COLOR.g  = kıyı faktörü     0..1  (1=karaya bitişik kenar, 0=açık su)
//   COLOR.b  = akış hızı        0..1  (0=durgun; kanal/boru akışında >0)
//   UV       = dünya-uzayı yatay koordinat (desen sürekliliği için
//              hücre yereli DEĞİL, world_pos.xz / doku_olcegi)
//   CUSTOM0.xy = akış yönü (normalize, durgun suda (0,0))
//
// KALİTE: quality uniform'u — 0: sadece bant+köpük (Düşük),
//         1: +hareket+parıltı+fresnel (Orta/Yüksek)
// =============================================================
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back,
            diffuse_lambert, specular_schlick_ggx;

// ---- RENK BANTLARI (stilize, 3 ayrık bant) ----
uniform vec3 color_shallow : source_color = vec3(0.498, 0.831, 0.847); // #7FD4D8
uniform vec3 color_mid     : source_color = vec3(0.353, 0.663, 0.902); // #5AA9E6
uniform vec3 color_deep    : source_color = vec3(0.231, 0.490, 0.769); // #3B7DC4
uniform float band1 : hint_range(0.0, 1.0) = 0.33; // sığ->orta eşiği
uniform float band2 : hint_range(0.0, 1.0) = 0.66; // orta->derin eşiği
uniform float band_soft : hint_range(0.001, 0.2) = 0.03; // geçiş sertliği

// ---- KÖPÜK ----
uniform vec3 foam_color : source_color = vec3(0.918, 0.969, 0.969); // #EAF7F7
uniform float foam_width : hint_range(0.0, 1.0) = 0.16;  // İNCE kıyı bandı
uniform float foam_wobble = 0.14;   // kenar dalgalanması (arttı — düz çizgi kırılsın)
uniform float foam_pulse_speed = 0.6;
uniform float foam_break : hint_range(0.0, 1.0) = 0.45;
    // köpüğün KESİKLİLİĞİ: 0=kesintisiz şerit, 1=çok kopuk parçalar
uniform float foam_opacity : hint_range(0.0, 1.0) = 0.65;
    // köpük yarı saydam — altından su rengi sezilir

// ---- YÜZEY HAREKETİ ----
uniform sampler2D noise_tex : hint_default_black, repeat_enable;
    // Claude Code: NoiseTexture2D (FastNoiseLite, seamless) bağla
uniform float wave_speed_1 = 0.029;   // prototip Hız 1.45 işlendi
uniform float wave_speed_2 = 0.019;
uniform vec2  wave_dir_1 = vec2(1.0, 0.35);
uniform vec2  wave_dir_2 = vec2(-0.4, 1.0);
uniform float normal_strength : hint_range(0.0, 1.0) = 0.38;
    // prototip Kırışıklık 0.75 -> gdshader ölçeğinde ~0.38
    // (prototip noise'u daha sertti; görsel eşdeğeri bu civarda,
    //  Inspector'dan 0.30-0.50 bandında ince ayar yapılabilir)

// --- GERÇEK DALGA SİSTEMİ (prototipten: 3 yönlü sinüs) ---
// Prototip değerleri: yükseklik 0.09, dalga boyu 1.9, hız 1.45
uniform float wave_amplitude = 0.09;
uniform float wave_frequency = 1.9;
uniform float wave_time_scale = 1.45;

// ---- PARILTI + FRESNEL ----
uniform float sparkle_threshold : hint_range(0.8, 0.999) = 0.950;
    // eşik düşürüldü: daha SIK kıvılcım (prototip Parıltı 1.5 seçimi)
uniform float sparkle_intensity = 0.05;
    // KULLANICI ISTEGI (parlaklik turu, v2.1'de yeniden islendi):
    // gunduz cok parlak -> 0'a yakin. Asil beyazlik kaynagi specular'di
    // (asagida spec_strength); kivilcimlar da ayni istekle kisildi.
uniform float spec_strength : hint_range(0.0, 1.0) = 0.05;
    // Yuzey yansima gucu (eski sabit 0.55). Alcak acida gokyuzu/gunes
    // yansimasi golu sutlu beyaza boyuyordu — 0'a yakin istendi.
uniform float fresnel_power = 3.0;
uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.72; // sığda saydamlık
uniform float alpha_deep    : hint_range(0.0, 1.0) = 0.94;

// ---- GECE / SICAK IŞIK YANSIMASI (Ocak-meşale) ----
uniform float night_mix : hint_range(0.0, 1.0) = 0.0; // gündüz 0, gece 1 (koddan)
uniform vec3 night_tint : source_color = vec3(0.16, 0.22, 0.38);
uniform vec3 warm_glow_color : source_color = vec3(1.0, 0.62, 0.28);
uniform int  warm_light_count = 0;               // aktif sıcak ışık sayısı (max 4)
uniform vec3 warm_lights[4];                     // dünya konumları (koddan)
uniform float warm_light_radius = 6.0;

// ---- GENEL ----
uniform int quality : hint_range(0, 1) = 1;
uniform float flow_speed_scale = 3.0; // akış hızı çarpanı

varying vec3 v_world_pos;
// 4.7 DUZELTMESI (her surumde yeniden isleniyor): CUSTOM0 yalniz vertex
// asamasinda okunabilir; fragment'taki akis yonu varying ile tasinir.
varying vec2 v_flow_dir;

varying float v_wave_h; // dalga yüksekliği (fragment'ta normal katkısı için)

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_flow_dir = CUSTOM0.xy;
    v_wave_h = 0.0;
    if (quality > 0) {
        // ÜÇ YÖNLÜ DALGA (prototipten birebir): farklı yön/frekans/fazda
        // üç sinüs üst üste — yüzey gerçekten şekil olarak dalgalanır
        float t = TIME * wave_time_scale;
        vec2 p = v_world_pos.xz;
        float h = 0.0;
        h += sin(dot(p, vec2( 1.0, 0.35)) * wave_frequency        + t * 1.0      ) * 0.5;
        h += sin(dot(p, vec2(-0.5, 1.0 )) * wave_frequency * 1.7  + t * 1.3 + 1.7) * 0.3;
        h += sin(dot(p, vec2( 0.3,-1.0 )) * wave_frequency * 2.6  + t * 0.8 + 4.0) * 0.2;
        v_wave_h = h;
        // kıyıda dalga söner (köpük bandı titremesin, kıyı çizgisi oturaklı)
        VERTEX.y += h * wave_amplitude * (1.0 - COLOR.g);
    }
}

void fragment() {
    float depth_f = COLOR.r;
    float shore_f = COLOR.g;
    float flow_f  = COLOR.b;
    vec2 flow_dir = v_flow_dir;

    // ---------- 1. RENK BANTLARI ----------
    vec3 col = color_shallow;
    col = mix(col, color_mid,  smoothstep(band1 - band_soft, band1 + band_soft, depth_f));
    col = mix(col, color_deep, smoothstep(band2 - band_soft, band2 + band_soft, depth_f));

    // ---------- 2. YÜZEY HAREKETİ (normal karışımı) ----------
    vec3 n = vec3(0.0, 0.0, 1.0);
    if (quality > 0) {
        // akan hücrede kayma yönü/hızı akıştan; durgunda iki sabit yön
        vec2 drift1 = mix(wave_dir_1 * wave_speed_1,
                          flow_dir * wave_speed_1 * flow_speed_scale * max(flow_f, 0.2),
                          step(0.01, flow_f));
        vec2 drift2 = mix(wave_dir_2 * wave_speed_2,
                          flow_dir * wave_speed_2 * flow_speed_scale * max(flow_f, 0.2) * 1.4,
                          step(0.01, flow_f));
        vec3 n1 = texture(noise_tex, UV + TIME * drift1).rgb * 2.0 - 1.0;
        vec3 n2 = texture(noise_tex, UV * 1.7 + TIME * drift2).rgb * 2.0 - 1.0;
        // büyük dalganın eğimi de normale katılır (prototipteki gibi —
        // dalga tepeleri ışığı farklı kırar, hacim hissi buradan gelir)
        vec2 wave_slope = vec2(v_wave_h * 0.15, v_wave_h * 0.10);
        n = normalize(vec3((n1.xy + n2.xy) * normal_strength + wave_slope, 1.0));
    }
    NORMAL_MAP = n * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;

    // ---------- 3. KIYI KÖPÜĞÜ (ince, kesikli, yarı saydam) ----------
    float wob = texture(noise_tex, UV * 2.3 + vec2(TIME * 0.015)).r;
    float pulse = sin(TIME * foam_pulse_speed) * 0.5 + 0.5;
    float foam_edge = foam_width * (0.85 + 0.15 * pulse) + (wob - 0.5) * foam_wobble;
    // yumuşak kenarlı ince bant (geçiş genişledi: 0.06 -> 0.14, keskin kontur kırıldı)
    float foam_m = smoothstep(1.0 - foam_edge, 1.0 - foam_edge + 0.14, shore_f);
    // KESİKLİLİK: büyük ölçekli noise köpüğü yer yer tamamen SİLER
    // (kıyı boyunca kesintisiz şerit yerine kopuk kopuk köpük yamaları)
    float gap = texture(noise_tex, UV * 1.1 + vec2(TIME * 0.008, -TIME * 0.006)).r;
    foam_m *= smoothstep(foam_break - 0.15, foam_break + 0.15, gap);
    // iç desen: noktalı doku
    float foam_dots = step(0.45, texture(noise_tex, UV * 6.0 + vec2(TIME * 0.01)).r);
    foam_m *= mix(0.6, 1.0, foam_dots);
    // yarı saydam karışım — köpük altından su rengi sezilir
    col = mix(col, foam_color, foam_m * foam_opacity);

    // ---------- 4. GECE TONU + SICAK YANSIMA ----------
    col = mix(col, col * night_tint * 2.2, night_mix);
    if (night_mix > 0.05 && warm_light_count > 0) {
        float glow = 0.0;
        for (int i = 0; i < warm_light_count; i++) {
            float d = distance(v_world_pos.xz, warm_lights[i].xz);
            // titrek sıcak leke — ateş kıpırtısı
            float flicker = 0.85 + 0.15 * sin(TIME * 7.0 + float(i) * 1.7);
            glow += smoothstep(warm_light_radius, warm_light_radius * 0.25, d) * flicker;
        }
        glow = clamp(glow, 0.0, 1.0) * night_mix;
        col = mix(col, warm_glow_color, glow * 0.45);
        EMISSION = warm_glow_color * glow * 0.35; // sudan hafif ışıma
    }

    // ---------- 5. FRESNEL + SAYDAMLIK ----------
    float fres = 0.0;
    if (quality > 0) {
        fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
                   fresnel_power);
    }
    float base_alpha = mix(alpha_shallow, alpha_deep, depth_f);
    ALPHA = clamp(base_alpha + fres * 0.15 + foam_m * foam_opacity * 0.15, 0.0, 1.0);

    ALBEDO = col;

    // ---------- 6. PARILTI ----------
    ROUGHNESS = 0.18;
    SPECULAR = spec_strength;
    if (quality > 0) {
        float sp = texture(noise_tex, UV * 3.1 + vec2(TIME * 0.03, -TIME * 0.02)).r;
        float sparkle = step(sparkle_threshold, sp) * sparkle_intensity;
        // gece parıltısı sıcak tona döner
        vec3 sparkle_col = mix(vec3(1.0), warm_glow_color, night_mix * 0.7);
        EMISSION += sparkle_col * sparkle * (0.5 + 0.5 * night_mix);
    }
}
