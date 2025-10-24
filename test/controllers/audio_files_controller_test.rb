require "test_helper"

class AudioFilesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @audio_file = AudioFile.new(
      status: :uploaded
    )

    # Create a mock file attachment
    mock_file = Rack::Test::UploadedFile.new(
      StringIO.new("fake audio content" * 1000), # Make it bigger for realistic file size
      "audio/mpeg",
      original_filename: "test.mp3"
    )
    @audio_file.original_file.attach(mock_file)
    @audio_file.save!
  end

  test "should get index" do
    get audio_files_url
    assert_response :success
    assert_select "h1", "Audio File Separator"
  end

  test "should create audio_file with valid upload" do
    file = fixture_file_upload("test.mp3", "audio/mpeg")

    assert_difference("AudioFile.count", 1) do
      post audio_files_url, params: {
        audio_file: {
          original_file: file
        }
      }
    end

    assert_redirected_to audio_file_url(AudioFile.last)

    # Verify metadata was extracted
    audio_file = AudioFile.last
    assert_equal "test", audio_file.title
    assert audio_file.duration > 0
    assert audio_file.file_size > 0
  end

  test "should create audio_file with turbo stream" do
    file = fixture_file_upload("test.mp3", "audio/mpeg")

    assert_difference("AudioFile.count", 1) do
      post audio_files_url,
           params: {
             audio_file: {
               original_file: file
             }
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type

    # Verify metadata was extracted
    audio_file = AudioFile.last
    assert_equal "test", audio_file.title
    assert audio_file.duration > 0
    assert audio_file.file_size > 0
  end

  test "should reject invalid file formats with turbo stream" do
    file = fixture_file_upload("test.txt", "text/plain")

    assert_no_difference("AudioFile.count") do
      post audio_files_url,
           params: { audio_file: { title: "Invalid File", original_file: file } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "should show audio_file" do
    get audio_file_url(@audio_file)
    assert_response :success
  end

  test "should get edit" do
    get edit_audio_file_url(@audio_file)
    assert_response :success
  end

  test "should update audio_file" do
    patch audio_file_url(@audio_file), params: { audio_file: { title: "Updated Title" } }
    assert_redirected_to audio_file_url(@audio_file)

    @audio_file.reload
    assert_equal "Updated Title", @audio_file.title
  end

  test "should destroy audio_file" do
    assert_difference("AudioFile.count", -1) do
      delete audio_file_url(@audio_file)
    end

    assert_redirected_to audio_files_url
  end

  test "should destroy audio_file with turbo stream" do
    assert_difference("AudioFile.count", -1) do
      delete audio_file_url(@audio_file),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "should serve stems for completed audio file" do
    # Mark as completed and attach stems
    @audio_file.update!(status: :completed)

    # Create mock stem files
    vocals_file = StringIO.new("fake vocals content")
    @audio_file.vocals_stem.attach(io: vocals_file, filename: "vocals.wav", content_type: "audio/wav")

    get stems_audio_file_url(@audio_file, stem_type: "vocals")
    assert_response :success
    assert_equal "audio/wav", response.content_type
  end

  test "should return not found for missing stems" do
    get stems_audio_file_url(@audio_file, stem_type: "vocals")
    assert_response :not_found
  end

  test "should return not found for invalid stem type" do
    get stems_audio_file_url(@audio_file, stem_type: "invalid")
    assert_response :not_found
  end

  test "should serve downloads for completed audio file" do
    @audio_file.update!(status: :completed)

    # Create mock stem files
    vocals_file = StringIO.new("fake vocals content")
    @audio_file.vocals_stem.attach(io: vocals_file, filename: "vocals.wav", content_type: "audio/wav")

    get download_audio_file_url(@audio_file, stem_type: "vocals")
    assert_response :success
    assert_equal "audio/wav", response.content_type
    assert_includes response.headers["Content-Disposition"], "attachment"
  end

  private

  def fixture_file_upload(filename, content_type)
    # Create more realistic file content to pass validations
    content = case filename
              when "test.mp3"
                # More substantial content to pass size validation
                "fake mp3 content " * 1000  # Make it bigger
              when "test.txt"
                "plain text content"
              else
                "generic content " * 1000
              end

    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end
end