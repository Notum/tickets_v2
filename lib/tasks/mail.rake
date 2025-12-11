namespace :mail do
  desc "Send a test email. Usage: bin/rails mail:test[recipient@example.com]"
  task :test, [ :email ] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Error: Email is required"
      puts "Usage: bin/rails mail:test[recipient@example.com]"
      exit 1
    end

    puts "Sending test email to #{email}..."

    begin
      TestMailer.test_email(email).deliver_now
      puts "Test email sent successfully!"
    rescue => e
      puts "Failed to send email: #{e.message}"
      exit 1
    end
  end
end
