# Description:
#   Allows Hubot to store a recent chat history
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

  robot.catchAll (res) ->
    if (!robot.history)
      robot.history = []

    item = {
      message : res.message,
      time : new Date()
    }

    if item.message.text.indexOf(robot.name) is 0
      item.message.text = item.message.text.substring(robot.name.length).trim()

    if (robot.history.push(item) > 300)
      robot.history.shift()

  robot.lastMsg = (user, min) ->
  	if (robot.history and robot.history.length > 0)
  		return robot.history[i].message for i in [(robot.history.length - 1)..0] when checkMsg(robot.history[i], user, min)
  	return null

checkMsg = (item, user, min) ->
	return item.message.user.name == user.name and item.message.user.room == user.room and (new Date().getTime() - item.time.getTime()) < min * 60 * 1000