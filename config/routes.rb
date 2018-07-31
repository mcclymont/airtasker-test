Rails.application.routes.draw do
  namespace :api, defaults: {format: :json} do
    resources :widgets, only: :index
  end
end
