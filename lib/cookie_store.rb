class CookieStore
  attr_accessor :wxuin, :wxsid, :skey, :pass_ticket

  def initialize(options={})
    set(permit_options(options))
  end

  def set(options={})
    options = parse_header(options) if options.is_a?(String)

    permit_options(options).each do |k, v|
      instance_variable_set "@#{k}", v
    end
  end

  def parse_header(str="")
    {}
  end

  private
    def permit_options(options={})
      HashWithIndifferentAccess.new(options).slice(:wxuin, :wxsid, :skey, :pass_ticket)
    end
end
