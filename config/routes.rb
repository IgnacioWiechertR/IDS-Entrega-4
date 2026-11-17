Rails.application.routes.draw do
  # Only sign in / sign out: accounts are created by staff and locks expire on their own.
  devise_for :users, only: :sessions

  # Landing panel of each role (A1). Their content arrives with D1, A5 and the course cards.
  get "dashboard" => "dashboard#index", as: :dashboard

  resources :accounts, only: %i[index new create edit update destroy] do
    member do
      patch :role, action: :update_role
      patch :reactivate
    end

    collection do
      get :import, action: :import_form
      post :import, action: :import_csv
      get :sample_csv
    end
  end
  resources :teacher_assignments, only: %i[ index create ]

  # The director's active university (A3).
  resource :university_selection, only: :update

  # Attendance (B6, B8–B10): the user's sections, and the list and table of each one.
  get "attendance" => "attendance#index", as: :attendance
  resources :sections, only: [] do
    resource :attendance, only: %i[ show edit update ], controller: "attendance"
    # C11: all the grades of the section with their status, for its profesor and ayudantes.
    resource :gradebook, only: :show
    # C13: evaluations always belong to a section.
    resources :evaluations, only: %i[ index new create ] do
      # C1: the ayudante enters the preliminary grades of the evaluation.
      resource :grade_sheet, only: %i[ edit update ]
      # C2, C5, C6: the profesor reviews the pending grades and approves or rejects them.
      resource :grade_review, only: :show do
        post :approve
        post :reject
      end
      # C8: the profesor who rejected the grades edits the rejection comment (:id is one grade of that rejection).
      resources :rejection_comments, only: :update
    end
  end

  # C10: the student's official grades, by course, and the detail of each correction.
  resources :my_grades, only: %i[ index show ]

  # C12: the user's inbox (the old scaffold listed every notification).
  resources :notifications, only: :index
  resources :announcements
  resources :attendance_records
  resources :attendance_sessions
  resources :grades
  # B1 only enables uploads in the context of a course. B2-B5 keep their own scope.
  resources :materials, only: :index
  # The public Active Storage direct-upload endpoint stays closed: see the B5 route below (rails_direct_uploads).
  # resources :enrollments
  # resources :section_staffs
  resources :course_coordinators, only: %i[ index create ]
  resources :courses do
    resources :materials, only: %i[ new create ]
    resources :sections do
       resources :assistant_assignments, only: [ :index, :create, :destroy ]
       resources :enrollments, only: [ :index, :create, :destroy ]
    end
  end
  resources :terms
  resources :faculties
  resources :users
  resources :universities

  # B2: reading stays separate from B1's upload routes and controller.
  resources :courses, only: [] do
    resources :materials, only: %i[ index show ], controller: "course_materials" do
      get :preview, on: :member
    end
  end

  # D3/D4: indicadores flujo de notas
  namespace :reports do
    resource :data_completeness, only: :show, controller: "data_completeness"
    resource :grade_statuses, only: :show
    resource :consolidated, only: :show
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # B4: only the uploader can confirm and delete a material within its course.
  resources :courses, only: [] do
    resources :material_deletions, only: %i[ index show destroy ]
  end

  # B3: editing is restricted to the original uploader and stays separate from B1/B2/B5.
  resources :courses, only: [] do
    resources :material_edits, only: %i[ index edit update ]
  end

  # B5: download originals only after checking access to their course.
  resources :courses, only: [] do
    resources :material_downloads, only: :index
    resources :materials, only: [] do
      resource :download, only: :show, controller: "material_downloads"
    end
  end
  # Keep the conventional direct-upload endpoint closed and its helper available
  # for B1. Multipart uploads continue through B1's authorized course endpoint.
  post "#{ActiveStorage.routes_prefix}/direct_uploads", to: "materials#index", as: :rails_direct_uploads

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
