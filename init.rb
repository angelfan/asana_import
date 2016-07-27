Redmine::Plugin.register :asana_import do
  name 'Asana Import plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  menu :top_menu, :asana_imports, '/asana_imports/new', :caption => :asana_imports, :after => :projects, :if => Proc.new { User.current.admin? }
end