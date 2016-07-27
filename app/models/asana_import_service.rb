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

  def find_or_initialize_tracker(tracker_name)
    return false unless tracker_name
    if tracker_name
      tracker = User.find_or_initialize_by(login: tracker_name.split(' ').join(''))
      if tracker.new_record?
        tracker.safe_attributes = user_attributes(tracker_name)
        tracker.activate
        tracker.password, tracker.password_confirmation = 'Commandp123', 'Commandp123'
        tracker.save(validate: false)
      end

      project.add_default_member(tracker)
      project.save

      tracker
    end
  end

  def create_issue(row)
    tracker = find_or_initialize_tracker(row[5])
    issue = Issue.new
    issue.project = @project
    issue.author ||= User.current
    issue.safe_attributes = issue_attributes(tracker, row)
    issue.save!
  rescue => _e
    errors.push(row[0], issue.errors.full_messages)
  end

  def user_attributes(tracker_name)
    {
      'login' => tracker_name.gsub(' ', ''),
      'firstname' => tracker_name.split(' ').first,
      'lastname' => tracker_name.split(' ').last,
      'mail' => "#{tracker_name.gsub(' ', '')}@commandp.com",
      'admin' => 'false',
      'language' => I18n.locale
    }
  end

  def issue_attributes(tracker, row)
    {
      'is_private' => '0',
      'tracker_id' => '1',
      'subject'=> row[4],
      'description'=> row[8],
      'status_id'=> '1',
      'priority_id' => '2',
      'assigned_to_id' => tracker.try(:id).to_s,
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