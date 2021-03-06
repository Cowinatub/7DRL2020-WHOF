local controls = {}

--Support for WASD, Keypad, and Vi-keys
controls["moveBotLeft"] = {"kp1", "z"}
controls["moveBot"] = {"kp2", "x"}
controls["moveBotRight"] = {"kp3", "c"}
controls["moveRight"] = {"kp6", "d"}
controls["moveTopRight"] = {"kp9", "e"}
controls["moveTop"] = {"kp8", "w"}
controls["moveTopLeft"] = {"kp7", "q"}
controls["moveLeft"] = {"kp4", "a"}
controls["moveStay"] = {}
controls["sword"] = {"s", "kp5", "space", "5"}
controls["examine"] = {"v"}
controls["shoot"] = {"f"}
controls["cancel"] = {"escape"}

local reverseControls = {}

function initiatePlayer(map, x, y)
	--Do some preprocessing on controls
	for control, keys in pairs(controls) do
		for i = 1, #keys do
			reverseControls[keys[i]] = control
		end
	end
	
	local player = {character = nil, side = "player", currentlyActing = true, targeting = false, speed = 1, maxSpeed = 5, decals = {}, maxHealth = 8, lastHit = -2, arrows = 3, maxArrows = 6, firing = false, fireRange = 6, dead = false, travelDist = 0}
	player.health = player.maxHealth
	player.lastHealth = player.maxHealth
	
	local spawnTile = findFreeTileFromPoint(map, x, y, 0)
	player.character = activateCharacter(initiateCharacter(map, spawnTile.x, spawnTile.y, initiateLetter("@", {1, 1, 1, 1}), player))
	initiateLance(map, player.character, {1, 1, 1, 1})
	
	return player
end

function updatePlayer(player, camera, dt)
	camera.centerX = player.character.x
	camera.centerY = player.character.y
end

function damagePlayer(player, amount, damageSource)
	if GlobalTime - player.lastHit >= 1 then
		player.lastHealth = player.health
	end
	player.lastHit = GlobalTime
		
	player.health = player.health - amount
	if player.health <= 0 then
		killPlayer(player)
		
		startEndScreen(player, damageSource)
	end
	love.audio.play("grunt5.ogg", "static", false)
end

function healPlayer(player, amount)
	player.lastHealth = player.health
	
	player.health = math.min(player.health + amount, player.maxHealth)
	player.lastHit = GlobalTime
end

function killPlayer(player)
	player.dead = true
	player.character.dead = true
	love.audio.play("whinny.ogg", "static", false, 1)
end

function checkPlayerVictory(player)
	if player.travelDist >= WinDistance then
		player.dead = true
		startEndScreen(player, "victory")
	end
end

--Shifts the player 1 space
function movePlayer(player, xDir, yDir)
	playerGallopSound(player.speed)
	shiftCharacter(player.character, xDir, yDir)
	-- Increase the disance travelled
	player.travelDist = player.travelDist + xDir
end

--Detects player input to start a new round
function playerKeypressed(player, camera, key, curRound)
	if not player.dead then
		local action = reverseControls[key]
		
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
		elseif action == "sword" then
			kind = "sword"
		elseif action == "examine" then
			if not player.firing then
				if camera.movingCursor then
					camera.movingCursor = false
					camera.cursor.remove = true
				else
					camera.movingCursor = true
					initCameraCursor(camera, player, false)
				end
			else
				playerCancelFiring(player, camera)
			end
		elseif action == "shoot" then
			if player.arrows > 0 then
				if player.firing then
					if camera.cursorX == player.character.tile.x and camera.cursorY == player.character.tile.y then
						playerCancelFiring(player, camera)
					else
						player.arrows = player.arrows - 1
						fireArrow(player.character, camera.cursorX, camera.cursorY)
						playerCancelFiring(player, camera)
						startRound(player, player.character.map, curRound)
					end
				else
					if camera.movingCursor then
						camera.cursor.remove = true
					end
					
					camera.movingCursor = true
					initCameraCursor(camera, player, true)
					player.firing = true
				end
			end
		elseif action == "cancel" then
			if player.firing then
				playerCancelFiring(player, camera)
			end
			if camera.movingCursor then
				camera.movingCursor = false
				camera.cursor.remove = true
			end
		end
		
		--Player made an input change
		if kind == "movement" then
			--print(curRound.finished)
			if curRound.finished then
				if not camera.movingCursor then
					determinePlayerAction(player, dirX, dirY, curRound)
				else
					moveCameraCursor(camera, dirX, dirY, player.firing, player)
				end
			end
		elseif kind == "rest" then
			--Player made a blank move with no input then just start the round
			if curRound.finished then
				if not camera.movingCursor then
					startRound(player, player.character.map, curRound)
				end
			end
		elseif kind == "sword" then
			if curRound.finished then
				if not camera.movingCursor then
					characterStartSlashing(player.character)
					startRound(player, player.character.map, curRound)
				end
			end
		end
	end
