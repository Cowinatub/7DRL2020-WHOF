function roundFloat(number)
	local remainder = number%1
	if remainder >= 0.5 then
		return math.ceil(number)
	else
		return math.floor(number)
	end
end