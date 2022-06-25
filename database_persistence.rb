require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'todos')
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, list_id)

    tuple = result.first
    todos = find_todos_for_list(list_id)
    { id: tuple['id'].to_i, name: tuple['name'], todos: todos }
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      todos = find_todos_for_list(list_id)
      { id: list_id, name: tuple['name'], todos: todos }
    end
  end

  def create_list(name)
    sql = "INSERT INTO lists (name) VALUES $1"
    query(sql, name)
  end

  def delete_list(list_id)
    todo_sql = "DELETE FROM todos WHERE id = $1"
    list_sql = "DELETE FROM lists WHERE id = $1"
    query(todo_sql, list_id)
    query(list_sql, list_id)
  end

  def update_list_name(list_id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, list_id)
  end

  def create_new_todo(list_id, todo_name)
    # list = find_list(list_id)
    # id = next_element_id(list[:todos])
    # list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    # list = find_list(list_id)
    # list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, completed)
    # list = find_list(list_id)
    # todo = find_todo(list, todo_id)
    # todo[:completed] = completed == "false"
  end

  def mark_all_todos_as_completed(list_id)
    # list = find_list(list_id)
    #
    # list[:todos].each do |todo|
    #   todo[:completed] = true
    # end
  end

  def find_todo(list, todo_id)
    # list[:todos].find { |todo| todo[:id] == todo_id }
  end

  private

  def find_todos_for_list(list_id)
    sql = "SELECT id, name, completed FROM todos WHERE list_id = $1"
    result = query(sql, list_id)
    result.map do |tuple|
      completed = tuple['completed'] == 't'
      { id: tuple['id'].to_i, name: tuple['name'], completed: completed }
    end
  end
end
