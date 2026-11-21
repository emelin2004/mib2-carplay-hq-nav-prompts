# Analysis: CarPlay navigation prompt audio on MHI2_ER_AU57x_K3663_1

All addresses refer to `/mnt/app/eso/lib/libairplay.so` from MU1425 (694088 bytes, SHA1 `fa413305f4aebfe94c80cf454647d2042a507a45`). It is an ARM, QNX 6 build of Apple's CarPlay receiver. In this file, file offset = virtual address.

## AirPlay audio formats

CarPlay negotiates a format per audio stream from a bitmask the receiver offers:

| Bit | Format |
|---|---|
| `0x4` | PCM 8 kHz mono |
| `0x10` | PCM 16 kHz mono |
| `0x40` | PCM 24 kHz mono |
| `0x800` | PCM 44.1 kHz stereo |
| `0x4000` | PCM 48 kHz mono |
| `0x8000` | PCM 48 kHz stereo |

The stream types are 100 (main: Siri, calls, media), 101 (alternate: navigation prompts) and 102 (buffered media). The log string `100 - main, 101 - alternate` confirms this.

## Stock code

`AudioSessionGetSupportedInputFormats` (0x42e54) is `mov r0,#0x10; mov r1,#0; bx lr`, so it returns 16 kHz mono for every stream.

`AudioSessionGetSupportedOutputFormats` (0x43214):

```
43214  push  {r4-r7,lr}
4321c  mov   r7, r0                ; stream type
43220  bl    AudioSessionGetSupportedInputFormats   ; r0:r1 = 0x10
43228  cmp   r7, #0x65             ; 101 ?
43230  movne r4, #0x8000           ; other streams: 48 kHz stereo
43238  moveq r4, #0x10             ; stream 101: 16 kHz mono
4323c  movne r5, #0
43240  moveq r5, #0
43244  orr   r4, r4, r0            ; | input formats (0x10)
4324c  orr   r5, r5, r1
...    log "<AirPlay> Supported output formats: %#X"
43284  mov   r0, r4 ; mov r1, r5   ; 64-bit result
```

Result: stream 101 gets `0x10`. Every other stream gets `0x8010`.

No instruction between the `cmp` at 0x43228 and 0x43244 sets flags, so the EQ/NE condition is still valid at 0x43244.

## Patch

| Offset | Stock | 24 kHz | 48 kHz |
|---|---|---|---|
| 0x43238 | `10 40 a0 03` moveq r4,#0x10 | `40 40 a0 03` moveq r4,#0x40 | `01 49 a0 03` moveq r4,#0x4000 |
| 0x43244 | `00 40 84 e1` orr r4,r4,r0 | `00 40 84 11` orrne r4,r4,r0 | `00 40 84 11` orrne r4,r4,r0 |

Changing the `orr` to `orrne` stops the input mask (`0x10`) being OR'd back in for stream 101, so 16 kHz is no longer offered at all. On MHI2Q the iPhone kept choosing 16 kHz whenever it was still in the list. The result is `0x40` or `0x4000` for stream 101, and an unchanged `0x8010` for every other stream.

Patched SHA1:

- 24 kHz: `e8f2a206d0027d9b958682bdce7c05b8ecdeb23a`
- 48 kHz: `5e977f44f82f733b1ad37705671b4fd9428b6dc6`

## Playback path

- `AirPlayAudioFormatToASBD` (0x27ed4) turns `0x4000` into `lpcm` at 48000 Hz, 16-bit, 1 channel. It uses the same code as `0x40`, with a different rate.
- `AudioStreamPrepare` (0x442d8) sends stream 100 to an nvaudio device chosen by audio type: `MPL5` for media, `TEL2` for telephony, `ANN4` for speech. Every other stream, including 101, goes to the nvaudio device `ANN3`. It then calls `nvaudio_set_pcm_info` with the negotiated rate, bit depth and channel count. There is no rate whitelist.
- `libnvaudio.so` has a sample-rate converter and only rejects a rate of 0. The TDM outputs run at 48 kHz, so 48 kHz prompts need no resampling.
- Unlike MHI2Q, there is no fixed 16 kHz QSA device in this path, so no re-routing is needed.

## Integrity

No checksum or signature check of `libairplay.so` was found in the app partition. Only `dio_manager` loads the library.
