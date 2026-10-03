# Recorded Kogger CHART regression

Fixture: https://kogger.tech/wp-content/uploads/00028_DownView.klf

Uploaded fixture is 96,835,584 bytes; SHA-256:
`1ff5e23abbdd37e31eeacd7875c4e8a457ccb927641e47ea77c861151ab2ace0`.

The recording uses KP2 (`CC55`), which the previous NAVO decoder ignored.
Its outer frames include proxy traffic. Proxy packets are deliberately excluded
from sonar measurements; treating their embedded payload as a CHART header
produces false resolution/offset values and excessive zero filling.

The non-proxy CHART v0 stream contains 385,561 fragments and 15,423 completed
columns of 5,000 samples at 10 mm resolution, zero absolute offset (50 m range).
Concatenated completed raw columns have SHA-256:
`f597aee532fadf5ec71e48b4fd2f8890ee32c63927023e66d15516dfef745055`.
These reference values were calculated from the uploaded file using a separate
frame walk with Fletcher verification and the upstream KP2 layout. The original
Kogger FrameParser was also compiled and run to check the outer protocol.

The recording begins within a column at seqOffset 2200: missing samples are
zero filled, as in KoggerApp. It ends with an incomplete 200-sample column and
seven trailing bytes. The last column remains pending until the next boundary;
no synthetic boundary or depth is inserted. There are no non-proxy DIST v0
measurements in this fixture. Bottom depth needs a CHART bottom-track processor.

Build with Qt6 Core/Gui/Concurrent/Sql/Quick/Qml/Test:

```sh
cmake -S tests/kogger-replay -B /tmp/navo-replay
cmake --build /tmp/navo-replay -j2
/tmp/navo-replay/navo-kogger-replay /path/to/00028_DownView.klf
/tmp/navo-replay/navo-sonar-ui-replay custom/qml/NavoSonarPro.qml tests/kogger-replay/mock-imports kogger-columns.json
```

The decoder tests compare full-read and irregular fragmented replay against the
count and raw-byte digest, and cover KP1/KP2 fragmentation, missing samples,
checksum recovery, measurement filtering and reset. Dataset/Epoch conversion
must preserve every amplitude and the physical scale. Adapter retention is
bounded to 3,000 records/16 MB.

The processor integration walks the actual upstream FrameParser, reads recorded
MAVLink GPS and attitude, then feeds all completed columns into the production
NavoKoggerService and original bottom/surface algorithms. Native Dataset batches
roll at 3,000 epochs/16 MB and workers stop before clearing shared data. A
fixed test-only link UUID is combined with the recorded route 2.

GPS_RAW_INT fix_type must be at least 3 before recording positions. Initial
GLOBAL_POSITION_INT messages contain (0,0) before a fix; accepting them creates
an incorrect local origin millions of metres from the actual track and breaks
triangulation. Missing fixes remain unlocated. Production input likewise requires
the boat GPS fix and a healthy vehicle link; host arrival is not a device clock.

Processed results retain their own column sequence, host arrival time, heading,
GPS and echo around the detected bottom. Position refreshes do not duplicate
unchanged geo samples. Sequence counters survive decoder reset so delayed
results cannot attach to a new scan's columns. Sonar PRO updates the matching
history column when its delayed bottom result arrives.

The surface test requests the remaining track's actual local bounds, requires
visible tiles and validates positive finite depth cells with triangulation marks.
CSV evidence preserves native height types, including extrapolated cells. These
interpolated/extrapolated surface cells are not additional measured soundings.
DownView has no validated lateral channel geometry, so side-scan mosaic stays
disabled rather than projecting a fabricated swath.

The visual test loads production Sonar PRO with 240 actual columns, checks
DAY/NAVO and landscape/portrait rendering, delayed bottom association and actual
menu/close mouse clicks. Map dependencies are mocked and disabled. Evidence is
exported as PNG and CSV by the dedicated GitHub workflow.

This validates native algorithms and the isolated production ecogram component.
It does not establish GPS/device-clock synchronization, installed Android
end-to-end behavior, live hardware performance, side-scan mosaic geometry or
that the native surface tiles are rendered by the full app's map/3D viewer.
Keep the PR draft until those applicable integration checks are complete.
