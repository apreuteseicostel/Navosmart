#include "../custom/src/NavoConnectionPolicy.h"
#include <cassert>
#include <cstring>
#include "../custom/src/NavoConnectivityDiagnosis.h"
#include <iostream>
int main() {
    using namespace NavoConnectionPolicy;
    assert(retryAllowed(false, 0, 0, 0));
    assert(!retryAllowed(true, 0, 0, 900000)); // never replace an existing link
    assert(!retryAllowed(false, 1, 1000, 15999));
    assert(retryAllowed(false, 1, 1000, 16000));
    assert(!retryAllowed(false, 2, 1000, 30999));
    assert(retryAllowed(false, 2, 1000, 31000));
    assert(!retryAllowed(false, 5, 1000, 9999999)); // fail closed after retry budget
    assert(retryDelay(1)==15000 && retryDelay(2)==30000 && retryDelay(30)==300000);
    assert(!heartbeatFresh(true, 0, 10000)); // transport open is not MAVLink
    assert(!heartbeatFresh(false, 9000, 10000));
    assert(!heartbeatFresh(true, 11000, 10000));
    assert(heartbeatFresh(true, 9000, 10000));
    assert(!heartbeatFresh(true, 4000, 10000));
    using NavoConnectivityDiagnosis::Input;
    using NavoConnectivityDiagnosis::explain;
    auto code=[](Input s,const char* expected){assert(std::strcmp(explain(s).code,expected)==0);};
    Input d;
    code(d,"idle"); d.platform=false;code(d,"platform");d.platform=true;
    d.replay=true;d.stopped=true;code(d,"replay");d.replay=false;code(d,"stopped");d.stopped=false;
    d.selected=false;code(d,"model");d.selected=true;
    d.attempts=5;code(d,"retries");d.attempts=0;
    d.sdkError=true;code(d,"sdk_error");d.sdkError=false;
    d.link=true;code(d,"controller");d.rc=true;code(d,"channel");
    d.receiver=0;code(d,"receiver");d.receiver=-1;code(d,"channel");
    d.channel=true;code(d,"no_rx");d.bytes=42;code(d,"no_heartbeat");
    d.heartbeatSeen=true;code(d,"heartbeat_lost");
    d.live=true;d.receiver=0;d.sdkError=true;code(d,"live"); // heartbeat wins contradictory metadata
    d.stopped=true;code(d,"stopped");d.stopped=false;d.replay=true;code(d,"replay");
    std::cout << "PASS 14 explanatory diagnosis states, unknown receiver, contradictory metadata, replay/manual precedence and RX versus HEARTBEAT evidence\n";
    std::cout << "PASS connectivity retry budget, backoff, no active-link replacement and heartbeat expiry\n";
}
