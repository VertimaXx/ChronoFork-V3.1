assert(plugin,"Save the complete setup Script as a local Studio plugin")
local toolbar=plugin:CreateToolbar("ChronoFork")
local setup=toolbar:CreateButton("ChronoSetup","Full movement replication setup and explained settings","")
local contact=toolbar:CreateButton("ChronoConnect","Competitive contact setup and game connections","")
setup.ClickableWhenViewportHidden=true contact.ClickableWhenViewportHidden=true
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,false,false,510,810,370,500)
local runtimeWidget=plugin:CreateDockWidgetPluginGuiAsync("ChronoForkFull-3.3-preview",info) runtimeWidget.Title="ChronoFork · movement and networking"
local contactWidget=plugin:CreateDockWidgetPluginGuiAsync("ChronoForkContact-3.3-preview",info) contactWidget.Title="ChronoFork · competitive contacts"
local connectionView=require(script.ContactEditor.View).Mount(contactWidget,{core=script.Core,runtime=script.Runtime,
	onInstalled=function(object)game:GetService("Selection"):Set({object})end,
	openScript=function(object)game:GetService("Selection"):Set({object}) if object:IsA("LuaSourceContainer") then game:GetService("ScriptEditorService"):OpenScriptDocumentAsync(object) end end})
local view=require(script.Editor.View).Mount(runtimeWidget,script.ChronoFork,function()contactWidget.Enabled=true end)
setup.Click:Connect(function()runtimeWidget.Enabled=not runtimeWidget.Enabled end)
contact.Click:Connect(function()contactWidget.Enabled=not contactWidget.Enabled connectionView.Go(6)end)
plugin.Unloading:Connect(function()view.Destroy() connectionView.Destroy() runtimeWidget:Destroy() contactWidget:Destroy()end)
