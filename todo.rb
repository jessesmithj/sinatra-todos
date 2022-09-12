require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
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

    p complete_lists
    p incomplete_lists

  incomplete_lists.each { | list | yield list, lists.index(list) }
  complete_lists.each { | list | yield list, lists.index(list) }
  end 

  # Similar to method above but different approach (and for todos in a list)
  # Reminder: &block in method defintion is converting a block to a Proc object
  # Reminder: &block in method invocation is converting a Proc object to a block
  def sort_todos(todos, &block) 
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do | todo, index | 
      if todo[:completed]
        complete_todos[todo] = index 
      else 
        incomplete_todos[todo] = index 
      end 
    end 

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end 
end 

# Sinatra sessions is a simple Ruby hash 
# Set up a key :lists, which stores an array of hashes that contain todo lists with # of todos in each todo list
before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all lists of lists
get "/lists" do
  @lists = session[:lists]
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
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Create a new list 
post "/lists" do 
  list_name = params[:list_name].strip
 
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single Todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout 
end

# Edit an existing todo list
get "/lists/:id/edit" do 
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list
end 

#Update an Existing todo list
post "/lists/:id" do 
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do 
  id = params[:id].to_i 
  deleted_list = session[:lists].delete_at(id) 
  session[:success] = "#{deleted_list[:name]} list successfully deleted."

  redirect :lists
end 

# Return an error if the name is invalid. Return nil if valid. 
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Add a new todo to a Todo list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i 
  @list = session[:lists][@list_id]
  todo_text = params[:todo].strip # task to be added to Todo list stored within params[:todo] (key we've defined in our form)
  
  error = error_for_todo(todo_text)
  if error 
    session[:error] = error
    erb :list, layout: :layout
  else 
    @list[:todos] << {name: todo_text, completed: false}
    session[:success] = "The todo was successfully added." 
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a Todo list
post "/lists/:list_id/todos/:todo_id/delete" do 
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  
  deleted_todo = @list[:todos].delete_at(todo_id) 
  session[:success] = "#{deleted_todo[:name]} has been successfully deleted."
  redirect "/lists/#{@list_id}" 
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do 
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}" 
end 

# Mark all todos as complete in a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos are complete."
  redirect "/lists/#{@list_id}" 
end
