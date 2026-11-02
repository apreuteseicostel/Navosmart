#pragma once
#include <cstdint>

// Read-only classification from current session evidence. No commands or inferred IPs.
namespace NavoConnectivityDiagnosis {
struct Input {
    bool platform = true, selected = true, replay = false, stopped = false;
    bool link = false, rc = false, channel = false, live = false, heartbeatSeen = false;
    bool sdkError = false;
    int receiver = -1; // -1 unknown/stale, 0 explicitly disconnected, 1 connected
    int attempts = 0;
    std::uint64_t bytes = 0;
};
struct Result { const char* code; const char* explanation; const char* action; };
inline Result explain(const Input& s) {
    if (!s.platform) return {"platform", "Adaptorul RCSDK nu este disponibil pe această platformă sau lipsește din APK.", "Folosește APK-ul NAVO cu RCSDK pe telecomanda Android ARM G20."};
    if (s.replay) return {"replay", "Este activă redarea unei înregistrări; canalul live este oprit intenționat.", "Închide redarea înainte de a verifica legătura live."};
    if (s.stopped) return {"stopped", "Conectarea a fost oprită manual; reconectarea automată este suspendată.", "Apasă Conectează pentru reluare. Oprește nu trimite HOLD bărcii."};
    if (!s.selected) return {"model", "Modelul telecomenzii nu a fost recunoscut automat drept G20.", "Selectează Conectează numai dacă aplicația rulează pe G20."};
    // A parsed heartbeat outranks unavailable, stale or contradictory vendor metadata.
    if (s.live) return {"live", "H743 trimite un HEARTBEAT MAVLink recent prin această legătură.", "Legătura de telemetrie este confirmată. Aceasta nu confirmă GPS, armarea sau funcționarea camerei/sonarului."};
    if (!s.link && s.attempts >= 5) return {"retries", "Cele cinci încercări automate s-au încheiat fără confirmarea autopilotului.", "Verifică alimentarea H743/GR01 și închide FLY/Device Tool, apoi apasă Conectează."};
    if (s.sdkError) return {"sdk_error", "SDK-ul sau canalul de comunicație a raportat o eroare; mesajul tehnic este afișat mai jos.", "Închide aplicațiile care pot ocupa canalul și verifică alimentarea GR01. Reîncearcă după corectarea erorii."};
    if (!s.link) return {"idle", "Canalul RCSDK nu este pornit; nu există încă dovadă de legătură cu H743.", "Apasă Conectează sau activează conectarea automată la pornire."};
    if (!s.rc) return {"controller", "SDK-ul nu a confirmat încă legătura cu telecomanda G20.", "Închide FLY/Device Tool și verifică firmware-ul Android G20 compatibil cu SDK-ul (20250110 sau ulterior)."};
    if (s.receiver == 0) return {"receiver", "G20 este accesibil, dar datele radio recente raportează GR01 deconectat.", "Verifică alimentarea GR01 și împerecherea radio. Această stare nu dovedește o problemă la firele UART."};
    if (!s.channel) return {"channel", "G20 este accesibil, dar canalul de date nu este încă deschis. Starea GR01 se verifică separat în detaliile radio.", "Verifică GR01 și închide aplicațiile care folosesc același canal; apoi reconectează."};
    if (s.heartbeatSeen) return {"heartbeat_lost", "Canalul este deschis, dar HEARTBEAT-ul primit anterior a expirat.", "Verifică dacă H743 rămâne alimentat și dacă sosesc date noi. Un canal deschis nu confirmă autopilotul."};
    if (!s.bytes) return {"no_rx", "Canalul este deschis, dar QGC nu a primit niciun octet în această sesiune.", "Verifică alimentarea H743, TX H743 → RX GR01, masa comună și egalitatea vitezelor UART. Verifică protocolul MAVLink al portului H743 folosit."};
    return {"no_heartbeat", "QGC primește octeți, dar nu a identificat un HEARTBEAT de autopilot MAVLink valid.", "Verifică baud-ul, protocolul MAVLink și portul H743 conectat la GR01. Datele pot avea alt format sau pot fi corupte; cauza nu este încă demonstrată."};
}
}
