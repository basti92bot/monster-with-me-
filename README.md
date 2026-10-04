# Monster With Me

Eigenständige Monster-Energy-Fan-App mit schwarzem Design, grünen Akzenten und einer eigenen Dosenillustration. Keine offizielle App von Monster Energy.

## Funktionen

- Monster Original, Ultra White, Mango Loco, Pipeline Punch und Zero Sugar.
- Ein-Tipp-Eintrag, frei wählbare Menge, Verlauf und Wochenübersicht.
- Persönliches Tageslimit als selbst gewählter Richtwert, keine Trinkempfehlung.
- Bestehende Anmeldung aus RepPilot oder Water With Me.
- Eigene Profile und Freunde per QR-Code oder Einladungscode.
- Anstoßen, Push-Mitteilungen und Pop-ups mit Getränk und Menge.
- Keine Standortfunktion; Freunde sehen keine E-Mail-Adresse.
- Als App auf dem Home-Bildschirm installierbar.

## Entwicklung und Veröffentlichung

Node.js 22, pnpm 11.25.0. `pnpm install --frozen-lockfile`, `pnpm test`, `pnpm build`.
Der Workflow baut und veröffentlicht bei Änderungen auf `main`. GitHub Pages verwendet GitHub Actions als Quelle.

## Daten und Push

Der private Supabase-Datenbereich `mwm_private` ist von Water With Me getrennt. Die Anmeldung verwendet das bestehende Projekt. Öffentliche RPCs sind Security Invoker; interne Funktionen prüfen Anmeldung und Freundschaften. Direkter Tabellenzugriff ist gesperrt und RLS aktiviert. Profilnamen, Getränke und Tagesmengen sehen ausschließlich verbundene Freunde.

`backend/schema.sql` dokumentiert die einmalige Einrichtung. Nicht ungeprüft erneut ausführen. `backend/test.sql` und `backend/push/test.sql` verwenden vollständig zurückgerollte Testdaten. Die Tests prüfen Isolation, Freundschaften, Besitz, Eingaben, Push-Abonnements, verschlüsselte Nutzlasten, Versandwiederholungen und sichere Mitteilungslinks.

Push auf jedem Gerät unter Freunde oder Profil aktivieren. Auf dem iPhone in Safari zum Home-Bildschirm hinzufügen und über das Icon öffnen. Die Systemberechtigung wird nur nach Antippen angefragt. Mit „Test-Mitteilung senden“ lässt sich der Empfang prüfen. Ein realer iPhone-Test muss am Gerät erfolgen.

Die Edge Function `mwm-push` prüft ihren eigenen Dispatcher-Token. Sie nutzt die bestehende VAPID-Identität, aber einen eigenen Dispatcher-Schlüssel sowie getrennte Abonnements und Aufträge. Private Schlüssel verbleiben in Supabase Vault. Im Frontend steht ausschließlich der öffentliche Publishable Key. Mitteilungen öffnen immer diese App und enthalten nur die zufällige Getränke-ID im Link.

Version 1.0.1
