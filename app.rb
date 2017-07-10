$:.push File.dirname(__FILE__)
require "boot"

# get uuid
uuid_params = {
  appid: WEIXIN_APPID,
  redirect_uri: "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage",
  fun: "new",
  lang: "en_US",
  _: String(Time.now.to_i*1000+Random.rand(999))
}
logger.info "uuid request: https://login.weixin.qq.com/jslogin?#{uuid_params.to_query}"
uuid_resp = client.get("https://login.weixin.qq.com/jslogin?#{uuid_params.to_query}")
logger.info "uuid response #{uuid_resp.status}: #{uuid_resp.body}"
uuid = uuid_resp.body.split('"')[-2]

# show login qrcode
puts RQRCode::QRCode.new("https://login.weixin.qq.com/l/#{uuid}").as_ansi

# confirm login
cookie_query = loop do
  login_confirm_params = {
    uuid: uuid,
    tip: 0,
    _: get_timestamp
  }
  login_confirm_resp = client.get("https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?#{login_confirm_params.to_query}")
  logger.info "login confirm resp #{login_confirm_resp.status}: #{login_confirm_resp.body}"
  if login_confirm_resp.body =~ /redirect_uri/
    break login_confirm_resp.body.split.last.split('"')[-2].split("?")[-1]+"&fun=new&version=v2"
  else
    sleep 0.1
  end
end

# get cookie
logger.info "cookie request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{cookie_query}"
# resp_before_redirect = client.get("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{cookie_query}")
# cookie_resp = client.get(Nokogiri::XML(resp_before_redirect.body).at("redirecturl").children.to_s)
cookie_resp = client.get("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{cookie_query}")
logger.info "cookie response #{cookie_resp.status}: #{cookie_resp.body}"
cookie_info = Hash.from_xml(cookie_resp.body)["error"].slice("skey", "wxsid", "wxuin", "pass_ticket")
pass_ticket = cookie_info["pass_ticket"]
logger.info "pass_ticket: #{pass_ticket}"

# wx init
logger.info "webwx init resquest: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?lang=en_US&pass_ticket=#{pass_ticket}"
webwx_init_resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?r=#{get_timestamp}&lang=en_US&pass_ticket=#{pass_ticket}", {
  BaseRequest: {
    Uin: cookie_info["wxuin"],
    Sid: cookie_info["wxsid"],
    Skey: cookie_info["skey"],
    DeviseID: get_device_id
  }
}.to_json
logger.info "webwx init response #{webwx_init_resp.status}: #{webwx_init_resp.body}"
webwx_init_info = JSON.load(webwx_init_resp.body)

# webwx sync 保持长连接
begin
  synccheck_params = {
    r: get_timestamp,
    skey: cookie_info["skey"],
    sid: cookie_info["wxsid"],
    uin: cookie_info["wxuin"],
    deviceid: get_device_id,
    synckey: webwx_init_info["SyncKey"]["List"].map{|h| "#{h['Key']}_#{h['Val']}" }.join("|")
  }
  synccheck_resp = client.get "https://webpush.weixin.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{synccheck_params.to_query}"
  logger.info "synccheck response #{synccheck_resp.status}: #{synccheck_resp.body}"
rescue => e
  logger.error "#{e.class.name}: #{e.message}"
  retry
end

webwxsync_params = {
  sid: cookie_info["wxsid"],
  skey: cookie_info["skey"],
  lang: "en_US",
  pass_ticket: pass_ticket,
}
webwxsync_resp = client.post("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{webwxsync_params.to_query}"), {
  BaseRequest: {
    DeviseID: get_device_id,
    Sid: cookie_info["wxsid"],
    Skey: cookie_info["skey"],
    Uin: cookie_info["wxuin"]
  },
  SyncKey: webwx_init_info["SyncKey"],
  rr: Time.now.to_i
}.to_json
byebug
logger.info "webwxsync response #{webwxsync_resp.status}: #{webwxsync_resp.body}"

