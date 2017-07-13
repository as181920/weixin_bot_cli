module MessageHandler
  extend self

  def reply(received)
    case received['MsgType']
    when 1
      if received['Content'] =~ /test/
        return {content: "哼", type: 1}
      end
    else
    end
  end
end
