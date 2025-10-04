local Utils = {}
function Utils.shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end
function Utils.neighbors(x, y)
	return {
		{x = x,   y = y-1, dir = "N"},
		{x = x+1, y = y,   dir = "E"},
		{x = x,   y = y+1, dir = "S"},
		{x = x-1, y = y,   dir = "W"},
	}
end
function Utils.opposite(dir)
	return ({N = "S", S = "N", E = "W", W = "E"})[dir]
end
return Utils
