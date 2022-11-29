require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader" 
  also_reload "database_persistence.rb"
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0 
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { | list | yield list }
    complete_lists.each { | list | yield list }
  end 

  # Similar to method above but different approach (and for todos in a list)
  # Reminder: &block in method defintion is converting a block to a Proc object
  # Reminder: &block in method invocation is converting a Proc object to a block
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end 

# A sinatra sessions is a simple Ruby hash 
# Set up a key :lists, which stores an array of hashes that contain todo lists 
# with # of todos in each todo list -- see: Class#SessionPersistence initilaize method

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render a new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error if the name is invalid. Return nil if valid. 
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Checks to see if lists exists. If it does, loads list. If it does not, throws error and redirects.
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not fonud."
  redirect "/lists"
end

# Create a new list 
post "/lists" do 
  list_name = params[:list_name].strip
 
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout 
end

# Edit an existing todo list
get "/lists/:id/edit" do 
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list
end 

# Update an Existing todo list
post "/lists/:id" do 
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do 
  id = params[:id].to_i 

  @storage.delete_list(id)
  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists" 
  else  
    redirect "/lists"
  end
end 

# Return an error if the name is invalid. Return nil if valid. 
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i 
  @list = load_list(@list_id)
  todo_name = params[:todo].strip # task to be added to Todo list stored within params[:todo] (a key we've defined in our form)
  
  error = error_for_todo(todo_name)
  if error 
    session[:error] = error
    erb :list, layout: :layout
  else 
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "The todo was successfully added." 
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a Todo list
post "/lists/:list_id/todos/:todo_id/delete" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else  
    session[:success] = "#{deleted_todo[:name]} has been successfully deleted."
    redirect "/lists/#{@list_id}" 
  end
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}" 
end 

# Mark all todos as complete in a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_as_completed(@list_id)

  session[:success] = "All todos are complete."
  redirect "/lists/#{@list_id}" 
end
