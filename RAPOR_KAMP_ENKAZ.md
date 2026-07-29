# KAMP ENKAZI — devrik sandık + araştırma masası sökümü (kamp-enkaz)

## SORUN (oyunda bildirildi)

Başlangıç kampındaki "üretim köşesi" dekoru — devrik araştırma masası
ve devrik boş sandık — SALT GÖRSELDİ (`_camp_prop_structure`: veri yok,
çarpışma yok, etkileşim yok). Karakter içinden geçiyordu ve hiçbir
aletle kaldırılamıyordu. Kasıtlı "terk edilmiş kamp" sahnelemesiydi ama
işlevsizliği kafa karıştırıyordu.

## ÇÖZÜM: ENKAZ SÖKÜMÜ

- Devrik masa + sandık artık **enkaz**: boş el ya da aletle dokununca
  sökülür (silah hariç — dövüş sırasında yanlışlıkla sökülmesin).
- Söküm küçük malzeme düşürür (yağma hissi; sayılar
  `scripts/camp_balance.gd` SALVAGE): sandık = 1 odun + 1 çubuk,
  masa = 1 odun + 2 çubuk.
- Söküm KALICI: hücre kayda yazılır (`camp_enkaz`), yüklemede
  `_build_spawn_camp` işaretli hücreyi atlar.
- Kapsam dışı: sönük meşale direkleri, kulübe, kuyu (kampın kimliği).

## DOĞRULAMA

PREFABTEST genişletildi: `enkaz_sokum=true dusen=2 kalici=true` —
söküm çalışıyor, malzeme düşüyor, `_build_spawn_camp` yeniden
kurulumunda geri gelmiyor (test kendi izini temizler). PREFABTEST
ci-fast görünürlük grep'ine eklendi.
