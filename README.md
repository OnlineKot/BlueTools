# BlueTools

Mała apka na iPhone'a do grzebania w Bluetooth LE. Pokazuje, co jest wokół ciebie, pozwala się z tym połączyć i podejrzeć, co urządzenie ma w środku. Ma też tryb szukania, który przydał mi się już kilka razy, kiedy słuchawka wpadła pod kanapę.

Kod jest otwarty (GPL-3.0), nie ma reklam, kont ani żadnej analityki. Apka w ogóle nie łączy się z internetem.

<p align="center">
  <img src="BlueTools/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" alt="Ikona BlueTools">
</p>

## Co potrafi

- **Lista urządzeń w pobliżu** z siłą sygnału, przybliżoną odległością i producentem (o ile da się go rozpoznać z danych rozgłoszeniowych).
- **Przypinanie i własne nazwy.** Losowe „Bez nazwy” można nazwać po swojemu, np. „Klucze” albo „Głośnik w kuchni”.
- **Filtry**: chowanie urządzeń bez nazwy, minimalna siła sygnału, wyszukiwarka i sortowanie.
- **Połączenie z urządzeniem**: usługi, charakterystyki, odczyt, zapis (tekst albo hex) i nasłuchiwanie powiadomień. Wszystko trafia do historii, więc widać, co przyszło i co poszło.
- **Szukanie**: duże kółko rośnie, im bliżej jesteś, a telefon lekko wibruje, kiedy robi się cieplej.
- Znane UUID (bateria, tętno, informacje o urządzeniu, Nordic UART i parę innych) mają normalne nazwy zamiast ciągu cyferek.

## Instalacja

Gotowy plik `.ipa` buduje się automatycznie przy każdym pushu. Znajdziesz go w zakładce **Actions** (artefakt `BlueTools-ipa`) albo w **Releases**, jeśli jest otagowana wersja.

IPA nie jest podpisane, więc trzeba je zainstalować jednym ze znanych sposobów:

- [AltStore](https://altstore.io) albo [SideStore](https://sidestore.io), za darmo z własnym Apple ID (aplikację trzeba odświeżać co 7 dni),
- [Sideloadly](https://sideloadly.io) z komputera,
- TrollStore, jeśli masz telefon i wersję iOS, które go obsługują.

Wymagany jest iOS 16 lub nowszy.

## Budowanie samemu

Potrzebujesz Maca z Xcode 15 lub nowszym i [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open BlueTools.xcodeproj
```

W Xcode wybierz swój zespół w zakładce *Signing & Capabilities* i odpal na telefonie. Symulator nie ma Bluetooth, więc tam za dużo nie zobaczysz.

Jeśli chcesz samo IPA bez podpisu, tak jak robi to CI:

```sh
xcodebuild -project BlueTools.xcodeproj -scheme BlueTools \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
mkdir Payload && cp -R build/Build/Products/Release-iphoneos/BlueTools.app Payload/
zip -qry BlueTools.ipa Payload
```

## Jak to jest poukładane

```
BlueTools/
  App/          start aplikacji i zakładki
  Bluetooth/    skanowanie i obsługa połączenia (CoreBluetooth)
  Models/       urządzenie z listy i słownik znanych identyfikatorów
  Views/        ekrany w SwiftUI
  Support/      drobiazgi: hex, ustawienia, przypięte urządzenia
project.yml     opis projektu dla XcodeGen
```

Plik `.xcodeproj` nie jest trzymany w repo, generuje go XcodeGen. Dzięki temu nie ma konfliktów w tym okropnym `project.pbxproj`.

## Parę uczciwych uwag

- Odległość to szacunek z siły sygnału. Ściana, kieszeń albo twoja ręka potrafią zmienić wynik o kilka metrów, więc w trybie szukania patrz raczej na to, czy rośnie.
- iOS nie pokazuje prawdziwych adresów MAC. Identyfikator, który widzisz, nadaje system i jest inny na każdym telefonie.
- Słuchawki i zegarki Apple często zmieniają adres co kilkanaście minut (to celowe, chodzi o prywatność), więc mogą znikać i pojawiać się jako nowe.
- Klasyczny Bluetooth (stare głośniki, samochody) nie jest widoczny przez CoreBluetooth. Apka widzi tylko BLE.

## Chcesz pomóc?

Zgłoszenia i pull requesty są mile widziane. Szczególnie przydadzą się kolejne znane UUID i identyfikatory producentów w `Models/KnownIDs.swift`, jeśli coś u ciebie wyświetla się jako „Bez nazwy”, a wiesz, co to jest.

## Licencja

GPL-3.0. Pełny tekst jest w pliku [LICENSE](LICENSE).
