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
    if project.new_record?
      project.name = filename.gsub('_', ' ')
    end
    project.add_default_member(user)
    project.save
    project
  end

  def find_or_initialize_assigner(assigner_name)
    return false if assigner_name.blank?
    login = assigner_name.gsub(' ', '').downcase
    assigner = User.find_or_initialize_by(login: login)
    if assigner.new_record?
      assigner.safe_attributes = user_attributes(assigner_name)
      assigner.login = login
      assigner.activate
      assigner.password, assigner.password_confirmation = 'Commandp123', 'Commandp123'
      assigner.save(validate: false)
      project.add_default_member(assigner) unless project.members.pluck(:id).include?(assigner.id)
      project.save
    end

    assigner
  end

  def create_issue(row)
    assigner = find_or_initialize_assigner(row[5])
    issue = Issue.new
    issue.project = project
    issue.author = user
    issue.tracker = ::Tracker.first
    issue.status = ::IssueStatus.first
    issue.priority = ::IssuePriority.first
    issue.safe_attributes = issue_attributes(assigner, row)
    issue.save!
  rescue => e
    binding.pry
    errors.push(row[0], e.to_s)
  end

  def user_attributes(assigner_name)
    firstname = assigner_name.split(' ').first
    lastname = assigner_name.split(' ').last
    lastname = lastname == firstname ? '' : lastname
    {
      'firstname' => firstname,
      'lastname' => lastname,
      'mail' => "#{assigner_name.gsub(' ', '')}@commandp.com",
      'admin' => 'false',
      'language' => I18n.locale
    }
  end

  def issue_attributes(assigner, row)
    {
      'is_private' => '0',
      'subject'=> row[4],
      'description'=> row[8],
      'assigned_to_id' => assigner.try(:id).to_s,
      'start_date' => row[1],
      'done_ratio' => '0',
      'watcher_user_ids' => [user.id]
    }
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
      @errors.map {|key, msg| "#{key}: #{msg}"}.join('</br> ')
    end
  end
end