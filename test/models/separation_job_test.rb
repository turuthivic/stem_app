require "test_helper"

class SeparationJobTest < ActiveSupport::TestCase
  def setup
    @audio_file = AudioFile.new(
      title: "Test Song",
      duration: 180.5,
      file_size: 5_000_000,
      status: :uploaded
    )

    # Create a mock file attachment
    mock_file = Rack::Test::UploadedFile.new(
      StringIO.new("fake audio content"),
      "audio/mpeg",
      original_filename: "test.mp3"
    )
    @audio_file.original_file.attach(mock_file)
    @audio_file.save!

    @separation_job = SeparationJob.new(
      audio_file: @audio_file,
      status: :pending,
      progress: 0.0,
      separation_type: :vocals_accompaniment
    )
  end

  test "should be valid with valid attributes" do
    assert @separation_job.valid?
  end

  test "should belong to audio_file" do
    association = SeparationJob.reflect_on_association(:audio_file)
    assert_equal :belongs_to, association.macro
    assert @separation_job.audio_file == @audio_file
  end

  test "should validate presence of status" do
    @separation_job.status = ""
    assert_not @separation_job.valid?
    assert_includes @separation_job.errors[:status], "can't be blank"
  end

  test "should validate presence of separation_type" do
    @separation_job.separation_type = ""
    assert_not @separation_job.valid?
    assert_includes @separation_job.errors[:separation_type], "can't be blank"
  end

  test "should validate progress is between 0 and 100" do
    @separation_job.progress = -1
    assert_not @separation_job.valid?
    assert_includes @separation_job.errors[:progress], "must be greater than or equal to 0"

    @separation_job.progress = 101
    assert_not @separation_job.valid?
    assert_includes @separation_job.errors[:progress], "must be less than or equal to 100"

    @separation_job.progress = 50
    assert @separation_job.valid?
  end

  test "should have valid status enum" do
    assert @separation_job.pending?

    @separation_job.status = :running
    assert @separation_job.running?

    @separation_job.status = :completed
    assert @separation_job.completed?

    @separation_job.status = :failed
    assert @separation_job.failed?

    @separation_job.status = :cancelled
    assert @separation_job.cancelled?
  end

  test "should have valid separation_type enum" do
    assert @separation_job.vocals_accompaniment?

    @separation_job.separation_type = :drums_other
    assert @separation_job.drums_other?

    @separation_job.separation_type = :bass_other
    assert @separation_job.bass_other?

    @separation_job.separation_type = :piano_other
    assert @separation_job.piano_other?
  end

  test "should set defaults on creation" do
    job = SeparationJob.create!(audio_file: @audio_file)
    assert job.pending?
    assert job.vocals_accompaniment?
    assert_equal 0.0, job.progress
  end

  test "mark_as_started! should update status and timestamps" do
    @separation_job.save!
    @separation_job.mark_as_started!

    assert @separation_job.running?
    assert_not_nil @separation_job.started_at
    assert_equal 0, @separation_job.progress
  end

  test "mark_as_completed! should update status and timestamps" do
    @separation_job.save!
    @separation_job.mark_as_completed!

    assert @separation_job.completed?
    assert_not_nil @separation_job.completed_at
    assert_equal 100, @separation_job.progress
    assert_nil @separation_job.error_message
  end

  test "mark_as_failed! should update status and error message" do
    @separation_job.save!
    error_msg = "Processing failed"
    @separation_job.mark_as_failed!(error_msg)

    assert @separation_job.failed?
    assert_not_nil @separation_job.completed_at
    assert_equal error_msg, @separation_job.error_message
  end

  test "update_progress! should clamp values between 0 and 100" do
    @separation_job.save!

    @separation_job.update_progress!(-10)
    assert_equal 0, @separation_job.progress

    @separation_job.update_progress!(150)
    assert_equal 100, @separation_job.progress

    @separation_job.update_progress!(75)
    assert_equal 75, @separation_job.progress
  end

  test "duration calculation works correctly" do
    @separation_job.save!
    assert_equal 0, @separation_job.duration

    @separation_job.update!(started_at: 1.hour.ago)
    duration = @separation_job.duration
    assert duration > 3500 # Should be around 3600 seconds (1 hour)
    assert duration < 3700
  end

  test "scopes work correctly" do
    @separation_job.save!

    # Test active scope
    active_jobs = SeparationJob.active
    assert_includes active_jobs, @separation_job

    # Test finished scope
    @separation_job.mark_as_completed!
    finished_jobs = SeparationJob.finished
    assert_includes finished_jobs, @separation_job

    active_jobs = SeparationJob.active
    assert_not_includes active_jobs, @separation_job
  end
end