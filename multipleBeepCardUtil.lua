local component = require('component')

if not component.isAvailable('beep') then
	error('Must Insert Beep Card!!')
  return
end

local module = {
	cards = {},
}

for address, _ in component.list('beep') do
	table.insert(module.cards, address)
end

function module:beep(frequencyDurationTable)
	local separateBeeps = {{}}
	local counter = 0
	local sep = {}
	for i, v in pairs(frequencyDurationTable) do
		if counter % 8 == 0 and counter > 0 then
			local cardId = counter // 8 + 1
			separateBeeps[cardId] = sep
			sep = {}
		end
		sep[i] = v
		counter = counter + 1
	end
	local reasons = {}
	local allOk = true
	for cid, fdt in pairs(separateBeeps) do
		local card = self.cards[cid]
		local ok, reason = component.invoke(card, 'beep', fdt)
		if not ok then
			reasons[card] = reason
			allOk = false
		end
	end
	return allOk, reasons
end

function module:getBeepCount()
	local beeps = 0
	for _, c in pairs(self.cards) do
		beeps = beeps + component.invoke(c, 'getBeepCount')
	end
	return beeps
end

return module
