class SeparationJob < ApplicationRecord
  # Associations
  belongs_to :audio_file

  # Enums
  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    cancelled: 4
  }

  enum :separation_type, {
    vocals_accompaniment: "vocals_accompaniment",
    drums_other: "drums_other",
    bass_other: "bass_other",
    piano_other: "piano_other"
  }

  # Validations
  validates :status, presence: true
  validates :separation_type, presence: true
  validates :progress, presence: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_update :broadcast_progress_update, if: -> { saved_change_to_progress? && !Rails.env.test? }
  after_update :update_audio_file_status

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:pending, :running]) }
  scope :finished, -> { where(status: [:completed, :failed, :cancelled]) }

  # Instance methods
  def duration
    return 0 if started_at.nil?

    end_time = completed_at || Time.current
    end_time - started_at
  end

  def estimated_completion
    return nil unless running? && progress > 0

    # ML separation is very CPU-intensive and takes much longer than the progress % suggests
    # Progress 0-30% is fast (initialization), 30-70% is very slow (ML separation), 70-100% is fast (saving)
    # Better to estimate based on audio file duration

    if audio_file&.duration
      # Processing time depends on hardware (GPU vs CPU)
      # GPU (Apple Silicon/NVIDIA): ~0.3-0.5x the audio duration
      # CPU: ~1.5-2.5x the audio duration

      # Check if we have GPU info in progress messages (we could track this better in the future)
      # For now, estimate conservatively assuming CPU, but reduce for typical M2 performance
      multiplier = if audio_file.duration > 300 # 5 minutes
        1.0  # With GPU, even long files are much faster
      else
        0.5  # Short files process very quickly on GPU
      end

      estimated_total_seconds = audio_file.duration * multiplier

      # Adjust based on current progress
      if progress < 30
        # Still in fast initialization phase
        started_at + estimated_total_seconds.seconds
      elsif progress < 70
        # In slow ML separation phase - this is 70% of total time
        elapsed = Time.current - started_at
        # We're in the 70% slow phase, estimate accordingly
        progress_in_slow_phase = (progress - 30) / 40.0  # 30-70 is 40% range
        slow_phase_duration = estimated_total_seconds * 0.7
        remaining_slow_phase = slow_phase_duration * (1 - progress_in_slow_phase)
        fast_phase_remaining = estimated_total_seconds * 0.15  # 15% for final phase
        Time.current + (remaining_slow_phase + fast_phase_remaining).seconds
      else
        # In fast final phase
        elapsed = Time.current - started_at
        remaining_percent = (100 - progress) / 100.0
        estimated_remaining = (estimated_total_seconds * 0.15) * remaining_percent
        Time.current + estimated_remaining.seconds
      end
    else
      # Fallback to simple progress-based calculation
      elapsed = Time.current - started_at
      total_estimated = (elapsed / progress) * 100
      started_at + total_estimated.seconds
    end
  end

  def mark_as_started!
    update!(status: :running, started_at: Time.current, progress: 0)
  end

  def mark_as_completed!
    update!(
      status: :completed,
      completed_at: Time.current,
      progress: 100,
      error_message: nil
    )
  end

  def mark_as_failed!(error_msg)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error_msg
    )
  end

  def update_progress!(new_progress)
    update!(progress: new_progress.clamp(0, 100))
  end

  private

  def set_defaults
    self.status = :pending if status.blank?
    self.separation_type = :vocals_accompaniment if separation_type.blank?
    self.progress = 0.0 if progress.blank?
  end

  def broadcast_progress_update
    # Broadcast progress update via Turbo Streams
    broadcast_replace_to(
      "audio_file_#{audio_file.id}",
      target: "separation_job_#{id}",
      partial: "separation_jobs/progress",
      locals: { separation_job: self }
    )
  end

  def update_audio_file_status
    # Guard against deleted audio files
    return unless audio_file.present?

    case status
    when "running"
      audio_file.update!(status: :processing) if audio_file.uploaded?
    when "completed"
      audio_file.update!(status: :completed) if audio_file.processing?
    when "failed"
      audio_file.update!(status: :failed) if audio_file.processing?
    when "cancelled"
      # Don't update audio file status - it's likely being deleted
      # or has already been deleted
      Rails.logger.info "SeparationJob #{id} cancelled, skipping audio_file status update"
    end
  rescue ActiveRecord::RecordNotFound
    # Audio file was deleted, this is expected for cancelled jobs
    Rails.logger.debug "Audio file not found when updating status for SeparationJob #{id}"
  end
end
