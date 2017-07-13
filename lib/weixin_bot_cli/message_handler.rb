module WeixinBotCli
  module MessageHandler
    extend self

    def reply(received)
      case received['MsgType']
      when 1
        if received['Content'] =~ /test/
          return {Content: "哼", Type: 1}
        end
      else
      end
    end
  end
end
