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
