
cp = require('child_process')
exec = cp.exec
execSync = cp.execSync
updateScript = "#{__dirname}/../src/deploy-from-github-to-openshift.sh"
updateCwd = "#{__dirname}/../"
updateRepoDir = 'UpdateRepo'

module.exports = (robot) ->  
  updateRepoDir = robot.name + updateRepoDir

  srcWords = '(source|src|remote|from|sources|srcs|remotes)'
  addPrefix = "(add\\s+update\\s+#{srcWords}|update\\s+#{srcWords}\\s+add|update\\s+add\\s+#{srcWords})"
  namePart = '([^\\/\\s]+)'
  pathPart = '([^\\/\\@\\:\\s]+\\/[^\\/\\@\\:\\s]+)'
  sshPart = '((ssh|git)\\:\\/\\/)?([^\\/\\:\\s]+\\@[^\\s]+\\:[^\\s]+\\.git[\\/]?)'
  httpsPart = '(https\\:\\/\\/[^\\s]+\\.git)'
  rmWords = '(rm|remove|delete|del)'
  rmPrefix = "(#{rmWords}\\s+update\\s+#{srcWords}|update\\s+#{srcWords}\\s+#{rmWords}|update\\s+#{rmWords}\\s+#{srcWords})"
  listWords = '(ls|list|show)'
  listReg = "(#{listWords}\\s+update\\s+#{srcWords}|update\\s+#{srcWords}\\s+#{listWords}|update\\s+#{listWords}\\s+#{srcWords})"
  updatePrefix = "(update\\s+(yourself\\s+)?(from|via|with|to))"
  updateDefault = "(update\\s+(yourself|now|yourself\\s+now)|self\\s+update)"

  robot.respond regex(addPrefix, namePart, pathPart),  (res) -> addSrc(robot, res, res.match[5], path2https(res.match[6]))
  robot.respond regex(addPrefix, pathPart),            (res) -> addSrc(robot, res, null,         path2https(res.match[5]))
  robot.respond regex(addPrefix, namePart, sshPart),   (res) -> addSrc(robot, res, res.match[5], ssh2https(res.match[8]) )
  robot.respond regex(addPrefix, sshPart),             (res) -> addSrc(robot, res, null,         ssh2https(res.match[7]) )
  robot.respond regex(addPrefix, namePart, httpsPart), (res) -> addSrc(robot, res, res.match[5], res.match[6]            )
  robot.respond regex(addPrefix, httpsPart),           (res) -> addSrc(robot, res, null,         res.match[5]            )

  robot.respond regex(listReg),                        (res) -> listSrc(robot, res)

  robot.respond regex(rmPrefix, pathPart),             (res) -> rmSrc(robot, res, null,         path2https(res.match[8]))
  robot.respond regex(rmPrefix, namePart),             (res) -> rmSrc(robot, res, res.match[8], null)
  robot.respond regex(rmPrefix, sshPart),              (res) -> rmSrc(robot, res, null,         ssh2https(res.match[10]))
  robot.respond regex(rmPrefix, httpsPart),            (res) -> rmSrc(robot, res, null,         res.match[8])
  
  robot.respond regex(updateDefault),                  (res) -> updateFrom(robot, res, null, null)
  robot.respond regex(updatePrefix, namePart),         (res) -> updateFrom(robot, res, res.match[4], null)
  robot.respond regex(updatePrefix, pathPart),         (res) -> updateFrom(robot, res, null, path2https(res.match[4]))
  robot.respond regex(updatePrefix, sshPart),          (res) -> updateFrom(robot, res, null, ssh2https(res.match[6]))
  robot.respond regex(updatePrefix, httpsPart),        (res) -> updateFrom(robot, res, null, res.match[4])

  process.on 'exit', (code) ->
    pendingUpdate = PendingUpdate.load(robot)
    return unless pendingUpdate
    robot.messageRoom pendingUpdate.room, "<@#{pendingUpdate.username}>: 我需要先关闭一下自己."

  robot.brain.on 'loaded', =>
    pendingUpdate = PendingUpdate.load(robot)
    return unless pendingUpdate
    pendingUpdate.finish(robot)
    currentCommit = currentCommitHash()
    return if currentCommit is pendingUpdate.commit
    url = pendingUpdate.urlName(robot)
    from = pendingUpdate.commitName()
    to = pendingUpdate.commitName(currentCommit)
    robot.messageRoom pendingUpdate.room, "<@#{pendingUpdate.username}>: 我更新成功了. \n> From #{from} to #{to} on #{url} "