end

function playerCancelFiring(player, camera)
	camera.movingCursor = false
	camera.cursor.remove = true
	player.firing = false
end

--changes the player's facing and speed depending on input then starts a round
function determinePlayerAction(player, dirX, dirY, curRound)
	local angle = angleBetweenVectors(0, 0, dirX, dirY)
	-- Angle relative to the direction
	local relAngle = distanceBetweenAngles(angle, player.character.facing)
	--is the angle positive or negative
	local angleDir = findAngleDirection(player.character.facing, angle)
	--Convert rel angle to degrees
	relAngle = math.deg(relAngle)
	--Makes it negative or positive
	relAngle = relAngle * angleDir

	--At zero speeed just shift in the direction immedietly
	if player.speed == 0 then
		--print("player use single space move")
		player.character.facing = angle
		player.speed = 1
	else
		--relative angle of zero means will accelerate forward
		if relAngle == 0 then
			modifySpeed(player, 1)
			--print("player moving forward")
		end

		--relative angle of 45 or 315 will not change speed, only angle
		if relAngle == 45 then
			shiftClockwise(player.character)
			--print("player turning clockwise")
		end
		if relAngle == -45 then
			shiftAnticlockwise(player.character)
			--print("player turning anticlockwise")
		end

		--Doing a turn that slows you
		if relAngle == 90 or relAngle == 135 then
			shiftClockwise(player.character)
			modifySpeed(player, -1)
			--print("player slowing down and turning clockwise")
		end
		if relAngle == -90 or relAngle == -135 then
			shiftAnticlockwise(player.character)
			modifySpeed(player, -1)
			--print("player slowing down and turning anticlockwise")
		end

		--Just slowing down
		if relAngle == 180 or relAngle == -180 then
			modifySpeed(player, -1)
			--print("player slowing down")
		end
	end
	
	--Start the round
	startRound(player, player.character.map, curRound)
end

function getPossiblePlayerTiles(player)
	local tiles = {}
	local addTileInLine = function(dist, angle)
		local tileX = player.character.tile.x + dist*roundFloat(math.cos(angle))
		local tileY = player.character.tile.y + dist*roundFloat(math.sin(angle))
		local tile = getMapTile(player.character.map, tileX, tileY)
		if checkTileWalkable(tile, player.character) then
			table.insert(tiles, tile)
		elseif tile.character then
			if tile.character.id == player.character.id then
				table.insert(tiles, tile)
			end
		end
	end
	
	--Rest
	addTileInLine(player.speed, player.character.facing)
	--Accelerate
	if player.speed < player.maxSpeed then
		addTileInLine(player.speed + 1, player.character.facing)
	end
	--Slow
	if player.speed > 0 then
		addTileInLine(player.speed - 1, player.character.facing)
	end
	
	addTileInLine(player.speed, player.character.facing + math.pi/4)
	addTileInLine(player.speed, player.character.facing - math.pi/4)
	
	return tiles
end

function findPlayerPositionInXTurns(player, x)
	local targetTile = getTileFromPointAtDistance(player.character.map, player.character.tile.x, player.character.tile.y, player.character.facing, x*player.speed)
	return targetTile
end

--Clamps the speed
function modifySpeed(player, speedChange)
	player.speed = player.speed + speedChange

	if player.speed >= player.maxSpeed then
		player.speed = player.maxSpeed
	elseif player.speed <= 0 then
	    player.speed = 0
	end
end

