#!/usr/bin/env python3
import argparse
import json
import pathlib
import wave

import numpy as np
import mlx_whisper


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio")
    parser.add_argument("--model", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--language", default="auto")
    args = parser.parse_args()

    with wave.open(args.audio, "rb") as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getframerate() != 16000:
            raise ValueError("Expected 16 kHz mono 16-bit PCM WAV")
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(np.float32) / 32768.0

    result = mlx_whisper.transcribe(
        samples,
        path_or_hf_repo=args.model,
        language=None if args.language == "auto" else args.language,
        verbose=True,
    )
    payload = {
        "text": result["text"].strip(),
        "language": result.get("language"),
        "segments": [
            {"start": item["start"], "end": item["end"], "text": item["text"]}
            for item in result.get("segments", [])
        ],
    }
    pathlib.Path(args.output).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
