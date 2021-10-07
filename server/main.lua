ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

Citizen.CreateThread(function()
    local ready = 0
    local buis = 0
    local cur = 0
    local sav = 0
    local gang = 0

    local accts = exports.ghmattimysql:executeSync('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Business' })
    buis = #accts
    if accts[1] ~= nil then
        for k, v in pairs(accts) do
            local acctType = v.business
            if businessAccounts[acctType] == nil then
                businessAccounts[acctType] = {}
            end
            businessAccounts[acctType][tonumber(v.businessid)] = generateBusinessAccount(tonumber(v.account_number), tonumber(v.sort_code), tonumber(v.businessid))
            while businessAccounts[acctType][tonumber(v.businessid)] == nil do Wait(0) end
        end
    end
    ready = ready + 1

    local savings = exports.ghmattimysql:executeSync('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Savings' })
    sav = #savings
    if savings[1] ~= nil then
        for k, v in pairs(savings) do
            savingsAccounts[v.citizenid] = generateSavings(v.citizenid)
        end
    end
    ready = ready + 1

    local gangs = exports.ghmattimysql:executeSync('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Gang' })
    gang = #gangs
    if gangs[1] ~= nil then
        for k, v in pairs(gangs) do
            gangAccounts[v.gangid] = loadGangAccount(v.gangid)
        end
    end
    ready = ready + 1

    repeat Wait(0) until ready == 5
    local totalAccounts = (buis + cur + sav + gang)
end)

exports('business', function(acctType, bid)
    if businessAccounts[acctType] then
        if businessAccounts[acctType][tonumber(bid)] then
            return businessAccounts[acctType][tonumber(bid)]
        end
    end
end)

RegisterServerEvent('qb-banking:server:modifyBank')
AddEventHandler('qb-banking:server:modifyBank', function(bank, k, v)
    if banks[tonumber(bank)] then
        banks[tonumber(bank)][k] = v
        TriggerClientEvent('qb-banking:client:syncBanks', -1, banks)
    end
end)

exports('modifyBank', function(bank, k, v)
    TriggerEvent('qb-banking:server:modifyBank', bank, k, v)
end)

exports('registerAccount', function(cid)
    local _cid = tonumber(cid)
    currentAccounts[_cid] = generateCurrent(_cid)
end)

exports('current', function(cid)
    if currentAccounts[cid] then
        return currentAccounts[cid]
    end
end)

exports('debitcard', function(cardnumber)
    if bankCards[tonumber(cardnumber)] then
        return bankCards[tonumber(cardnumber)]
    else
        return false
    end
end)

exports('savings', function(cid)
    if savingsAccounts[cid] then
        return savingsAccounts[cid]
    end
end)

exports('gang', function(gid)
    if gangAccounts[cid] then
        return gangAccounts[cid]
    end
end)

function checkAccountExists(acct, sc)
    local success
    local cid
    local actype
    local processed = false
    local exists = exports.ghmattimysql:executeSync('SELECT * FROM bank_accounts WHERE account_number = ? AND sort_code = ?', { acct, sc })
    if exists[1] ~= nil then
        success = true
        cid = exists[1].character_id
        actype = exists[1].account_type
    else
        success = false
        cid = false
        actype = false
    end
    processed = true
    repeat Wait(0) until processed == true
    return success, cid, actype
end

RegisterServerEvent('qb-banking:createNewCard')
AddEventHandler('qb-banking:createNewCard', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer ~= nil then
        local cid = xPlayer.identifier
        if (cid) then
            currentAccounts[cid].generateNewCard()
        end
    end
end)

RegisterServerEvent('qb-base:itemUsed')
AddEventHandler('qb-base:itemUsed', function(_src, data)
    if data.item == "moneybag" then
        TriggerClientEvent('qb-banking:client:usedMoneyBag', _src, data)
    end
end)

