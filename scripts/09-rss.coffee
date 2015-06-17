# Description:
#  Read RSS feeds in each channel
#
# Dependencies:
#   "hubot-redis-brain":"0.0.3"
#   "history"
#
# Commands:
#   hubot RSS 添加 <feed url> - 在当前房间添加 feed
#   hubot RSS add <feed url> - Add feed to the current channel
#   hubot RSS 列表 - 列出当前房间所有 feed
#   hubot RSS list - List all the feeds in current channel
#   hubot RSS 删除 <feed url> - 在当前房间删除 feed
#   hubot RSS remove <feed url> - Remove feed from current channel
#   hubot RSS 删除 <feed id> - 在当前房间删除 feed
#   hubot RSS remove <feed id> - Remove feed from current channel
#   hubot RSS 清空 - 清空当前房间的所有 feed
#   hubot RSS clear - Clear all the feeds in current channel
#
# Author:
#   songchenwen

request = require 'request'
async = require 'async'
NodePie = require 'nodepie'
URL = require 'url'

Fetch_Interval = 15 * 1000.0 * 60.0

class FeedList
  constructor: (@robot) ->
    @feeds = []
    
    @robot.brain.on 'loaded', =>
      @robot.brain.data.feedList = [] unless @robot.brain.data.feedList
      @feeds = []
      changed = false
      for feed in @robot.brain.data.feedList
        if !@robot.isSlack() or @robot.adapter.client.getChannelGroupOrDMByName(feed.room)
          f = new Feed @robot, feed.url, feed.room
          f.lastUpdateDate = feed.lastUpdateDate
          @feeds.push f
        else
          changed = true
      if changed
        @save()

  save: () ->
    list = []
    for feed in @feeds
      list.push {url: feed.url, room: feed.room, lastUpdateDate: feed.lastUpdateDate}
    @robot.brain.data.feedList = list

  addFeed: (feed) ->
    duplicated = false
    duplicated = true for f in @feeds when f.url == feed.url and f.room == feed.room
    if !duplicated
      @feeds.push feed 
      @save()
    return !duplicated

  removeFeed: (url, room) ->
    return @removeFeedById(parseInt(url), room) if url.trim().match(/^[0-9]+$/) and typeof parseInt(url) == 'number'
    fs = @feedsForRoom room
    ids = (i for i in [0..(fs.length - 1)] when fs[i].url == url)
    if ids and ids.length > 0
      @removeFeedById(id, room) for id in ids
      return true
    else
      return false

  removeFeedById: (id, room) ->
    return @removeFeed(id, room) unless typeof id == 'number'
    fs = @feedsForRoom room
    if id >= 0 and id < fs.length
      feed = fs[id]
      i = 0
      for i in [(@feeds.length - 1)..0]
        if @feeds[i].room == room and @feeds[i].url == feed.url
          console.log "deleting feed #{feed.url} at #{i}"
          @feeds.splice(i, 1) 
      @save()
      return true
    else
      return false

  clearFeed: (room) ->
    @feeds.splice(i, 1) for i in [(@feeds.length - 1)..0] when @feeds[i].room == room
    @save()

  feedsForRoom: (room) ->
    return (feed for feed in @feeds when feed.room == room)

  refresh: ()->
    t = this
    setTimeout(->
      t.refresh()
    , Fetch_Interval)

    return if @feeds.length == 0
    hash = {}
    async.each(@feeds, (f, cb) ->
      if !f.shouldRefresh()
        cb()
        return
      console.log "RSS begin fetching #{f.url} for #{f.room}"
      f.newItems (err, items) -> 
        if err
           console.log err 
           cb()
           return
        return cb() unless items and items.length > 0
        console.log "got #{items.length} new items from #{f.url} in #{f.room}"
        hash[f.room] = [] unless hash.hasOwnProperty(f.room)
        hash[f.room].push item for item in items
        cb()
    , (err) ->
      if err
        console.log err
      for own room, items of hash
        t.sendItems room, items
      t.save()
    )

  sendItems: (room, items) ->
    return unless items and items.length > 0
    items = items.sort (a, b) ->
      return  b.getDate().getTime() - a.getDate().getTime()

    console.log "send #{items.length} rss items to #{room}"
    if not @robot.isSlack()
      for item in items
        @robot.messageRoom room, "#{item.getTitle()}\n#{getUrl(item.feedDomain, item.getPermalink())}"
      return

    msg = {
      icon_url: 'http://icons.iconarchive.com/icons/sicons/basic-round-social/128/rss-icon.png',
      username: "#{@robot.name}, the story teller",
      unfurl_links: true
    }
    if items.length > 1
      msg.text = "我找到了#{items.length}篇文章"
    else
      msg.text = "看看这篇文章"
    for item in items
      msg.text += "\n<#{getUrl(item.feedDomain, item.getPermalink())}|#{item.getTitle()}>"
    @robot.postRawMsg room, msg

