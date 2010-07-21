class CustomTestModel < ActiveRecord::Base
  acts_as_oqgraph :class_name => 'CustomEdge', :from_key => 'orig_id', :to_key => 'dest_id'
end