RegisterServerEvent('qb-banking:server:unpackMoneyBag')
AddEventHandler('qb-banking:server:unpackMoneyBag', function(item)
    local _src = source
    if item ~= nil then
        local xPlayer = ESX.GetPlayerFromId(_src)
        local xPlayerCID = xPlayer.identifier
        local decode = json.decode(item.metapublic)
        --_char:Inventories():Remove().Item(item, 1)
        --_char:Cash().Add(tonumber(decode.amount))
        --TriggerClientEvent('pw:notification:SendAlert', _src, {type = "success", text = "The cashier has counted your money bag and gave you $"..decode.amount.." cash.", length = 5000})
    end
end)

function getCharacterName(cid)
    local src = source
    local player = ESX.GetPlayerFromId(src)
    local name = player.firstname
end

RegisterServerEvent('qb-banking:initiateTransfer')
AddEventHandler('qb-banking:initiateTransfer', function(data)
    --[[
    local _src = source
    local _startChar = ESX.GetPlayerFromId(_src)
    while _startChar == nil do Wait(0) end

    local checkAccount, cid, acType = checkAccountExists(data.account, data.sortcode)
    while checkAccount == nil do Wait(0) end

    if (checkAccount) then 
        local receiptName = getCharacterName(cid)
        while receiptName == nil do Wait(0) end

        if receiptName ~= false or receiptName ~= nil then 
            local userOnline = exports.qb-base:checkOnline(cid)
            
            if userOnline ~= false then
                -- User is online so we can do a straght transfer 
                local _targetUser = exports.qb-base:Source(userOnline)
                if acType == "Current" then
                    local targetBank = _targetUser:Bank().Add(data.amount, 'Bank Transfer from '.._startChar.GetName())
                    while targetBank == nil do Wait(0) end
                    local bank = _startChar:Bank().Remove(data.amount, 'Bank Transfer to '..receiptName)
                    TriggerClientEvent('pw:notification:SendAlert', _src, {type = "inform", text = "You have sent a bank transfer to "..receiptName..' for the amount of $'..data.amount, length = 5000})
                    TriggerClientEvent('pw:notification:SendAlert', userOnline, {type = "inform", text = "You have received a bank transfer from ".._startChar.GetName()..' for the amount of $'..data.amount, length = 5000})
                    TriggerClientEvent('qb-banking:openBankScreen', _src)
                    TriggerClientEvent('qb-banking:successAlert', _src, 'You have sent a bank transfer to '..receiptName..' for the amount of $'..data.amount)
                else
                    local targetBank = savingsAccounts[cid].AddMoney(data.amount, 'Bank Transfer from '.._startChar.GetName())
                    while targetBank == nil do Wait(0) end
                    local bank = _startChar:Bank().Remove(data.amount, 'Bank Transfer to '..receiptName)
                    TriggerClientEvent('pw:notification:SendAlert', _src, {type = "inform", text = "You have sent a bank transfer to "..receiptName..' for the amount of $'..data.amount, length = 5000})
                    TriggerClientEvent('pw:notification:SendAlert', userOnline, {type = "inform", text = "You have received a bank transfer from ".._startChar.GetName()..' for the amount of $'..data.amount, length = 5000})
                    TriggerClientEvent('qb-banking:openBankScreen', _src)
                    TriggerClientEvent('qb-banking:successAlert', _src, 'You have sent a bank transfer to '..receiptName..' for the amount of $'..data.amount)
                end
                
            else
                -- User is not online so we need to manually adjust thier bank balance.
                    MySQL.Async.fetchScalar("SELECT `amount` FROM `bank_accounts` WHERE `account_number` = @an AND `sort_code` = @sc AND `character_id` = @cid", {
                        ['@an'] = data.account,
                        ['@sc'] = data.sortcode,
                        ['@cid'] = cid
                    }, function(currentBalance)
                        if currentBalance ~= nil then
                            local newBalance = currentBalance + data.amount
                            if newBalance ~= currentBalance then
                                MySQL.Async.execute("UPDATE `bank_accounts` SET `amount` = @newBalance WHERE `account_number` = @an AND `sort_code` = @sc AND `character_id` = @cid", {
                                    ['@an'] = data.account,
                                    ['@sc'] = data.sortcode,
                                    ['@cid'] = cid,
                                    ['@newBalance'] = newBalance
                                }, function(rowsChanged)
                                    if rowsChanged == 1 then
                                        local time = os.date("%Y-%m-%d %H:%M:%S")
                                        MySQL.Async.insert("INSERT INTO `bank_statements` (`account`, `character_id`, `account_number`, `sort_code`, `deposited`, `withdraw`, `balance`, `date`, `type`) VALUES (@accountty, @cid, @account, @sortcode, @deposited, @withdraw, @balance, @date, @type)", {
                                            ['@accountty'] = acType,
                                            ['@cid'] = cid,
                                            ['@account'] = data.account,
                                            ['@sortcode'] = data.sortcode,
                                            ['@deposited'] = data.amount,
                                            ['@withdraw'] = nil,
                                            ['@balance'] = newBalance,
                                            ['@date'] = time,
                                            ['@type'] = 'Bank Transfer from '.._startChar.GetName()
                                        }, function(statementUpdated)
                                            if statementUpdated > 0 then 
                                                local bank = _startChar:Bank().Remove(data.amount, 'Bank Transfer to '..receiptName)
                                                TriggerClientEvent('pw:notification:SendAlert', _src, {type = "inform", text = "You have sent a bank transfer to "..receiptName..' for the amount of $'..data.amount, length = 5000})
                                                TriggerClientEvent('qb-banking:openBankScreen', _src)
                                                TriggerClientEvent('qb-banking:successAlert', _src, 'You have sent a bank transfer to '..receiptName..' for the amount of $'..data.amount)
                                            end
                                        end)
                                    end
                                end)
                            end
                        end
                    end)
            end
        end
    else
        -- Send error to client that account details do no exist.
        TriggerClientEvent('qb-banking:transferError', _src, 'The account details entered could not be located.')
    end
]]
end)

