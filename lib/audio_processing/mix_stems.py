#!/usr/bin/env python3
"""
Audio stem mixing script.
Mixes multiple audio files together and outputs a single mixed MP3 file.
"""

import sys
import os
import json
import argparse
import tempfile

try:
    import soundfile as sf
    import numpy as np
    from pydub import AudioSegment
except ImportError as e:
    print(json.dumps({
        "status": "error",
        "error": f"Missing dependency: {e}",
        "message": "Please install required packages: pip install soundfile numpy pydub"
    }))
    sys.exit(1)


def mix_stems(input_paths, output_path, volumes=None, output_format='mp3', bitrate='192k'):
    """
    Mix multiple audio stems together with optional volume control.

    Args:
        input_paths: List of paths to audio files to mix (WAV or MP3)
        output_path: Path for the output mixed file
        volumes: Optional list of volume multipliers (0.0 to 1.0) for each stem
        output_format: Output format ('mp3' or 'wav'), defaults to 'mp3'
        bitrate: MP3 bitrate (e.g., '192k'), only used if output_format is 'mp3'

    Returns:
        dict: Status and path to mixed file
    """
    try:
        if not input_paths:
            return {
                "status": "error",
                "error": "No input files provided"
            }

        # Default volumes to 1.0 if not provided
        if volumes is None:
            volumes = [1.0] * len(input_paths)
        elif len(volumes) != len(input_paths):
            volumes = volumes + [1.0] * (len(input_paths) - len(volumes))

        # Load all audio files (supports both WAV and MP3)
        audio_data = []
        sample_rate = None

        for i, path in enumerate(input_paths):
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

            # Apply volume
            volume = volumes[i] if i < len(volumes) else 1.0
            data = data * volume

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
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        # Write the mixed audio in the requested format
        if output_format == 'mp3':
            # Create temporary WAV file
            temp_wav = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            try:
                # Write to temporary WAV
                sf.write(temp_wav.name, mixed, sample_rate)
                # Convert to MP3 using pydub
                audio = AudioSegment.from_wav(temp_wav.name)
                audio.export(output_path, format="mp3", bitrate=bitrate)
            finally:
                # Clean up temporary file
                temp_wav.close()
                if os.path.exists(temp_wav.name):
                    os.unlink(temp_wav.name)
        else:
            # Write as WAV
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
    parser.add_argument('output_file', help='Output audio file path')
    parser.add_argument('input_files', nargs='+', help='Input audio files to mix (WAV or MP3)')
    parser.add_argument('--volumes', type=str, default=None,
                        help='Comma-separated volume levels (0.0-1.0) for each input file')
    parser.add_argument('--format', type=str, default='mp3', choices=['mp3', 'wav'],
                        help='Output format (default: mp3)')
    parser.add_argument('--bitrate', type=str, default='192k',
                        help='MP3 bitrate (default: 192k)')

    args = parser.parse_args()

    # Parse volumes if provided
    volumes = None
    if args.volumes:
        try:
            volumes = [float(v) for v in args.volumes.split(',')]
        except ValueError:
            print(json.dumps({
                "status": "error",
                "error": "Invalid volume format. Use comma-separated numbers (e.g., 0.8,1.0,0.5)"
            }))
            sys.exit(1)

    result = mix_stems(args.input_files, args.output_file, volumes, args.format, args.bitrate)
    print(json.dumps(result))

    if result["status"] == "error":
        sys.exit(1)


if __name__ == "__main__":
    main()
