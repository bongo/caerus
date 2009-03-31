class Track < ActiveRecord::Base
  belongs_to                    :site
  before_validation_on_create   :create_site_relationship
  validates_uniqueness_of       :view, :scope => [:site_id, :visitor, :session],
                                :if => lambda {|track|
                                  track.visitor && track.session && track.site_id
                                }

  #
  # The #duration attribute is marked in the same row as the last
  # row of a session (visit).  This means that the row marked with #duration
  # contains information about the number of page_views in a session (#view)
  # the duration of the session (#duration), the visitor (#visitor) and the
  # exit url (#url).  So its a handy row to use for summarising a visit and
  # is used to retrieve only one row from any given visit - and hence to
  # summarise the number of visits.
  #
  named_scope :page_views,
    :conditions => "outbound = 0 and url IS NOT NULL"
  
  named_scope :visitors,
    :select => "UNIQUE visitor", :conditions => "visitor IS NOT NULL"
  
  # non-null duration identifies unique visits
  named_scope :visits,
    :conditions => 'duration IS NOT NULL'
  
  # Visitors for whom their first visit was during this period
  named_scope :new_visitors,
    :conditions => "visit = 1 AND duration IS NOT NULL" 
  
  # Visitors who visited before the current period and have now returned
  named_scope :return_visitors,
    :conditions => "visit > 1 AND duration IS NOT NULL"
  
  # Visitors who have visited more than once in the current period
  named_scope :repeat_visitors, 
    {:conditions => "visit > 1 AND duration IS NOT NULL AND previous_session IS NOT NULL"}
  
  named_scope :entry_pages,
    :conditions => "view = 1 and url IS NOT NULL"

  named_scope :landing_pages, 
    :conditions => "view = 1 and url IS NOT NULL and campaign_name IS NOT NULL"

  named_scope :exit_pages,
    :conditions => "duration IS NOT NULL"
     
  named_scope :duration,
    :conditions => "duration IS NOT NULL"
  
  named_scope :bounces, :conditions => "duration IS NOT NULL and view = 1" do
    def rate
      number = count
      entries = entry_pages.count
      number / entries
    end
  end
  
  named_scope :opened_emails,
    :conditions => "campaign_name IS NOT NULL and campaign_medium = 'email' AND campaign_source = 'open'"
    
  named_scope :clicked_emails,
    :conditions => "campaign_name IS NOT NULL and campaign_medium = 'email' AND campaign_source = 'landing'"
    
  named_scope :between, lambda {|range|
    repeat_visitors.send("proxy_options=", {:test => 'test'})
    puts repeat_visitors.proxy_options.inspect
    {:conditions => {:tracked_at => range} }
  }
 
  named_scope :by, lambda {|*args|
    # Args are passed as SELECT and GROUP clauses
    # with special attention paid to :day, :month, :year, :hour
    # configurations because the manipulate the #tracked_at formation
    #
    # Note that this also controls the grouping since we add each
    # argument to both the SELECT and GROUP.  This simplifies reporting
    # on either aggregate events (ie. 43 page views this month) versus
    # more fine-grained reporting.
    
    select = []
    group = []
    args.each do |a|
      case a
      when :day
        select << "date(tracked_at) as tracked_at"
        group << "date(tracked_at)"
      when :month
        select << "date_format(tracked_at, '%Y/%m/1') as tracked_at"
        group << "year(tracked_at), month(tracked_at)"
      when :year
        select << "date_format(tracked_at, '%Y/1/1') as tracked_at"
        group << "year(tracked_at)"
      when :hour
        select << "date_format(tracked_at, '%Y/%m/%d %k:00:00') as tracked_at"
        group << "day(tracked_at), hour(tracked_at)"
      else
        select << a.to_s
        group << a.to_s
      end
    end
    select << "count(*) as count"
    {:select => select.join(', '), :group => group.join(', ')}
  } do
    
    # Can't use the standard AR versions of these because #by munges
    # the SQL to it's own ends.
    def count
      find(:all).size
    end
    
    def sum(arg = :count)
      find(:all).map(&arg).sum
    end
    
    def average(arg = :count)
      values = find(:all).map(&arg)
      values.sum.to_f / values.size.to_f
    end
  end
  
  # => Campaign scoping
  named_scope   :campaign, lambda {|campaign|
    {:conditions => {:campaign_name => campaign}}
  }
            
  named_scope   :source, lambda {|source|
    {:conditions => {:campaign_source => source}}
  }         

  named_scope   :medium, lambda {|method|
    {:conditions => {:campaign_medium => method}}
  } 
  
  # Visitor may have several parts when imported from the tracking system
  # => 0: Visitor id
  # => 1: Number of visits
  # => 2: Current session timestamp
  # => 3: Previous session timestamp
  def visitor=(v)
    return if v.blank?
    parts = v.split('.')
    raise "Track: Badly formed visitor variable: '#{s}" if parts.size > 4
    self.write_attribute('visitor', parts[0])
    RAILS_DEFAULT_LOGGER.debug "Visitor #{parts[0]} with visit #{parts[1]}"
    self.visit = parts[1] if parts[1]
    parts[3] = parts[3].to_i / 1000 if parts[3] && parts[3].to_i.is_a?(Bignum)
    self.previous_session = Time.at(parts[3].to_i) if parts[3]
  end
  
  def session=(s)
    return if s.blank?
    parts = s.split('.')
    parts[1] = parts[2] if parts.size == 3  # Small error window of bad cookies - can delete
    self.write_attribute('session', parts[0])
    self.view = parts[1] if parts[1]    
  end

private
  def create_site_relationship
    return unless self.site_code
    self.site = Site.find_by_tracker(self.site_code)
  end
  
end
