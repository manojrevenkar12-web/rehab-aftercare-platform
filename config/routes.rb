Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :session, only: %i[create show destroy]
      get "caseload", to: "caseload#index"
      resources :patients, only: :show
      resources :enrolments, only: [] do
        member do
          post :approve
          post :units, action: :record_unit
          post :end_early
          post :check_ins, action: :check_in
          get :timeline
        end
        resources :drafts, only: :create
        resource :closing_report, only: [] do
          post :sign
        end
        resource :claim, only: [] do
          post :assemble, to: "claims#assemble"
        end
      end
      resources :drafts, only: :show do
        member do
          post :approve
          post :reject
        end
      end
      resources :claims, only: %i[index show] do
        member do
          post :submit
          post :paid
          post :rejected
          post :review
        end
      end
      resources :audit_events, only: :index
    end
  end

  # everything else is the console's own routing (sign-in, caseload, patients, billing, audit)
  root "console#show"
  get "*path", to: "console#show", constraints: ->(req) { !req.path.start_with?("/api", "/up", "/assets") && req.format.html? }
end
