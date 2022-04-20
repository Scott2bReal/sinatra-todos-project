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

# View one specific list
get '/lists/:list_id' do
  id = params[:list_id].to_i
  @list = session[:lists][id]

  erb :list, layout: :layout
end

# Render the list name change form
get '/lists/:list_id/edit' do
  id = params[:list_id].to_i
  @list = session[:lists][id]

  erb :edit, layout: :layout
end

# Update existing list name
post '/lists/:list_id' do
  id = params[:list_id].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been changed to \"#{list_name}\"."
    redirect "/lists/#{id}"
  end
end

# Delete list
post '/lists/:list_id/destroy' do
  id = params[:list_id].to_i
  name = session[:lists][id][:name]
  session[:lists].delete_at(id)
  session[:success] = "The list \"#{name}\" was deleted"
  redirect '/lists'
end

# Validate new to-do name
def error_for_todo(list, name)
  if !(1..100).cover? name.size
    "The todo name must be between 1 and 100 characters"
  elsif list[:todos].any? { |todo| todo[:name] == name }
    "The todo name must be unique"
  end
end

# Add to-do item to a list
post '/lists/:list_id/todos' do
  list_id = params[:list_id].to_i
  @list = session[:lists][list_id]
  text = params[:todo].strip

  error = error_for_todo(@list, text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: params[:todo], completed: false }
    session[:success] = "The todo '#{params[:todo]}' was added."
    redirect "/lists/#{list_id}"
  end
end

# Delete a specific to-do item from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todo_name = session[:lists][list_id][:todos][todo_id][:name]
  session[:lists][list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo item '#{todo_name}' was deleted"
  redirect "/lists/#{list_id}"
end
