// =============================================================
// SON KOR — ÇİM SHADER'I (grass.gdshader)
// Godot 4.x / spatial. grass_tuft.glb (MultiMesh) için tasarlandı.
//
// ENTEGRASYON SÖZLEŞMESİ (Claude Code):
// - MultiMeshInstance3D materyali olarak atanır (tüm tutamlar tek
//   draw call'da bu shader'la çizilir). Ekstra instance verisi
//   GEREKMEZ: varyasyon dünya konumundan türetilir.
// - blade_height: tutam modelinin yerel Y yüksekliği (Root Scale
//   SONRASI). Yanlışsa salınım ya hiç görünmez ya abartılır.
// - player_pos: her karede oyuncunun dünya konumu (tek uniform set
//   — ucuz). quality 0'da okunmaz.
// - night_mix: su shader'ıyla AYNI kaynaktan (gündüz/gece sistemi).
// - noise_tex: su ile AYNI NoiseTexture2D paylaşılabilir (bellek).
// - Aynı shader çiçek/eğrelti gibi diğer küçük bitki tutamlarına da
//   atanabilir (base/tip renklerini materyal kopyasında değiştir).
// =============================================================
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// cull_disabled: çim yaprakları iki yüzlü düzlemler — arkadan da görünür

// ---- RENK ----
uniform vec3 color_base : source_color = vec3(0.373, 0.478, 0.322); // #5F7A52 kök
uniform vec3 color_tip  : source_color = vec3(0.549, 0.753, 0.400); // #8CC066 uç
uniform float tip_start : hint_range(0.0, 1.0) = 0.25; // gradyan başlangıcı
uniform float hue_variation : hint_range(0.0, 0.3) = 0.10;
    // tutamdan tutama ton oynaması (dünya konumundan, bedava)

// ---- RÜZGÂR ----
uniform sampler2D noise_tex : hint_default_black, repeat_enable;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.12;
uniform float wind_speed = 0.35;
uniform vec2  wind_dir = vec2(1.0, 0.3);      // esiş yönü (xz)
uniform float wind_gust_scale = 0.04;
    // noise örnekleme ölçeği: küçük değer = geniş, dalga dalga esinti

// ---- OYUNCU EZMESİ ----
uniform vec3 player_pos = vec3(0.0);
uniform float bend_radius = 1.1;   // etki yarıçapı (hücre ~1m)
uniform float bend_strength = 0.35;

// ---- GECE ----
uniform float night_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint : source_color = vec3(0.30, 0.36, 0.55);

// ---- GENEL ----
uniform float blade_height = 0.5;  // tutamın yerel yüksekliği (metre)
uniform int quality : hint_range(0, 1) = 1;

varying float v_h;       // 0=kök, 1=uç
varying vec3 v_world;

void vertex() {
    v_h = clamp(VERTEX.y / max(blade_height, 0.001), 0.0, 1.0);
    vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world = wpos;

    if (quality > 0) {
        // --- RÜZGÂR: geniş esinti dalgası (noise) + ince titreşim (sin) ---
        // yükseklikle kare oranında etki: kök sabit, uç savrulur
        float sway_w = v_h * v_h;
        float gust = texture(noise_tex,
            wpos.xz * wind_gust_scale + TIME * wind_speed * 0.15).r;
        gust = (gust - 0.5) * 2.0;                      // -1..1
        float flutter = sin(TIME * 2.2 + wpos.x * 3.1 + wpos.z * 2.3) * 0.25;
        vec2 sway = normalize(wind_dir) * (gust + flutter)
                    * wind_strength * sway_w;

        // --- OYUNCU EZMESİ: yakın çim oyuncudan uzağa yatar ---
        vec2 away = wpos.xz - player_pos.xz;
        float d = length(away);
        float bend = smoothstep(bend_radius, bend_radius * 0.25, d)
                     * bend_strength * sway_w;
        if (d > 0.001) { sway += normalize(away) * bend; }
        // yatan çim hafif alçalır (ezilme hissi)
        VERTEX.y -= bend * 0.4 * blade_height;

        VERTEX.x += sway.x;
        VERTEX.z += sway.y;
    }
}

// ucuz hash: dünya konumundan tutam-başına sabit rastgele değer
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void fragment() {
    // --- KÖK-UÇ GRADYANI ---
    float t = smoothstep(tip_start, 1.0, v_h);
    vec3 col = mix(color_base, color_tip, t);

    // --- TUTAM VARYASYONU: her tutamın tonu birazcık farklı ---
    // MultiMesh örneğinin kökü ~aynı xz'de: kök konumuyla hash
    float hv = hash21(floor(v_world.xz * 2.0) * 0.5);
    // yeşil ekseninde ± oynama + hafif sarıya kayma
    col *= 1.0 + (hv - 0.5) * hue_variation * 2.0;
    col.r *= 1.0 + (hv - 0.5) * hue_variation;

    // --- GECE ---
    col = mix(col, col * night_tint * 2.0, night_mix);

    ALBEDO = col;
    // hafif sahte AO: kökler gölgeli (zemine oturma hissi)
    ALBEDO *= mix(0.72, 1.0, v_h);
}
