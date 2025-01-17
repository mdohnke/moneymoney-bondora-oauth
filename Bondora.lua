-- Extension for MoneyMoney to fetch data from Bondora
--
-- Copyright (c) 2025 Marco Dohnke

-------------------------


local BANK_CODE = "Bondora (OAuth2)"
local REDIRECT_URI = "https://service.moneymoney-app.com/1/redirect"
local SCOPE = "Investments ReportRead"
local AUTH_URL = "https://app.bondora.com/oauth/authorize"

WebBanking {
    version = 0.1,
    url = "https://api.bondora.com",
    services = {BANK_CODE},
    description = string.format(MM.localizeText("Bondora Account"), BANK_CODE),
}

-- HTTPS connection object
local connection

-- Set to true on initial setup to query all transactions
local isInitialSetup = false

-- Due to rate limiting of the Bondora API we reuse the account balance and investment response
-- Time how long to "cache" the account balance response 
local timeToHoldBalanceResponse = 300
local timeToHoldInvestmentResponse = 720

local clientId
local clientSecret

function SupportsBank(protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == BANK_CODE
end

function InitializeSession2(protocol, bankCode, step, credentials, interactive)
    -- Bondora's authentication uses OAuth2 and want a redirect to their website
    -- see https://api.bondora.com/Intro#authorization for details
    -- IMPORTANT: Please contact MoneyMoney developer before using OAuth in your own extension.
    if step == 1 then
        clientId = credentials[1]
        clientSecret = credentials[2]

        -- Create HTTPS connection object.
        connection = Connection()

        -- Check if access token is still valid
        local authenticated = false
        if LocalStorage.accessToken and os.time() < LocalStorage.expiresAt then
            print("Validating access token.")
            print("Access Token: " .. LocalStorage.accessToken)
            print("Expires at: " .. os.date("%m/%d/%Y %I:%M %p", LocalStorage.expiresAt))
            local eventlog = queryPrivate("api/v1/eventlog")
            if eventlog["Success"] == true then
                authenticated = true
                print("Authenticated!")
            else
                authenticated = false
                print("Not authenticated!")
            end
            print("Authenticated? -> " .. string.format("%s", authenticated))
        end

        -- Obtain OAuth 2.0 authorization code from web browser.
        if not authenticated then
            return {
                title = "Bondora API",
                challenge = AUTH_URL .. 
                    "?client_id=" .. MM.urlencode(clientId) .. 
                    "&redirect_uri=" .. MM.urlencode(REDIRECT_URI) ..
                    "&response_type=code" ..
                    "&scope=" .. MM.urlencode(SCOPE)
                -- The URL argument "state" will be automatically inserted by MoneyMoney.
            }
        end
    end

    if step == 2 then
        local authorizationCode = credentials[1]

        -- Exchange authorization code for access token.
        print("Requesting OAuth access token with authorization code.")
        local postContent = "grant_type=authorization_code" .. 
            "&client_id=" .. MM.urlencode(clientId) .. 
            "&client_secret=" .. MM.urlencode(clientSecret) .. 
            "&redirect_uri=" .. MM.urlencode(REDIRECT_URI) ..
            "&code=" .. MM.urlencode(authorizationCode)
        local postContentType = "application/x-www-form-urlencoded"
        local headers = {
            ['Accept'] = "application/json"
        }
        local json = JSON(connection:request("POST", url .. "/oauth/access_token", postContent, postContentType, headers)):dictionary()
        -- Store access token and expiration date.
        print("Access Token: " .. json["access_token"])
        print("Expires in: " .. json["expires_in"])
        LocalStorage.accessToken = json["access_token"]
        LocalStorage.expiresAt = os.time() + json["expires_in"]
        print("Expires at: " .. os.date("%m/%d/%Y %I:%M %p", LocalStorage.expiresAt))

    end

end

function ListAccounts(knownAccounts)
    -- Fetch Go&Grow Accounts
    local accounts = GetGoGrowAccounts()
    -- Fetch Portfolio Pro and other accounts
    table.insert(accounts, GetOtherBondoraAccounts())
    return accounts
end

function RefreshAccount(account, since)
    local s = {}
    
    if(account["accountNumber"] == "Go&Grow Accounts") then
        s = mergeTables(s,GetGoGrowBalance())
    end
    if(account["accountNumber"]== "Other Bondora Products") then
        s = mergeTables(s, GetOtherBondoraProductBalance())
    end
    return {securities = s}
end

function EndSession()
end

--
-- Bondora API object handling 
--
function GetGoGrowAccounts()
    FetchOrUpdateGoAndGrowData()
    local accounts = {}
    if LocalStorage.balanceResponse["Success"] then
        if LocalStorage.balanceResponse["Payload"]["GoGrowAccounts"] ~= nil then
            table.insert(accounts, {
                name = "Go&Grow Accounts",
                accountNumber = "Go&Grow Accounts",
                currency = "EUR",
                portfolio = true,
                type = "AccountTypePortfolio"
            })
        end
    end
    return accounts
end

-- Fetch account values for Bondora Go&Grow
function GetGoGrowBalance()
    FetchOrUpdateGoAndGrowData()
    local securites = {}
    for key, value in pairs(LocalStorage.balanceResponse["Payload"]["GoGrowAccounts"]) do
        table.insert(securites, {
            name = value["Name"],
            quantity = 1,
            purchasePrice = value["NetDeposits"],
            price = value["TotalSaved"],
            currency = nil
        })
    end
    return securites
end

-- Check if other Bondora products like Portfolio Pro / Portfolio Manager / API / Manual are used
function GetOtherBondoraAccounts()
    FetchOrUpdateInvestmentsData()
    -- If number of investments > 0 then other bondora products are used
    if LocalStorage.investmentsResponse["TotalCount"] > 0 then
        return {
            name = "Portfolio Pro etc.",
            accountNumber = "Other Bondora Products",
            currency = "EUR",
            portfolio = true,
            type = "AccountTypePortfolio"            
        }
    else
        -- Seems that only Go&Grow is used, so we return an empty table
        return {}
    end
end

-- Fetch balance for other Bondora products like Portfolio Pro / Portfolio Manager / API / Manual
function GetOtherBondoraProductBalance()
    FetchOrUpdateInvestmentsData()
    local s = {}
    for key, value in pairs(LocalStorage.investmentsResponse["Payload"]) do
        table.insert(s, {
            name = value["InvestmentNumber"],
            quantity = 1,
            purchasePrice = value["PrincipalRemaining"],
            price = value["PrincipalRemaining"]-value["PrincipalLateAmount"],
            currency = nil,
        })
    end

    return s
end

-- 
-- HTTP helpers
--

function FetchOrUpdateGoAndGrowData()
    -- Fetch new data in respect to API rate limiting
    if LocalStorage.balanceResponse == nil then
        LocalStorage.balanceResponse = queryPrivate("api/v1/account/balance")
        if LocalStorage.balanceResponse["Success"] then
            LocalStorage.balanceResponseTimestamp = os.time() + timeToHoldBalanceResponse
        end
    elseif LocalStorage.balanceResponse ~= nil and LocalStorage.balanceResponseTimestamp < os.time() then
        LocalStorage.balanceResponse = queryPrivate("api/v1/account/balance")
        if LocalStorage.balanceResponse["Success"] then
            LocalStorage.balanceResponseTimestamp = os.time() + timeToHoldBalanceResponse
        end
    end
    print("Balance Cache will be invalidated in " .. LocalStorage.balanceResponseTimestamp-os.time() .. " seconds.")
end

function FetchOrUpdateInvestmentsData()
    if LocalStorage.investmentsResponse == nil then
        LocalStorage.investmentsResponse = queryPrivate("api/v1/account/investments?LoanStatusCode=2&LoanStatusCode=5&LoanStatusCode=100")
        if LocalStorage.investmentsResponse["Success"] then
            LocalStorage.investmentsResponseTimestamp = os.time() + timeToHoldInvestmentResponse
        end
    elseif LocalStorage.investmentsResponse ~= nil and LocalStorage.investmentsResponseTimestamp < os.time() then
        LocalStorage.investmentsResponse = queryPrivate("api/v1/account/investments?LoanStatusCode=2&LoanStatusCode=5&LoanStatusCode=100")
        if LocalStorage.investmentsResponse["Success"] then
            LocalStorage.investmentsResponseTimestamp = os.time() + timeToHoldInvestmentResponse
        end
    end
    print("Investments Cache will be invalidated in " .. LocalStorage.investmentsResponseTimestamp-os.time() .. " seconds.")

end

-- Builds the request for sending to Bondora API and unpacks
-- the returned json object into a table
function queryPrivate(method, params)
    local path = string.format("/%s", method)

    if not (params == nil) then
        local queryParams = httpBuildQuery(params)
        if string.len(queryParams) > 0 then
            path = path .. "?" .. queryParams
        end
    end

    local headers = {}
    headers["Authorization"] = "Bearer " .. LocalStorage.accessToken
    headers["Accept"] = "application/json"

    content = connection:request("GET", url .. path, nil, nil, headers)

    return JSON(content):dictionary()
end

function httpBuildQuery(params)
    local str = ''
    for key, value in pairs(params) do
        str = str .. key .. "=" .. value .. "&"
    end
    str = str.sub(str, 1, -2)
    return str
end

function mergeTables(table1, table2)
	for _, value in ipairs(table2) do
		table1[#table1+1] = value
	end
	return table1
end


-- DEBUG Helpers

--[[ RecPrint(struct, [limit], [indent])   Recursively print arbitrary data.
        Set limit (default 100) to stanch infinite loops.
        Indents tables as [KEY] VALUE, nested tables as [KEY] [KEY]...[KEY] VALUE
        Set indent ("") to prefix each line:    Mytable [KEY] [KEY]...[KEY] VALUE
--]]
function RecPrint(s, l, i) -- recursive Print (structure, limit, indent)
    l = (l) or 100; i = i or ""; -- default item limit, indent string
    if (l < 1) then print "ERROR: Item limit reached."; return l - 1 end;
    local ts = type(s);
    if (ts ~= "table") then print(i, ts, s); return l - 1 end
    print(i, ts); -- print "table"
    for k, v in pairs(s) do -- print "[KEY] VALUE"
        l = RecPrint(v, l, i .. "\t[" .. tostring(k) .. "]");
        if (l < 0) then break end
    end
    return l
  end