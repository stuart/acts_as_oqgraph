require 'active_record'
require File.join(File.dirname(__FILE__),'graph_edge')
require 'mysql'

module OQGraph
  def self.included(base)
    base.extend(ClassMethods)
  end
      
    module ClassMethods
      # Usage:
      # 
      # Class Foo < ActiveRecord::Base
      #     acts_as_oqgraph  +options+
      #     ....
      # end
      # 
      # Options: 
      # :class_name - The name of the edge class, defaults to current class name appended with Edge. eg FooEdge
      # :table_name - The name of the edge table, defaults to table name of the specified class, eg foo_edges
      # :oqgraph_table_name - the name of the volatile oqgraph table. Default foo_edge_oqgraph
      # :from_key - The from key field in the edge table. Default 'from_id'
      # :to_key - The to key field in the edge table. Default: 'to_id'
      # :weight_column - The weight field in the edge table.
      # 
      # Setup:
      # This gem requires the use of MySQL or MariaDB with the OQGraph engine plugin.
      # For details of this see: http://openquery.com/products/graph-engine
      # 
      # You will need a table for the edges with the following schema:
      #   create_table foo_edges do |t|
      #       t.integer from_id
      #       t.integer to_id
      #       t.double weight
      #   end   
      # The field names and table name can be changed via the options listed above.
      #
      # The gem will automatically create the oqgraph table.
      # To rebuild the oqgraph table do:
      #       Model.rebuild_graph
      #
      # Examples of use:
      # 
      # Creating and removing edges:
      #  foo.create_edge_to(bar)
      #  bar.create_edge_to(baz, 2.0)
      #  foo.remove_edge_to(bar) : Note that this removes ALL edges to bar from foo.
      # or alternatively:
      #  foo.outgoing_nodes << bar
      #  foo.outgoing_nodes
      #
      # Examining edges:
      #  foo.originating 
      #    returns [foo]
      #  baz.originating
      #    returns [foo, bar,baz]
      #  bar.reachable
      #    returns [bar, baz]
      #  foo.reachable?(baz)
      #    returns true
      #
      # Path Finding:
      #   foo.shortest_path_to(baz)
      #    returns [foo, bar,baz]
      #
      # With breadth first edge weights are not taken into account:
      #  foo.shortest_path_to(baz, :method => :breadth_first)
      #
      # All these methods return the node object with an additional weight field.
      # This enables you to query the weights associated with the edges found.
      # 
      def acts_as_oqgraph(options = {})
        
        unless check_for_oqgraph_engine 
          raise "acts_as_oqgraph requires the OQGRAPH engine. Install the oqgraph plugin with the following SQL: INSTALL PLUGIN oqgraph SONAME 'oqgraph_engine.so'"
        end
        
        class_name = options[:class_name] || "#{self.name}Edge"
        edge_table_name = options[:table_name] || class_name.pluralize.underscore
        oqgraph_table_name = options[:oqgraph_table_name] || "#{self.name}Oqgraph".underscore  
        from_key = options[:from_key] || 'from_id'
        to_key = options[:to_key]   || 'to_id' 
        weight_column = options[:weight_column] || 'weight'
        # Create the Edge Model
        eval <<-EOS
          class ::#{class_name} < ::GraphEdge
            set_table_name "#{edge_table_name}"
            
            belongs_to :from, :class_name => '#{self.name}', :foreign_key => '#{from_key}'
            belongs_to :to, :class_name => '#{self.name}', :foreign_key => '#{to_key}'
            
            cattr_accessor :node_class, :oqgraph_table_name, :to_key, :from_key, :weight_column
            
            @@oqgraph_table_name = '#{oqgraph_table_name}'
            @@from_key = '#{from_key}'
            @@to_key = '#{to_key}'
            @@node_class = #{self}
            @@weight_column = '#{weight_column}'
            
            create_graph_table
          end
        EOS
        
        has_many :outgoing_edges, {
           :class_name => class_name,
           :foreign_key => from_key,
           :include => :to,
           :dependent => :destroy
         }
        
        has_many :incoming_edges, {
           :class_name => class_name,
           :foreign_key => to_key,
           :include => :from,
           :dependent => :destroy
         }
        
        has_many :outgoing_nodes, :through => :outgoing_edges, :source => :to
        has_many :incoming_nodes, :through => :incoming_edges, :source => :from
                                    
        class_eval <<-EOF
          include OQGraph::InstanceMethods
          
          def self.edge_class
            #{class_name.classify}
          end
          
          def self.edge_table
            '#{edge_table_name}'
          end
          
          def self.rebuild_graph
            edge_class.create_graph_table
          end
        EOF
      end

      private
      
      # Check that we have the OQGraph engine plugin installed in MySQL
      def check_for_oqgraph_engine
        begin
          result = false
          engines = self.connection.execute("SHOW ENGINES")
          engines.each do |engine|
            result = true if (engine[0]=="OQGRAPH" and engine[1]=="YES")
          end
          return result
        rescue ActiveRecord::StatementInvalid => e
          raise "MySQL or MariaDB 5.1 or above with the OQGRAPH engine is required for the acts_as_oqgraph gem.\nThe following error was raised: #{e.inspect}"
        end    
      end
    end
    
    module InstanceMethods
      
      # The class used for the edges between nodes
      def edge_class
        self.class.edge_class
      end
      
      # Creates a one way edge from this node to another with a weight.
      def create_edge_to(other, weight = 1.0)
        edge_class.create!(:from_id => id, :to_id => other.id, :weight => weight)
      end
      
      # +other+ graph node to edge to
      # +weight+ positive float denoting edge weight
      # Creates a two way edge between this node and another.
      def create_edge_to_and_from(other, weight = 1.0)
        edge_class.create!(:from_id => id, :to_id => other.id, :weight => weight)
        edge_class.create!(:from_id => other.id, :to_id => id, :weight => weight)
      end
      
      # +other+ The target node to find a route to
      # +options+ A hash of options: Currently the only option is
      #            :method => :djiskstra or :breadth_first
      # Returns an array of nodes in order starting with this node and ending in the target
      # This will be the shortest path from this node to the other.
      # The :djikstra method takes edge weights into account, the :breadth_first does not.
      def shortest_path_to(other, options = {:method => :djikstra})
        edge_class.shortest_path(self,other, options)
      end
      
      # Returns an array of all nodes which can trace to this node
      def originating
        edge_class.originating_nodes(self)
      end
      
      # true if the other node can reach this node.
      def originating?(other)
        originating.include?(other)
      end
      
      # Returns all nodes reachable from this node.
      def reachable
        edge_class.reachable_nodes(self)
      end
      
      # true if the other node is reachable from this one
      def reachable?(other)
       reachable.include?(other)
      end
      
      # +other+ The target node to find a route to 
      # Gives the path weight as a float of the shortest path to the other
      def path_weight_to(other)
        edge_class.shortest_path(self,other,:method => :djikstra).map{|edge| edge.weight.to_f}.sum
      end
    end
    
end

ActiveRecord::Base.class_eval { include OQGraph }  