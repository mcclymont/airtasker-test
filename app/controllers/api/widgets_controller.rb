module Api
  class WidgetsController < ApplicationController
    def index
      render json: [
        {name: 'Foo', price: 100.45, description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed.'},
        {name: 'Bar', price: 21.5,   description: 'do eiusmod tempor incididunt ut labore et dolore magna aliqua.'},
        {name: 'FooBar', price: 3.4, description: 'Ut enim ad minim veniam, quis nostrud exercitation ullamco.'},
        {name: 'Fizz', price: 32.55, description: 'laboris nisi ut aliquip ex ea commodo consequat.'}
      ]
    end
  end
end
