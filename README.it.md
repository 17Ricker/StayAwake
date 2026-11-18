<p align="center"><img src="Resources/AppIcon.png" width="128" alt="Icona di StayAwake"></p>

# StayAwake

[English](README.md) · **Italiano** · [Español](README.es.md)

Una piccola app per la barra dei menu di macOS che tiene il Mac acceso, **anche a coperchio chiuso**, per tutto il tempo che scegli.

<p align="center"><img src="docs/screenshots/night.png" width="720" alt="StayAwake nello stile Notte: spento, timer in corso, continuo"></p>

## Cosa fa

- **Timer** da 5 minuti a 24 ore, oppure **continuo** finché non lo fermi. Mentre corre puoi aggiungere tempo.
- Funziona **a coperchio chiuso** (usa `pmset disablesleep` di macOS).
- **Prima la sicurezza:**
  - si ferma quando la batteria scende sotto il 20% (facoltativo);
  - si ferma se macOS segnala una temperatura critica (facoltativo);
  - quando esci riporta lo sleep alla normalità, e lo fa anche se l'app crasha o viene chiusa a forza.
- Tre stili (Notte, Retro, Modern) e tre lingue (Italiano, English, Español).
- **Nessuna connessione di rete**, nessuna telemetria, nessun aggiornamento automatico.

<p align="center"><img src="docs/screenshots/modern.png" width="560" alt="StayAwake nello stile Modern"></p>

## Requisiti

macOS 14 Sonoma o successivo, su Mac con Apple silicon o Intel.

## Installazione

1. Scarica `StayAwake.zip` e `StayAwake.zip.sha256` dall'[ultima release](https://github.com/ricky7x/StayAwake/releases/latest).
2. Verifica il download (facoltativo, consigliato):

   ```bash
   shasum -a 256 -c StayAwake.zip.sha256
   gh attestation verify StayAwake.zip -R ricky7x/StayAwake
   ```

   - Il primo comando controlla che il file non sia rovinato o modificato.
   - Il secondo ([GitHub CLI](https://cli.github.com)) dimostra che lo zip è stato costruito da GitHub Actions **a partire dal codice pubblico di questo repository**.
3. Decomprimi e sposta **StayAwake** nella cartella **Applicazioni**.
4. Aprila. StayAwake è gratuita e non è notarizzata da Apple, quindi la prima volta macOS dice che non può verificare lo sviluppatore.
   - Premi **Fine**, poi apri **Impostazioni di Sistema → Privacy e sicurezza**.
   - Scorri fino al messaggio su StayAwake e premi **Apri comunque**. Basta farlo una volta.
   - Non disattivare Gatekeeper e non togliere gli attributi di quarantena per aggirare l'avviso.

Cerca il fulmine ⚡ nella barra dei menu.

## Compilarla da sé

Serve Xcode (l'app completa: le macro di SwiftUI non si compilano con i soli Command Line Tools).

```bash
git clone https://github.com/ricky7x/StayAwake.git
cd StayAwake
./test.sh        # test, senza password admin
./installa.sh    # compila e installa in ~/Applicazioni
```

`./release.sh` produce lo stesso zip universale firmato ad-hoc delle release.

## A cosa serve la password

Solo un amministratore può cambiare `disablesleep`. La prima volta che avvii StayAwake, macOS mostra la sua finestra della password: StayAwake non la vede e non la salva. Con quella password StayAwake installa una regola che permette **solo al tuo utente** di eseguire **solo questi due comandi** senza password:

```
#501 ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- `501` è il tuo ID utente.
- La regola viene controllata con `visudo` prima di essere installata.
- Sta in un file suo, `/etc/sudoers.d/stayawake-uid<tuo ID>`, uno per utente, così gli utenti dello stesso Mac non si sovrascrivono a vicenda.

Per vederla:

```bash
sudo cat /etc/sudoers.d/stayawake-uid$(id -u)
```

Da sapere: anche le altre app che girano con il tuo utente possono usare questa regola, ma solo per accendere o spegnere lo sleep, nient'altro.

## Togliere tutto

1. **Prima spegni StayAwake** (Stop, oppure disattiva Continuo).
2. In StayAwake: **Impostazioni → Rimuovi permesso** (macOS chiede la password admin). Oppure nel Terminale:

   ```bash
   sudo rm /etc/sudoers.d/stayawake-uid$(id -u)
   sudo pmset -a disablesleep 0    # si assicura che lo sleep sia tornato normale
   ```

3. Esci da StayAwake e trascinala nel Cestino.

Le versioni precedenti alla 1.0 usavano un solo file, `/etc/sudoers.d/stayawake`. La 1.0 lo toglie da sola se contiene la tua vecchia regola; altrimenti puoi cancellarlo con `sudo rm /etc/sudoers.d/stayawake`.

## Sicurezza e limiti

- **Non mettere il Mac in uno zaino con StayAwake attivo.** A coperchio chiuso può scaldarsi. La protezione temperatura ferma StayAwake a temperatura critica, ma non affidarti solo a quella.
- A batteria, a coperchio chiuso il Mac continua a consumare. La protezione batteria ferma StayAwake sotto il 20%.
- Se il Mac **si riavvia** con StayAwake attivo, lo sleep resta disattivato finché StayAwake non si riapre. Attiva **Avvia al login**, così succede da solo.
- Se StayAwake crasha o viene chiusa a forza, un piccolo processo in background riporta lo sleep alla normalità entro un paio di secondi.
- StayAwake non fa nessuna connessione di rete.

## Lingue

**Impostazioni → Lingua**: Sistema, Italiano, English, Español. *Sistema* segue la lingua di macOS, oppure l'inglese se non è nessuna di queste.

<p align="center"><img src="docs/screenshots/settings.png" width="560" alt="Impostazioni negli stili Notte e Retro"></p>

## Sicurezza

In [SECURITY.md](SECURITY.md) trovi cosa gira come amministratore e come segnalare una vulnerabilità.

## Licenza

[MIT](LICENSE) © 2026 Riccardo Gnoni
