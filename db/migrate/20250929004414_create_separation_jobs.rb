class CreateSeparationJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :separation_jobs do |t|
      t.references :audio_file, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.float :progress, null: false, default: 0.0
      t.text :error_message
      t.string :separation_type, null: false, default: 'vocals_accompaniment'
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :separation_jobs, :status
    add_index :separation_jobs, :separation_type
    add_index :separation_jobs, [:audio_file_id, :status]
  end
end
