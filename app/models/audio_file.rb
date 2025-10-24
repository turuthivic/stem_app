class AudioFile < ApplicationRecord
  # Active Storage attachments
  has_one_attached :original_file
  has_one_attached :vocals_stem
  has_one_attached :accompaniment_stem

  # Associations
  has_many :separation_jobs, dependent: :destroy

  # Enums
  enum :status, {
    uploaded: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :original_file, presence: true
  validates :status, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :file_size, presence: true, numericality: { greater_than: 0 }

  validate :acceptable_audio_format

  # Callbacks
  before_validation :extract_metadata, if: -> { original_file.attached? }
  after_create :enqueue_separation_job, unless: -> { Rails.env.test? }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }

  private

  def acceptable_audio_format
    return unless original_file.attached?

    # Check both content type and file extension for better validation
    acceptable_types = %w[audio/mpeg audio/wav audio/flac audio/m4a audio/mp4]
    acceptable_extensions = %w[.mp3 .wav .flac .m4a .mp4]

    filename = original_file.filename.to_s.downcase
    file_extension = File.extname(filename)
    content_type = original_file.content_type

    # Accept if either content type OR extension is valid
    valid_format = acceptable_types.include?(content_type) || acceptable_extensions.include?(file_extension)

    unless valid_format
      errors.add(:original_file, "must be an audio file (MP3, WAV, FLAC, M4A)")
    end

    # Size limit: 100MB
    if original_file.byte_size > 100.megabytes
      errors.add(:original_file, "must be less than 100MB")
    end
  end

  def extract_metadata
    return unless original_file.attached?

    # Extract title from filename if not provided
    if title.blank?
      self.title = original_file.filename.base
    end

    # Set file size from attachment
    self.file_size = original_file.byte_size

    # Set duration if not provided (for now, use a placeholder)
    # In production, this would use ffprobe to get actual duration
    if duration.blank? || duration == 0.0
      # For testing/demo purposes, estimate based on file size
      # 1MB ≈ 1 minute (very rough estimate for compressed audio)
      estimated_duration = (original_file.byte_size / 1_000_000.0) * 60.0
      self.duration = [estimated_duration, 30.0].max # Minimum 30 seconds
    end
  end

  def enqueue_separation_job
    AudioSeparationJob.perform_later(self)
  end
end
