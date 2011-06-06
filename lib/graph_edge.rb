# This is the non-volatile store for the graph data.

class GraphEdge < ActiveRecord::Base
  
  after_create  :add_to_graph
  after_destroy :remove_from_graph
  after_update  :update_graph
  
  # Creates the OQgraph table if it does not exist.
  def self.create_graph_table
        
      connection.execute <<-EOS
      CREATE TABLE IF NOT EXISTS #{oqgraph_table_name} (
          latch   SMALLINT  UNSIGNED NULL,
          origid  BIGINT    UNSIGNED NULL,
          destid  BIGINT    UNSIGNED NULL,
          weight  DOUBLE    NULL,
          seq     BIGINT    UNSIGNED NULL,
          linkid  BIGINT    UNSIGNED NULL,
          KEY (latch, origid, destid) USING HASH,
          KEY (latch, destid, origid) USING HASH
        ) ENGINE=OQGRAPH;
       EOS
    
    # if the DB server has restarted then there will be no records in the oqgraph table.
    if connection.select_value("SELECT COUNT(*) FROM #{oqgraph_table_name}") == 0
      connection.execute <<-EOS
        REPLACE INTO #{oqgraph_table_name} (origid, destid, weight) 
        SELECT #{from_key}, #{to_key}, #{weight_column} FROM #{table_name}
        EOS
    end                   
  end   
  
  # Returns the shortest path from node to node.
  # +options+ A hash containing options.
  # The only option is :method which can be 
  # :breadth_first to do a breadth first search.
  # It defaults to using Djikstra's algorithm.
  def self.shortest_path(from, to, options)
    latch = case options[:method]
      when :breadth_first then 2
      else 1
    end  
    latch = 1
    latch = 2 if options[:method] == :breadth_first
    
    sql = <<-EOS
     WHERE latch = #{latch} AND origid = #{from.id} AND destid = #{to.id}
     ORDER BY seq;
    EOS
    
    node_class.find_by_sql select_for_node << sql
  end
  
  # Finds all the nodes that lead to the node
  def self.originating_nodes(node)    
    sql = <<-EOS
     WHERE latch = 1 AND destid = #{node.id}
     ORDER BY seq;
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  # Finds all the nodes that are reachable from the node
  def self.reachable_nodes(node)    
    sql = <<-EOS
     WHERE latch = 1 AND origid = #{node.id}
     ORDER BY seq;
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  # Finds the edges leading directly into the node
  # FIXME: Note this currently does not work.
  # I suspect a bug in OQGraph engine.
  # Using the node classes incoming_nodes is equivalent to this.
  def self.in_edges(node)
    sql = <<-EOS
     WHERE latch = 0 AND destid = #{node.id}
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  # Finds the edges leading directly out of the node
  def self.out_edges(node)    
    sql = <<-EOS
     WHERE latch = 0 AND origid = #{node.id}
    EOS
  
    node_class.find_by_sql select_for_node << sql 
  end

private
  
  # Callback to add new graph edges to the OQGraph table
  def add_to_graph
    connection.execute <<-EOS
      REPLACE INTO #{oqgraph_table_name} (origid, destid, weight) 
      VALUES (#{self.send(self.class.from_key)}, #{self.send(self.class.to_key)}, #{self.send(self.class.weight_column) || 1.0})
    EOS
  end    
    
    
  # Callback to remove deleted graph edges from the OQGraph table
  def remove_from_graph
    # Ignores trying to delete nonexistent records
     connection.execute <<-EOS
        DELETE IGNORE FROM #{oqgraph_table_name} WHERE origid = #{self.send(self.class.from_key)} AND destid = #{self.send(self.class.to_key)};
     EOS
  end
  
  # Callback to update graph edges in the OQGraph table
  def update_graph
    connection.execute <<-EOS
      UPDATE #{oqgraph_table_name} 
      SET origid = #{self.send(self.class.from_key)}, 
          destid = #{self.send(self.class.to_key)}, 
          weight = #{self.send(self.class.weight_column)} 
      WHERE origid = #{self.send(self.class.from_key + '_was')} AND destid = #{self.send(self.class.to_key + '_was')};
    EOS
  end
  
  # nodoc
  def self.select_for_node
    sql = "SELECT "
    sql << node_class.columns.map{|column| "#{node_table}.#{column.name}"}.join(",")
    sql << ", #{oqgraph_table_name}.weight FROM #{oqgraph_table_name} JOIN #{node_table} ON (linkid=id) "
  end
  
  # Returns the table containing the nodes for these edges.
  def self.node_table
    node_class.table_name
  end
end