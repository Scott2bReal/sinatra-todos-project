require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return error message if the list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters"
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique"
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  id = session[:lists].size.to_s

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get '/lists/:list_id' do
  id = params[:list_id].to_i
  @list = session[:lists][id]

  erb :list, layout: :layout
end

get 'lists/:list_id/edit' do
  id = params[:list_id].to_i
  @list = session[:lists][id]

  erb :edit, layout: :layout
end

post 'lists/:list_id/edit' do
  id = params[:list_id].to_i
  @list = session[:lists][id]
end
