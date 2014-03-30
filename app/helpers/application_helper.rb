module ApplicationHelper

  def markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
                                        :safe_links_only => true,
                                        :space_after_headers => true)
    markdown.render(safe_squeeze(text))
  end

  def display_search_box?
    display_search_box = true
    if (params[:controller] === "static_pages" && params[:action] === "home") ||
       (params[:controller] === "documents" && params[:action] === "search")
       display_search_box = false
    end
    return display_search_box
  end

  # A simple check to see if the user is an admin.
  def admin?
    session[:password] == ENV["HSSS_ADMIN_PASSWORD"]
  end

  # Returns the full title on a per-page basis.
  def full_title(page_title)
    base_title = "Research and alerts for public documents published by cities and towns"
    if page_title.empty?
      base_title
    else
      "#{page_title}".html_safe
    end
  end

  # Create a navigation link within a list item.
  def nav_link_to(name, path, exact = true)
    options = {}

    if (exact && (request.path_info.eql? path)) || (!exact && (request.path_info.starts_with? path))
      options[:class] = 'active'
    end

    "#{tag('li', options, true)}#{link_to(name, path)}</li>".html_safe
  end

  # Remove superfluous whitespaces from the given string.
  def safe_squeeze(value)
    value = value.strip.gsub(/\s+/, ' ').squeeze(' ').strip unless value.nil?
  end
end
