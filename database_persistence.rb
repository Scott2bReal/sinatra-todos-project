require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'todos')
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    # sql = "SELECT * FROM lists WHERE id = $1"
    sql = <<~SQL
      SELECT
        l.*,
        COUNT(NULLIF(t.completed, true)) AS todos_remaining_count,
        COUNT(t.id) AS todos_count
      FROM lists l
      LEFT JOIN todos t ON t.list_id = l.id
      GROUP BY l.id
      HAVING l.id = $1;
    SQL
    result = query(sql, list_id)

    tuple = result.first
    todos = find_todos_for_list(list_id)
    { id: tuple['id'].to_i, name: tuple['name'], todos: todos }
  end

  def all_lists
    # sql = "SELECT * FROM lists;"
    sql = <<~SQL
      SELECT
        l.*,
        COUNT(NULLIF(t.completed, true)) AS todos_remaining_count,
        COUNT(t.id) AS todos_count
      FROM lists l
      LEFT JOIN todos t ON t.list_id = l.id
      GROUP BY l.id
      ORDER BY l.id;
    SQL
    result = query(sql)

    result.map do |tuple|
      {
        id: tuple['id'].to_i,
        name: tuple['name'],
        todos_count: tuple["todos_count"].to_i,
        todos_remaining_count: tuple["todos_remaining_count"].to_i
      }
    end
  end

  def create_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
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
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, completed)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, completed, list_id, todo_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
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
