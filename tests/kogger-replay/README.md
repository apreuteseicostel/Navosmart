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

Build against Qt6 Core/Gui and run the actual production decoder:

```sh
cmake -S tests/kogger-replay -B /tmp/navo-replay
cmake --build /tmp/navo-replay -j2
/tmp/navo-replay/navo-kogger-replay /path/to/00028_DownView.klf
```

Tests compare full-read and irregular fragmented replay against both count and
raw byte digest, then cover KP1/KP2 byte-by-byte input, missing fragments,
checksum recovery, measurement type filtering and reset.

The integration extension feeds each real column into the NAVO adapter and
upstream Epoch/Dataset sources. It compares all raw amplitudes and physical
resolution and exercises the adapter's 3,000-record/16 MB retention budget.
A fixed test-only channel UUID is used; missing fixture GPS remains missing.
Dataset is cleared in 128-column batches to bound this test. This does not
validate production Dataset eviction or live channel identity wiring.

This test does not validate Android rendering, GPS/CHART temporal alignment,
bottom-track, mosaic or bathymetry. Those require separate integration tests. The dedicated GitHub workflow installs real Qt6 and
fetches the original fixture; hash mismatch fails the run.