updateFrom = (robot, res, name, url) -> 
  if !process.env.OPENSHIFT_APP_NAME
    res.reply "貌似我现在不在 OpenShift 上."
    return
  if !name and !url
    urls = getUpdateUrls(robot)
    if urls.length == 0
      res.reply '我现在还没有更新源'
      return
    d = duplicate robot, 'origin', null
    if !d
      d = urls[0]
    name = d.name
    url = d.url

  d = duplicate robot, name, url
  if !d
    if name
      res.reply "找不到叫做 `#{name}` 的更新源." 
    if url
      user = "<@#{res.message.user.name}>"
      msg = robot.lastSentMsg(res.send("#{user}: 我需要先检查一下这个版本库。。。"))
      testUrl url, (err) ->
        if err
          m = "#{user}: 呃, 刚才那个版本库貌似有问题, 我不能从那里更新."
          if msg
            msg.updateMessage m
          else
            res.send m
          return
        if msg
          msg.deleteMessage()
        reallyDoUpdate(robot, res, null, url)
    return
  reallyDoUpdate(robot, res, d.name, d.url)

reallyDoUpdate = (robot, res, name, url) ->
  represent = name
  represent = url unless name
  user = "<@#{res.message.user.name}>"
  msg = robot.lastSentMsg(res.send("#{user}: 我开始从 `#{represent}` 更新自己了。。。"))
  options = {
    env: process.env
    cwd: updateCwd
  }
  options.env.GIT_ASKPASS = 'echo'
  options.env.UPDATE_URL = url
  updateRepo = updateCwd + '/tmp/' + updateRepoDir
  if options.env.OPENSHIFT_TMP_DIR
    updateRepo = options.env.OPENSHIFT_TMP_DIR + updateRepoDir
  options.env.UPDATE_DIR = updateRepo
  if !options.env.OPENSHIFT_DEPLOYMENT_BRANCH
    options.env.OPENSHIFT_DEPLOYMENT_BRANCH = 'master'
  gitRepoPath = updateCwd + '.git'
  if options.env.OPENSHIFT_APP_NAME and options.env.HOME
    gitRepoPath = options.env.HOME + '/git/' + options.env.OPENSHIFT_APP_NAME + '.git'
  options.env.GIT_REPO_PATH = gitRepoPath

  pendingUpdate = null
  currentCommit = currentCommitHash()
  if currentCommit
    pendingUpdate = new PendingUpdate(res.message.user.room, res.message.user.name, url, currentCommit)
    pendingUpdate.save(robot)

  log = '```'
  logMsg = robot.lastSentMsg(res.send(log))
  p = exec "sh #{updateScript}", options, (err, stdout, stderr) ->
    delete options.env.GIT_ASKPASS
    delete options.env.UPDATE_URL
    delete options.env.UPDATE_DIR
    delete options.env.GIT_REPO_PATH
    pendingUpdate.finish(robot) if pendingUpdate
    console.log "DEPLOY: update err: #{err}, stdout: #{stdout}, stderr: #{stderr}"
    m = "#{user}: 从 `#{represent}` 更新成功"
    if err
      m = "#{user}: 从 `#{represent}` 更新失败了"
      if !logMsg
        m += " \n```\n#{err} \n\n#{stdout} \n\n#{stderr}\nq```"
    if msg
      msg.updateMessage m
    else
      res.send m
  writeLog = (data) ->
    robot.logger.info "DEPLOY: #{data}"
    if logMsg
      log += data
      logMsg.updateMessage(log + ' ```')
  p.stdout.on 'data', writeLog
  p.stderr.on 'data', writeLog

addSrc = (robot, res, name, url) ->
  if !url
    res.reply '当使用 SSH 协议的时候, 我只能从 Github 上的版本库更新.'
    return

  name = 'origin' unless name
  d = duplicate(robot, name, url)
  if d
    res.reply "已存在一个重复的更新源 \n ``` #{d.name} : #{d.url} ``` "
    return
  user = "<@#{res.message.user.name}>"
  msg = robot.lastSentMsg(res.send("#{user}: 要从这个版本库更新? 让我先看看它。。。"))
  testUrl url, (err) ->
    if err
      m = "#{user}: 呃, 刚才那个版本库貌似有问题, 我不能从那里更新."
      if msg
        msg.updateMessage m
      else
        res.send m
      return
    addUpdateUrl robot, name, url
    m = "#{user}: 我已经添加了新的更新源\n ``` #{name} : #{url} ```"
    if msg
      msg.updateMessage m
    else
      res.send m

listSrc = (robot, res) ->
  urls = getUpdateUrls robot
  if urls.length == 0
    res.reply '我现在还没有更新源'
    return
  msg = '我现在有这些更新源 ```\n'
  msg += "#{u.name} : #{u.url}\n" for u in urls
  msg = msg.trim() + ' ```'
  res.reply msg

