require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, { escape_html: true }
end

helpers do
  def completed_list?(list)
    todos_count(list).positive? && todos_remaining_count(list).zero?
  end

  def list_class(list)
    return "complete" if completed_list?(list)
  end

  def todo_class(todo)
    return "complete" if todo[:completed]
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def todos_count(list)
    list[:todos].size
  end

  def sorted_lists(lists)
    lists.sort_by! { |list| completed_list?(list) ? 1 : 0 }
  end

  def sort_lists!(lists)
    sorted_lists(lists).each_with_index do |list, idx|
      yield(list, idx)
    end
  end

  def sorted_todos(todos)
    todos.sort_by! { |todo| todo[:completed] ? 1 : 0 }
  end

  def sort_todos!(todos)
    sorted_todos(todos).each_with_index do |todo, idx|
      yield(todo, idx)
    end
  end
end

# Validate new to-do name
def error_for_todo(list, name)
  if !(1..100).cover? name.size
    "The todo name must be between 1 and 100 characters"
  elsif list[:todos].any? { |todo| todo[:name] == name }
    "The todo name must be unique"
  end
end

before do
  @storage = SessionPersistence.new(session)
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = @storage.all_lists

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
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "The list name must be unique"
  end
end

# Create a new list
post '/lists' do
  error = error_for_list_name(params[:list_name])
  name = params[:list_name].strip

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_list(name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |lst| lst[:id] == id }
  end

  def all_lists
    @session[:lists]
  end

  def create_list(name)
    id = next_element_id(all_lists)
    @session[:lists] << { id: id, name: name, todos: [] }
  end

  def delete_list(id)
    @session[:lists].delete_if { |lst| lst[:id] == id }
  end

  def update_list_name(list_id, new_name)
    list = find_list(list_id)
    list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, completed)
    list = find_list(list_id)
    todo = find_todo(list, todo_id)
    todo[:completed] = completed == "false"
  end

  def mark_all_todos_as_completed(list_id)
    list = find_list(list_id)

    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  def find_todo(list, todo_id)
    list[:todos].find { |todo| todo[:id] == todo_id }
  end

  private

  def next_element_id(elements)
    max = elements.map { |element| element[:id] }.max
    max ? (max + 1) : 0
  end
end

# Handle user requesting non-existant list
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not found"
  redirect '/lists'
end

# View one specific list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Render the list name change form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit, layout: :layout
end

# Update existing list name
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = "The list name has been changed to \"#{list_name}\"."
    redirect "/lists/#{@list_id}"
  end
end

# Delete list
post '/lists/:list_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  name = @list[:name]
  @storage.delete_list(@list_id)
  session[:success] = "The list \"#{name}\" was deleted"
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect '/lists'
  end
end

# Add to-do item to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(@list, text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = "The todo '#{params[:todo]}' was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a specific to-do item from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @todo_id = params[:todo_id].to_i
  @todo = @storage.find_todo(@list, @todo_id)
  @todo_name = @todo[:name]

  @storage.delete_todo_from_list(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo item '#{@todo_name}' was deleted"
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a to-do item
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i
  is_completed = params[:completed]

  @storage.update_todo_status(@list_id, @todo_id, is_completed)
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Complete all todos on a given list
post '/lists/:list_id/complete-all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @storage.mark_all_todos_as_completed(@list_id)

  session[:success] = "All todos have been marked as completed."
  redirect "/lists/#{@list_id}"
end
