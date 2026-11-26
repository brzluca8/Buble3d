"""Render short original mono cues offline. Runtime playback uses normal WAV resources."""
from array import array
import math
from pathlib import Path
import random
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "board" / "audio"


def render(name, notes):
    """Each strike specifies onset, frequency, decay, volume and noise fraction."""
    size = math.ceil(RATE * max(onset + decay * 7 for onset, _, decay, _, _ in notes))
    mix = [0.0] * size
    rng = random.Random(name)
    for onset, pitch, decay, volume, noise in notes:
        first = round(onset * RATE)
        low = 0.0
        for j in range(min(size - first, round(7 * decay * RATE))):
            t = j / RATE
            low = 0.64 * low + 0.36 * rng.uniform(-1, 1)
            angle = math.tau * pitch * t
            tone = math.sin(angle) + 0.23 * math.sin(2.01 * angle)
            envelope = min(1.0, t / 0.0025) * math.exp(-t / decay)
            mix[first + j] += envelope * volume * ((1 - noise) * tone + noise * low)
    samples = array("h", (int(32767 * max(-1, min(1, s))) for s in mix))
    with wave.open(str(OUT / (name + ".wav")), "wb") as file:
        file.setparams((1, 2, RATE, size, "NONE", "not compressed"))
        file.writeframes(samples.tobytes())


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True, parents=True)
    render("tumble", [(t, f, d, v, .65) for t, f, d, v in [
        (0, 540, .017, .43), (.075, 820, .013, .29), (.19, 620, .022, .34),
        (.34, 390, .025, .52), (.43, 780, .015, .29), (.56, 560, .018, .31),
        (.65, 940, .011, .22), (.72, 690, .011, .17)]])
    render("step", [(0, 285, .016, .32, .65), (.017, 510, .012, .13, .32)])
    render("land", [(0, 180, .043, .40, .35), (.035, 340, .022, .19, .60)])
    render("coin", [(0, 1175, .058, .32, .02), (.067, 1760, .067, .22, .01)])
    render("gem", [(0, 880, .088, .27, .01), (.085, 1319, .11, .23, .01)])
    render("upgrade", [(0, 430, .032, .46, .50), (.105, 587, .07, .31, .08),
                       (.20, 740, .075, .28, .04), (.28, 880, .12, .24, .01)])

    render("button", [(0, 630, .021, .22, .12), (.018, 845, .018, .14, .04)])
    render("contact", [(0, 188, .029, .38, .48), (.009, 780, .014, .19, .73)])
    # Six original two-beat phrases on plucked strings and soft glass.
    tune = [74, 78, 81, 78, 76, 73, 69, 73, 71, 74, 78, 83,
            81, 78, 76, 73, 74, 69, 71, 78, 76, 73, 69, 66]
    notes = []
    hz = lambda midi: 440 * 2 ** ((midi - 69) / 12)
    for i, note in enumerate(tune):
        notes.append((i * .58, hz(note), .15, .155 if i % 2 == 0 else .10, .008))
        if i % 4 == 0:
            notes.append((i * .58, hz([50, 45, 47, 45, 50, 45][i // 4]), .49, .18, .016))
    render("poiana", notes)
