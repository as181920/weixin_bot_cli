module WeixinBotCli
  class Bot
    SpecialUserNames = [
      'newsapp', 'fmessage', 'filehelper', 'weibo', 'qqmail',
      'fmessage', 'tmessage', 'qmessage', 'qqsync', 'floatbottle',
      'lbsapp', 'shakeapp', 'medianote', 'qqfriend', 'readerapp',
      'blogapp', 'facebookapp', 'masssendapp', 'meishiapp',
      'feedsapp', 'voip', 'blogappweixin', 'weixin', 'brandsessionholder',
      'weixinreminder', 'wxid_novlwrv3lqwv11', 'gh_22b87fa7cb3c',
      'officialaccounts', 'notification_messages', 'wxid_novlwrv3lqwv11',
      'gh_22b87fa7cb3c', 'wxitil', 'userexperience_alarm', 'notification_messages'
    ]

    attr_accessor :client, :logger, :device_id
    attr_accessor :uuid, :ticket, :scan, :lang
    attr_accessor :wxuin, :wxsid, :skey, :pass_ticket
    attr_accessor :current_user, :sync_key
    attr_accessor :contact_list, :public_list, :group_list, :special_list
    attr_accessor :user_handler, :contact_handler, :message_handler

    WEIXIN_APPID = 'wx782c26e4c19acffb'
    ConfirmLoginError = Class.new StandardError

    class << self
      def get_uuid
        params = {
          appid: WEIXIN_APPID,
          redirect_uri: "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage",
          fun: "new",
          lang: 'en_US',
          _: Utility.current_timestamp("ms")
        }
        logger.info "get_uuid request => url: https://login.weixin.qq.com/jslogin?#{params.to_query}"
        resp = Faraday.get("https://login.weixin.qq.com/jslogin?#{params.to_query}")
        logger.info "get_uuid response #{resp.status} => #{resp.body}"
        return resp.body.split('"')[-2]
      end

      def logger
        @logger ||= Logger.new STDOUT
      end
    end

    def initialize(uuid)
      @uuid = uuid
      @client = Faraday.new do |builder|
        builder.use :cookie_jar
        builder.adapter Faraday.default_adapter
      end
      @logger = Logger.new STDOUT
      @device_id = "e#{Random.rand(10**15).to_s.rjust(15,'0')}"
      @lang =  "en_US"
      @contact_list = []
      @public_list = []
      @group_list = []
      @special_list = []
      @user_handler = UserHandler.new(self)
      @contact_handler = ContactHandler.new(self)
      @message_handler = MessageHandler.new(self)
    end

    def run
      show_login_qrcode
      confirm_login
      get_cookie
      get_init_info
      open_status_notify
      get_contact
      get_group_member
      sync_message
    end

    def show_login_qrcode
      puts RQRCode::QRCode.new("https://login.weixin.qq.com/l/#{uuid}").as_ansi
    end

    def confirm_login
      loop do
        params = {
          uuid: uuid,
          tip: 0,
          _: Utility.current_timestamp
        }
        logger.info "confirm_login request => url: https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?#{params.to_query}"
        resp = client.get("https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?#{params.to_query}")
        logger.info "confirm_login response #{resp.status} => #{resp.body}"
        resp_info = Utility.str_to_hash(resp.body)
        if resp_info["window.redirect_uri"].present?
          break Utility.parse_url_query(resp_info["window.redirect_uri"]).slice("ticket", "scan").each{|k, v| instance_variable_set("@#{k}", v) }
        elsif Integer(resp_info["window.code"]) >= 400
          raise ConfirmLoginError, resp.body
        else
          sleep 0.1
        end
      end
    end

    def get_cookie
      params = {
        ticket: ticket,
        uuid: uuid,
        lang: lang,
        scan: scan,
        fun: "new",
        version: "v2"
      }
      logger.info "get_cookie request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{params.to_query}"
      resp = client.get("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{params.to_query}")
      logger.info "get_cookie response #{resp.status} => #{resp.body}"
      HashWithIndifferentAccess.new(Utility.parse_xml(resp.body)["error"]).slice(:wxuin, :wxsid, :skey, :pass_ticket).each{ |k, v| instance_variable_set "@#{k}", v }
    end

    def get_init_info
      params = {
        r: Utility.current_timestamp,
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request
      }
      logger.info "get_init_info resquest => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}", body.to_json
      logger.info "get_init_info response #{resp.status} => #{JSON.load(resp.body).slice('BaseResponse', 'Count', 'User', 'ContactList').to_json}"
      init_info = JSON.load(resp.body)
      @current_user = init_info["User"]
      @sync_key = init_info["SyncKey"]
      user_handler.handle(current_user)
      contact_handler.handle(current_user)
      init_info["ContactList"].each { |contact| push_to_matched_list(contact) }
      init_info["ContactList"].each { |contact| contact_handler.handle(contact) }
    end

    def open_status_notify
      params = {
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request,
        Code: 3,
        FromUserName: current_user["UserName"],
        ToUserName: current_user["UserName"],
        ClientMsgId: Utility.current_timestamp
      }
      logger.info "open_status_notify request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}", body.to_json
      logger.info "open_status_notify response #{resp.status} => #{Utility.compact_json(resp.body)}"
    end

    def get_contact
      params = {
        seq: 0,
        pass_ticket: pass_ticket,
        skey: skey,
        r: Utility.current_timestamp
      }
      body = {
        BaseRequest: base_request
      }
      logger.info "get_contact request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}", body.to_json
      logger.info "get_contact response #{resp.status} => #{Utility.compact_json(resp.body)}"
      resp_info = JSON.load(resp.body)
      resp_info['MemberList'].each { |member| push_to_matched_list(member) }
      resp_info['MemberList'].each { |member| contact_handler.handle(member) }
    end

    def get_group_member
      params = {
        seq: 0,
        pass_ticket: pass_ticket,
        type: "ex",
        r: Utility.current_timestamp
      }
      body = {
        BaseRequest: base_request,
        Count: group_list.count,
        List: group_list.map{|g| {UserName: g["UserName"], EncryChatRoomId: ""} }
      }
      logger.info "get_group_member request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxbatchgetcontact?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxbatchgetcontact?#{params.to_query}", body.to_json
      logger.info "get_group_member response #{resp.status} => #{Utility.compact_json(resp.body)}"
      resp_info = JSON.load(resp.body)
      resp_info["ContactList"].each do |group|
        group_list.detect{ |g| g["UserName"] == group["UserName"] }&.tap do |g|
          g.merge!("EncryChatRoomId" => group["EncryChatRoomId"], "MemberList" => group["MemberList"])
          g["MemberList"].each do |member|
            contact_handler.handle(member.merge("ChatGroupName" => g["NickName"]))
          end
        end
      end
    end

    def sync_message
      loop do
        check_result = sync_check
        raise SyncCheckError, check_result.to_json unless check_result["retcode"] == "0"
        get_message if check_result["selector"].to_i > 0
      end
    end

    def sync_check
      params = {
        r: Utility.current_timestamp("ms"),
        sid: wxsid,
        uin: wxuin,
        deviceid: device_id,
        synckey: synckey_to_str(sync_key),
        _: Utility.current_timestamp("ms")
      }
      logger.info "sync_check request => url: https://webpush.weixin.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
      resp = client.get "https://webpush.wx.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
      logger.info "sync_check response #{resp.status} => #{resp.body}"
      Hash[*resp.body.split("=")[-1].gsub(/{|}|\"/, "").split(/:|,/)]
    end

    def get_message
      params = {
        sid: wxsid,
        skey: skey,
        pass_ticket: pass_ticket,
        lang: lang
      }
      body = {
        BaseRequest: base_request,
        SyncKey: sync_key,
        rr: ~Utility.current_timestamp
      }
      logger.info "get_message request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{params.to_query}", body.to_json
      logger.info "get_message response #{resp.status} => #{JSON.load(resp.body).slice('BaseResponse', 'AddMsgCount', 'AddMsgList').to_json}"
      resp_info = JSON.load(resp.body)
      @sync_key = resp_info["SyncKey"]
      resp_info['AddMsgList'].each do |msg|
        reply = Hash(message_handler.handle(msg, self))
        client_msg_id = "#{Time.now.to_i * 10000}#{Random.rand(1000..9999)}"
        send_message({FromUserName: current_user["UserName"], ToUserName: msg["FromUserName"], LocalID: client_msg_id, ClientMsgId: client_msg_id}.merge(reply)) if reply.present?
      end
    end

    def send_message(msg)
      params = {
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request,
        Msg: msg
      }
      logger.info "send_message request => url: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}, body: #{body.to_json}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}", body.to_json
      logger.info "send_message response #{resp.status} => #{Utility.compact_json(resp.body)}"
    end

    def full_contact_info_list
      @full_contact_info_list ||= (contact_list + public_list + special_list + group_list).push(current_user).tap do |info_list|
        group_list.map{ |g| info_list += g["MemberList"] }
      end
    end

    def contact_name_pairs
      @contact_name_pairs ||= full_contact_info_list.inject({}){|h, e| h.merge!({e["UserName"] => e["NickName"]})}
    end

    private
      def synckey_to_str(sync_key_hash)
        sync_key_hash["List"].map{|h| "#{h['Key']}_#{h['Val']}" }.join("|")
      end

      def push_to_matched_list(contact)
        matched_list = if contact["UserName"].in?(SpecialUserNames)
                         @special_list
                       elsif contact["VerifyFlag"].in?([8, 24, 56])
                         @public_list
                       elsif contact["UserName"] =~ /^@@/
                         @group_list
                       else
                         @contact_list
                       end
        matched_list.push(contact.slice("UserName", "NickName", "Signature", "EncryChatRoomId", "MemberList"))
      end

      def base_request
        { Uin: wxuin, Sid: wxsid, Skey: skey, DeviceID: device_id }
      end
  end
end
