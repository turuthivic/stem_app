#!/usr/bin/env python3
"""
Simple audio separation script for demonstration purposes.
This creates mock vocals and accompaniment stems using basic audio processing.
In production, this would be replaced with actual ML-based separation (Demucs/Spleeter).
"""

import sys
import os
import json
import argparse
import tempfile
import traceback

try:
    import librosa
    import soundfile as sf
    import numpy as np
    from pydub import AudioSegment
except ImportError as e:
    print(json.dumps({
        "status": "error",
        "error": f"Missing dependency: {e}",
        "message": "Please install required packages: pip install librosa soundfile numpy pydub"
    }))
    sys.exit(1)

def update_progress(progress, message="Processing..."):
    """Send progress update to stdout as JSON"""
    print(json.dumps({
        "status": "progress",
        "progress": progress,
        "message": message
    }), flush=True)

def simple_separation(audio_data, sample_rate):
    """
    Simple audio separation using basic signal processing.
    This is a demonstration - real separation would use ML models.

    Args:
        audio_data: Audio data as numpy array
        sample_rate: Sample rate of the audio

    Returns:
        tuple: (vocals, accompaniment) as numpy arrays
    """

    # Convert to stereo if mono
    if len(audio_data.shape) == 1:
        audio_data = np.stack([audio_data, audio_data])
    elif audio_data.shape[0] > 2:
        # Take first two channels if more than stereo
        audio_data = audio_data[:2]

    # Simple center channel extraction for "vocals"
    # This is a basic technique - real separation is much more sophisticated
    if audio_data.shape[0] == 2:
        # Vocals: emphasize center channel (L+R)/2
        vocals = (audio_data[0] + audio_data[1]) / 2

        # Accompaniment: side information (L-R)/2 + some of the center
        accompaniment = (audio_data[0] - audio_data[1]) / 2
        # Add some original signal back to accompaniment to make it sound fuller
        accompaniment = accompaniment + 0.3 * vocals

        # Convert back to stereo
        vocals = np.stack([vocals, vocals])
        accompaniment = np.stack([accompaniment, accompaniment])
    else:
        # Mono - just duplicate with slight processing
        vocals = audio_data * 0.8  # Slightly attenuated original
        accompaniment = audio_data * 0.6  # More attenuated for "backing"

    return vocals, accompaniment

def separate_audio(input_path, output_dir, job_id=None):
    """
    Separate audio file into vocals and accompaniment.

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

        # Load the audio file
        update_progress(20, "Loading audio file...")
        audio_data, sample_rate = librosa.load(input_path, sr=None, mono=False)

        update_progress(40, "Analyzing audio structure...")

        # Get duration for progress tracking
        duration = len(audio_data) / sample_rate if len(audio_data.shape) == 1 else len(audio_data[0]) / sample_rate
        update_progress(50, f"Processing {duration:.1f} seconds of audio...")

        # Perform simple separation
        update_progress(60, "Separating vocals and accompaniment...")
        vocals, accompaniment = simple_separation(audio_data, sample_rate)

        update_progress(80, "Saving separated audio files...")

        # Save stems as MP3 files (192kbps for good quality and smaller size)
        output_paths = {}

        # Normalize audio to prevent clipping
        vocals = vocals / np.max(np.abs(vocals)) * 0.95 if np.max(np.abs(vocals)) > 0 else vocals
        accompaniment = accompaniment / np.max(np.abs(accompaniment)) * 0.95 if np.max(np.abs(accompaniment)) > 0 else accompaniment

        # Helper function to save as MP3
        def save_as_mp3(audio_data, file_path, sample_rate, bitrate="192k"):
            # Create temporary WAV file
            temp_wav = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            try:
                # Write to temporary WAV
                sf.write(temp_wav.name, audio_data.T if audio_data.shape[0] == 2 else audio_data, sample_rate)
                # Convert to MP3 using pydub
                audio = AudioSegment.from_wav(temp_wav.name)
                audio.export(file_path, format="mp3", bitrate=bitrate)
            finally:
                # Clean up temporary file
                temp_wav.close()
                if os.path.exists(temp_wav.name):
                    os.unlink(temp_wav.name)

        # Save vocals as MP3
        vocals_path = os.path.join(output_dir, "vocals.mp3")
        save_as_mp3(vocals, vocals_path, sample_rate)
        output_paths['vocals'] = vocals_path

        # Save accompaniment as MP3
        accompaniment_path = os.path.join(output_dir, "accompaniment.mp3")
        save_as_mp3(accompaniment, accompaniment_path, sample_rate)
        output_paths['accompaniment'] = accompaniment_path

        update_progress(100, "Audio separation completed successfully!")

        return {
            "status": "success",
            "message": "Audio separation completed",
            "output_paths": output_paths,
            "job_id": job_id,
            "duration": duration,
            "sample_rate": sample_rate
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