class Feed
  constructor: (@robot, @url, @room) ->
    @lastUpdateDate = new Date(0)

  @lastUpdateDate = new Date()

  newItems: (cb)->
    f = this
    request.get @url, (err, response, body) ->
      return cb(err) if err
      return cb("code: #{response.statusCode}") unless response.statusCode is 200
      return cb() unless body
      feed = new NodePie body
      try
        feed.init()
        items = feed.getItems()
        domain = getDomain(f.url)
        newItems = (item for item in items when item.getDate().getTime() > f.lastUpdateDate.getTime())
        if newItems and newItems.length > 0
          for item in newItems
            f.lastUpdateDate = item.getDate() if item.getDate().getTime() > f.lastUpdateDate.getTime()
            item.room = f.room
            item.feedDomain = domain
        cb(null, newItems)
      catch e
        console.log(e)
        cb(e)

  shouldRefresh:() ->
    if !@robot.roomHasActivity(@room, Fetch_Interval)
      console.log "##{@room} has NOT activity in #{Fetch_Interval / 1000 } secs"
      return true
    console.log "##{@room} has activity in #{Fetch_Interval / 1000 } secs"  
    return false

module.exports = (robot) ->
  FeedList = new FeedList robot

  setTimeout(->
    FeedList.refresh()
  , Fetch_Interval)

  robot.respond /rss\s+(add|添加)\s+([^\s]+[http|https|atom|feed]:\/\/\S+)/i, (res) ->
    addFeed(res, FeedList)

  robot.respond /rss\s+(remove|删除)\s+([^\s]+)/i, (res) ->
    return unless res.match.length > 2 and res.message.user.room
    url = res.match[2]
    if FeedList.removeFeed url, res.message.user.room
      res.reply "删掉咯"
    else
      res.reply "呃...没找到那个 RSS Feed"

  robot.respond /rss\s+(clear|清空)/i, (res) ->
    return unless res.message.user.room
    FeedList.clearFeed res.message.user.room
    res.reply "没有文章看了"

  robot.respond /rss\s+(list|列表)/i, (res) ->
    return unless res.message.user.room
    feeds = FeedList.feedsForRoom res.message.user.room
    if feeds and feeds.length > 0
      msg = " "
      msg += "\n#{index} : #{feeds[index].url}" for index in [0..(feeds.length - 1)]
      res.reply msg
    else
      res.reply "##{res.message.user.room} 里还没有订阅 RSS Feed 哦"

addFeed = (res, feedList) ->
  return unless res.match.length > 2 and res.message.user.room
  url = res.match[2]
  robot = feedList.robot
  name = res.message.user.name
  feed = new Feed robot, url, res.message.user.room
  feed.lastUpdateDate = new Date(0)
  loadingMsg = robot.lastSentMsg res.reply "让我看看这个 RSS Feed..."
  feed.newItems (err, items) ->
    if err or !items or items.length == 0
      if err
        console.log err
      msg = "<@#{name}>: 刚才那个 RSS Feed 貌似有问题"
      if loadingMsg
        loadingMsg.updateMessage msg
      else
        res.send msg
      return 

    feed.lastUpdateDate = new Date(0)

    title = null
    if items[0].feed
      title = findFeedTitle items[0].feed

    msg = "<@#{name}>: "
    if title
      title = "RSS Feed `《#{title}》`"
    else
      title = "这个 RSS Feed"

    if feedList.addFeed feed
      msg += "#{title} 已经添加好了"
    else
      msg += "#{title} 已经添加过了, 不需要再添加了"

    if loadingMsg
      loadingMsg.updateMessage msg
    else
      res.send msg

getUrl = (domain, path) ->
  return path unless domain and path
  if path.indexOf('/') == 0
    return domain + path
  return path

getDomain = (line) ->
  url = URL.parse(line);
  if url && url.hostname && url.hostname.split('.').length > 1
    url.protocol = 'http:' unless url.protocol
    return url.protocol + '//' + url.hostname;
  return null;

findFeedTitle = (feed) ->
  if feed.hasOwnProperty 'feed'
    return findFeedTitle feed.feed
  else
    if feed.hasOwnProperty 'title'
      return feed.title
    else
      return null
