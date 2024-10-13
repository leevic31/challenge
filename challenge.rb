require 'json'

def main(users_file, companies_file)
    users = get_users(users_file)

    companies = get_companies(companies_file)
    companies_data_by_id = create_companies_data_by_id(companies)
    companies_data = update_companies_data_from_users(users, companies_data_by_id)
    formatted_companies_data = format_companies_data(companies_data)

    create_output_file(formatted_companies_data)
end

# Reads and parses a JSON file of user data and returns a list of user hashes.
#
# @param users_file [String] The file of user data.
# @return [Array<Hash>] Array of hashes, each representing a user.
# @raise [Errno::ENOENT] If the file does not exist.
# @raise [JSON::ParserError] If the file contents are not valid JSON.
def get_users(users_file)
    begin
        file = File.read(users_file)
        JSON.parse(file)
    rescue Errno::ENOENT => e
        puts "Error: File not found - #{e.message}"
        exit(1)
    rescue JSON::ParserError => e
        puts "Error: Invalid JSON format - #{e.message}"
        exit(1)
    end
end

# Reads and parses a JSON file of company data and returns a list of company hashes.
#
# @param companies_file [String] The file of company data.
# @return [Array<Hash>] Array of hashes, each representing a company.
# @raise [Errno::ENOENT] If the file does not exist.
# @raise [JSON::ParserError] If the file contents are not valid JSON.
def get_companies(companies_file)
    begin
        file = File.read(companies_file)
        JSON.parse(file)
    rescue Errno::ENOENT => e
        puts "Error: File not found - #{e.message}"
        exit(1)
    rescue JSON::ParserError => e
        puts "Error: Invalid JSON format - #{e.message}"
        exit(1)
    end
end

# Creates a hash of companies data indexed by company ID.
#
# @param companies [Array<Hash>] Array of hashes, each representing a company.
# @return [Hash] A hash where each key is the company ID and each value is the company hash.
# @raise [KeyError] If a company hash is missing the "id" key
def create_companies_data_by_id(companies)
    companies_data_by_id = {}

    companies.each do |company|
        begin
            id = company.fetch("id")
            company["users_emailed"] = []
            company["users_not_emailed"] = []
            company["total_top_up_amount"] = 0
            companies_data_by_id[id] = company
        rescue KeyError
            puts "Error: Company is missing id - #{company}"
            exit(1)
        end
    end

    companies_data_by_id
end

# Processes an active user and increment its associated company's total top up amount
#
# @param users [Array<Hash>] Array of hashes, each representing a user.
# @param companies_data [Hash] A hash of companies.
# @return companies_data [Hash] A hash of companies.
# @raise [KeyError] If a user hash is missing the "active_status" key
def update_companies_data_from_users(users, companies_data)
    users.each do |user|
        begin    
            if user.fetch("active_status")
                company = companies_data[user["company_id"]]
                process_active_user(user, company)
                increment_company_total_top_up_amount(company)
            end
        rescue KeyError
            puts "Error: User is missing active_status - #{user}"
            exit(1)
        end
    end

    companies_data
end

# Adds user to the company hash based on the email status of user and company.
# Creates a "new_token_balance" field in the user hash.
#
# @param user [Hash] A hash representing a user.
# @param company [Hash] A hash representing a company.
# @return [void] No return value. The user and company hashes are modified in place.
# @raise [KeyError] If a company hash is missing the "top_up" key.
# @raise [ArgumentError] If a company's top up is less than 0.
def process_active_user(user, company)
    begin
        company_top_up = company.fetch("top_up")
        raise ArgumentError, "Company top up must be greater than or equal to 0" if company_top_up < 0

        create_new_token_balance_for_user(user, company_top_up)
    rescue KeyError
        puts "Error: Company is missing top_up - #{company}"
        exit(1)
    rescue ArgumentError => e
        puts "Error: #{e.message} - #{company}"
        exit(1)
    end

    add_user_based_on_email_status(user, company)
end

# Creates a "new_token_balance" field in the user hash based on the user's tokens and the company's top up amount.
#
# @param user [Hash] A hash representing a user.
# @param company_top_up [Integer] An integer representing a company's top up amount.
# @return [void] No return value. The user hash is modified in place.
# @raise [KeyError] If the user hash is missing the "tokens" key.
# @raise [ArgumentError] If the the user's tokens is less than 0.
def create_new_token_balance_for_user(user, company_top_up)
    begin
        raise KeyError, "User is missing tokens" unless user.key?("tokens")
        raise ArgumentError, "User tokens must be greater than or equal to 0" if user["tokens"] < 0

        user["new_token_balance"] = user["tokens"] + company_top_up
    rescue KeyError => e
        puts "Error: #{e.message} - #{user}"
        exit(1)
    rescue ArgumentError => e
        puts "Error: #{e.message} - #{user}"
        exit(1)
    end
