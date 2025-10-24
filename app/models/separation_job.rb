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

    elapsed = Time.current - started_at
    total_estimated = (elapsed / progress) * 100
    started_at + total_estimated.seconds
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
    case status
    when "running"
      audio_file.update!(status: :processing) if audio_file.uploaded?
    when "completed"
      audio_file.update!(status: :completed) if audio_file.processing?
    when "failed"
      audio_file.update!(status: :failed) if audio_file.processing?
    end
  end
end
