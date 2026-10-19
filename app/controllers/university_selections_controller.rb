# Lets the director pick the active university from the top bar (A3).
class UniversitySelectionsController < ApplicationController
  def update
    authorize! :switch, University

    university = University.find(params.expect(:university_id))
    session[:university_id] = university.id
    redirect_to home_path_for(current_user), notice: t("university_selection.changed", name: university.name)
  end
end
