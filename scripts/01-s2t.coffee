# Description:
#  简 -> 繁, 用户的上一次输入
#
# Dependencies:
#   History
#
# Commands:
#   hubot s2t - 简 -> 繁
#   hubot 繁体 - 简 -> 繁
#
# Author:
#   songchenwen

request = require 'request'

EXCUSES = ["你说什么？", "听不清，大点声。", "这边信号貌似有问题。"]

module.exports = (robot) ->

  robot.respond /s2t/i, (res) ->
    s2t(robot, res)

  robot.respond /繁体/i, (res) ->
    s2t(robot, res)

s2t = (robot, res) ->
  res.message.done = true
  s = robot.lastMsg(res.message.user, 5)
  if s and s.text
    loadingMsg = null
    if s.text.length > 4
      loadingMsg = res.reply "好的，我这就把 \"#{s.text.substring(0, 4)}...\" 转换成繁体"
    else
      loadingMsg = res.reply "好的，我正在把 \"#{s.text}\" 转换成繁体"

    if loadingMsg
      loadingMsg = robot.lastSentMsg loadingMsg

    request.post {
      url: "http://opencc.byvoid.com/convert", 
      form: {
        text: s.text,
        config: "s2twp.json"
      }
      }, (err, response, body) ->
        if err or response.statusCode isnt 200
          console.log(err + "code: " + response.statusCode + " " + body )
          if loadingMsg
            loadingMsg.deleteMessage()
          res.reply res.random EXCUSES
        else
          if loadingMsg
            loadingMsg.updateMessage body
          else
            res.send body
  else
    res.reply("我居然没找到要转换的内容。")
    

