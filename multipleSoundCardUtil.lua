local component = require('component')

if not component.isAvailable('sound') then
	error('Must Insert Sound Card!!')
	return
end

local module = {
	cards = {},
}

local card_ids = {}
local channels = 0
local waves = {}
do
	local tableIdx = 1
	for address, _ in component.list('sound') do
		module.cards[tableIdx] = address
		card_ids[address] = tableIdx
		tableIdx = tableIdx + 1
	end
	channels = component.invoke(module.cards[1], 'channel_count')
	waves = component.invoke(module.cards[1], 'modes')
end

local function getValidCardChannel(channel)
	if channel < 1 then
		return false, 'Channel Must Over 1'
	end
	local cardId = (channel - 1) // channels + 1
	local cardChannel = (channel - 1) % channels + 1
	local cardAddress = module.cards[cardId]
	if cardAddress == nil then
		return false, 'TOO BIG CHANNEL: ' ..
			tostring(channel) .. ' > ' .. tostring(module:channel_count())
	end
	return cardAddress, cardChannel
end

local function invokeModulation(channel, modIndex, fmam, intensity)
	local reason = ''
	local soundCard1, channel1 = getValidCardChannel(channel)
	local soundCard2, channel2 = getValidCardChannel(modIndex)
	if soundCard1 == nil or soundCard2 == nil then
		reason = 'Invalid Channel'
	elseif soundCard1 ~= soundCard2 then
		reason = 'CHANNEL ID MUST BE BETWEEN SAME CARD' ..
			tostring(card_ids[soundCard1] * channels) .. ' >= modIndex >= '..
			tostring((card_ids[soundCard1] - 1) * channels + 1) .. ' OR ' ..
			tostring(card_ids[soundCard2] * channels) .. ' >= channel >= ' ..
			tostring((card_ids[soundCard2] - 1) * channels + 1)
	elseif channel1 == channel2 then
		reason = 'CANNOT USE SAME CHANNEL ID'
	else
		if fmam == 'FM' and type(intensity) == 'number' then
			return component.invoke(soundCard1, 'setFM', channel1, channel2, intensity)
		elseif fmam == 'AM' then
			return component.invoke(soundCard1, 'setAM', channel1, channel2)
		else
			reason = 'FM need intensity'
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

function module:channel_count()
	return channels * #module.cards
end

function module:modes()
	return waves
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

function module:FullReset()
	for i = 1, (#self.cards * self.channels), 1 do
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

return module
