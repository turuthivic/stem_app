require "open3"
require "json"
require "fileutils"
require "tmpdir"

class AudioSeparationJob < ApplicationJob
  queue_as :default

  def perform(audio_file)
    # Guard clause: Check if audio_file still exists
    # This handles the case where the audio file was deleted while job was queued
    unless audio_file && audio_file.persisted?
      Rails.logger.info "AudioSeparationJob skipped: AudioFile no longer exists"
      return
    end

    # Create a separation job record to track progress
    separation_job = audio_file.separation_jobs.build(
      separation_type: :vocals_accompaniment,
      status: :pending
    )
    separation_job.save!

    begin
      # Mark job as started
      separation_job.mark_as_started!

      # Check if job was cancelled (audio file deleted during processing)
      separation_job.reload
      if separation_job.cancelled?
        Rails.logger.info "AudioSeparationJob cancelled for job #{separation_job.id}"
        return
      end

      # Perform the actual audio separation
      # Note: This method now handles stem attachment internally before cleanup
      success = separate_audio_file(audio_file, separation_job)

      if success
        # Mark audio file as completed
        audio_file.update!(status: :completed)
        separation_job.mark_as_completed!

        Rails.logger.info "Audio separation completed for AudioFile #{audio_file.id}"
      else
        raise StandardError, "Audio separation failed"
      end

    rescue ActiveRecord::RecordNotFound => e
      # Audio file was deleted during processing - this is expected behavior
      Rails.logger.info "AudioSeparationJob stopped: AudioFile was deleted during processing"
      # Don't raise error - this is not a failure, just a cancellation
      return
    rescue => e
      # Only update records if they still exist
      begin
        audio_file.reload
        separation_job.reload

        Rails.logger.error "Audio separation failed for AudioFile #{audio_file.id}: #{e.message}"
        audio_file.update!(status: :failed)
        separation_job.mark_as_failed!(e.message)
      rescue ActiveRecord::RecordNotFound
        Rails.logger.info "Cannot mark job as failed - records were deleted"
      end

      raise e
    end
  end

  private

  def separate_audio_file(audio_file, separation_job)
    # Create temporary directory for processing
    temp_dir = Dir.mktmpdir("audio_separation_#{audio_file.id}")

    begin
      # Download the original file to temp directory
      input_path = File.join(temp_dir, "input#{File.extname(audio_file.original_file.filename.to_s)}")

      # Write the file using File.open to ensure proper file handling
      File.open(input_path, "wb") do |file|
        file.write(audio_file.original_file.download)
      end

      # Verify file was written successfully
      unless File.exist?(input_path) && File.size(input_path) > 0
        raise StandardError, "Failed to write input file to #{input_path}"
      end

      Rails.logger.info "Input file written to #{input_path} (#{File.size(input_path)} bytes)"

      # Create output directory
      output_dir = File.join(temp_dir, "output")
      Dir.mkdir(output_dir)

      # Run Python separation script (using Demucs ML-based separation)
      script_path = Rails.root.join("lib", "audio_processing", "separate_audio.py")
      command = [
        "python3",
        script_path.to_s,
        input_path,
        output_dir,
        "--job-id", separation_job.id.to_s
      ]

      Rails.logger.info "Running separation command: #{command.join(' ')}"

      # Execute the command with real-time progress tracking
      Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
        stdin.close

        # Read progress updates from stdout
        result = nil
        stdout.each_line do |line|
          begin
            json_output = JSON.parse(line)

            case json_output["status"]
            when "progress"
              # Update separation job progress
              separation_job.update_progress!(json_output["progress"])
              Rails.logger.info "Separation progress for job #{separation_job.id}: #{json_output['progress']}% - #{json_output['message']}"

            when "success"
              # Final success result
              result = {
                success: true,
                output_paths: json_output["output_paths"],
                duration: json_output["duration"],
                sample_rate: json_output["sample_rate"]
              }

            when "error"
              # Error result
              result = {
                success: false,
                error: json_output["error"] || "Unknown error from separation script"
              }
            end
          rescue JSON::ParserError
            # Skip non-JSON lines (might be debug output)
            Rails.logger.debug "Non-JSON output from separation script: #{line.strip}"
          end
        end

        # Wait for process to complete
        status = wait_thr.value

        unless status.success?
          stderr_output = stderr.read
          Rails.logger.error "Python script failed with exit code #{status.exitstatus}"
          Rails.logger.error "STDERR: #{stderr_output}"
          result = {
            success: false,
            error: "Separation script failed with exit code #{status.exitstatus}. Error: #{stderr_output}"
          }
        else
          # Read any remaining stderr even on success (might have warnings)
          stderr_output = stderr.read
          Rails.logger.info "STDERR (warnings): #{stderr_output}" if stderr_output && !stderr_output.empty?
        end

        # If we didn't get a result from JSON parsing, it's an error
        result ||= {
          success: false,
          error: "No valid result received from separation script"
        }

        # Attach stems BEFORE the ensure block cleans up temp directory
        if result[:success] && result[:output_paths]
          Rails.logger.info "Attaching stems from output paths before cleanup"
          attach_stems(audio_file, result[:output_paths])
          Rails.logger.info "Stems attached successfully"
        end

        # Return success status
        result[:success]
      end

    ensure
      # Clean up temporary directory
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      Rails.logger.info "Cleaned up temporary directory: #{temp_dir}"
    end
  end

  def attach_stems(audio_file, output_paths)
    output_paths.each do |stem_type, file_path|
      next unless File.exist?(file_path)

      case stem_type
      when "vocals"
        File.open(file_path, "rb") do |file|
          audio_file.vocals_stem.attach(
            io: file,
            filename: "#{audio_file.title}_vocals.wav",
            content_type: "audio/wav"
          )
        end
      when "drums"
        File.open(file_path, "rb") do |file|
          audio_file.drums_stem.attach(
            io: file,
            filename: "#{audio_file.title}_drums.wav",
            content_type: "audio/wav"
          )
        end
      when "bass"
        File.open(file_path, "rb") do |file|
          audio_file.bass_stem.attach(
            io: file,
            filename: "#{audio_file.title}_bass.wav",
            content_type: "audio/wav"
          )
        end
      when "other"
        File.open(file_path, "rb") do |file|
          audio_file.other_stem.attach(
            io: file,
            filename: "#{audio_file.title}_other.wav",
            content_type: "audio/wav"
          )
        end
      end
    end
  end
end
