# TEST BULGULARI — 4 Düzeltme Raporu

Otonom mod. Branch: `test-duzeltmeleri` (yapi-sistemi üstüne).

## 4. AĞAÇ HATASI — KÖK NEDEN (teşhis önce)

**Belirti:** Tek ağaç olması gereken yerde 4-5 ağaç iç içe; bir kesim
hepsini götürüyor.

**Kök neden (b şıkkı):** Kullanılan model `quat2_tree02.glb`, GLB içinde
**tek bir birleşik mesh** olarak duran bir *grup* modeli
("Resource_PineTree_Group" — 4-5 çam tek mesh'e gömülü). `_model_pool`
GLB'nin üst-düzey mesh'li çocuklarını sayar; burada 1 parça görür →
`parts.size() <= 1` dalına düşer → `_merged_node_mesh(scene)` TÜM sahneyi
(bütün çam grubunu) tek mesh'e birleştirir. Sonra her ağaç hücresi bu
grup mesh'ini render eder → "4-5 ağaç iç içe". Kesim tek varlık (hücre)
olduğu için hepsi birden gider (c değil — kesim doğru çalışıyor; sorun
görselin çoklu ağaç içermesi).

**Doğrulama:** `quat2_tree02.glb` = 1 mesh (grup). Karşılaştırma:
`quat2_tree01.glb` = 5 ayrı mesh (NormalTree_1..5, pool düzgün çalışır),
Kenney `tree_pineDefaultA.glb` = 1 mesh ama **tek ağaç**.

**Düzeltme:**
1. Ağaç havuzu tek-ağaç çam modellerine geçirildi (Kenney
   `tree_pine*` — her biri tek ağaç); birkaç varyanttan havuz kurulup
   hücreye göre çeşitlilik korunur.
2. Harita yüklemede **min 1 boş hücre** kuralı: bir "T" hücresi, zaten
   yerleştirilmiş bir ağacın 8-komşuluğundaysa zemine çevrilir (spawn'da
   seyreltme). Böylece 1 hücre = en fazla 1 ağaç ve ağaçlar bitişmez.
3. Kesim zaten tek hücreyi etkiliyordu (değişmedi).

*(Diğer 3 madde ve test listesi aşağıda; iş ilerledikçe dolar.)*
