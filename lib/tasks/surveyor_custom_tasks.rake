namespace :surveyor do
  desc "custom dump all responses to a given survey"
  task :custom_dump => :environment do

    require 'fileutils.rb'
    survey_version = ENV["SURVEY_VERSION"] 
    access_code = ENV["SURVEY_ACCESS_CODE"] || SURVEY_ACCESS_CODE[:fi]
    
    raise "USAGE: rake surveyor:dump SURVEY_ACCESS_CODE=<access_code> [OUTPUT_DIR=<dir>] [SURVEY_VERSION=<survey_version>]" unless access_code
    params_string = "code #{access_code}"

    surveys = Survey.where(:access_code => access_code).order("survey_version ASC")
    if survey_version.blank?
      survey = surveys.last
    else
      params_string += " and survey_version #{survey_version}"
      survey = surveys.where(:survey_version => survey_version).first
    end
    raise "No Survey found with #{params_string}" unless survey

    questions = []
    column_names=['citizen_id' , 'email', 'first_name', 'last_name', 'user_state' ,'access_code', 'language' ,'started_at','completed_at']
    column_names += ['authenticated_firstnames', 'authenticated_lastname', 'authenticated_birth_date', 'authenticated_occupancy_county']
    language = (survey.access_code[-2] + survey.access_code[-1]).upcase
    survey.sections_with_questions.first.questions.each do |q|
      unless q.display_type == "label"
        questions << q.id
        column_names << q.get_question_number.to_s + "_" + q.data_export_identifier
      end
    end
    report = CSV.generate("") do |csv|
      csv << column_names
      ResponseSet.where("user_id is not null").each do |rs|
        c = Citizen.find(rs.user_id)
        row = [c.id, c.email, c.first_name, c.last_name,
                rs.user_state, rs.access_code,
                language, rs.started_at,rs.completed_at,
                c.profile.authenticated_firstnames,
                c.profile.authenticated_lastname,
                c.profile.authenticated_birth_date,
                c.profile.authenticated_occupancy_county]
        questions.each do |qid|
          response_ansewrs = rs.responses.where('question_id = ?', qid)
          if response_ansewrs.length <= 1
            row << response_ansewrs.first.to_s
          else
            h={}
            response_ansewrs.each {|r| h[r.answer.display_order] = r.to_s}
            row <<  h.to_s
          end
        end
        csv << row
      end
    end

    dir = ENV["OUTPUT_DIR"] || Rails.root + 'tmp'
    mkpath(dir) # Create all non-existent directories
    full_path = File.join(dir,"#{survey.access_code}_v#{survey.survey_version}_#{Time.now.to_i}.csv")
    File.open(full_path, 'w') do |f|
      f.write(report)
    end

    #require 'fog'

    #connection = Fog::Storage.new({
      #:provider                 => 'AWS',
      #:aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY'],
      #:aws_access_key_id        => ENV['AWS_ACCESS_KEY_ID']
    #})

    #directory = connection.directories.get("surveys")


    #file = directory.files.get('data.txt')
    #file.body = File.open("/path/to/my/data.txt")
    #file.save
    #
  end
end


