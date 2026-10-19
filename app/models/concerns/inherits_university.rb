# Domain records store the university of the record they belong to (a grade, the one of its
# evaluation; an enrollment, the one of its section), so every table can be isolated by university.
module InheritsUniversity
  extend ActiveSupport::Concern

  class_methods do
    def inherits_university_from(parent)
      belongs_to :university

      before_validation { self.university ||= public_send(parent)&.university }

      validate do
        owner = public_send(parent)
        errors.add(:university, :must_match_parent) if owner && university_id != owner.university_id
      end
    end
  end
end