function format_int(number)
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

ESX.RegisterServerCallback('qb-banking:getBankingInformation', function(source, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    while xPlayer == nil do Wait(0) end
        if (xPlayer) then
            local banking = {
                    ['name'] = xPlayer.firstname .. ' ' .. xPlayer.lastname,
                    ['bankbalance'] = '$'.. format_int(xPlayer.getAccounts('bank'),
                    ['cash'] = '$'.. format_int(xPlayer.getMoney()),
                    ['accountinfo'] = xPlayer.account,
                }
                
                if savingsAccounts[xPlayer.identifier] then
                    local cid = xPlayer.identifier
                    banking['savings'] = {
                        ['amount'] = savingsAccounts[cid].GetBalance(),
                        ['details'] = savingsAccounts[cid].getAccount(),
                        ['statement'] = savingsAccounts[cid].getStatement(),
                    }
                end

                cb(banking)
        else
            cb(nil)
        end
end)

RegisterServerEvent('qb-banking:createBankCard')
AddEventHandler('qb-banking:createBankCard', function(pin)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local cid = xPlayer.identifier
    local AdSoyad = exports.ghmattimysql:execute('SELECT * FROM users WHERE identifier = @identifier', {
        ["@identifier"] = xPlayer.identifier,
    })
    local cardNumber = math.random(1000000000000000,9999999999999999)
    local info = {
        CartNumara = cardNumber,
        Sahip = AdSoyad[1].firstname..' '.AdSoyad[1].lastname
    }
    local selectedCard = Config.cardTypes[math.random(1,#Config.cardTypes)]
    info.citizenid = cid
    info.name = AdSoyad[1].firstname..' '.AdSoyad[1].lastname
    info.cardNumber = cardNumber
    info.cardPin = tonumber(pin)
    info.cardActive = true
    info.cardType = selectedCard
    
    if selectedCard == "visa" then
        xPlayer.addInventoryItem('visa', 1, nil, info)
    elseif selectedCard == "mastercard" then
        xPlayer.addInventoryItem('mastercard', 1, nil, info)
    end

    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = 'inform', text = 'Başarıyla kredi kartı çıkardın!'})
end)

RegisterServerEvent('qb-banking:doQuickDeposit')
AddEventHandler('qb-banking:doQuickDeposit', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = xPlayer.getMoney()

    if tonumber(amount) <= currentCash then
        local cash = xPlayer.removeMoney('cash', tonumber(amount))
        local bank = xPlayer.addAccountMoney('bank', tonumber(amount))
        if bank then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, 'You made a cash deposit of $'..amount..' successfully.')
        end
    end
end)

RegisterServerEvent('qb-banking:toggleCard')
AddEventHandler('qb-banking:toggleCard', function(toggle)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    while xPlayer == nil do Wait(0) end
        --_char:Bank():ToggleDebitCard(toggle)
end)

RegisterServerEvent('qb-banking:doQuickWithdraw')
AddEventHandler('qb-banking:doQuickWithdraw', function(amount, branch)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    while xPlayer == nil do Wait(0) end
    local currentCash = xPlayer.getAccounts('bank')
    
    if tonumber(amount) <= currentCash then
        local cash = xPlayer.removeAccountMoney('bank', tonumber(amount))
        local bank = xPlayer.addMoney(tonumber(amount))
        if cash then 
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, 'You made a cash withdrawal of $'..amount..' successfully.')
        end
    end
end)

