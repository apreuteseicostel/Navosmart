#pragma once
#include <algorithm>
#include <cstdint>

// No I/O: retry limits and freshness are shared with focused native tests.
namespace NavoConnectionPolicy {
inline std::int64_t retryDelay(int attempts) {
    return std::min<std::int64_t>(300000, 15000LL << std::min(std::max(attempts - 1, 0), 5));
}
inline bool retryAllowed(bool hasLink, int attempts, std::int64_t lastAttempt, std::int64_t now) {
    return !hasLink && attempts < 5 && (attempts == 0 || now - lastAttempt >= retryDelay(attempts));
}
inline bool heartbeatFresh(bool connected, std::int64_t lastHeartbeat, std::int64_t now) {
    return connected && lastHeartbeat > 0 && now >= lastHeartbeat && now - lastHeartbeat < 6000;
}
}
