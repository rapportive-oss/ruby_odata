module OData
	# Internally used helper class for building a dynamic class.  This class shouldn't be called directly.
	class ClassBuilder
		# Creates a new instance of the ClassBuilder class
		#
		# ==== Required Attributes
		# - klass_name: 	The name/type of the class to create
		# - methods:			The accessor methods to add to the class
		# - nav_props:		The accessor methods to add for navigation properties
		def initialize(klass_name, methods, nav_props)
			@klass_name = klass_name
			@methods = methods
			@nav_props = nav_props
		end
		
		# Returns a dynamically generated class definition based on the constructor parameters
		def build
			# return if already built
		  return @klass unless @klass.nil?
		
		  # need the class name to build class
		  return nil    if @klass_name.nil?
		      
			@klass = Class.new.extend(ActiveSupport::JSON)
 
			add_methods(@klass)
			add_nav_props(@klass)
			
		  return @klass
		end
		
		private
		def add_methods(klass)
			# Add metadata methods
			klass.send :define_method, :__metadata do
				instance_variable_get("@__metadata")
			end
			klass.send :define_method, :__metadata= do |value|
					instance_variable_set("@__metadata", value)
			end
		  klass.send :define_method, :as_json do |options|
				meta = '__metadata'

				options ||= {}
				options[:type] ||= :unknown

				vars = self.instance_values

				# For adds, we need to get rid of all attributes except __metadata when passing
				# the object to the server
				# TODO: There should be a universal way to figure out if we are on an addition
				#   activesupport 2.3.8 doesn't pass through the :type to all levels, but passes :seen
				#		activesupport 3.0.0.beta4 doesn't pass :seen in options
				if (options[:type] == :add || !options[:seen].nil?) && vars.has_key?(meta)
					vars.delete_if { |k,v| k != meta}
				else
					vars.delete(meta)
				end

				# Convert a BigDecimal to a string for serialization (to match Edm.Decimal)
				decimals = vars.find_all { |o| o[1].class == BigDecimal } || []
				decimals.each do |d|
					vars[d[0]] = d[1].to_s
				end

				# Convert Time to an RFC3339 string for serialization
				times = vars.find_all { |o| o[1].class == Time } || []
				times.each do |t|
          sdate = t[1].xmlschema(3)
          # Remove the ending Z (indicating UTC).
          # If the Z is there when saving, the time is converted to local time on the server
          sdate.chop! if sdate.match(/Z$/)
					vars[t[0]] = sdate
				end

				vars
			end


			# Add the methods that were passed in
			@methods.each do |method_name|
				klass.send :define_method, method_name do
					instance_variable_get("@#{method_name}")
				end
				klass.send :define_method, "#{method_name}=" do |value|
					instance_variable_set("@#{method_name}", value)
				end
			end
		end

		def add_nav_props(klass)
			@nav_props.each do |method_name|
				klass.send :define_method, method_name do
					instance_variable_get("@#{method_name}")
				end
				klass.send :define_method, "#{method_name}=" do |value|
					instance_variable_set("@#{method_name}", value)
				end
			end
		end
	end
end # module OData
