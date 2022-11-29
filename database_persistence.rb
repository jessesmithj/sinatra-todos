require "pg"
require "pry"

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(statement, *params) # since it's a splat in the paramter, it's already an array -- even with one param
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"  #fetch the data
    result = query(sql, id) # grab the data with a PG::Result object

    tuple = result.first # result returns an array of records, we only care about the first here

    list_id = tuple["id"].to_i # retreiving the value for the key id from the tuple
    todos = find_todos_for_list(list_id)
    {id: list_id, name: tuple["name"], todos: todos}
  end

  def all_lists 
    sql = "SELECT * FROM lists"
    result = query(sql)

    result.map do |tuple|
      list_id = tuple["id"].to_i
      todos = find_todos_for_list(list_id)
      {id: list_id, name: tuple["name"], todos: todos}
    end
  end

  # all_lists explination
  
  # [{id:, name:, todos:}] # we want to keep the same format using sql that we had with sessions, which was this
  #example: 
      # new_val = result.map do |tuple|
      #   {id: tuple["id"], name: tuple["name"], todos: []}
      # end
  
      # p new_val

      # starting value - [["1", "Homework"], ["2", "Music"]]
      # after using map [{:id=>"1", :name=>"Homework", :todos=>[]}, {:id=>"2", :name=>"Music", :todos=>[]}]   
 
  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, id)

    # query("DELETE FROM todos WHERE list_id = $1", id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, id)
  end 

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, todo_name)
  end 

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET complete = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET complete = true WHERE list_id = $1"
    query(sql, list_id)
  end 

  private
  # returns an array of hashes that represents the data for the todos on a specific list
  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todos WHERE list_id = $1"
    todos_result = query(todo_sql, list_id)

    todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i, # casting to an integer
        name: todo_tuple["name"], 
        completed: todo_tuple["complete"] == "t" } # casting to a boolean value
    end
  end
end