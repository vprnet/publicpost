require 'sidekiq/web'

HeSaidSheSaid::Application.routes.draw do

  devise_for :users

  #####################
  ## API ROUTES HERE ##
  #####################
  api_version(:module => "V1", :path => "/api/v1") do
    match '/documents/classifications' => 'documents#classifications', :defaults => { :format => 'json' }
    match '/documents/content_types' => 'documents#content_types', :defaults => { :format => 'json' }
    match '/documents/legislative_bodies' => 'documents#legislative_bodies', :defaults => { :format => 'json' }
    match '/documents/search' => 'documents#search', :defaults => { :format => 'json' }

    resources :documents, only: [:index, :show, :update], :defaults => { :format => 'json' }
    resources :municipalities, only: [:index, :show], :defaults => { :format => 'json' }
  end

  ###############################################
  ## Rack web interface for the Sidekiq queues ##
  ###############################################
  constraint = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.admin? }
  constraints constraint do
    mount Sidekiq::Web => '/sidekiq'
  end

  #################################
  ## User related routes ##
  #################################
  resources :users, only: [:index, :show] do
    resources :users
  end

  #################################
  ## Municipality related routes ##
  #################################
  resources :municipalities, only: [:index, :show] do
    resources :documents
  end

  #############################
  ## Document related routes ##
  #############################
  match '/documents/search' => 'documents#search'
  match '/documents/:id/process' => 'documents#process_document'
  match '/documents/:id/train_meeting/:classification' => 'documents#train_meeting'
  match '/documents/:id/train_legislative_body/:classification' => 'documents#train_legislative_body'
  resources :documents, only: [:index, :show, :update, :new]

  match '/top50' => 'entities#index'
  resources :entities, only: [:index, :show, :update]

  # Allows for viewing all documents at the state level
  match '/states/:state/documents(/:classification)' => 'municipalities#states', :as => :state_documents

  resources :search_alerts, only: [:index, :show, :create, :update, :destroy]

  root to: 'static_pages#home'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
