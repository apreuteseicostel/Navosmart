#include "../custom/src/NavoConnectionPolicy.h"
#include <cassert>
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
    std::cout << "PASS connectivity retry budget, backoff, no active-link replacement and heartbeat expiry\n";
}