rmSrc = (robot, res, name, url) ->
  return unless name or url
  m = name
  if !name
    m = url
  if rmUpdateUrl(robot, name, url)
    res.reply "更新源已删除, `#{m}` "
  else
    res.reply "没有找到要删除的更新源, `#{m}` "

testUrl = (url, cb) ->
  options = {
    env: process.env
  }
  options.env.GIT_ASKPASS = 'echo'
  exec "git ls-remote -h #{url}", options, (err, stdout, stderr) ->
    console.log "DEPLOY: test url err: #{err}, stdout: #{stdout}, stderr: #{stderr}"
    cb(err) if cb

getUpdateUrls = (robot) ->
  urls = robot.brain.data.updateUrls
  if !Array.isArray(urls)
    robot.brain.data.updateUrls = []
    urls = robot.brain.data.updateUrls
  return urls

duplicate = (robot, name, url) ->
  urls = getUpdateUrls(robot)
  return u for u in urls when u.name == name or u.url == url
  return null

addUpdateUrl = (robot, name, url) ->
  urls = getUpdateUrls(robot)
  urls.push {name: name, url: url} unless duplicate(robot, name, url)

rmUpdateUrl = (robot, name, url) ->
  urls = getUpdateUrls(robot)
  d = duplicate(robot, name, url)
  if d
    urls.splice(urls.indexOf(d))
    return true
  else
    return false

ssh2https = (url) ->
  githubPrefix = 'git@github.com:'
  if url.indexOf(githubPrefix) == 0
    url = url.substring(githubPrefix.length)
    if url.lastIndexOf('/') == (url.length - 1)
      url = url.substring(0, url.length - 1)
    path = url.substring(0, url.length - '.git'.length)
    return path2https(path)
  else
    return null

path2https = (path) ->
  return "https://github.com/#{path}.git"

currentCommitHash = () ->
  options = {
    env: process.env
    cwd: updateCwd
    timeout: 1 * 1000
  }
  gitRepoPath = updateCwd + '.git'
  if options.env.OPENSHIFT_APP_NAME and options.env.HOME
    gitRepoPath = options.env.HOME + '/git/' + options.env.OPENSHIFT_APP_NAME + '.git'
  branch = options.env.OPENSHIFT_DEPLOYMENT_BRANCH 
  branch = 'master' unless branch
  headRef = "refs/heads/#{branch}"
  try
    result = execSync "git ls-remote -h #{gitRepoPath}", options
    result = result.toString() if typeof result isnt 'string'
    for line in result.split(/\r\n|[\n\v\f\r\x85\u2028\u2029]/)
      elements = line.split(/\s+/)
      elements = (el for el in elements when el.trim().length > 0)
      if elements.length > 0
        ref = el for el in elements when el.trim() is headRef.trim()
        return elements[0] if ref
  catch e
    console.log "DEPLOY: current commit hash error #{e}"
  return null

regex = (parts...) ->
  s = parts.join('\\s+')
  return new RegExp("#{s}\\s*$", 'i')

class PendingUpdate
  constructor: (@room, @username, @url, @commit) ->
    if typeof @room == 'object' and @room.hasOwnProperty('room')
      @username = @room.username
      @url = @room.url
      @commit = @room.commit
      @room = @room.room

  isOnGithub: () ->
    return PendingUpdate.isOnGithub @url

  @isOnGithub: (url)->
    return url.indexOf('https://github.com') == 0

  commitName: (commit) ->
    commit = @commit unless commit
    return PendingUpdate.commitName @url, commit

  urlName: (robot) ->
    return "`#{@url}`" unless robot.brain.data
    urls = getUpdateUrls(robot)
    return "<#{urls[i].url}|#{urls[i].name}>" for i in [0..(urls.length - 1)] when urls[i].url is @url
    return "`#{@url}`"

  save: (robot) ->
    robot.logger.info "DEPLOY: save penddingUpdate #{@room} #{@username} #{@url} #{@commit}"
    if robot.brain.data
      robot.brain.data.pendingUpdate = {
        room: @room,
        username: @username,
        url: @url,
        commit: @commit
      }

  finish: (robot) ->
    robot.logger.info "DEPLOY: finish pendingUpdate #{@room} #{@username} #{@url} #{@commit}"
    if robot.brain.data
      robot.brain.data.pendingUpdate = null

  @load: (robot) ->
    if robot.brain.data and robot.brain.data.pendingUpdate
      return new PendingUpdate robot.brain.data.pendingUpdate
    return null

  @commitName : (url, commit) ->
    if PendingUpdate.isOnGithub url
      url = url.replace(/\.git[\/]?$/, '')
      url = url + '/commit/' + commit
      return "<#{url}|#{commit.substring(0, 7)}>"
    return "`#{commit.substring(0, 7)}`" 

