Rails.application.routes.draw do
  resources :users, only: [:create, :new] do
    collection do
      post 'login', to: 'users#login'
      get 'login', to: 'users#login_form'
      delete 'logout', to: 'users#logout'
      get 'profile', to: 'users#show', as: 'show'
      put 'profile', to: 'users#update', as: 'update'
    end
  end

  resources :profiles, only: [:show], param: :username do
    member do
      post 'follow', to: 'profiles#follow'
      delete 'unfollow', to: 'profiles#unfollow'
      get 'favorited', to: 'profiles#favorited'
    end
  end

  resources :articles do
    collection do
      get 'feed', to: 'articles#feed'
    end
    member do
      post 'favorite', to: 'articles#favorite'
      delete 'unfavorite', to: 'articles#unfavorite'
    end
    resources :comments, only: [:create, :destroy, :index], param: :id do
      member do
        delete '', to: 'comments#destroy'
      end
    end
  end

  resources :tags, only: [:index]

  root 'articles#index'
end
