require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "bcrypt"
require "yaml"

# Enable Sessions
configure do
  enable :sessions
  set :session_secret, 'secret'
end

# Render Homepage
get "/" do
  if logged_in?
    @user = session[:username][:user]
    @initial_budget = session[:username][:initial_budget]
    @expenses = session[:username][:finance][:expenses]
    session[:username][:finance][:budget] = num_to_dollars(calculate_remaining(@initial_budget.to_f, @expenses))
    @remaining = session[:username][:finance][:budget]
    @expenses = session[:username][:finance][:expenses]
  end
  erb :home
end

# Sends user to homepage if they are not logged in
def verify_credentials
  if logged_in? == nil
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end
end

# Render Sign-In Page
get "/user" do
  erb :signin
end

# Handle Sign-In POST Request
post "/user/signin" do
  @username = params[:username]
  password = params[:password]
  if correct_login?(@username, password)
    session[:message] = "Hey you cool kitten, welcome back!"
    session[:username] = { user: @username, finance: { budget: nil, expenses: [] }, initial_budget: nil } 
    redirect "/"
  else
    session[:message] = "Try again!"
    erb :signin
  end
end

# Handle Sign-Out POST Request
post "/user/signout" do
  session.delete(:username)
  session[:message] = "Siobhan has successfully logged you out!"
  redirect "/"
end

# Checks if credentials are valid
def correct_login?(username, password)
  root_path = File.expand_path("../", __FILE__)
  path = File.join(root_path, "users.yaml")
  acceptable_users = YAML.load(File.read(path))
  if acceptable_users.key?(username)
    ref_password = BCrypt::Password.new(acceptable_users[username])
    ref_password == password
  else
    false
  end
end

# Handles Adding Expense GET request by rendering adding expense page
get "/add/expense" do
  erb :add_expense
end

# Processes adding expense POST request by adding expense data to session
post "/add/expense" do
  expense_name = params[:expense_name]
  expense_amount_str = params[:expense_amount]
  if valid_amount?(expense_amount_str)
    @initial_budget = session[:username][:initial_budget].to_f
    session[:username][:finance][:expenses] << [ expense_name, num_to_dollars(expense_amount_str.to_f), next_expense_id ]
    @expenses = session[:username][:finance][:expenses]
    erb :test
    remaining = num_to_dollars(calculate_remaining(@initial_budget, @expenses))
    session[:username][:finance][:budget] = remaining
    session[:message] = "Siobhan gave you a dirty look, but nevertheless your expense has been recorded and your budget has been updated."
    redirect "/"
  else
    session[:message] = "Siobhan is upset, make sure you put in a valid amount before she crosses her patience threshold!"
    erb :add_expense
  end
end
    
# Calculates next expense id
def next_expense_id
  return 1 if session[:username][:finance][:expenses].empty?
  @expenses = session[:username][:finance][:expenses]
  @expenses.map { |expense| expense[2] }.flatten.max + 1
end

# Handles Adding Budget GET request by rendering adding budget page
get "/add/budget" do
  @initial_budget = session[:username][:initial_budget] 
  erb :add_budget
end

# Handles adding budget POST request - Updates budget in session
post "/add/budget" do
  budget = params[:budget]
  if valid_amount?(budget)
    session[:username][:finance][:budget] = num_to_dollars(budget.to_f) if session[:username][:finance][:budget].nil?
    session[:username][:initial_budget] = num_to_dollars(budget.to_f)
    session[:message] = "Siobhan created your budget and tells you NOT TO SPEND IT ALL"
    redirect "/"
  else
    session[:message] = "Hey you cool cat, you need to enter a real dollar amount!"
    erb :add_budget
  end
end

# Renders page for picking which expense to edit
get "/user/edit/expense" do
  @expenses = session[:username][:finance][:expenses]
  erb :edit_expense
end

# Renders page for editing a specifc expense
get "/user/edit/expense/:id" do |n|
  @expense = session[:username][:finance][:expenses].select { |expense| expense[2] == n.to_i }.flatten
  @expense_name = @expense[0]
  @expense_amount = @expense[1]
  @id = @expense[2]
  erb :edit_specific
end

# Handles updating an existing expense's POST request
post "/update/expense/:id" do |n|
  expense_name = params[:expense_name]
  expense_amount = params[:expense_amount]
  if valid_amount?(expense_amount)
    id = n.to_i
    old_expense = session[:username][:finance][:expenses].select { |expense| expense[2] == n.to_i }.flatten
    session[:username][:finance][:expenses].delete(old_expense)
    session[:username][:finance][:expenses] << [expense_name, expense_amount, id]
    redirect "/"
  else
    session[:message] = "Hey you cool cat, you need to enter a real dollar amount!"
    erb :edit_specific
  end
end

post "/user/delete/expense/:id" do |n|
  old_expense = session[:username][:finance][:expenses].select { |expense| expense[2] == n.to_i }.flatten
  session[:username][:finance][:expenses].delete(old_expense)
  redirect "/"
end

# Subtracts expenses from initial budget to calculate remaining money left
def calculate_remaining(initial_budget, expenses)
  budget = initial_budget
  expenses.each { |expense| budget -= expense[1].to_f }
  budget
end

# Validates money amount string input
def valid_amount?(string)
  return false if string.match(/[^0-9\.]/)
  if string.count(".") == 1
    if string.to_f > 0
      string.split(".").last.size <= 2
    end
  else
    false
  end
end

# turns float into valid dollar string
def num_to_dollars(float)
  float_str = float.to_s
  cents = float_str.split(".").last
  dollars = float_str.split(".").first
  loop do
    break if cents.size == 2
    cents << "0"
  end
  dollars + "." + cents
end

helpers do
  # Verifies if a user is logged in
  def logged_in?
    true unless session[:username].nil?
  end
end