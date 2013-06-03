Unclaimedproperty::Application.routes.draw do
  root to: 'welcome#index'
  get '/about',    to: 'welcome#about'
  get '/contact',    to: 'welcome#contact'
  resources :notifications
  resources :properties
end