--Creates player arrow decals
function createPlayerDecals(player)
	if not player.dead then
		local arrowColour = {1, 1, 1, 0.5}
		local localArrowCreate = function(facing, imageFacing, dist)
			local tileX, tileY = getCardinalPointInDirection(player.character.tile.x, player.character.tile.y, facing, dist)
			local arrow = createArrowDecal(Map, tileX, tileY, imageFacing)
			arrow.colour = arrowColour
			arrow.flashing = 0.3
			table.insert(player.decals, {decal = arrow, facing = imageFacing})
		end
		
		if player.speed > 0 then
			localArrowCreate(player.character.facing, player.character.facing, math.min(player.speed + 1, player.maxSpeed))
			
			localArrowCreate(player.character.facing + math.pi/4, player.character.facing + math.pi/4, player.speed)
			
			localArrowCreate(player.character.facing - math.pi/4, player.character.facing - math.pi/4, player.speed)
			
			if player.speed > 1 then
				localArrowCreate(player.character.facing + math.pi/4, player.character.facing + math.pi/2, player.speed - 1)
				
				localArrowCreate(player.character.facing - math.pi/4, player.character.facing - math.pi/2, player.speed - 1)
			end
			localArrowCreate(player.character.facing, player.character.facing - math.pi, player.speed - 1)
			
			
			if player.speed < player.maxSpeed then
				local tileX, tileY = getCardinalPointInDirection(player.character.tile.x, player.character.tile.y, player.character.facing, player.speed)
				local restDot = initiateDecal(Map, tileX, tileY, "dot")
				restDot.colour = arrowColour
				restDot.flashing = 0.3
				table.insert(player.decals, {decal = restDot, facing = nil})
			end
		else
			localArrowCreate(-3*math.pi/4, -3*math.pi/4, 1)
			localArrowCreate(-math.pi/2, -math.pi/2, 1)
			localArrowCreate(-math.pi/4, -math.pi/4, 1)
			localArrowCreate(0, 0, 1)
			localArrowCreate(math.pi/4, math.pi/4, 1)
			localArrowCreate(math.pi/2, math.pi/2, 1)
			localArrowCreate(3*math.pi/4, 3*math.pi/4, 1)
			localArrowCreate(math.pi, math.pi, 1)
		end
	end
end

function playerDecalsClicked(x, y, player, camera, curRound)
	if camera.movingCursor then
		local tX, tY = mousePosToTilePos(x, y, camera)
		if player.firing and tX == camera.cursorX and tY == camera.cursorY then
			playerKeypressed(player, camera, "f", curRound)
		else
			jumpCameraCursor(camera, tX, tY, player.firing, player)
		end
	else
		local tX, tY = mousePosToTilePos(x, y, camera)
		
		for i = 1, #player.decals do
			local decal = player.decals[i]
			if decal.decal.x == tX and decal.decal.y == tY then
				local command = "kp5"
				if decal.facing then
					if distanceBetweenAngles(decal.facing, 0) == 0 then
						command = "kp6"
					elseif distanceBetweenAngles(decal.facing, math.pi/4) == 0 then
						command = "kp3"
					elseif distanceBetweenAngles(decal.facing, math.pi/2) == 0 then
						command = "kp2"
					elseif distanceBetweenAngles(decal.facing, 3*math.pi/4) == 0 then
						command = "kp1"
					elseif distanceBetweenAngles(decal.facing, math.pi) == 0 then
						command = "kp4"
					elseif distanceBetweenAngles(decal.facing, -math.pi/4) == 0 then
						command = "kp9"
					elseif distanceBetweenAngles(decal.facing, -math.pi/2) == 0 then
						command = "kp8"
					elseif distanceBetweenAngles(decal.facing, -3*math.pi/4) == 0 then
						command = "kp7"
					end
				end
				
				print(command)
				playerKeypressed(player, camera, command, curRound)
				break
			end
		end
	end
end

--Removes all the player decals
function removePlayerDecals(player)
	while #player.decals > 0 do
		player.decals[1].decal.remove = true
		table.remove(player.decals, 1)
	end
end

function collectPlayerPickups(map, player)
	if player.speed <= player.maxSpeed then
		local collectibles = collectPickupsInRange(map, player.character.tile.x, player.character.tile.y, 1)
		
		if collectibles["health"] then
			healPlayer(player, 2*collectibles["health"])
		end
		if collectibles["arrows"] then
			player.arrows = math.min(player.maxArrows, player.arrows + collectibles["arrows"])
		end
	end
end