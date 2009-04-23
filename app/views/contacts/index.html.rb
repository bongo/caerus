panel 'panels.contacts_index' do
  block do
    search t(".name_search"), :id => :contactSearch, :search_id => :contactSearchField, :replace => :contactCards, :url => contacts_url
    with_tag(:div, :id => :contactCards) do
      store render 'contacts'
    end
  end
end