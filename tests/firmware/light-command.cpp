#include "../../firmware/NAVOMODEL_Arduino/NavoLightCommand.h"
#include <cassert>
#include <string>
#include <cstdio>

std::string frame(const std::string& payload) {
    uint8_t cs=0;for(char c:payload)cs^=uint8_t(c);
    char hex[5];std::snprintf(hex,sizeof(hex),"*%02X",cs);
    return "$"+payload+hex+"\r\n";
}
int main() {
    NavoLightCommandBuffer buffer;bool head=false,pos=false;
    auto send=[&](const std::string& s){bool applied=false;for(char c:s)applied=buffer.feed(c,head,pos)||applied;return applied;};
    assert(send(frame("NAVOCMD,1,HEAD,ON"))&&head&&!pos);
    assert(send(frame("NAVOCMD,1,POS,TOGGLE"))&&head&&pos);
    assert(send(frame("NAVOCMD,1,HEAD,OFF"))&&!head&&pos);
    for(const auto& payload:{"NAVOCMD,2,HEAD,ON","NAVOCMD,1,ESC,ON","NAVOCMD,1,HEAD,ON,EXTRA","NAVOCMD,,1,HEAD,ON","NAVOCMD,1,HEAD,"}) {
        assert(!send(frame(payload)));assert(!head&&pos);
    }
    assert(!send("$NAVOCMD,1,HEAD,ON*00\n"));assert(!head&&pos);
    assert(!send(std::string(80,'x')+frame("NAVOCMD,1,HEAD,ON")));assert(!head&&pos);
    assert(send(frame("NAVOCMD,1,HEAD,ON"))&&head&&pos);
    std::puts("PASS Nano commands: fragmented byte input, outputs, checksum, malformed/extra fields, overflow discard/recovery");
}
