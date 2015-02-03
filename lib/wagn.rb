# should be able to move these to more appropriate places
WAGN_GEM_ROOT = File.expand_path('../..', __FILE__)

module Wagn

  class << self    
    def root
      Rails.root
    end
  
    def application
      Rails.application
    end
    
    def config
      application.config
    end
    
    def paths
      application.paths
    end
    
    def gem_root
      WAGN_GEM_ROOT
    end
    
    def with_logging method, message, opts, &block
      if (pl_config=Wagn.config.performance_logger) && pl_config[:methods] && pl_config[:methods].include?(method)
        Wagn::Log::Performance.with_timer(method, message, opts) do
          block.call
        end
      else
        block.call
      end
    end
    
    
    def future_stamp
      ## used in test data
      @@future_stamp ||= Time.local 2020,1,1,0,0,0
    end
  end
  
end