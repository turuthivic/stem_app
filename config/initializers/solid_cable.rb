# Configure Solid Cable to use the cable database
Rails.application.config.to_prepare do
  # Ensure SolidCable models connect to the cable database
  if defined?(SolidCable)
    SolidCable::Record.connects_to database: { writing: :cable, reading: :cable }
  end
end
