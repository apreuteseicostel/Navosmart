#pragma once
#include <stdint.h>
#include <string.h>

inline int8_t navoHexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

// Validate the complete frame before changing any output state.
inline bool navoApplyLightCommand(char* line, bool& head, bool& position) {
    if (!line || line[0] != '$') return false;
    char* star = strchr(line, '*');
    if (!star || strlen(star) != 3) return false;
    const int8_t hi = navoHexDigit(star[1]), lo = navoHexDigit(star[2]);
    if (hi < 0 || lo < 0) return false;
    uint8_t checksum = 0;
    uint8_t commas = 0;
    for (char* c = line + 1; c < star; ++c) {
        checksum ^= uint8_t(*c);
        if (*c == ',') { if (c == line + 1 || c[-1] == ',' || c + 1 == star) return false; ++commas; }
    }
    if (commas != 3) return false;
    if (checksum != uint8_t((hi << 4) | lo)) return false;
    *star = '\0';
    char* save = nullptr;
    char* kind = strtok_r(line + 1, ",", &save);
    char* version = strtok_r(nullptr, ",", &save);
    char* target = strtok_r(nullptr, ",", &save);
    char* operation = strtok_r(nullptr, ",", &save);
    if (!kind || !version || !target || !operation || strtok_r(nullptr, ",", &save) ||
        strcmp(kind, "NAVOCMD") || strcmp(version, "1")) return false;
    bool* state = !strcmp(target, "HEAD") ? &head : !strcmp(target, "POS") ? &position : nullptr;
    if (!state) return false;
    if (!strcmp(operation, "ON")) *state = true;
    else if (!strcmp(operation, "OFF")) *state = false;
    else if (!strcmp(operation, "TOGGLE")) *state = !*state;
    else return false;
    return true;
}

class NavoLightCommandBuffer {
public:
    bool feed(char c, bool& head, bool& position) {
        if (c == '\r') return false;
        if (c == '\n') {
            line_[length_] = '\0';
            const bool applied = !overflow_ && length_ && navoApplyLightCommand(line_, head, position);
            length_ = 0; overflow_ = false;
            return applied;
        }
        if (overflow_) return false;
        if (length_ < sizeof(line_) - 1) line_[length_++] = c;
        else { overflow_ = true; length_ = 0; }
        return false;
    }
private:
    char line_[64] = {};
    uint8_t length_ = 0;
    bool overflow_ = false;
};
