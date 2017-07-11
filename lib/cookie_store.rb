module CookieStore
  extend self

  attr_accessor :wxuin, :wxsid, :skey, :pass_ticket

  def set(options={})
    permit_options(options).each do |k, v|
      instance_variable_set "@#{k}", v
    end
  end

  private
    def permit_options(options={})
      HashWithIndifferentAccess.new(options).slice(:wxuin, :wxsid, :skey, :pass_ticket)
    end
end
