namespace :users do
  desc "Create a new user by email. Usage: bin/rails users:create[user@example.com]"
  task :create, [ :email ] => :environment do |t, args|
    email = args[:email]

    if email.blank?
      puts "Error: Email is required"
      puts "Usage: bin/rails users:create[user@example.com]"
      exit 1
    end

    user = User.new(email: email)

    if user.save
      puts "User created successfully!"
      puts "  Email: #{user.email}"
      puts "  ID: #{user.id}"
    else
      puts "Error creating user:"
      user.errors.full_messages.each do |message|
        puts "  - #{message}"
      end
      exit 1
    end
  end

  desc "List all users"
  task list: :environment do
    users = User.all.order(:email)

    if users.empty?
      puts "No users found."
    else
      puts "Users (#{users.count}):"
      users.each do |user|
        puts "  [#{user.id}] #{user.email}"
      end
    end
  end

  desc "Delete a user by email. Usage: bin/rails users:delete[user@example.com]"
  task :delete, [ :email ] => :environment do |t, args|
    email = args[:email]

    if email.blank?
      puts "Error: Email is required"
      puts "Usage: bin/rails users:delete[user@example.com]"
      exit 1
    end

    user = User.find_by("LOWER(email) = ?", email.downcase)

    if user
      user.destroy
      puts "User deleted successfully: #{email}"
    else
      puts "User not found: #{email}"
      exit 1
    end
  end
end
