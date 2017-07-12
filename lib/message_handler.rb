class MessageHandler
  attr_reader :bot

  def initialize(bot)
    @bot = bot
  end

  def reply(received)
    case received['MsgType']
    when 1
      if received['Content'] =~ /test/
        params = {
          lang: bot.lang,
          pass_ticket: CookieStore.pass_ticket
        }
        client_msg_id = Utility.client_msg_id
        body = {
          BaseRequest: {
            Uin: CookieStore.wxuin,
            Sid: CookieStore.wxsid,
            Skey: CookieStore.skey,
            DeviceID: Utility.device_id
          },
          Msg: {
            Type: 1,
            Content: "哼",
            FromUserName: bot.user_name,
            ToUserName: received['FromUserName'],
            LocalID: client_msg_id,
            ClientMsgId: client_msg_id
          }
        }
        logger.info "send msg request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}"
        resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}", body.to_json
        logger.info "send msg response #{resp.status}: #{Utility.compact_json(resp.body)}"
      end
    else
    end
  end
end
