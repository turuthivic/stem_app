#!/usr/bin/env python3
"""
Audio stem mixing script.
Mixes multiple WAV files together and outputs a single mixed WAV file.
"""

import sys
import os
import json
import argparse

try:
    import soundfile as sf
    import numpy as np
except ImportError as e:
    print(json.dumps({
        "status": "error",
        "error": f"Missing dependency: {e}",
        "message": "Please install required packages: pip install soundfile numpy"
    }))
    sys.exit(1)


def mix_stems(input_paths, output_path):
    """
    Mix multiple audio stems together.

    Args:
        input_paths: List of paths to WAV files to mix
        output_path: Path for the output mixed WAV file

    Returns:
        dict: Status and path to mixed file
    """
    try:
        if not input_paths:
            return {
                "status": "error",
                "error": "No input files provided"
            }

        # Load all audio files
        audio_data = []
        sample_rate = None

        for path in input_paths:
            if not os.path.exists(path):
                return {
                    "status": "error",
                    "error": f"Input file not found: {path}"
                }

            data, sr = sf.read(path)

            # Ensure consistent sample rate
            if sample_rate is None:
                sample_rate = sr
            elif sr != sample_rate:
                return {
                    "status": "error",
                    "error": f"Sample rate mismatch: expected {sample_rate}, got {sr} for {path}"
                }

            # Convert mono to stereo if needed
            if len(data.shape) == 1:
                data = np.stack([data, data], axis=1)

            audio_data.append(data)

        # Find the maximum length
        max_length = max(d.shape[0] for d in audio_data)

        # Pad shorter files with zeros
        padded_data = []
        for data in audio_data:
            if data.shape[0] < max_length:
                padding = np.zeros((max_length - data.shape[0], data.shape[1]))
                data = np.vstack([data, padding])
            padded_data.append(data)

        # Mix by summing all stems
        mixed = np.sum(padded_data, axis=0)

        # Normalize to prevent clipping
        max_val = np.max(np.abs(mixed))
        if max_val > 0:
            mixed = mixed / max_val * 0.95

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        # Write the mixed audio
        sf.write(output_path, mixed, sample_rate)

        return {
            "status": "success",
            "message": "Stems mixed successfully",
            "output_path": output_path,
            "sample_rate": sample_rate,
            "duration": max_length / sample_rate,
            "stems_mixed": len(input_paths)
        }

    except Exception as e:
        return {
            "status": "error",
            "error": f"Error mixing stems: {str(e)}"
        }


def main():
    parser = argparse.ArgumentParser(description='Mix multiple audio stems into one file')
    parser.add_argument('output_file', help='Output WAV file path')
    parser.add_argument('input_files', nargs='+', help='Input WAV files to mix')

    args = parser.parse_args()

    result = mix_stems(args.input_files, args.output_file)
    print(json.dumps(result))

    if result["status"] == "error":
        sys.exit(1)


if __name__ == "__main__":
    main()
