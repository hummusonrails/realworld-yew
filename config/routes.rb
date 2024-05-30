Rails.application.routes.draw do
  resources :users, only: [:create] do
    collection do
      post 'login', to: 'users#login'
      get '', to: 'users#show'
      put '', to: 'users#update'
    end
  end

  resources :profiles, only: [:show], param: :username do
    member do
      post 'follow', to: 'profiles#follow'
      delete 'follow', to: 'profiles#unfollow'
    end
  end

  resources :articles do
    collection do
      get 'feed', to: 'articles#feed'
    end
    member do
      post 'favorite', to: 'articles#favorite'
      delete 'favorite', to: 'articles#unfavorite'
    end
    resources :comments, only: [:create, :destroy, :index]
  end

  resources :tags, only: [:index]

  root 'articles#index'
end
