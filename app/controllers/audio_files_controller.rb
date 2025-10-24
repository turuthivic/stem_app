class AudioFilesController < ApplicationController
  before_action :set_audio_file, only: [:show, :edit, :update, :destroy, :stems, :download]

  def index
    @audio_files = AudioFile.recent.includes(:separation_jobs)
  end

  def show
    @separation_jobs = @audio_file.separation_jobs.recent
  end

  def new
    @audio_file = AudioFile.new
  end

  def create
    @audio_file = AudioFile.new(audio_file_params)

    respond_to do |format|
      if @audio_file.save
        format.html { redirect_to @audio_file, notice: 'Audio file uploaded successfully! Processing will begin shortly.' }
        format.turbo_stream { redirect_to @audio_file }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("upload_form", partial: "audio_files/upload_form", locals: { audio_file: @audio_file }),
            turbo_stream.prepend("flash_messages", partial: "shared/flash", locals: { message: @audio_file.errors.full_messages.join(", "), type: "alert" })
          ]
        end
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @audio_file.update(audio_file_params.except(:original_file))
        format.html { redirect_to @audio_file, notice: 'Audio file was successfully updated.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@audio_file, partial: "audio_files/audio_file", locals: { audio_file: @audio_file }) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("edit_form", partial: "audio_files/edit_form", locals: { audio_file: @audio_file }) }
      end
    end
  end

  def destroy
    @audio_file.destroy
    respond_to do |format|
      format.html { redirect_to audio_files_url, notice: 'Audio file was successfully deleted.' }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@audio_file) }
    end
  end

  def stems
    stem_type = params[:stem_type]

    case stem_type
    when 'vocals'
      send_stem(@audio_file.vocals_stem)
    when 'accompaniment'
      send_stem(@audio_file.accompaniment_stem)
    when 'original'
      send_stem(@audio_file.original_file)
    else
      head :not_found
    end
  end

  def download
    stem_type = params[:stem_type]

    case stem_type
    when 'vocals'
      send_download(@audio_file.vocals_stem, "#{@audio_file.title}_vocals.wav")
    when 'accompaniment'
      send_download(@audio_file.accompaniment_stem, "#{@audio_file.title}_accompaniment.wav")
    when 'original'
      send_download(@audio_file.original_file, @audio_file.original_file.filename.to_s)
    else
      head :not_found
    end
  end

  private

  def set_audio_file
    @audio_file = AudioFile.find(params[:id])
  end

  def audio_file_params
    params.require(:audio_file).permit(:title, :original_file, :duration, :file_size)
  end

  def send_stem(attachment)
    if attachment.attached?
      send_data attachment.download,
                type: attachment.content_type,
                disposition: 'inline'
    else
      head :not_found
    end
  end

  def send_download(attachment, filename)
    if attachment.attached?
      send_data attachment.download,
                type: attachment.content_type,
                disposition: 'attachment',
                filename: filename
    else
      head :not_found
    end
  end
end
