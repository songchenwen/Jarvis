# Description:
#  Print Hubot's log in the room
#
# Dependencies:
#
# Commands:
#   hubot log 
#   hubot stop log
#   hubot clear log
#
# Author:
#   songchenwen

cp = require('child_process')
exec = cp.exec

logScript = "#{__dirname}/../src/log.sh"

module.exports = (robot) ->

  maxMsgLength = 4000
  if robot.isSlack()
    maxMsgLength = robot.adapter.MAX_MESSAGE_LENGTH

  logging = null

  robot.respond /(start\s+)?log[s]?(\s+(here|me))?\s*/i, (res) ->
    if !process.env.OPENSHIFT_NODEJS_LOG_DIR
      res.reply '呃。。。看来我没有被部署到 Openshift 上啊'
      return

    robot.logger.info "LOG: max log message length #{maxMsgLength}"

    options = {
      env: process.env
      cwd: process.env.OPENSHIFT_NODEJS_LOG_DIR
    }

    msg = null
    history = ''

    logging = exec "sh #{logScript}", options, (err, stdout, stderr)->
      logging = null
      res.reply '我停止输出日志了'

    logging.stdout.on 'data', (data) ->
      if history.length + data.length > maxMsgLength
        msg = null
        history = ''

      history += data
      if msg
        msg.updateMessage history
      else
        msg = robot.lastSentMsg(res.send(history))

  robot.respond /stop\s+log[s]?(\s+(here|me))?\s*/i, (res) ->
    if logging
      logging.kill()

  robot.respond /clear\s+log[s]?\s*/i, (res) ->
    if logging
      logging.kill()
    if !process.env.OPENSHIFT_NODEJS_LOG_DIR
      res.reply '呃。。。看来我没有被部署到 Openshift 上啊'
      return
    options = {
      env: process.env
      cwd: process.env.OPENSHIFT_NODEJS_LOG_DIR
    }
    exec "rm -f *.log", options, (err, stdout, stderr) ->
      robot.logger.info "LOG: clear log err:#{err}, stdout:#{stdout}, stderr:#{stderr}"
      res.reply '我把日志清空了'