end

# Add user to the company hash.
#
# @param user [Hash] A hash representing a user.
# @param company [Hash] A hash representing a company.
# @return [void] No return value. The company hash is modified in place.
# @raise [KeyError] If the company hash is missing the "email_status" key.
def add_user_based_on_email_status(user, company)
    begin
        if user.fetch("email_status") && company.fetch("email_status")
            company["users_emailed"] << user
        else
            company["users_not_emailed"] << user
        end
    rescue KeyError
        puts "Error: Company is missing email_status - #{company} or User is missing email_status - #{user}"
        exit(1)
    end
end

# Add company's top up amount to the company's total top up amount.
#
# @param company [Hash] A hash representing a company.
# @return [void] No return value. The company hash is modified in place.
def increment_company_total_top_up_amount(company)
    company["total_top_up_amount"] += company["top_up"]
end

# Sorts the array of user hashes in each company hash by last name.
# Sorts the array of company hashes by id.
#
# @param companies [Array<Hash>] Array of hashes, each representing a company.
# @return [Array<Hash>] Array of hashes, each representing a company, sorted by id. 
def format_companies_data(companies_data)
    companies = companies_data.values

    for company in companies
        sort_users_by_last_name(company["users_emailed"])
        sort_users_by_last_name(company["users_not_emailed"])
    end

    sort_companies_by_id(companies)
end

# Sorts the array of user hashes by last name.
#
# @param users [Array<Hash>] Array of hashes, each representing a user.
# @return [Array<Hash>] Array of user hashes, sorted by last name.
# @raise [KeyError] If a user hash is missing the "last_name" key.
def sort_users_by_last_name(users)
    users.sort_by! do |user| 
        begin
            user.fetch("last_name")
        rescue KeyError
            puts "Error: User missing last_name - #{user}"
            exit(1)
        end
    end
end

# Sorts the array of company hashes by id.
#
# @param companies [Array<Hash>] Array of companies, each representing a company.
# @return [Array<Hash>] Array of company hashes, sorted by id.
def sort_companies_by_id(companies)
    companies.sort_by! { |company| company["id"] }
end

# Creates the output file of the companies that added tokens to their active users.
#
# @param companies_data [Array<Hash>] Array of hashes, each representing a company.
# @return [void] No return value. A file "output.txt" is created.
def create_output_file(companies_data)
    File.open("output.txt", "w") do |file|
        for company in companies_data
            create_company_output(file, company)
        end
    end
end

# Writes the company data to the output file.
#
# @param file [IO] The output file that will be written to.
# @param company [Hash] A hash representing a company.
# @return [void] No return value. The file is being written to.
# @raise [KeyError] If the company hash is missing the "id" or "name" keys.
def create_company_output(file, company)
    if company["users_emailed"].any? || company["users_not_emailed"].any?
        begin
            file.puts "Company Id: #{company.fetch("id")}"
            file.puts "Company Name: #{company.fetch("name")}"
            file.puts "Users Emailed:"
            
            if company["users_emailed"]
                create_user_output(file, company["users_emailed"])
            end
        
            file.puts "Users Not Emailed:"
            
            if company["users_not_emailed"]
                create_user_output(file, company["users_not_emailed"])
            end
        
            file.puts "Total amount of top ups for #{company["name"]}: #{company["total_top_up_amount"]}"
            file.puts "\n"
        rescue KeyError
            puts "Error: Company is missing id or name - #{company}"
            exit(1)
        end
    end
end

# Writes the users data to the output file.
#
# @param file [IO] The output file that will be written to.
# @param users [Array<Hash>] Array of hashes, each representing a user.
# @return [void] No return value. The file is being written to.
def create_user_output(file, users)
    for user in users
        begin
            file.puts "        #{user.fetch("last_name")}, #{user.fetch("first_name")}, #{user.fetch("email")}"
            file.puts "          Previous Token Balance, #{user["tokens"]}"
            file.puts "          New Token Balance #{user["new_token_balance"]}"
        rescue KeyError
            puts "Error: User missing last_name, first_name or email - #{user}"
            exit(1)
        end
    end
end

main('users.json', 'companies.json')