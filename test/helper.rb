require 'rubygems'
require 'test/unit'
require 'mysql'
require 'active_record'
require 'active_support'
require 'active_support/test_case'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'acts_as_oqgraph'

class ActiveSupport::TestCase
end
