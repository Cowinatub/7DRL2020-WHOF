local controls = {}
controls["moveBotLeft"] = {"kp1"}
controls["moveBot"] = {"kp2", "down"}
controls["moveBotRight"] = {"kp3"}
controls["moveRight"] = {"kp6", "right"}
controls["moveTopRight"] = {"kp9"}
controls["moveTop"] = {"kp8", "top"}
controls["moveTopLeft"] = {"kp7"}
controls["moveLeft"] = {"kp4", "left"}
controls["moveStay"] = {"kp5"}

local reverseControls = {}

function innitiatePlayer(map, x, y)
	--Do some preprocessing on controls
	for control, keys in pairs(controls) do
		for i = 1, #keys do
			reverseControls[keys[i]] = control
			--error(keys[i] .. ":" .. control)
		end
	end
	
	player = {character = nil, currentlyActing = true, targeting = false}
	player.character = activateCharacter(innitiateCharacter(map, x, y, innitiateLetter("@", {1, 1, 0, 1})))
	return player
end

function updatePlayer(player, camera, dt)
	camera.x = player.character.x
	camera.y = player.character.y
end

function movePlayer(player, xdir, ydir, camera)
	shiftCharacter(player.character, xdir, ydir)
end

function playerKeypressed(player, camera, key)
	local action = reverseControls[key]
	--error(key)
	
	local dirX = 0
	local dirY = 0
	local kind = "none"
	if action == "moveBotLeft" then
		kind = "movement"
		dirX = -1
		dirY = 1
	elseif action == "moveBot" then
		kind = "movement"
		dirX = 0
		dirY = 1
	elseif action == "moveBotRight" then
		kind = "movement"
		dirX = 1
		dirY = 1
	elseif action == "moveRight" then
		kind = "movement"
		dirX = 1
		dirY = 0
	elseif action == "moveTopRight" then
		kind = "movement"
		dirX = 1
		dirY = -1
	elseif action == "moveTop" then
		kind = "movement"
		dirX = 0
		dirY = -1
	elseif action == "moveTopLeft" then
		kind = "movement"
		dirX = -1
		dirY = -1
	elseif action == "moveLeft" then
		kind = "movement"
		dirX = -1
		dirY = 0
	elseif action == "moveStay" then
		kind = "rest"
	end
	
	if kind == "movement" then
		if player.currentlyActing then
			movePlayer(player, dirX, dirY, camera)
		end
	end
end