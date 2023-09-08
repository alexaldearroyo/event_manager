require "csv"
require "google/apis/civicinfo_v2"
require "erb"
require "date"

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/\D/, "")
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == "1"
    phone_number[1..10]
  else
    "0000000000"
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: ["legislatorUpperBody", "legislatorLowerBody"],
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

puts "EventManager initialized."

contents = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol,
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

hours_count = Hash.new(0)
days_count = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_number(row[:homephone])
  registration_hour = row[:regdate].split(" ")[1].split(":")[0]
  registration_day = Date.strptime(row[:regdate], "%m/%d/%y").strftime("%A")

  day_of_week = Date.strptime(row[:regdate], "%m/%d/%y").wday

  hours_count[registration_hour] += 1
  days_count[registration_day] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

max_count = hours_count.values.max
peak_hours = hours_count.select { |hour, count| count == max_count }.keys

max_count_day = days_count.values.max
peak_days = days_count.select { |day, count| count == max_count_day }.keys

puts "Peak registration hours: #{peak_hours.join(', ')}"
puts "Peak registration days: #{peak_days.join(', ')}"