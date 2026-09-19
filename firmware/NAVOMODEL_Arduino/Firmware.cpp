/* NAVOMODEL firmware 1.1 candidate for Rev.D D0.1, classic Nano 16 MHz.
   Arduino core + direct AVR peripherals; no third-party libraries.
   HCT14 inputs invert RC/servo pulses. H743 telemetry uses D0/D1. */
#include <Arduino.h>
#include "Firmware.h"
#include "Config.h"
#include "LightControl.h"
#include "NavoH743Telemetry.h"
#if !defined(__AVR_ATmega328P__) || F_CPU != 16000000UL
#error "Use classic Nano ATmega328P 16 MHz"
#endif
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/wdt.h>
#include <util/delay.h>
#include <util/atomic.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <stdlib.h>
static LightControl lights;
static volatile uint16_t pulse[5],start[5];
static volatile uint32_t seen[5],started_ms[5];
static volatile bool active[5];
static uint8_t prev_d;
static const uint8_t masks[5]={_BV(PD2),_BV(PD3),_BV(PD5),_BV(PD6),_BV(PD7)};
ISR(PCINT2_vect){uint8_t d=PIND,change=d^prev_d;uint16_t t=TCNT1;uint32_t now=millis();for(uint8_t i=0;i<5;i++)if(change&masks[i]){if(!(d&masks[i])){start[i]=t;started_ms[i]=now;active[i]=true;}else{uint16_t us=(uint16_t)(t-start[i])/2;if(active[i]&&now-started_ms[i]<=3&&us>=900&&us<=2100){pulse[i]=us;seen[i]=now;}else seen[i]=0;active[i]=false;}}prev_d=d;}
static uint16_t adc(uint8_t ch){ADMUX=_BV(REFS0)|(ch&15);ADCSRA|=_BV(ADSC);while(ADCSRA&_BV(ADSC)){}uint16_t sum=0;for(uint8_t i=0;i<8;i++){ADCSRA|=_BV(ADSC);while(ADCSRA&_BV(ADSC)){}sum+=ADC;}return sum/8;}
static void pixelbyte(uint8_t v){uint8_t hi=PORTD|_BV(PD4),lo=PORTD&~_BV(PD4),n;asm volatile("ldi %[n],8\n\t""1: out %[port],%[hi]\n\t""nop\n\tnop\n\tnop\n\tnop\n\t""sbrs %[v],7\n\t""out %[port],%[lo]\n\t""lsl %[v]\n\t""nop\n\tnop\n\tnop\n\tnop\n\t""out %[port],%[lo]\n\t""nop\n\tnop\n\tnop\n\t""dec %[n]\n\t""brne 1b\n\t":[v] "+r"(v),[n] "=&d"(n):[port] "I"(_SFR_IO_ADDR(PORTD)),[hi] "r"(hi),[lo] "r"(lo));}
static void rgb(uint8_t r,uint8_t g,uint8_t b){uint8_t sr=SREG;cli();pixelbyte(g);pixelbyte(r);pixelbyte(b);
#if RGBW_PIXEL
pixelbyte(0);
#endif
SREG=sr;_delay_us(100);}
static bool head,pos,water_latched,water_fault,temp_fault;
static uint8_t wet_count,fault_count,dry_count;static uint32_t ack_since,water_next,water_started;static bool water_sampling;
static uint16_t last_hop[2];static uint32_t blue_until;static uint16_t battery_mv;static int16_t temp_c;
#if H743_TELEMETRY
static NavoH743Telemetry h743(Serial);
#endif
static void control(uint16_t a,bool va,uint32_t now){int8_t event=lights.update(a,va,now);if(event<0)pos=!pos;if(event>0)head=!head;}
static void water(uint32_t now){if(!water_sampling&&(int32_t)(now-water_next)>=0){PORTB|=_BV(PB3);water_started=now;water_sampling=true;}if(water_sampling&&now-water_started>=10){uint16_t w=adc(2);PORTB&=~_BV(PB3);water_sampling=false;water_next=now+490;bool wet=w>=200,fault=w<30;wet_count=wet?(wet_count<3?wet_count+1:3):0;fault_count=fault?(fault_count<3?fault_count+1:3):0;dry_count=(!wet&&!fault)?(dry_count<10?dry_count+1:10):0;if(wet_count>=3)water_latched=true;if(fault_count>=3)water_fault=true;if(dry_count>=4)water_fault=false;}}
void navoBegin(){cli();MCUSR=0;wdt_disable();PORTB=_BV(PB4);DDRB=_BV(PB0)|_BV(PB1)|_BV(PB2)|_BV(PB3);DDRD=_BV(PD4);PORTD=0;ADCSRA=_BV(ADEN)|_BV(ADPS2)|_BV(ADPS1)|_BV(ADPS0);DIDR0=_BV(ADC0D)|_BV(ADC1D)|_BV(ADC2D);TCCR1A=0;TCCR1B=0;TCNT1=0;TIMSK1=0;TCCR1B=_BV(CS11);prev_d=PIND;PCMSK2=_BV(PCINT18)|_BV(PCINT19)|_BV(PCINT21)|_BV(PCINT22)|_BV(PCINT23);PCICR=_BV(PCIE2);sei();
#if ENABLE_WATCHDOG
wdt_enable(WDTO_1S);
#endif
rgb(0,0,0);
#if H743_TELEMETRY
Serial.begin(H743_BAUD);
#elif DIAGNOSTICS
Serial.begin(115200);
#endif
}
void navoTick(){static uint32_t last_sensors=0,last_led=0;
#if H743_TELEMETRY
static uint32_t last_h743=0;
#endif
#if DIAGNOSTICS
static uint32_t last_serial=0;
#endif
wdt_reset();uint32_t now=millis();uint16_t p[5];uint32_t t[5];ATOMIC_BLOCK(ATOMIC_RESTORESTATE){for(uint8_t i=0;i<5;i++){p[i]=pulse[i];t[i]=seen[i];}}bool valid[5];for(uint8_t i=0;i<5;i++)valid[i]=t[i]&&now-t[i]<60;control(p[0],valid[0],now);water(now);
if(now-last_sensors>=200){last_sensors=now;uint16_t a=adc(0);battery_mv=(uint32_t)((uint64_t)a*ADC_REF_MV*122/(22UL*1023UL));uint16_t n=adc(1);temp_fault=(n<110||n>1018);if(!temp_fault){float ohm=10000.0f*n/(1023.0f-n)-1000.0f;if(ohm<=0)temp_fault=true;else temp_c=(int16_t)(1.0f/(1.0f/298.15f+logf(ohm/10000.0f)/3950.0f)-273.15f);}for(uint8_t i=0;i<2;i++){if(valid[i+2]&&last_hop[i]&&abs((int)p[i+2]-(int)last_hop[i])>250)blue_until=now+1200;if(valid[i+2])last_hop[i]=p[i+2];}}
bool hot=!temp_fault&&temp_c>=60,low=battery_mv<13200;if(battery_mv<12500||hot||temp_fault)head=false;if(head)PORTB|=_BV(PB0);else PORTB&=~_BV(PB0);if(pos)PORTB|=_BV(PB1);else PORTB&=~_BV(PB1);if(!(PINB&_BV(PB4))){if(!ack_since)ack_since=now;if(now-ack_since>2000&&dry_count>=4){water_latched=false;water_fault=false;}}else ack_since=0;bool alarm=water_latched||water_fault||hot||temp_fault||low;bool beep=water_latched?(now%1000<150||(now%1000>=300&&now%1000<450)):alarm?(now%3000<120):false;if(beep)PORTB|=_BV(PB2);else PORTB&=~_BV(PB2);
if(now-last_led>=100){last_led=now;if(water_latched){if((now/250)%2)rgb(60,0,0);else rgb(45,45,45);}else if(water_fault||temp_fault){if((now/500)%2)rgb(45,0,45);else rgb(0,0,0);}else if(hot)rgb(60,0,45);else if(low)rgb(60,0,0);else if((int32_t)(blue_until-now)>0)rgb(0,0,50);else if(battery_mv<14400||temp_c>=50)rgb(45,25,0);else rgb(0,45,0);}
#if H743_TELEMETRY
if(now-last_h743>=H743_PERIOD_MS){last_h743=now;NavoTelemetryState s;s.battery_mV=battery_mv;s.temp_c10=temp_fault?(int16_t)-32768:(int16_t)(temp_c*10);s.water=water_latched;s.waterFault=water_fault;s.headlight=head;s.position=pos;s.hopperLeftUs=valid[2]?p[2]:0;s.hopperRightUs=valid[3]?p[3]:0;s.rudderUs=valid[4]?p[4]:0;s.alarmMask=(water_latched?1:0)|(water_fault?2:0)|(low?4:0)|((hot||temp_fault)?8:0);h743.send(s,now);}
#endif
#if DIAGNOSTICS
if(now-last_serial>=1000){last_serial=now;Serial.print(F("RC="));Serial.print(p[0]);Serial.print(F(" valid="));Serial.print(valid[0]);Serial.print(F(" BAT_mV="));Serial.print(battery_mv);Serial.print(F(" TEMP_C="));Serial.print(temp_c);Serial.print(F(" temp_fault="));Serial.print(temp_fault);Serial.print(F(" water_alarm="));Serial.print(water_latched);Serial.print(F(" water_fault="));Serial.print(water_fault);Serial.print(F(" HEAD="));Serial.print(head);Serial.print(F(" POS="));Serial.println(pos);}
#endif
}
