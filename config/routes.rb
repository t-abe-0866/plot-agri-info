Rails.application.routes.draw do
  
  constraints ->  request { request.session[:user_id].present? } do
    # ログインしてる時のパス
    root to: "homes#index"
  end
  # ログインしてない時のパス
  root to: 'sessions#new'
  
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  get 'signup', to: 'users#new'
  
  get 'graphs', to: 'graphs#index'
  
  post 'map_save', to: 'homes#create'
  
  resources :users, only: [:index, :show, :new, :create]
end
