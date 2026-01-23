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
    from demucs.pretrained import get_model
    from demucs.apply import apply_model
    import soundfile as sf
    import numpy as np
    import librosa
    from pydub import AudioSegment
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
        update_progress(0, "Initializing Demucs separation...")

        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)

        update_progress(10, "Loading Demucs htdemucs model...")

        # Detect best available device (GPU or CPU)
        if torch.cuda.is_available():
            device = 'cuda'
            update_progress(12, f"Using NVIDIA GPU (CUDA) for acceleration...")
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            device = 'mps'  # Apple Silicon (M1/M2/M3) Metal Performance Shaders
            update_progress(12, f"Using Apple Silicon GPU (Metal) for acceleration...")
        else:
            device = 'cpu'
            update_progress(12, f"Using CPU (no GPU detected)...")

        # Load the pretrained Demucs model
        # htdemucs is a good balance of quality and speed (Hybrid Transformer Demucs)
        model = get_model('htdemucs')
        model.to(device)

        update_progress(20, "Loading audio file...")

        # Load the audio file - try multiple methods for compatibility
        try:
            # First try soundfile for common audio formats (WAV, FLAC, OGG)
            data, sr = sf.read(input_path, always_2d=True)
            wav = torch.from_numpy(data.T).float()  # Convert to torch tensor and transpose to (channels, samples)
        except Exception as e:
            # Fall back to librosa for video files and other formats (uses ffmpeg/audioread)
            # librosa loads as mono by default, so set mono=False to keep stereo
            data, sr = librosa.load(input_path, sr=None, mono=False)
            # librosa returns shape (samples,) for mono or (channels, samples) for stereo
            if data.ndim == 1:
                data = data.reshape(1, -1)  # Add channel dimension for mono
            wav = torch.from_numpy(data).float()

        # Resample if necessary
        if sr != model.samplerate:
            resampler = torchaudio.transforms.Resample(sr, model.samplerate)
            wav = resampler(wav)

        # Ensure correct number of channels
        if wav.shape[0] < model.audio_channels:
            # Mono to stereo: duplicate channel
            wav = wav.repeat(model.audio_channels, 1)
        elif wav.shape[0] > model.audio_channels:
            # Stereo to mono: average channels
            wav = wav.mean(dim=0, keepdim=True)

        # wav shape should be (channels, samples)
        # Store the original sample rate and duration for metadata
        original_sr = sr
        duration = wav.shape[1] / model.samplerate

        update_progress(30, "Running ML-based audio separation...")

        # Apply the model to separate sources
        # apply_model expects shape (batch, channels, samples), so add batch dimension
        wav = wav.unsqueeze(0).to(device)  # Shape: (1, channels, samples) and move to GPU

        # sources shape after processing: (batch, num_sources, channels, samples)
        with torch.no_grad():
            sources = apply_model(model, wav, device=device, split=True, overlap=0.25)

        # Remove batch dimension: (num_sources, channels, samples)
        sources = sources[0]

        update_progress(70, "Processing separated stems...")

        # Get stem names from model
        # model.sources typically contains: ['drums', 'bass', 'other', 'vocals']
        stem_names = model.sources

        # Extract all 4 individual stems
        stems = {}
        for idx, name in enumerate(stem_names):
            stems[name] = sources[idx]

        update_progress(80, "Saving separated audio files...")

        # Helper function to save as MP3
        def save_as_mp3(audio_data, file_path, sample_rate, bitrate="192k"):
            # Create temporary WAV file
            temp_wav = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            try:
                # Write to temporary WAV
                sf.write(temp_wav.name, audio_data, sample_rate)
                # Convert to MP3 using pydub
                audio = AudioSegment.from_wav(temp_wav.name)
                audio.export(file_path, format="mp3", bitrate=bitrate)
            finally:
                # Clean up temporary file
                temp_wav.close()
                if os.path.exists(temp_wav.name):
                    os.unlink(temp_wav.name)

        # Save stems as MP3 files (192kbps for good quality and smaller size)
        output_paths = {}
        for stem_name, stem_audio in stems.items():
            output_path = os.path.join(output_dir, f"{stem_name}.mp3")

            # Move to CPU and convert to numpy
            stem_audio = stem_audio.cpu().numpy()

            # Normalize audio to prevent clipping
            max_val = np.max(np.abs(stem_audio))
            if max_val > 0:
                stem_audio = stem_audio / max_val * 0.95

            # Transpose to [samples, channels] for soundfile
            stem_audio = stem_audio.T

            # Save as MP3
            save_as_mp3(stem_audio, output_path, model.samplerate)
            output_paths[stem_name] = output_path

        update_progress(100, "Audio separation completed successfully!")

        return {
            "status": "success",
            "message": "ML-based audio separation completed with Demucs htdemucs",
            "output_paths": output_paths,
            "job_id": job_id,
            "sample_rate": model.samplerate,
            "duration": duration
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