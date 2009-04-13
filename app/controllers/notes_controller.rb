class NotesController < ApplicationController
  before_filter   :retrieve_note, :only => :update
  
  def create
    @note = Note.new(params[:note])
    @note.created_by = current_user
    @note.save
  end
  
  def update
    @note.attributes = params[:note]
    @note.updated_by = current_user
    @note.save
  end
  
private
  def retrieve_note
    @note = Note.find!(params[:id])
  end
  
end
