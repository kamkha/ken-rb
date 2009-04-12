module Ken
  class Resource
    # initializes a resource by json result
    def initialize(data)
      return nil unless data
      raise "error" unless data.kind_of?(Hash)
      
      # intialize lazy if there is no type supplied
      @schema_loaded = false
      @attributes_loaded = false
      @data = data
      
      self
    end
    
    # @api public
    def id
      @data["id"] || ""
    end
    
    # @api public
    def name
      @data["name"] || ""
    end
    
    # @api public
    def to_s
      name || id || ""
    end
    
    # @api public
    def inspect
      result = "#<Resource id=\"#{id}\" name=\"#{name || "nil"}\">"
    end
    
    # returns all assigned types
    # @api public
    def types
      load_schema! unless schema_loaded?
      @types
    end
    
    # returns all available vies based on the assigned types
    # @api public
    def views
      @views ||= Ken::Collection.new(types.map { |type| Ken::View.new(self, type) })
    end
    
    # returns all the properties from all assigned types
    # @api public
    def properties
      @properties = Ken::Collection.new
      types.each do |type|
        @properties.concat(type.properties)
      end
      @properties
    end
    
    # returns all attributes for every type the resource is an instance from
    # @api public
    def attributes
      load_attributes! unless attributes_loaded?
      @attributes.values
    end
    
    # returns true if type information is already loaded
    # @api public
    def schema_loaded?
      @schema_loaded
    end
    
    # returns true if attributes are already loaded
    # @api public
    def attributes_loaded?
      @attributes_loaded
    end
    
    private
    def fetch_attributes
      # fetching all objects regardless of the type
      # check this http://lists.freebase.com/pipermail/developers/2007-December/001022.html
      
      query = {
        :"/type/reflect/any_master" => [
          {
            :id => nil,
            :link => nil,
            :name => nil
          }
        ],
        :"/type/reflect/any_reverse" => [
          {
            :id => nil,
            :link => nil,
            :name => nil
          }
        ],
        :"/type/reflect/any_value" => [
          {
            :link => nil,
            :value => nil
            # :lang => "/lang/en",
            # :type => "/type/text"
          }
        ],
        :id => id
      }
      
      Ken.session.mqlread(query)
    end
    
    def load_attributes!
      data = @data["ken:attribute"] || fetch_attributes
      
      # master & value attributes
      raw_attributes = Ken::Util.convert_hash(data["/type/reflect/any_master"])
      raw_attributes.merge!(Ken::Util.convert_hash(data["/type/reflect/any_value"]))
      @attributes = {}
      raw_attributes.each_pair do |a, d|
        properties.select { |p| p.id == a}.each do |p|
          @attributes[p.id] = Ken::Attribute.create(d, p)
        end
      end
      
      # reverse properties
      raw_attributes = Ken::Util.convert_hash(data["/type/reflect/any_reverse"])
      raw_attributes.each_pair do |a, d|
        properties.select { |p| p.master_property == a}.each do |p|
          @attributes[p.id] = Ken::Attribute.create(d, p)
        end
      end
      
      @attributes_loaded = true
    end
    
    def fetch_schema
      query = {
        :id => id,
        :name => nil,
        :"ken:type" => [{
          :id => nil,
          :name => nil,
          :properties => [{
            :id => nil,
            :name => nil,
            :expected_type => nil,
            :unique => nil
          }]
        }]
      }
      
      Ken.session.mqlread(query)["ken:type"]
    end
    
    # loads the resources metainfo
    # @api private
    def load_schema!
      @data["ken:type"] ||= fetch_schema
      @types = Ken::Collection.new(@data["ken:type"].map { |type| Ken::Type.new(type) })
      @schema_loaded = true
    end
    

  end # class Resource
end # module Ken