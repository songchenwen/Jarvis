# Description:
#  ping some site by hubot
#
# Dependencies:
#   None
#
# Commands:
#   hubot ping <domain> - ping the domain
#
# Author:
#   songchenwen

cp = require 'child_pty'

updatingMsgTimeNeeded = 4000

module.exports = (robot) ->

  robot.respond /ping\s+([^\s]+)\s*$/i, (res) ->
    domain = res.match[1]
    if domain.indexOf('http://') == 0
      domain = domain.substring('http://'.length)
    if domain.indexOf('https://') == 0
      domain = domain.substring('https://'.length)

    msg = "<@#{res.message.user.name}>: 我正在 ping #{domain}\n"

    reply = null
    if robot.isSlack()
      reply = robot.lastSentMsg(res.send(msg))
      if reply
        msg += "```"
      else 
        robot.logger.warning "PING: slack has not reply message, something goes wrong"
        msg = "```"

    beginTime = new Date().getTime()
    ping = cp.spawn 'ping', ['-c', '5', "#{domain}"]
    robot.logger.info "PING: begin ping #{domain}"

    ping.stdout.on 'data', (data) ->
      data = data.toString()
      data = data.replace('\r\n', '\n')
      data = data.replace('\n\r', '\n')
      robot.logger.info "PING: #{data}"
      msg += data
      if reply
        reply.updateMessage(msg + "```")

    ping.on 'exit', (code) ->
      hasData = reply and (msg.indexOf("```") < (msg.length - "```".length))
      if code isnt 0
        errorMsg = "*但是出错了*.\n"
        if code == 68
          errorMsg = "*但是出错了*, #{domain} 真的是个有效的域名吗?\n"
        msg = msg.replace "我正在 ping #{domain}\n", "我正在 ping #{domain}. " + errorMsg
        if reply
          if hasData
            reply.updateMessage(msg + "```")
          else
            reply.updateMessage(msg.substring(0, 0 - '```'.length))
      if reply
        timeUsed = new Date().getTime() - beginTime 
        if timeUsed < updatingMsgTimeNeeded
          setTimeout(->
            robot.logger.info "PING: delay updating message for #{updatingMsgTimeNeeded - timeUsed} millisecs"
            if hasData
              reply.updateMessage(msg + "```")
            else
              reply.updateMessage(msg.substring(0, 0 - '```'.length))
          , updatingMsgTimeNeeded - timeUsed)
      else
        res.send msg

      robot.logger.info "PING: exit #{code}"


