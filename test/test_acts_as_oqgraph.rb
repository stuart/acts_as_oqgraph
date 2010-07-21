require 'helper'

class TestActsAsOqgraph < ActiveSupport::TestCase
  def setup
    
    ActiveRecord::Base.establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :password => "",
        :database => "test"
      )
    
    ActiveRecord::Base.connection.execute("CREATE TABLE IF NOT EXISTS test_models(id INTEGER DEFAULT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) );")
    ActiveRecord::Base.connection.execute("CREATE TABLE IF NOT EXISTS test_model_edges(id INTEGER DEFAULT NULL AUTO_INCREMENT PRIMARY KEY, from_id INTEGER, to_id INTEGER, weight DOUBLE);")
    ActiveRecord::Base.connection.execute("CREATE TABLE IF NOT EXISTS custom_edges(id INTEGER DEFAULT NULL AUTO_INCREMENT PRIMARY KEY, from_id INTEGER, to_id INTEGER, weight DOUBLE);")
    
    require File.join(File.dirname(__FILE__),'models/custom_test_model')
    require File.join(File.dirname(__FILE__),'models/test_model')
    
    @test_1 = TestModel.create(:name => 'a')
    @test_2 = TestModel.create(:name => 'b')
    @test_3 = TestModel.create(:name => 'c')
    @test_4 = TestModel.create(:name => 'd')
    @test_5 = TestModel.create(:name => 'e')
    @test_6 = TestModel.create(:name => 'f')
    
  end

  def teardown
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_models;")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_model_edges;")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS custom_edges;")
    ActiveRecord::Base.connection.execute("DELETE FROM test_model_oqgraph;") 
    ActiveRecord::Base.connection.execute("DELETE FROM custom_test_model_oqgraph;") 
    
  end
  
  def test_edge_table_and_class_names
    assert_equal "test_model_edges", TestModel.edge_table 
    assert_equal TestModelEdge, TestModel.edge_class
  end
  
  def test_edge_class_created
    assert_nothing_raised do
      ::TestModelEdge
      ::CustomEdge
    end
  end
  
  def test_creation_of_oqgraph_and_edge_tables
    mysql = Mysql.new('localhost', 'root', '', 'test')
    assert mysql.list_tables.include?('test_model_oqgraph')
    assert mysql.list_tables.include?('test_model_edges')
    fields = mysql.list_fields('test_model_oqgraph').fetch_fields.map{|f| f.name}
    assert fields.include?('origid')
    assert fields.include?('destid')
    assert fields.include?('weight')
    assert fields.include?('latch')
    assert fields.include?('seq')
    assert fields.include?('linkid')
  end
  
  def test_edge_class_name_option
    assert_equal 'custom_edges', CustomTestModel.edge_table
    assert_equal CustomEdge, CustomTestModel.edge_class
  end
  
  def test_test_model_edge_creation
    @test_1.create_edge_to(@test_2)
    assert_not_nil edge = TestModelEdge.find(:first, :conditions => {:from_id => @test_1.id, :to_id => @test_2.id, :weight => 1.0})
    assert @test_1.outgoing_nodes.include?(@test_2)
  end
  
  def test_edge_creation_through_association
    @test_1.outgoing_nodes << @test_2
    assert_not_nil edge = TestModelEdge.find(:first, :conditions => {:from_id => @test_1.id, :to_id => @test_2.id})
  end
  
  def test_test_model_undirected_edge_creation
    @test_1.create_edge_to_and_from(@test_2)
    assert_not_nil edge = TestModelEdge.find(:first, :conditions => {:from_id => @test_1.id, :to_id => @test_2.id, :weight => 1.0})
    assert_not_nil edge = TestModelEdge.find(:first, :conditions => {:from_id => @test_2.id, :to_id => @test_1.id, :weight => 1.0}) 
    assert @test_1.outgoing_nodes.include?(@test_2)
    assert @test_1.incoming_nodes.include?(@test_2)
  end
    
  def test_adding_weight_to_edges
    @test_1.create_edge_to(@test_2, 2.0)
    assert_not_nil edge = TestModelEdge.find(:first, :conditions => {:from_id => @test_1.id, :to_id => @test_2.id})
    assert edge.weight = 2.0
  end
  
  def test_edge_model_creation_creates_oqgraph_edge
    @test_1.create_edge_to(@test_2, 2.5)
    oqedge = ActiveRecord::Base.connection.execute("SELECT * FROM test_model_oqgraph WHERE origid=#{@test_1.id} AND destid=#{@test_2.id};")
    assert_equal [nil,"1","2","2.5",nil,nil], oqedge.fetch_row                                      
  end
  
  def test_edge_model_removal_deletes_oqgraph_edge
    @test_1.outgoing_nodes << @test_2
    edge = @test_1.outgoing_edges.find(:first, :conditions => {:to_id => @test_2.id})
    edge.destroy
    oqedge = ActiveRecord::Base.connection.execute("SELECT * FROM test_model_oqgraph WHERE origid=#{@test_1.id} AND destid=#{@test_2.id};")
    assert_equal nil, oqedge.fetch_row
  end
  
  def test_edge_model_update
    edge = @test_1.create_edge_to(@test_2, 2.5) 
    edge.update_attributes(:weight => 3.0)
    oqedge = ActiveRecord::Base.connection.execute("SELECT * FROM test_model_oqgraph WHERE origid=#{@test_1.id} AND destid=#{@test_2.id};") 
    assert_equal [nil,"1","2","3",nil,nil], oqedge.fetch_row
    edge.update_attributes(:to_id => 3)
    oqedge = ActiveRecord::Base.connection.execute("SELECT * FROM test_model_oqgraph WHERE origid=#{@test_1.id} AND destid=3;") 
    assert_equal [nil,"1","3","3",nil,nil], oqedge.fetch_row
  end
  
  def test_gettting_the_shortest_path 
    #   a -- b -- c -- d
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    @test_3.create_edge_to @test_4
    assert_equal [@test_1, @test_2, @test_3, @test_4], @test_1.shortest_path_to(@test_4)
    assert_equal ['a','b','c','d'], @test_1.shortest_path_to(@test_4).map(&:name)
  end
  
  def test_getting_shortest_path_more_complex
    #
    # a -- b -- c -- d
    #      |      / 
    #      e-- f 
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    @test_3.create_edge_to @test_4
    @test_2.create_edge_to @test_5
    @test_5.create_edge_to @test_6
    @test_4.create_edge_to @test_6
    assert_equal [@test_1, @test_2, @test_5, @test_6], @test_1.shortest_path_to(@test_6)
  end
  
  def test_path_returns_weight
    #   a -- b -- c -- d
    @test_1.create_edge_to @test_2, 2.0
    @test_2.create_edge_to @test_3, 1.5
    @test_3.create_edge_to @test_4, 1.2
    assert_equal [nil,"2","1.5","1.2"], @test_1.shortest_path_to(@test_4).map(&:weight)
  end
  
  def test_path_weight
    #   a -- b -- c -- d
     @test_1.create_edge_to @test_2, 2.0
     @test_2.create_edge_to @test_3, 1.5
     @test_3.create_edge_to @test_4, 1.2
     assert_equal 4.7, @test_1.path_weight_to(@test_4)
  end
  
  def test_path_find_breadth_first
    @test_1.outgoing_nodes << @test_2
    @test_2.outgoing_nodes << @test_3
    @test_3.outgoing_nodes << @test_4
    assert_equal [@test_1, @test_2, @test_3, @test_4], @test_1.shortest_path_to(@test_4, :method => :breadth_first)
  end
  
  def test_get_originating_nodes
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    assert_equal [@test_2, @test_1] , @test_2.originating
  end
    
  def test_get_reachable_nodes
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    assert_equal [@test_2, @test_3] , @test_2.reachable
  end
  
  def test_get_originating?
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    assert @test_2.originating?(@test_1)
    assert !@test_2.originating?(@test_3) 
  end
  
  def test_get_incoming_nodes
    @test_1.create_edge_to @test_2
    @test_2.create_edge_to @test_3
    assert_equal [@test_1] , @test_2.incoming_nodes
  end
  
   def test_get_outgoing_nodes
     @test_1.create_edge_to @test_2
     @test_2.create_edge_to @test_3
     assert_equal [@test_3] , @test_2.outgoing_nodes
   end
   
   def test_duplicate_links_ignored
     @test_1.create_edge_to @test_2
     assert_nothing_raised do
       @test_1.create_edge_to @test_2
     end
   end
   
   def test_duplicate_link_error
    ActiveRecord::Base.connection.execute("INSERT INTO test_model_oqgraph (destid, origid, weight) VALUES (99,99,1.0);")   
    assert_raises ActiveRecord::StatementInvalid do
      ActiveRecord::Base.connection.execute("INSERT INTO test_model_oqgraph (destid, origid, weight) VALUES (99,99,1.0);")
    end
   end
   
   def test_duplicate_link_error_fix
    ActiveRecord::Base.connection.execute("REPLACE INTO test_model_oqgraph (destid, origid, weight) VALUES (99,99,1.0);")   
    assert_nothing_raised do
      ActiveRecord::Base.connection.execute("REPLACE INTO test_model_oqgraph (destid, origid, weight) VALUES (99,99,1.0);")
    end
   end
   
    
end
