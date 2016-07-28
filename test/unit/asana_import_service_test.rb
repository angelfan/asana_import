# encoding: utf-8
require File.expand_path('../../test_helper', __FILE__)

class AsanaImportServiceTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :user_preferences, :roles,
           :trackers,
           :issue_statuses, :issue_categories, :issue_relations,
           :enumerations

  include Redmine::I18n

  def setup
    csv_path = Rails.root.join('plugins/asana_import/test/fixtures/files/Web_Sprint_Board.csv').to_s
    csv = ActionDispatch::Http::UploadedFile.new(
      filename: File.basename(csv_path), tempfile: File.open(csv_path)
    )
    service = AsanaImportService.new(csv, User.first)
    service.import
  end

  def test_project_name
    assert_equal 'Web Sprint Board', Project.last.name
  end

  def test_project_members
    assert_equal 7, Project.last.members.size
  end

  def test_user_size
    assert_equal 9 + 6, User.all.size
  end

  def test_issue_size
    assert_equal 17, Project.last.issues.size
  end

  def test_issue_assigner
    assert_equal 'nazi9999', Project.last.issues.second.assigned_to.login
  end

  def test_nazi9999_name
    nazi9999 = User.find_by(login: 'nazi9999')
    assert_equal 'nazi9999', nazi9999.firstname
    assert_equal '', nazi9999.lastname
  end

  def test_manic_name
    manic = User.find_by(login: 'manic.chuang')
    assert_equal 'Manic', manic.firstname
    assert_equal 'Chuang', manic.lastname
  end
end
