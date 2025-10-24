require "open3"
require "json"
require "fileutils"
require "tmpdir"

class AudioSeparationJob < ApplicationJob
  queue_as :default

  def perform(audio_file)
    # Create a separation job record to track progress
    separation_job = audio_file.separation_jobs.build(
      separation_type: :vocals_accompaniment,
      status: :pending
    )
    separation_job.save!

    begin
      # Mark job as started
      separation_job.mark_as_started!

      # Perform the actual audio separation
      result = separate_audio_file(audio_file, separation_job)

      if result[:success]
        # Attach the separated stems to the audio file
        attach_stems(audio_file, result[:output_paths])

        # Mark audio file as completed
        audio_file.update!(status: :completed)
        separation_job.mark_as_completed!

        Rails.logger.info "Audio separation completed for AudioFile #{audio_file.id}"
      else
        raise StandardError, result[:error]
      end

    rescue => e
      Rails.logger.error "Audio separation failed for AudioFile #{audio_file.id}: #{e.message}"
      audio_file.update!(status: :failed)
      separation_job.mark_as_failed!(e.message)
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

      # Run Python separation script
      script_path = Rails.root.join("lib", "audio_processing", "simple_separate.py")
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
          result = {
            success: false,
            error: "Separation script failed with exit code #{status.exitstatus}. Error: #{stderr_output}"
          }
        end

        # If we didn't get a result from JSON parsing, it's an error
        result ||= {
          success: false,
          error: "No valid result received from separation script"
        }

        result
      end

    ensure
      # Clean up temporary directory
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
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
      when "accompaniment"
        File.open(file_path, "rb") do |file|
          audio_file.accompaniment_stem.attach(
            io: file,
            filename: "#{audio_file.title}_accompaniment.wav",
            content_type: "audio/wav"
          )
        end
      end
    end
  end
end
