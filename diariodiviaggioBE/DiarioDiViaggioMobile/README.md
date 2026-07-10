# DiarioDiViaggioMobile

App Flutter mobile per il progetto DiarioDiViaggio.

## Funzionalita incluse

- Autenticazione: login, registrazione, recupero password
- Gestione viaggi: lista, creazione, modifica, eliminazione
- Condivisione viaggi: join tramite share code
- Trip items: creazione e lista con supporto upload immagine
- Bagagli: gestione valigie e oggetti con stato packed/unpacked
- Itinerario: calendario giornaliero e gestione attivita
- Profilo: visualizzazione e aggiornamento username/foto profilo

## Backend collegato

L'app usa le API di:

- DiarioDiViaggioApi (cartella sibling in diariodiviaggioBE)

Endpoint base configurato in `lib/main.dart`:

- `defaultApiBaseUrl = https://localhost:44324`

## Avvio locale

1. Avvia il backend .NET dalla cartella `DiarioDiViaggioApi`.
2. Dalla cartella `DiarioDiViaggioMobile` esegui:

```bash
flutter pub get
flutter run
```

## Test end-to-end manuali su emulatore Android

### 1) Avvia l'emulatore

Opzione Android Studio:

1. Apri Android Studio.
2. Vai in **Device Manager**.
3. Avvia un AVD (esempio: `Medium Phone API 36.1`).

Opzione CLI Flutter:

```bash
flutter emulators
flutter emulators --launch <emulator_id>
```

Verifica che il device sia online:

```bash
flutter devices
```

### 2) Configura l'URL API per emulatore Android

Per Android emulator non usare `localhost` del PC host. Usa invece:

- `https://10.0.2.2:44324` (o la porta reale del backend)

Nel progetto attuale aggiorna `defaultApiBaseUrl` in `lib/main.dart` prima dell'avvio.

### 3) Avvia backend e app mobile

1. Avvia `DiarioDiViaggioApi`.
2. Dalla cartella `DiarioDiViaggioMobile`:

```bash
flutter pub get
flutter run -d emulator-5554
```

Se l'id del device e diverso, usa quello mostrato da `flutter devices`.

### 4) Checklist E2E manuale consigliata

1. Registrazione utente nuovo.
2. Login e apertura dashboard viaggi.
3. Creazione viaggio, modifica, eliminazione.
4. Condivisione viaggio (copia codice) e join con codice.
5. Trip items: crea/modifica/elimina con immagine.
6. Bagagli: crea bagaglio, aggiungi item, toggle packed, elimina item.
7. Itinerario: aggiungi attivita, toggle completata, elimina attivita.
8. Profilo: modifica username e foto.

### 5) Comandi utili durante i test

```bash
flutter run -d emulator-5554
flutter logs
flutter clean
flutter pub get
```

## Nota rete su emulatori/dispositivi

- Android emulator: in genere `https://10.0.2.2:<porta>` invece di `localhost`
- Dispositivo fisico: usa IP LAN della macchina dev (`https://<ip-locale>:<porta>`)

Se necessario aggiorna `defaultApiBaseUrl` in `lib/main.dart`.

## Qualita codice

Verifiche eseguite:

- `flutter analyze` -> no issues
- `flutter test` -> test passati
