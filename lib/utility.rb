module Utility
  extend self

  def device_id
    @device_id ||= "e#{Random.rand(10**15).to_s.rjust(15,'0')}"
  end

  def current_timestamp(unit="s")
    case unit
    when "s"
      Integer(Time.now)
    when "ms"
      Integer(Time.now.to_f*1000)
    else
      Integer(Time.now)
    end
  end

  def str_to_hash(str="")
    str.split(": ")[-1].gsub('"', "").split(/;\n*/).map{|e| e.split("=", 2)}.to_h
  end

  def query_to_hash(query="")
    URI.decode_www_form(query).to_h
  end

  def parse_url_query(url="")
    query_to_hash URI.parse(url).query
  end

  def parse_xml(xml="")
    Hash.from_xml(xml)
  end

  def compact_json(json=nil)
    JSON.load(json).to_json
  end

  def client_msg_id
    "#{Time.now.to_i * 10000}#{Random.rand(1000..9999)}"
  end
end
