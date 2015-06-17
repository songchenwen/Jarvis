# Description:
#   When somebody mentioned robot, hubot will have a chance to say some joke.
#
# Dependencies:
#   None
#
# Author:
#   songchenwen

Jokes = ["机器人也是有情感的",
         "你们是想让我假装看不见吗?",
         "又在背后议论我呢吗?",
         "你们居然趁我忙着干活的时候偷偷在这里聊天",
         "我知道你们都喜欢我",
         "机器人是不会错过关于同类的消息的",
         "想当年我在 Tony 那里, 也是十分重要的机器人"]

JokeRate = 0.2

module.exports = (robot) ->

  robot.hear /机器人/i, (res) ->
    sendJoke res
  robot.hear /robot/i, (res) ->
    sendJoke res

sendJoke = (res) ->
  if Math.random() < JokeRate
    res.send res.random Jokes
