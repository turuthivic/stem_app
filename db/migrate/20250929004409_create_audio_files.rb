class CreateAudioFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :audio_files do |t|
      t.string :title, null: false
      t.float :duration, null: false, default: 0.0
      t.bigint :file_size, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :audio_files, :status
    add_index :audio_files, :created_at
  end
end
