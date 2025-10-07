local toolbar = plugin:CreateToolbar("Debug Lens")
local button = toolbar:CreateButton("Lens", "Toggle code lens", "rbxassetid://107063245435829")
button.ClickableWhenViewportHidden = true

local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioTheme = settings().Studio.Theme

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, true, 400, 200, 150, 150)
local widget = plugin:CreateDockWidgetPluginGui("ErrorLensDock", widgetInfo)
widget.Title = "Error Lens"

local container = Instance.new("Frame")
container.Size = UDim2.fromScale(1, 1)
container.BackgroundColor3 = StudioTheme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
container.BorderSizePixel = 0
container.Parent = widget

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local lineLabels = {}
for i = 1, 5 do
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = StudioTheme:GetColor(Enum.StudioStyleGuideColor.MainText)
	label.TextTransparency = 0.6
	label.Parent = container
	table.insert(lineLabels, label)
end

local function classifyError(err: string): "error" | "warning" | "ok"
	if not err or err == "" then
		return "ok"
	end

	err = err:lower()

	if err:find("expected 'then'") or err:find("expected 'do'") or err:find("near <eof>") then
		return "warning"
	end

	if err:find("unexpected symbol") or err:find("attempt to call") or err:find("nil value") or err:find("syntax error") then
		return "error"
	end

	if err:find("expected") or err:find("near") then
		return "error"
	end

	return "ok"
end

local lastChangedLine = 1
local previousLines = {}

local function parseError(errMsg)
	if not errMsg then return nil end
	local line = errMsg:match(":(%d+):")
	local message = errMsg:match(":%d+:%s*(.+)")
	if line then
		line = tonumber(line)
	end
	return line, message or errMsg
end

local function isLikelyIncomplete(lineText)
	return lineText:match("^%s*(if|for|while|repeat)%s*$") or
		(lineText:match("^%s*if") and not lineText:match("then%s*$")) or
		(lineText:match("^%s*for") and not lineText:match("do%s*$")) or
		(lineText:match("^%s*while") and not lineText:match("do%s*$"))
end

local function updateLens(textDocument)
	local lines = textDocument:GetText():split("\n")
	local currentLine = math.clamp(lastChangedLine, 1, #lines)

	local fullSource = table.concat(lines, "\n")
	local success, err = loadstring(fullSource)
	local errorLine, errorMessage = parseError(err)

	for i, label in ipairs(lineLabels) do
		local offset = i - 3
		local lineIndex = currentLine + offset
		local lineText = lines[lineIndex] or ""

		if errorLine == lineIndex then
			lineText = lineText .. "	⚠️ " .. (errorMessage or "")
		end

		label.Text = `${lineIndex}: {lineText}`

		if offset == 0 then
			local severity = "ok"
			if errorLine == lineIndex then
				severity = classifyError(err or "")
			elseif isLikelyIncomplete(lineText) then
				severity = "warning"
			end

			if severity == "error" then
				local warningColor = Color3.fromRGB(203, 90, 100)
				label.TextColor3 = warningColor
				label.BackgroundTransparency = 0.7
				label.BackgroundColor3 = warningColor
				label.FontFace.Weight = Enum.FontWeight.ExtraBold
			elseif severity == "warning" then 
				local warningColor = Color3.fromRGB(238, 151, 58)
				label.TextColor3 = warningColor
				label.BackgroundTransparency = 0.7
				label.BackgroundColor3 = warningColor
				label.FontFace.Weight = Enum.FontWeight.ExtraBold
			else
				local warningColor = Color3.fromRGB(120, 255, 120)
				label.TextColor3 = warningColor
				label.BackgroundTransparency = 1
			end
			label.TextTransparency = 0
			label.Font = Enum.Font.Code
		else
			label.TextColor3 = StudioTheme:GetColor(Enum.StudioStyleGuideColor.MainText)
			label.TextTransparency = 0.6
			label.Font = Enum.Font.Code
			label.BackgroundTransparency = 1
		end
	end
end

local function onTextChanged(textDocument)
	local lines = textDocument:GetText():split("\n")
	for i, line in ipairs(lines) do
		if previousLines[i] ~= line then
			lastChangedLine = i
			break
		end
	end
	previousLines = lines
	updateLens(textDocument)
end

local watching = false
local changeConn = nil

button.Click:Connect(function()
	watching = not watching
	button:SetActive(watching)
	widget.Enabled = watching

	if watching then
		print("[DebugLens] Widget opened.")
		changeConn = ScriptEditorService.TextDocumentDidChange:Connect(onTextChanged)
	else
		print("[DebugLens] Widget closed.")
		if changeConn then
			changeConn:Disconnect()
			changeConn = nil
		end
	end
end)

