#!/usr/bin/env python3
"""Generate original royalty-free WAV loops and SFX for SuitBreak."""
from __future__ import annotations

import math
import os
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.dirname(__file__)), "audio")


def clamp(v: float) -> int:
    return max(-32767, min(32767, int(v * 32767.0)))


def write_wav(path: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        wf.writeframes(b"".join(struct.pack("<h", clamp(s)) for s in samples))


def env(i: int, n: int, attack: float = 0.02, release: float = 0.08) -> float:
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq: float, seconds: float, volume: float = 0.22, wave_kind: str = "sine") -> list[float]:
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        phase = 2.0 * math.pi * freq * t
        if wave_kind == "tri":
            s = (2.0 / math.pi) * math.asin(math.sin(phase))
        elif wave_kind == "sq":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
        else:
            s = math.sin(phase)
        out.append(s * volume * env(i, n))
    return out


def noise(seconds: float, volume: float = 0.12, seed: int = 1) -> list[float]:
    n = int(seconds * RATE)
    x = seed
    out = []
    for i in range(n):
        x = (1103515245 * x + 12345) & 0x7FFFFFFF
        s = (x / 0x40000000) - 1.0
        out.append(s * volume * env(i, n, 0.01, 0.25))
    return out


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(0.001, max(abs(v) for v in out))
    if peak > 0.95:
        out = [v * 0.95 / peak for v in out]
    return out


def pad(track: list[float], seconds: float) -> list[float]:
    return track + [0.0] * int(seconds * RATE)


def note_seq(freqs: list[float], dur: float, gap: float = 0.02, volume: float = 0.2, kind: str = "sine") -> list[float]:
    out: list[float] = []
    silence = [0.0] * int(gap * RATE)
    for f in freqs:
        out += tone(f, dur, volume, kind) + silence
    return out


def loop_music(chords: list[list[float]], beat: float, bars: int, bass_oct: float = 0.5) -> list[float]:
    out: list[float] = []
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        # pad chord
        parts = [tone(f, beat * 4, 0.07, "tri") for f in chord]
        parts.append(tone(chord[0] * bass_oct, beat * 4, 0.09, "sine"))
        # arpeggio
        arp = []
        for step in range(8):
            f = chord[step % len(chord)] * (2.0 if step % 4 == 3 else 1.0)
            arp += tone(f, beat * 0.5, 0.08 if bar % 2 == 0 else 0.06, "sine")
        parts.append(arp)
        # soft kick each beat
        for b in range(4):
            kick = tone(70.0, beat * 0.18, 0.11, "sine")
            parts.append([0.0] * int(b * beat * RATE) + kick)
        out += mix(*parts)
    # loop-friendly fade edges
    fade = int(0.04 * RATE)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def main() -> None:
    music_dir = os.path.join(ROOT, "music")
    sfx_dir = os.path.join(ROOT, "sfx")

    # Menu: calm C major
    menu = loop_music(
        [
            [261.63, 329.63, 392.00],
            [220.00, 261.63, 329.63],
            [196.00, 246.94, 293.66],
            [174.61, 220.00, 261.63],
        ],
        beat=0.42,
        bars=8,
    )
    write_wav(os.path.join(music_dir, "menu.wav"), menu)

    # Lobby: brighter, slightly quicker E minor pentatonic-ish
    lobby = loop_music(
        [
            [329.63, 392.00, 493.88],
            [293.66, 369.99, 440.00],
            [246.94, 329.63, 392.00],
            [220.00, 277.18, 329.63],
        ],
        beat=0.36,
        bars=8,
        bass_oct=0.5,
    )
    write_wav(os.path.join(music_dir, "lobby.wav"), lobby)

    # Gameplay: darker, more pulse
    game = loop_music(
        [
            [196.00, 246.94, 293.66],
            [174.61, 220.00, 261.63],
            [146.83, 196.00, 246.94],
            [164.81, 196.00, 246.94],
        ],
        beat=0.32,
        bars=8,
        bass_oct=0.5,
    )
    write_wav(os.path.join(music_dir, "game.wav"), game)

    write_wav(os.path.join(sfx_dir, "ui_click.wav"), mix(tone(880, 0.06, 0.22), tone(1320, 0.04, 0.12)))
    write_wav(os.path.join(sfx_dir, "host.wav"), note_seq([392.00, 523.25, 659.25], 0.12, 0.04, 0.22))
    write_wav(os.path.join(sfx_dir, "join.wav"), note_seq([523.25, 659.25, 783.99], 0.1, 0.03, 0.22))
    write_wav(
        os.path.join(sfx_dir, "play_card.wav"),
        mix(noise(0.09, 0.18, 17), tone(180, 0.12, 0.2, "tri"), tone(90, 0.08, 0.12)),
    )
    write_wav(
        os.path.join(sfx_dir, "discard.wav"),
        mix(
            noise(0.28, 0.16, 91),
            tone(140, 0.22, 0.14, "tri"),
            pad(tone(220, 0.12, 0.1), 0.08),
        ),
    )
    write_wav(os.path.join(sfx_dir, "win.wav"), note_seq([523.25, 659.25, 783.99, 1046.50], 0.16, 0.05, 0.24))
    write_wav(os.path.join(sfx_dir, "lose.wav"), note_seq([392.00, 329.63, 261.63, 196.00], 0.2, 0.06, 0.2, "tri"))
    write_wav(os.path.join(sfx_dir, "illegal.wav"), mix(tone(180, 0.16, 0.18, "sq"), tone(190, 0.16, 0.1, "sq")))
    write_wav(os.path.join(sfx_dir, "player_join.wav"), note_seq([440.00, 554.37], 0.1, 0.05, 0.18))
    write_wav(os.path.join(sfx_dir, "start_match.wav"), note_seq([261.63, 329.63, 392.00, 523.25], 0.1, 0.03, 0.2))
    print("Wrote audio under", ROOT)


if __name__ == "__main__":
    main()
