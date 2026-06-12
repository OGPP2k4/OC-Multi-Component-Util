local component = require('component')

if not component.isAvailable('sound') then
	error('Must Insert Sound Card!!')
	return
end

local module = {
	cards = {},
}

print('sound.clear(), sound.delay(), sound.process() will affect all sound cards')

for address, _ in component.list('sound') do
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

local function invokeModulation(channel, modIndex, fmam, intensity)
	local reason = ''
	local soundCard1, channel1, cardId1 = getValidCardChannel(channel)
	local soundCard2, channel2, cardId2 = getValidCardChannel(modIndex)
	if soundCard1 == nil or soundCard2 == nil then
		reason = 'Invalid Channel'
	elseif soundCard1 ~= soundCard2 then
		local cardchR = {
			modIndex = {
				min = tostring(cardId1 * module:channel_count()),
				max = tostring((cardId1 - 1) * module:channel_count() + 1),
			},
			channel = {
				min = tostring(cardId2 * module:channel_count()),
				max = tostring((cardId2 - 1) * module:channel_count() + 1),
			},
		}
		reason = 'CHANNEL ID MUST BE BETWEEN SAME CARD' ..
		cardchR.modIndex.min .. ' >= modIndex >= ' .. cardchR.modIndex.max .. ' OR ' ..
		cardchR.channel.min .. ' >= channel >= ' .. cardchR.channel.max
	elseif channel1 == channel2 then
		reason = 'CANNOT USE SAME CHANNEL ID'
	else
		if fmam == 'FM' and type(intensity) == 'number' then
			return component.invoke(soundCard1, 'setFM', channel1, channel2, intensity)
		elseif fmam == 'AM' then
			return component.invoke(soundCard1, 'setAM', channel1, channel2)
		else
			reason = 'fmam need FM or AM'
		end
	end
	return false, reason
end

local function invokeValidChannel(channel, method, ...)
	local card, ch = getValidCardChannel(channel)
	if card ~= nil then
		return component.invoke(card, method, ch, ...)
	end
	return false, 'invalid'
end

local function invokeAllCards(method, ...)
	local allok = true
	local reasons = {}
	for _, c in pairs(module.cards) do
		local ok, reason = component.invoke(c, method, ...)
		if not ok then
			reasons[c] = reason
			allok = false
		end
	end
	return allok, reasons
end

function module:FullReset()
	for i = 1, (#self.cards * self:channel_count()), 1 do
		self:resetEnvelope(i)
		self:resetAM(i)
		self:resetFM(i)
		self:setWave(i, self:modes().square)
		self:close(i)
		self:setFrequency(i, 0)
	end
	self:clear()
	self:setTotalVolume(1)
end

function module:channel_count()
	return component.invoke(self.cards[1], 'channel_count')
end

function module:modes()
	return component.invoke(self.cards[1], 'modes')
end

function module:setTotalVolume(volume)
	for _, c in pairs(self.cards) do
		component.invoke(c, 'setTotalVolume', volume)
	end
end

function module:clear()
	for _, c in pairs(self.cards) do
		component.invoke(c, 'clear')
	end
end

function module:open(channel)
	return invokeValidChannel(channel, 'open')
end

function module:close(channel)
	return invokeValidChannel(channel, 'close')
end

function module:setWave(channel, type)
	return invokeValidChannel(channel, 'setWave', type)
end

function module:setFrequency(channel, frequency)
	return invokeValidChannel(channel, 'setFrequency', frequency)
end

function module:setLFSR(channel, initial, mask)
	return invokeValidChannel(channel, 'setLFSR', initial, mask)
end

function module:delay(duration)
	return invokeAllCards('delay', duration)
end

function module:setFM(channel, modIndex, intensity)
	return invokeModulation(channel, modIndex, 'FM', intensity)
end

function module:resetFM(channel)
	return invokeValidChannel(channel, 'resetFM')
end

function module:setAM(channel, modIndex)
	return invokeModulation(channel, modIndex, 'AM', nil)
end

function module:resetAM(channel)
	return invokeValidChannel(channel, 'resetAM')
end

function module:setADSR(channel, attack, decay, attenuation, release)
	return invokeValidChannel(channel, 'setADSR', attack, decay, attenuation, release)
end

function module:resetEnvelope(channel)
	return invokeValidChannel(channel, 'resetEnvelope')
end

function module:setVolume(channel, volume)
	return invokeValidChannel(channel, 'setVolume', volume)
end

function module:process()
	return invokeAllCards('process')
end

if require('shell') then
	local shell = require('shell')
	local args, options = shell.parse(...)
	if args[1] == 'reset' then
		module:FullReset()
	end
end

return module
