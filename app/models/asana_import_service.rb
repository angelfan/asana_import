require 'csv'

class AsanaImportService
  attr_reader :csv, :user
  attr_accessor :errors

  def initialize(csv, user = User.current)
    @csv = csv
    @user = user
    @errors = Errors.new
  end

  def import
    CSV.foreach(csv.path).to_a[1..-1].each do |row|
      create_issue(row)
    end
  end

  private

  def filename
    File.basename(csv.original_filename, '.csv')
  end

  def project
    @project ||= create_project
  end

  def create_project
    project = Project.find_or_initialize_by(identifier: filename.downcase)
    project.name = filename.tr('_', ' ') if project.new_record?
    project.add_default_member(user)
    project.save
    project
  end

  def find_or_initialize_assigner(assigner_name)
    return false if assigner_name.blank?
    login = ExtractName.new(assigner_name).login
    assigner = User.find_or_initialize_by(login: login)
    if assigner.new_record?
      assigner.safe_attributes = user_attributes(assigner_name)
      assigner.login = login
      assigner.activate
      assigner.password = 'Commandp123'
      assigner.password_confirmation = 'Commandp123'
      assigner.save(validate: false)
    end

    project.add_default_member(assigner) unless project.members.pluck(:id).include?(assigner.id)
    project.save
    assigner
  end

  def create_issue(row)
    assigner = find_or_initialize_assigner(row[5])
    issue = Issue.new
    issue.project = project
    issue.author = user
    issue.tracker = tracker
    issue.status = status
    issue.priority = priority
    issue.assigned_to = assigner if assigner
    issue.safe_attributes = issue_attributes(row)
    issue.save!
  rescue => e
    errors.push(row[0], e.to_s)
  end

  def tracker
    @tracker ||= ::Tracker.first
  end

  def status
    @status ||= ::IssueStatus.first
  end

  def priority
    @priority ||= ::IssuePriority.first
  end

  def user_attributes(assigner_name)
    extract_name = ExtractName.new(assigner_name)
    {
      'firstname' => extract_name.firstname,
      'lastname' => extract_name.lastname,
      'mail' => extract_name.mail,
      'admin' => 'false',
      'language' => I18n.locale
    }
  end

  def issue_attributes(row)
    {
      'is_private' => '0',
      'subject' => row[4],
      'description' => row[8],
      'start_date' => row[1],
      'done_ratio' => '0'
    }
  end

  class ExtractName
    attr_reader :assigner_name
    attr_reader :login, :firstname, :lastname, :mail

    MATCH_LIST = {
      'sammy.lin' => 'sammylin',
      'jimmy.kuo' => 'jimmy'
    }.freeze

    def initialize(assigner_name)
      @assigner_name = assigner_name
      result = extract
      @login = result[:login]
      @firstname = result[:firstname]
      @lastname = result[:lastname]
      @mail = result[:mail]
    end

    private

    def extract
      if assigner_name.include?('@')
        login = assigner_name.split('@').first
        firstname = login.split('.').first
        lastname = login.split('.').last
        mail = assigner_name
      else
        login = assigner_name.tr(' ', '.').downcase
        firstname = assigner_name.split(' ').first
        lastname = assigner_name.split(' ').last
        mail = "#{assigner_name.tr(' ', '.').downcase}@commandp.com"
      end
      lastname = lastname == firstname ? '' : lastname

      {
        login: MATCH_LIST[login] || login,
        firstname: firstname,
        lastname: lastname,
        mail: mail
      }
    end
  end

  class Errors
    attr_accessor :errors

    def initialize
      @errors = {}
    end

    def push(key, msg)
      errors[key] = msg
    end

    def present?
      errors.present?
    end

    def blank?
      !present?
    end

    def full_messages
      @errors.map { |key, msg| "#{key}: #{msg}" }.join('</br> ')
    end
  end
end
