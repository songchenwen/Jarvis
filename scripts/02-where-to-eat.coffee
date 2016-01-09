# Description:
#  Random where to eat
#
# Dependencies:
#   "hubot-redis-brain":"0.0.3"
#
# Commands:
#   hubot add restaurant <name> - add restaurant
#   hubot new restaurant <name> - add restaurant
#   hubot list restaurant - restaurant list
#   hubot 新餐馆 <name> - add restaurant
#   hubot 新饭店 <name> - add restaurant
#   hubot 增加饭店 <name> - add restaurant
#   hubot 所有饭店 - restaurant list
#   hubot 饭店列表 - restaurant list
#   hubot where to eat - random a restaurant
#   hubot 去哪吃 - random a restaurant
#
#
# Author:
#   songchenwen

module.exports = (robot) ->

	robot.respond /(add|new)\s+restaurant\s+(\S+)/i, (res) ->
		add robot, res, 2
	robot.respond /(新|增加)(饭店|饭馆|餐馆)\s+(\S+)/i, (res) ->
		add robot, res, 3
	robot.respond /(list restaurant[s]?|所有(饭店|饭馆|餐馆)|(饭店|饭馆|餐馆)列表)/i, (res) ->
		all robot, res
	robot.respond /(where (to|2) eat)|去哪吃/i, (res) ->
		where robot, res

noRestaurants = "我还不知道附近有什么餐馆"

all = (robot, res) ->
	list = robot.brain.data.restaurants
	if list
		res.reply list.join(', ')
	else
		res.reply noRestaurants

add = (robot, res, index) ->
	return unless res.match.length > index 
	restaurant = res.match[index]
	list = robot.brain.data.restaurants
	if !list
		list = []
	if list.indexOf(restaurant) < 0
		list.push(restaurant)
	robot.brain.data.restaurants = list
	res.reply "#{restaurant}, 记住了"

where = (robot, res) ->
	list = robot.brain.data.restaurants
	if list
		index = Math.floor(Math.random() * list.length)
		res.reply list[index]
	else
		res.reply noRestaurants

