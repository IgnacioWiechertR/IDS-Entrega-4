class AnnouncementsController < ApplicationController
  before_action :set_announcement, only: %i[ show edit update destroy ]

  # GET /announcements
  def index
    @announcements = Announcement.all
  end

  # GET /announcements/1
  def show
  end

  # GET /announcements/new
  def new
    @announcement = Announcement.new
  end

  # GET /announcements/1/edit
  def edit
  end

  # POST /announcements
  def create
    @announcement = Announcement.new(announcement_params)

    if @announcement.save
      redirect_to @announcement, notice: "Announcement was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /announcements/1
  def update
    if @announcement.update(announcement_params)
      redirect_to @announcement, notice: "Announcement was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /announcements/1
  def destroy
    @announcement.destroy!
    redirect_to announcements_path, notice: "Announcement was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_announcement
      @announcement = Announcement.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def announcement_params
      params.expect(announcement: [ :course_id, :section_id, :subject, :body, :author_id ])
    end
end
