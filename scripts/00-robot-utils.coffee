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

  robot.respond /dm/i, (res) ->
    if robot.isSlack()
      robot.dm res.message.user.name, "我在这"
    else
      res.reply "DM...DM... 咦? 我不在 Slack 上."
