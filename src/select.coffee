
selects = []

class Select
  constructor: (@robot, @res, @options, @limit_to_user, @callback) ->
    @room = @res.message.user.room
    @startUser = @res.message.user.name
    if @options
      tmpOp = @options
      @options = null unless Array.isArray(@options)
      if typeof tmpOp == 'string'
        @callback = @limit_to_user
        @limit_to_user = tmpOp
      else if typeof tmpOp == 'function'
        @callback = tmpOp
        @limit_to_user = null
    @limit_to_user = @startUser if (!@limit_to_user) and (@startUser == @room)

    if not Select.roomAvailable(@room, @limit_to_user)
      @canRun = false
      @callback() if @callback
      return
    @timeout = null
    @timeoutTime = 2 * 60 * 1000
    @timeoutRemindTime = 1 * 60 * 1000
    @canRun = true
    if @options
      @data = []
      for i in [0..(@options.length - 1)]
        @data.push {name: @options[i], count: 0, keyword: "#{i + 1}"}
    else
      @data = [{name: ':+1:', count: 0, keyword: ':+1:'}, {name: ':-1:', count: 0, keyword: ':-1:'}]

  run: (msg) ->
    return unless @canRun
    d.count = 0 for d in @data
    if msg
      @sendMsg msg
    else
      optionsMsg = ""
      if @options
        for d in @data
          optionsMsg += "\n> *#{d.keyword}* : #{d.name}"
        if @limit_to_user 
          if @startUser == @limit_to_user
            @sendMsg "<@#{@limit_to_user}>: 请您选择: #{optionsMsg}\n_回复序号做出选择_"
          else
            @sendMsg "<@#{@limit_to_user}>: <@#{@startUser}>请您选择: #{optionsMsg}\n_回复序号做出选择_"
        else
          @sendMsg "<!channel>: <@#{@startUser}> 发起了投票: #{optionsMsg}\n_回复序号做出选择_"
      else
        optionsMsg = "\n> 同意请回: :+1: 或者 `:+1:`\n> 反对请回: :-1: 或者 `:-1:`"
        if @limit_to_user
          if @startUser == @limit_to_user
            @sendMsg "<@#{@limit_to_user}>: 您同意吗?#{optionsMsg}" 
          else
            @sendMsg "<@#{@limit_to_user}>: 您同意 <@#{@startUser}> 吗?#{optionsMsg}"
        else
          @sendMsg "<!channel>: <@#{@startUser}> 发起了投票: #{optionsMsg}"

    @votedUsers = []
    if @limit_to_user 
      @voters = [@limit_to_user]
    else
      @voters = []
      channel = @robot.adapter.client.getChannelGroupOrDMByName(@room)
      for u in channel.members
        u = @robot.adapter.client.getUserByID(u)
        @voters.push u.name unless (u.presence == 'away' or u.is_bot)
          

    Select.register(@robot) unless Select.registered

    @canRun = false
    selects.push this
    t = this
    if @timeout
      clearTimeout @timeout
    @timeout = setTimeout ->
      t.onTimeout()
    , @timeoutTime

  onMsg: (res) ->
    user = res.message.user.name
    return if @limit_to_user and @limit_to_user isnt user
    return if @votedUsers.indexOf(user) >= 0
    text = res.match[1]
    voteFor = null
    for d in @data
      if d.keyword == text
        voteFor = d
        break
    return unless voteFor
    voteFor.count += 1
    @votedUsers.push user
    @voters.splice(@voters.indexOf(user)) if @voters.indexOf(user) >= 0
    res.message.done = true
    if @timeout
      clearTimeout(@timeout)
      @timeout = null
    if @voters.length == 0
      @finish()
      return
    t = this
    @timeout = setTimeout ->
      t.onTimeout()
    , @timeoutTime
    @sendMsg(@totalVotes())

  sendMsg: (msg, room) ->
    u = ""
    if @startUser
      u = " for #{@startUser}"
    room = @room unless room
    @robot.postRawMsg room, {icon_emoji: ':question:', text: msg, as_user: false, username: "#{@robot.name}, the voting bot#{u}"}

  onTimeout: () ->
    @timeout = null
    console.log "on timeout called"
    if @voters.length > 0
      v = "投票"
      v = "决定" unless @options
      msg = "不要来参与一下#{v}吗?\n"
      if @limit_to_user
        msg = "快点#{v}哇, "
      for u in @voters
        msg += "<@#{u}> "
      @sendMsg msg
    t = this
    @timeout = setTimeout ->
      t.finish()
    , @timeoutRemindTime


  finish: ()->
    if @timeout
      clearTimeout(@timeout)
      @timeout = null
    selects.splice(selects.indexOf(this)) if selects.indexOf(this) >= 0
    
    ev = "的投票结束了"
    ev = "的意见是" unless @options
    starter = "<@#{@startUser}>"
    room = null
    if @limit_to_user
      ev = "<@#{@limit_to_user}> #{ev}"
      starter += ":"
    else if !options
      ev = "大家#{ev}"
      starter += ":"

    if @startUser and @startUser isnt @limit_to_user
      ev = "#{starter} #{ev}"
      if @limit_to_user and @room == @limit_to_user
        room = @startUser
        @sendMsg "好的, 我这就去告诉 <@#{@startUser}>"

    if !@limit_to_user
      ev = "#{ev}\n"
    else
      ev = "#{ev}: "

    @sendMsg "#{ev}#{@totalVotes()}", room
    if @callback
      @callback(@data)

  totalVotes: ()->
    msg = "> "
    for d in @data
      if @limit_to_user and d.count > 0
        return "#{d.name}"
      msg += "#{d.name}: #{d.count}票,   "
    msg = msg.trim()
    return msg.substring(0, msg.length - 1)

Select.roomAvailable = (room, limit_to_user) ->
  duplicate = false
  duplicate = true for s in selects when s.room == room and s.limit_to_user == limit_to_user
  return not duplicate

Select.registered = false

Select.register = (robot) ->
  return if Select.registered
  Select.registered = true
  reg = /\s*(([0-9]+)|(\:(\+|\-)1\:))\s*$/i
  robot.hear reg, respond
  robot.respond reg, respond

respond = (res)->
  if selects and selects.length > 0
    s.onMsg(res) for s in selects when s.room == res.message.user.room

module.exports = Select
