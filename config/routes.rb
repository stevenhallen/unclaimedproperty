Unclaimedproperty::Application.routes.draw do
  root to: 'welcome#index'
  get '/about',    to: 'welcome#about'
  resources :notifications
  resources :properties
end