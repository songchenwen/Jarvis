# Description:
#  Ask the hubot to start a voting
#
# Dependencies:
#   "hubot-slack"
#   "robot-utils"
#
# Commands:
#   hubot 发起投票: [options] - 发起投票
#   hubot 去问问 @<user> 的意见: [options] - 征求 <user> 的意见
#
# Author:
#   songchenwen


Select = require '../src/select'

module.exports = (robot) ->

  robot.respond /(发起投票[\:|：|\s][\s]*)(([^\s]+)[\,|，]?[\s]*)+\s*/i, (res) ->
    text = res.message.text
    text = text.substring(text.indexOf(res.match[1]) + res.match[1].length)
    startVoting(text)

  robot.respond /([去]?问问\s*\@([^\s]+)\s*的[意见|看法|想法][\:|：|\s]?[\s]*)(([^\s]+)[\,|，]?[\s]*)*\s*/i, (res) ->
    text = res.message.text
    text = text.substring(text.indexOf(res.match[1]) + res.match[1].length)
    user = res.match[2]
    if res.message.user.name == res.message.user.room
      members = [res.message.user.name]
    else
      members = robot.usersInRoom(res.message.user.room)

    if members.indexOf(user) < 0
      return unless robot.isSlack()
      u = robot.adapter.client.getUserByName(user)
      if not u
        robot.logger.info "VOTE: no user named #{user}"
        return 
      if u.is_bot
        replyRandom(robot, res, text, u.name)
        return
      else
        res.message.user.room = user
        res.message.done = true
    startVoting(robot, res, text, user)

  robot.hear /[你们|大家].*[怎么|什么].*[觉得|意见|想法|看法|看].*/i, (res) ->
    res.reply "要召唤投票机器人吗?\n ```@#{robot.name}: 发起投票: 米饭, 面条\n@#{robot.name}: 去问问 @someone 的意见```"

replyRandom = (robot, res, text, name) ->
  items = null
  if text and text.length > 0
    items = text.split(/\,|，|\s/)
    items = (item for item in items when item.length > 0)
    items = unique(items)
    items = null if items.length == 0

  items = ['同意', '反对'] unless items

  msg = "我选择 *#{res.random(items)}*"
  if robot.name == name
    res.reply msg
  else
    res.reply "与其问其他机器人还不如问我. #{msg}"

startVoting = (robot, res, text, user) ->
  items = null
  if text and text.length > 0
    items = text.split(/\,|，|\s/)
    items = (item for item in items when item.length > 0)
    items = unique(items)
    items = null if items.length == 0

  select = new Select robot, res, items, user
  if select.canRun
    select.run()
  else
    res.reply "你们连续发起投票, 我要数不过来了"

unique = (array) ->
  output = {}
  output[array[key]] = array[key] for key in [0...array.length]
  value for key, value of output

