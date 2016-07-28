# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :asana_imports, only: [:new, :create]
