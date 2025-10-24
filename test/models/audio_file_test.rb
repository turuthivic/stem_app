require "test_helper"

class AudioFileTest < ActiveSupport::TestCase
  def setup
    @audio_file = AudioFile.new(
      title: "Test Song",
      duration: 180.5,
      file_size: 5_000_000,
      status: :uploaded
    )
  end

  test "should be valid with valid attributes" do
    # Create a mock file attachment
    mock_file = Rack::Test::UploadedFile.new(
      StringIO.new("fake audio content"),
      "audio/mpeg",
      original_filename: "test.mp3"
    )
    @audio_file.original_file.attach(mock_file)

    assert @audio_file.valid?
  end

  test "should validate presence of title" do
    @audio_file.title = nil
    assert_not @audio_file.valid?
    assert_includes @audio_file.errors[:title], "can't be blank"
  end

  test "should validate presence of original_file" do
    assert_not @audio_file.valid?
    assert_includes @audio_file.errors[:original_file], "can't be blank"
  end

  test "should validate duration is greater than 0" do
    @audio_file.duration = 0
    assert_not @audio_file.valid?
    assert_includes @audio_file.errors[:duration], "must be greater than 0"

    @audio_file.duration = -1
    assert_not @audio_file.valid?
  end

  test "should validate file_size is greater than 0" do
    @audio_file.file_size = 0
    assert_not @audio_file.valid?
    assert_includes @audio_file.errors[:file_size], "must be greater than 0"
  end

  test "should have valid status enum" do
    assert @audio_file.uploaded?

    @audio_file.status = :processing
    assert @audio_file.processing?

    @audio_file.status = :completed
    assert @audio_file.completed?

    @audio_file.status = :failed
    assert @audio_file.failed?
  end

  test "should have many separation_jobs" do
    assert_respond_to @audio_file, :separation_jobs
    association = AudioFile.reflect_on_association(:separation_jobs)
    assert_equal :has_many, association.macro
  end

  test "should have attached files" do
    assert_respond_to @audio_file, :original_file
    assert_respond_to @audio_file, :vocals_stem
    assert_respond_to @audio_file, :accompaniment_stem
  end

  test "scopes work correctly" do
    # Test recent scope
    assert_respond_to AudioFile, :recent

    # Test by_status scope
    assert_respond_to AudioFile, :by_status
  end
end