Rails.application.routes.draw do
  namespace :api do
    post 'users/login', to: 'users#login'
    post 'users', to: 'users#register'
    get 'user', to: 'users#current'
    put 'user', to: 'users#update'

    resources :profiles, param: :username, only: [:show] do
      member do
        post 'follow'
        delete 'follow', to: 'profiles#unfollow'
      end
    end

    resources :articles, param: :slug do
      collection do
        get 'feed'
      end
      member do
        post 'favorite'
        delete 'unfavorite'
      end
      resources :comments, only: %i[create index destroy], param: :id
    end

    get 'tags', to: 'tags#index'
  end

  resources :users, only: %i[create new] do
    collection do
      post 'login', to: 'users#login'
      get 'login', to: 'users#login_form'
      delete 'logout', to: 'users#logout'
      get 'profile', to: 'users#show', as: 'show'
      get 'settings', to: 'users#edit'
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
    resources :comments, only: %i[create destroy index], param: :id do
      member do
        delete '', to: 'comments#destroy'
      end
    end
  end

  resources :tags, only: [:index]

  root 'articles#index'
end
