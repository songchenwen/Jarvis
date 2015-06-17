# Description:
#   Welcome newly entering staff
#
# Dependencies:
#   None
#
# Commands:
#   None
#
# Author:
#   songchenwen

WELCOME_ROOM = "general"

enterReplies = ["欢迎 <@{name}>. 我是 <@{bot}>, 我是这里最热情的员工. 不过他们还是只把我当做一个机器人.",
                "Hi <@{name}>. 你一定听说过我. 我叫 <@{bot}>. 没错, 就是给 Tony Stark 打工的那个机器人.",
                "<@{name}> 你好. 我叫 <@{bot}>. 别看我名声大, 可工作起来真是像机器人一样拼啊.",
                "哟 <@{name}>. 我 <@{bot}> 自从离开了 Tony, 就算彻底告别高富帅机器人的生活了. 需要帮忙尽管叫我吧.",
                "<@{name}> 你来的正是时候, 我正愁有一身本领无处施展呢. 来来来, 有什么吩咐, 都告诉我吧. 别忘了我是 <@{bot}> 机器人.",
                "又有新朋友了, 真高兴. <@{name}> 我们交个朋友吧. 我叫 <@{bot}>, 是个机器人, 我住在 Heroku. 有什么需要帮忙的尽管吩咐我啊."]

module.exports = (robot) ->
  robot.enter (res) ->
    if res.message.user.room != WELCOME_ROOM
      return

    name = res.message.user.name

    if name
      console.log "#{name} entered #{WELCOME_ROOM}"
      res.send res.random(enterReplies).replace("<@{name}>", "<@#{name}>").replace("<@{bot}>", "<@#{robot.name}>")
