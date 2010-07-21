# This is the non-volatile store for the graph data.

class GraphEdge < ActiveRecord::Base
  
  after_create  :add_to_graph
  after_destroy :remove_from_graph
  after_update  :update_graph
  
  cattr_accessor :node_class, :oqgraph_table_name, :to_key, :from_key
  
  # Creates the OQgraph table if it does not exist.
  # Deletes all entries if it does exist and then repopulates with 
  # current edges. TODO Optimise this so that it only does so if the 
  # DB server has been restarted.
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
    
    connection.execute("DELETE FROM #{oqgraph_table_name}")
    
    self.all.each do |edge|
      edge.add_to_graph
    end
  end   
  
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
  
  def self.originating_vertices(to)    
    sql = <<-EOS
     WHERE latch = 1 AND destid = #{to.id}
     ORDER BY seq;
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  def self.reachable_vertices(from)    
    sql = <<-EOS
     WHERE latch = 1 AND origid = #{from.id}
     ORDER BY seq;
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  # FIXME: Note this currently does not work.
  # I suspect a bug in OQGRaph engine.
  def self.in_edges(to)
    sql = <<-EOS
     WHERE latch = 0 AND destid = #{to.id}
    EOS
    
    node_class.find_by_sql select_for_node << sql 
  end
  
  def self.out_edges(from)    
    sql = <<-EOS
     WHERE latch = 0 AND origid = #{from.id}
    EOS
  
    node_class.find_by_sql select_for_node << sql 
  end
   
    def add_to_graph
      connection.execute <<-EOS
        REPLACE INTO #{oqgraph_table_name} (origid, destid, weight) 
        VALUES (#{self.send(self.class.from_key)}, #{self.send(self.class.to_key)}, #{weight || 1.0})
      EOS
    end

private

    def remove_from_graph
      connection.execute <<-EOS
        DELETE FROM #{oqgraph_table_name} WHERE origid = #{self.send(self.class.from_key)} AND destid = #{self.send(self.class.to_key)};
      EOS
    end

    def update_graph
      connection.execute <<-EOS
        UPDATE #{oqgraph_table_name} 
        SET origid = #{self.send(self.class.from_key)}, 
            destid = #{self.send(self.class.to_key)}, 
            weight = #{weight} 
        WHERE origid = #{self.send(self.class.from_key + '_was')} AND destid = #{self.send(self.class.to_key + '_was')};
      EOS
    end
  def self.select_for_node
    sql = "SELECT "
    sql << node_class.columns.map{|column| "#{node_table}.#{column.name}"}.join(",")
    sql << ", #{oqgraph_table_name}.weight FROM #{oqgraph_table_name} JOIN #{node_table} ON (linkid=id) "
  end
  
  def self.node_table
    node_class.table_name
  end
end