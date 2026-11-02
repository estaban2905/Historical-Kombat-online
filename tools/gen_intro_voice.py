#!/usr/bin/env python3
"""Genera la narración de la intro (assets/sounds/intro/voice_N.wav).

Uso (Windows 10/11, desde la carpeta del proyecto; necesita ffmpeg y ffprobe en el PATH):
    python tools/gen_intro_voice.py

Usa la voz masculina española de Windows ("Microsoft Raul", API Windows.Media.SpeechSynthesis) y
ffmpeg la deja grave, anciana y solemne, "voz de lo alto": tono muy bajo, vibrato leve, una capa
una octava más grave y mucha reverberación. Es una voz PROVISIONAL: se puede reemplazar por una
grabación humana con los mismos nombres de archivo. El texto de cada frase es el mismo que se
muestra como subtítulo en scripts/ui/intro_screen.gd (SUBS). Al regenerar, la salida imprime la
duración de cada archivo: pásala a VOICE_LEN en intro_screen.gd.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds" / "intro"

LINES = [
    "Cuatro mentes de épocas distintas construyeron una máquina para ver todo el tiempo a la vez. La llamaron el Reloj del Origen.",
    "Funcionó... demasiado bien. Rompió el tiempo, y de la grieta nació el Nexo, el poder que sostiene todas las épocas.",
    "Los mundos chocaron. Reyes, guerreros y profetas fueron arrancados de su época y arrojados a un mismo campo de ruinas.",
    "Entonces el Nexo habló: solo uno de ustedes podrá reclamar mi poder. El último en pie decidirá si el tiempo se repara... o se escribe de nuevo.",
    "Aliados no hay. Épocas no hay. Reglas no hay.",
    "La historia se escribe a golpes.",
]

PS = r"""
param([string]$TextFile, [string]$OutFile)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType=WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) {
    $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $t.Wait(-1) | Out-Null
    $t.Result
}
$s = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$s.Voice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -like '*Raul*' } | Select-Object -First 1
$s.Options.SpeakingRate = 0.8
$s.Options.AudioPitch = 0.7
$text = [IO.File]::ReadAllText($TextFile, [Text.Encoding]::UTF8)
$stream = Await ($s.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
$reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
[void](Await ($reader.LoadAsync([uint32]$stream.Size)) ([uint32]))
$bytes = New-Object byte[] $stream.Size
$reader.ReadBytes($bytes)
[IO.File]::WriteAllBytes($OutFile, $bytes)
"""

# Voz anciana y solemne:
#  - asetrate/atempo: baja el tono (~un cuarto) y deja el ritmo pausado.
#  - vibrato: temblor leve de la edad.
#  - capa a una octava más grave (b) mezclada por debajo: voz "doble", de gran tamaño.
#  - recorte de agudos y refuerzo de graves; después reverberación de catedral.
FILTER = (
    "[0:a]asetrate=22050*0.78,aresample=22050,atempo=0.92,vibrato=f=4.2:d=0.05,"
    "equalizer=f=120:t=q:w=1:g=5,equalizer=f=3200:t=q:w=1:g=-7,lowpass=f=5200,asplit=2[a][b];"
    "[b]asetrate=22050*0.5,aresample=22050,atempo=2.0,volume=0.45[low];"
    "[a][low]amix=inputs=2:duration=first:normalize=0,"
    "aecho=0.8:0.88:110|230|470:0.40|0.28|0.16,alimiter=limit=0.95,volume=1.5"
)

def render(lines: list, out_dir: Path, prefix: str) -> None:
    """Sintetiza cada frase y la deja procesada en out_dir/<prefix>_N.wav (imprime su duración)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "tts.ps1"
        script.write_text(PS, encoding="utf-8-sig")
        for i, text in enumerate(lines, start=1):
            txt = Path(tmp) / f"l{i}.txt"
            raw = Path(tmp) / f"l{i}.wav"
            txt.write_text(text, encoding="utf-8")
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                            str(txt), str(raw)], check=True)
            dest = out_dir / f"{prefix}_{i}.wav"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-filter_complex", FILTER,
                            "-ac", "1", "-ar", "22050", str(dest)], check=True)
            print(dest.name, subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(dest)],
                capture_output=True, text=True).stdout.strip(), "s")

def main() -> None:
    render(LINES, OUT, "voice")

if __name__ == "__main__":
    sys.exit(main())
