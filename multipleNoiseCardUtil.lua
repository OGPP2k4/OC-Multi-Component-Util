local component = require('component')

if not component.isAvailable('noise') then
	error('Must Insert Noise Card!!')
	return
end

local module = {
	cards = {},
}

for address, _ in component.list('noise') do
	table.insert(module.cards, address)
end

local function getValidCardChannel(channel)
	if channel < 1 then
		print('Channel Must Over 1')
		return nil, nil, nil
	end
	local cardId = (channel - 1) // module:channel_count() + 1
	local cardChannel = (channel - 1) % module:channel_count() + 1
	local cardAddress = module.cards[cardId]
	if cardAddress == nil then
		print('TOO BIG CHANNEL: ' ..
			tostring(channel) .. ' > ' .. tostring(module:channel_count() * #module.cards))
		return nil, nil, nil
	end
	return cardAddress, cardChannel, cardId
end

local function invokeValidChannel(channel, method, ...)
	local card, ch = getValidCardChannel(channel)
	if card ~= nil then
		return component.invoke(card, method, ch, ...)
	end
	return false, 'invalid'
end

function module:channel_count()
	return component.invoke(self.cards[1], 'channel_count')
end

function module:modes()
	return component.invoke(self.cards[1], 'modes')
end

function module:getMode(channel)
	return invokeValidChannel(channel, 'getMode')
end

function module:setMode(channel, mode)
	return invokeValidChannel(channel, 'setMode', mode)
end

function module:add(channel, frequency, duration, initialDelay)
	if type(initialDelay) == 'number' then
		return invokeValidChannel(channel, 'add', frequency, duration, initialDelay)
	else
		return invokeValidChannel(channel, 'add', frequency, duration)
	end
end

function module:clear()
	for _, c in pairs(self.cards) do
		component.invoke(c, 'clear')
	end
end

function module:process()
	local allok = true
	local reasons = {}
	for _, c in pairs(module.cards) do
		local ok, reason = component.invoke(c, 'process')
		if not ok then
			reasons[c] = reason
			allok = false
		end
	end
	return allok, reasons
end

function module:getActiveChannels()
	local channels = 0
	for _, c in pairs(self.cards) do
		channels = channels + component.invoke(c, 'getActiveChannels')
	end
	return channels
end

function module:isReady()
	local ready = true
	for _, c in pairs(self.cards) do
		ready = ready and component.invoke(c, 'isReady')
	end
	return ready
end

function module:play(channels)
	local channelsPerCard = {}
	for i, note in pairs(channels) do
		local address, channel = getValidCardChannel(i)
		channelsPerCard[address][channel] = note
	end
	local allok = true
	local reasons = {}
	for _, c in pairs(module.cards) do
		local ok, reason = component.invoke(c, "play", channelsPerCard[c])
		if not ok then
			reasons[c] = reason
			allok = false
		end
	end
	return allok, reasons
end

return module
