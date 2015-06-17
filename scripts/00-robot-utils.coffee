# Description:
#   Add custom functions to robot
#
# Dependencies:
#   None
#
# Commands:
#   None
#
# Author:
#   songchenwen

module.exports = (robot) ->
  
  robot.slack = () ->
    if robot.adapterName == 'slack' and robot.adapter
      return robot.adapter.client
    return null

  robot.isSlack = () ->
    return robot.adapterName == 'slack'

  robot.dm = (user, strings...) -> 
    if user and robot.isSlack()
      if typeof user == "string"
        robot.messageRoom user, strings...
        return
      else if user.name
        robot.messageRoom user.name, strings...
        return
    
    console.log "Can't send DM"

  robot.lastSentMsg = (input) ->
    return null if !input
    if Array.isArray(input)
      return robot.lastSentMsg(input[input.length - 1])
    else
      if typeof input.updateMessage == 'function'
        return input
      else
        return null

  robot.postRawMsg = (channelName, rawMsg) ->
    return null unless rawMsg
    if robot.isSlack()
      client = robot.adapter.client
      return null unless client
      channel = client.getChannelGroupOrDMByName channelName
      return null unless channel
      rawMsg.unfurl_links = true
      return robot.lastSentMsg channel.postMessage rawMsg
    else
      return null

  robot.roomHasActivity = (room, millisec) ->
    return false unless room
    return true unless millisec > 0
    if robot.isSlack()
      history = robot.adapter.client.getChannelGroupOrDMByName(room).getHistory()
      return false unless history
      now = new Date().getTime()
      before = now - millisec
      for own timestamp, obj of history
        return true if timestamp * 1000 > before and obj.hasOwnProperty('type') and obj.type == 'message'
      return false
    else
      return !!(robot.lastMsg({room: room}, millisec / 1000 / 60))

  robot.respond /dm/i, (res) ->
    if robot.isSlack()
      robot.dm res.message.user.name, "我在这"
    else
      res.reply "DM...DM... 咦? 我不在 Slack 上."
