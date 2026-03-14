class AddErrorMessageToAudioFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :audio_files, :error_message, :text
  end
end
