Rails.application.routes.draw do
  # Audio files management
  resources :audio_files do
    member do
      get :stems # For serving individual stems
      get :download # For downloading processed files
      post :retry # For retrying failed processing jobs
      get :mix # For downloading mixed stems
    end
  end

  # Set root to audio files index
  root "audio_files#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA routes (optional)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
