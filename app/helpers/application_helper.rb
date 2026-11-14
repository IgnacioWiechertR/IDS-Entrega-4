module ApplicationHelper
  INPUT_CLASSES = "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 shadow-sm " \
                  "focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500".freeze
  PRIMARY_BUTTON_CLASSES = "inline-flex justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold " \
                           "text-white shadow-sm hover:bg-indigo-500 focus:outline-none focus:ring-2 " \
                           "focus:ring-indigo-500 focus:ring-offset-2".freeze

  # The validation errors of one field, shown right below it.
  def field_errors(form, attribute)
    messages = form.object.errors.full_messages_for(attribute)
    return if messages.empty?

    tag.p(messages.to_sentence, id: "#{form.object_name}_#{attribute}_error", class: "mt-1 text-sm text-red-700")
  end

  def nav_link_to(label, path)
    active = current_page?(path)
    classes = active ? "font-semibold text-indigo-700" : "text-slate-600 hover:text-slate-900"
    link_to label, path, class: classes, aria: { current: (active ? "page" : nil) }
  end
end
