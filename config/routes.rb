Rails.application.routes.draw do
  # Only sign in / sign out: accounts are created by staff and locks expire on their own.
  devise_for :users, only: :sessions

  # Landing panel of each role (A1). Their content arrives with D1, A5 and the course cards.
  get "dashboard" => "dashboard#index", as: :dashboard
  resources :accounts, only: :index
  resources :teacher_assignments, only: %i[ index create ]

  # The director's active university (A3).
  resource :university_selection, only: :update

  resources :notifications
  resources :announcements
  resources :attendance_records
  resources :attendance_sessions
  resources :grades
  resources :evaluations
  resources :materials
  # resources :enrollments
  # resources :section_staffs
  resources :course_coordinators
  # resources :sections
  resources :courses do
    resources :sections do
       resources :assistant_assignments, only: [ :index, :create, :destroy ]
       resources :enrollments, only: [ :index, :create, :destroy ]
    end
  end
  resources :terms
  resources :faculties
  resources :users
  resources :universities
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
