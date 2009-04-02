require 'core_extensions'
require 'flex_stuff'
require 'log_parser'
require 'web_analytics'
require 'flash_chart'
require 'page_layout'

# Small hack to let us play with
# proxy options in other named scopes
module ActiveRecord
  class Base
    def current_scoped_find=(scope) #:nodoc:
      scoped_methods.last[:find] = scope
    end
    
    def current_scoped_find
      scoped_methods.last[:find]
    end
  end
end
