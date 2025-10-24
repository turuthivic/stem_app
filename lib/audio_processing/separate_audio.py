#!/usr/bin/env python3
"""
Audio separation script using Demucs for STEM processing.
This script separates audio into vocals and accompaniment stems.
"""

import sys
import os
import json
import argparse
import tempfile
import shutil
from pathlib import Path
import traceback

try:
    import torch
    import torchaudio
    import demucs.api
    import librosa
    import soundfile as sf
    import numpy as np
except ImportError as e:
    print(json.dumps({
        "status": "error",
        "error": f"Missing dependency: {e}",
        "message": "Please install required packages: pip install -r requirements.txt"
    }))
    sys.exit(1)

def update_progress(progress, message="Processing..."):
    """Send progress update to stdout as JSON"""
    print(json.dumps({
        "status": "progress",
        "progress": progress,
        "message": message
    }), flush=True)

def separate_audio(input_path, output_dir, job_id=None):
    """
    Separate audio file into vocals and accompaniment using Demucs.

    Args:
        input_path: Path to input audio file
        output_dir: Directory to save separated stems
        job_id: Optional job ID for tracking

    Returns:
        dict: Status and paths to separated files
    """
    try:
        update_progress(0, "Initializing audio separation...")

        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)

        # Load the audio file to verify it's valid
        update_progress(10, "Loading audio file...")
        try:
            waveform, sample_rate = torchaudio.load(input_path)
        except Exception as e:
            # Fallback to librosa for more format support
            audio_data, sample_rate = librosa.load(input_path, sr=None, mono=False)
            if len(audio_data.shape) == 1:
                audio_data = audio_data[np.newaxis, :]
            waveform = torch.from_numpy(audio_data).float()

        # Convert to stereo if mono
        if waveform.shape[0] == 1:
            waveform = waveform.repeat(2, 1)

        update_progress(20, "Preparing separation model...")

        # Use Demucs for separation
        # htdemucs is a good balance of quality and speed
        separator = demucs.api.Separator(model="htdemucs")

        update_progress(30, "Running audio separation...")

        # Perform separation
        waveform_np = waveform.numpy()

        # Demucs expects (channels, samples) format
        if len(waveform_np.shape) == 2 and waveform_np.shape[0] == 2:
            separated = separator(waveform_np, sample_rate=sample_rate)
        else:
            # Convert to stereo if needed
            if len(waveform_np.shape) == 1:
                waveform_np = np.stack([waveform_np, waveform_np])
            separated = separator(waveform_np, sample_rate=sample_rate)

        update_progress(70, "Processing separated stems...")

        # Extract vocals and accompaniment (other stems)
        stems = {}

        # Demucs typically returns: drums, bass, other, vocals
        if 'vocals' in separated:
            stems['vocals'] = separated['vocals']

            # Combine everything except vocals for accompaniment
            accompaniment = None
            for key in separated:
                if key != 'vocals':
                    if accompaniment is None:
                        accompaniment = separated[key]
                    else:
                        accompaniment += separated[key]
            stems['accompaniment'] = accompaniment
        else:
            # Fallback: assume first stem is vocals, combine rest as accompaniment
            stem_keys = list(separated.keys())
            if len(stem_keys) >= 1:
                stems['vocals'] = separated[stem_keys[0]]

                accompaniment = None
                for key in stem_keys[1:]:
                    if accompaniment is None:
                        accompaniment = separated[key]
                    else:
                        accompaniment += separated[key]
                stems['accompaniment'] = accompaniment

        update_progress(80, "Saving separated audio files...")

        # Save stems as WAV files
        output_paths = {}
        for stem_name, stem_audio in stems.items():
            output_path = os.path.join(output_dir, f"{stem_name}.wav")

            # Ensure audio is in correct format for saving
            if isinstance(stem_audio, torch.Tensor):
                stem_audio = stem_audio.numpy()

            # Normalize audio to prevent clipping
            if np.max(np.abs(stem_audio)) > 0:
                stem_audio = stem_audio / np.max(np.abs(stem_audio)) * 0.95

            # Save as WAV
            sf.write(output_path, stem_audio.T, sample_rate)
            output_paths[stem_name] = output_path

        update_progress(100, "Audio separation completed successfully!")

        return {
            "status": "success",
            "message": "Audio separation completed",
            "output_paths": output_paths,
            "job_id": job_id
        }

    except Exception as e:
        error_msg = f"Error during audio separation: {str(e)}"
        traceback.print_exc()
        return {
            "status": "error",
            "error": error_msg,
            "job_id": job_id
        }

def main():
    parser = argparse.ArgumentParser(description='Separate audio into vocals and accompaniment')
    parser.add_argument('input_file', help='Input audio file path')
    parser.add_argument('output_dir', help='Output directory for separated stems')
    parser.add_argument('--job-id', help='Job ID for tracking')

    args = parser.parse_args()

    if not os.path.exists(args.input_file):
        print(json.dumps({
            "status": "error",
            "error": f"Input file not found: {args.input_file}"
        }))
        sys.exit(1)

    result = separate_audio(args.input_file, args.output_dir, args.job_id)
    print(json.dumps(result))

    if result["status"] == "error":
        sys.exit(1)

if __name__ == "__main__":
    main()