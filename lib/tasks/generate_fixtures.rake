require 'lib/util/card_builder.rb'      


def check_for_fulltext_schema
  schema_error = ("Oops! Attempt to load a schema with a broken cards table.  Rails can't properly dump and restore a schema with fulltext index data (indexed_content). " +
    "you'll need to connect to a database without these fields and rerun >rake db:schema:dump first.")
  begin 
    # it would be good to do a test here, but it has to see whether the type is tsvector now, because cards should always have indexed_content.
    
#    if Card.columns.map(&:name).include?('indexed_content')
#      raise(schema_error)
#    end
  rescue
    raise(schema_error)
  end
end
 
def set_database( db )
  y = YAML.load_file("#{RAILS_ROOT}/config/database.yml")
  y["development"]["database"] = db
  y["production"]["database"] = db
  File.open( "#{RAILS_ROOT}/config/database.yml", 'w' ) do |out|
    YAML.dump( y, out )
  end
end

namespace :db do
  namespace :test do
    desc 'Prepare the test database and load the schema'
    task :prepare => :environment do   
      check_for_fulltext_schema        
      if defined?(ActiveRecord::Base) && !ActiveRecord::Base.configurations.blank?
        Rake::Task[{ :sql  => "db:test:clone_structure", :ruby => "db:test:clone" }[ActiveRecord::Base.schema_format]].invoke
      end 
      puts ">>loading test fixtures"
      puts `rake db:fixtures:load RAILS_ENV=test`
    end
  end
  
  namespace :fixtures do
    desc "Load fixtures into the current environment's database.  Load specific fixtures using FIXTURES=x,y"
    task :load => :environment do
      require 'active_record/fixtures'
      ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
      (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(File.join(RAILS_ROOT, 'test', 'fixtures', '*.{yml,csv}'))).each do |fixture_file|
        Fixtures.create_fixtures('test/fixtures', File.basename(fixture_file, '.*'))
      end  
      Rake::Task['fulltext:prepare'].invoke
    end
  end
end
        
namespace :test do                            
  ## FIXME: this generates an "Adminstrator links" card with the wrong reader_id, I have been 
  ##  setting it by hand after fixture generation.  
  desc "recreate test fixtures from fresh db"
  task :generate_fixtures => :environment do  

    if System.enable_postgres_fulltext
      raise("Oops!  you need to disable postgres_fulltext in wagn.rb before generating fixtures")
    end
         
    abcs = ActiveRecord::Base.configurations    
    config = RAILS_ENV || 'development'  
    olddb = abcs[config]["database"]
    abcs[config]["database"] = "wagn_test_template"

  #=begin  
    begin
      set_database 'wagn_test_template'
      
      #Rake::Task['wagn:create'].invoke   # FIXME I'd rather call create, but it was operating on the wrong db
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke

      Rake::Task['db:schema:load'].invoke
      Rake::Task['wagn:bootstrap:load'].invoke
  
  
      # I spent waay to long trying to do this in a less hacky way--  
      # Basically initial database setup/migration breaks your models and you really 
      # need to start rails over to get things going again I tried ActiveRecord::Base.reset_subclasses etc. to no avail. -LWH
      puts ">>populating test data"
      puts `rake test:populate_template_database --trace`      
      puts ">>extracting to fixtures"
      puts `rake test:extract_fixtures`
      set_database olddb 
    rescue Exception=>e
      set_database olddb 
      raise e
    end
    # go ahead and load the fixtures into the test database
    
    puts ">>preparing test database"
    puts `rake db:test:prepare RAILS_ENV=test`
    #Rake::Task['db:test:prepare'].invoke
  #=end
  end

  desc "dump current db to test fixtures"
  task :extract_fixtures => :environment do
    sql = "SELECT * FROM %s"
    skip_tables = ["schema_info","schema_migrations","sessions"]
    ActiveRecord::Base.establish_connection
    (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name|
      i = "000"
      File.open("#{RAILS_ROOT}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        file.write data.inject({}) { |hash, record|
          hash["#{table_name}_#{i.succ!}"] = record
          hash
        }.to_yaml
      end
    end
  end
  
  desc "create sample data for testing"
  task :populate_template_database => :environment do   
    # setup test data here
    # additional test data auto-loaded from Test classes    
    # when I load these I don't want them to run as is the default; this is somewhat brutal..
    require 'test/unit'    
    require 'shoulda/test_unit'
    Test::Unit::AutoRunner.class_eval {  def self.run() 1 end }
              
    load 'test/fixtures/shared_data.rb'
    SharedData.add_test_data
    
    Dir["#{RAILS_ROOT}/test/**/*.rb"].each {|f| load "#{f}"}  
    Test::Unit::TestCase.descendents.each do |c|
      if c.respond_to? :add_test_data 
        c.add_test_data
      end
    end
  end
 
end
        

#end