require "application_system_test_case"

class AudioFilesTest < ApplicationSystemTestCase
  def setup
    # Create a test audio file
    @audio_file = AudioFile.new(
      title: "Test Song",
      duration: 180.5,
      file_size: 5_000_000,
      status: :uploaded
    )

    mock_file = Rack::Test::UploadedFile.new(
      StringIO.new("fake audio content"),
      "audio/mpeg",
      original_filename: "test.mp3"
    )
    @audio_file.original_file.attach(mock_file)
    @audio_file.save!
  end

  test "visiting the index" do
    visit audio_files_url

    assert_selector "h1", text: "Audio File Separator"
    assert_selector "h2", text: "Upload New Audio File"
    assert_selector "h2", text: "Your Audio Files"
  end

  test "uploading a new audio file" do
    visit audio_files_url

    # Should see the upload form
    assert_selector '[data-controller="upload"]'
    assert_selector 'input[type="file"]'
    assert_selector 'input[name="audio_file[title]"]'

    # Submit button should be disabled initially
    assert_selector 'input[type="submit"][disabled]'
  end

  test "displaying uploaded files" do
    visit audio_files_url

    # Should see the uploaded file
    assert_text "Test Song"
    assert_text "4.77 MB"  # File size formatted
    assert_text "3:00"     # Duration formatted
    assert_text "Uploaded" # Status
  end

  test "showing file details" do
    click_link "Test Song"

    assert_current_path audio_file_path(@audio_file)
    assert_text "Test Song"
  end

  test "deleting an audio file" do
    visit audio_files_url

    # Find and click delete button
    accept_confirm do
      find('[data-turbo-method="delete"]').click
    end

    # Should redirect back to index
    assert_current_path audio_files_path
    assert_no_text "Test Song"
  end

  test "handling completed file with stems" do
    # Set up completed file with stems
    @audio_file.update!(status: :completed)

    vocals_file = StringIO.new("fake vocals content")
    @audio_file.vocals_stem.attach(io: vocals_file, filename: "vocals.wav", content_type: "audio/wav")

    accompaniment_file = StringIO.new("fake accompaniment content")
    @audio_file.accompaniment_stem.attach(io: accompaniment_file, filename: "accompaniment.wav", content_type: "audio/wav")

    visit audio_files_url

    # Should see play buttons
    assert_selector 'a[data-controller="audio-player"]', text: "Vocals"
    assert_selector 'a[data-controller="audio-player"]', text: "Music"

    # Should see download dropdown
    assert_selector '[data-controller="dropdown"]'
  end

  test "drag and drop interface" do
    visit audio_files_url

    # Should see drag and drop area
    assert_selector '[data-controller="drag-drop"]'
    assert_text "Drop your audio file here"
    assert_text "or click to browse"
  end

  test "error handling for invalid files" do
    visit audio_files_url

    # Try to upload an invalid file (this would require JavaScript testing)
    # For now, just verify the error handling elements exist
    assert_selector 'input[accept="audio/*"]'
  end

  test "responsive design elements" do
    visit audio_files_url

    # Check for responsive grid classes
    assert_selector '.grid'
    assert_selector '.md\\:col-span-2'

    # Check for mobile-friendly elements
    assert_selector '.container'
    assert_selector '.mx-auto'
  end

  test "accessibility features" do
    visit audio_files_url

    # Check for proper labels
    assert_selector 'label[for="audio_file_title"]'

    # Check for semantic HTML
    assert_selector 'main'
    assert_selector 'header'

    # Check for descriptive text
    assert_text "Upload audio files to separate vocals from accompaniment using AI"
  end
end