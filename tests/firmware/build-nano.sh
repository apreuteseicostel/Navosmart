#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
avr_root=${AVR_TOOLCHAIN_ROOT:-/usr}
core="$avr_root/share/arduino/hardware/arduino/avr/cores/arduino"
variant="$avr_root/share/arduino/hardware/arduino/avr/variants/eightanaloginputs"
out_dir=${NAVO_FIRMWARE_BUILD_DIR:-"$repo_dir/build/firmware-nano"}
mkdir -p "$out_dir"
export PATH="$avr_root/bin:$PATH"
flags=(-mmcu=atmega328p -DF_CPU=16000000UL -DARDUINO=10819 -DARDUINO_AVR_NANO -DARDUINO_ARCH_AVR -Os -ffunction-sections -fdata-sections -I"$core" -I"$variant" -I"$avr_root/lib/avr/include")
objects=()
for source in "$core"/*.c "$core"/*.cpp "$core"/*.S; do
    name=$(basename "$source"); object="$out_dir/$name.o"
    if [[ "$source" == *.cpp ]]; then
        avr-g++ "${flags[@]}" -std=gnu++11 -fno-exceptions -fno-threadsafe-statics -c "$source" -o "$object"
    else
        avr-gcc "${flags[@]}" -c "$source" -o "$object"
    fi
    objects+=("$object")
done
firmware="$repo_dir/firmware/NAVOMODEL_Arduino"
avr-g++ "${flags[@]}" -std=gnu++11 -fno-exceptions -c "$firmware/Firmware.cpp" -o "$out_dir/Firmware.o"
avr-g++ "${flags[@]}" -std=gnu++11 -fno-exceptions -include Arduino.h -x c++ -c "$firmware/NAVOMODEL_Arduino.ino" -o "$out_dir/sketch.o"
avr-gcc -mmcu=atmega328p -Wl,--gc-sections -o "$out_dir/NAVO_NANO.elf" "${objects[@]}" "$out_dir/Firmware.o" "$out_dir/sketch.o" -lm
avr-objcopy -O ihex -R .eeprom "$out_dir/NAVO_NANO.elf" "$out_dir/NAVO_NANO.hex"
avr-size -C --mcu=atmega328p "$out_dir/NAVO_NANO.elf"
g++ -std=c++11 "$repo_dir/tests/firmware/light-command.cpp" -o "$out_dir/light-command-test"
"$out_dir/light-command-test"
