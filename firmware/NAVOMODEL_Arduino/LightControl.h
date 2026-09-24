#pragma once
#include <stdint.h>
#include "Config.h"
struct LightControl {
  bool armed=false; int8_t direction=0; uint32_t since=0;
  int8_t update(uint16_t us,bool valid,uint32_t now){
    if(!valid||us<900||us>2100){armed=false;direction=0;return 0;}
    if(RC_REVERSE) us=3000-us;
    if(us>1350&&us<1650){armed=true;direction=0;return 0;}
    int8_t next=us<1250?-1:us>1750?1:0;
    if(!armed||!next){direction=0;return 0;}
    if(next!=direction){direction=next;since=now;return 0;}
    if((uint32_t)(now-since)>=HOLD_MS){armed=false;direction=0;return next;}
    return 0;
  }
};
