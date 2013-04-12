Unclaimedproperty::Application.routes.draw do
  root to: 'welcome#index'
  resources :notifications
end