Unclaimedproperty::Application.routes.draw do
  root to: 'welcome#index'
  get '/about',    to: 'welcome#about'
  get '/contact',    to: 'welcome#contact'
  resources :notifications
  resources :properties do
    collection do
      get 'name/:name', to: 'properties#name_search'
      get 'zip/:zip', to: 'properties#zip_search'
    end
  end
  
end