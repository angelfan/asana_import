require 'csv'
class AsanaImportsController < ApplicationController
  unloadable


  def new
  end

  def create
    import_service = AsanaImportService.new(params[:csv])
    import_service.import
    if import_service.errors.present?
      flash[:error] = import_service.errors.full_messages
    else
      flash[:notice] = l(:asana_import_success)
    end
    redirect_to :back
  end
end

