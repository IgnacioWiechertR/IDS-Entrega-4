module Reports
  class DataCompletenessController < ApplicationController
    def show
      authorize! :read_data_completeness, :reports
      @rows = DataCompletenessService.call(university: current_university)
    end
  end
end