RegisterServerEvent('qb-banking:updatePin')
AddEventHandler('qb-banking:updatePin', function(pin)
    if pin ~= nil then 
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        while xPlayer == nil do Wait(0) end

        --   _char:Bank().UpdateDebitCardPin(pin)
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, 'You have successfully updated your debit card pin.')
    end
end)

RegisterServerEvent('qb-banking:savingsDeposit')
AddEventHandler('qb-banking:savingsDeposit', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    while xPlayer == nil do Wait(0) end
    local currentBank = xPlayer.getAccounts('bank')
    
    if tonumber(amount) <= currentBank then
        local bank = xPlayer.removeAccountMoney('bank', tonumber(amount))
        local savings = savingsAccounts[xPlayer.identifier].addMoney(tonumber(amount), 'Current Account to Savings Transfer')
        while bank == nil do Wait(0) end
        while savings == nil do Wait(0) end
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, 'You made a savings deposit of $'..tostring(amount)..' successfully.')
    end
end)

RegisterServerEvent('qb-banking:savingsWithdraw')
AddEventHandler('qb-banking:savingsWithdraw', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    while xPlayer == nil do Wait(0) end
    local currentSavings = savingsAccounts[xPlayer.identifier].GetBalance()
    
    if tonumber(amount) <= currentSavings then
        local savings = savingsAccounts[xPlayer.identifier].RemoveMoney(tonumber(amount), 'Savings to Current Account Transfer')
        local bank = xPlayer.addAccountMoney('bank', tonumber(amount))
        while bank == nil do Wait(0) end
        while savings == nil do Wait(0) end
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, 'You made a savings withdrawal of $'..tostring(amount)..' successfully.')
    end
end)

RegisterServerEvent('qb-banking:createSavingsAccount')
AddEventHandler('qb-banking:createSavingsAccount', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local success = createSavingsAccount(xPlayer.identifier)
    
    repeat Wait(0) until success ~= nil
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, 'You have successfully opened a savings account.')
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', "lightgreen", "**"..GetPlayerName(xPlayer.source) .. " (citizenid: "..xPlayer.identifier.." | id: "..xPlayer.source..")** opened a savings account")
end)

RegisterNetEvent("payanimation")
AddEventHandler("payanimation", function()
TriggerEvent('animations:client:EmoteCommandStart', {"id"})
end)
