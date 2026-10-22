-- Packaged as a Script with Core and Editor children. Save as Local Plugin in Studio.
assert(plugin,"Save this Script as a Local Plugin")
local toolbar=plugin:CreateToolbar("Chrono V3")
local toggle=toolbar:CreateButton("ChronoSetup","Connect Chrono to your existing game","")
toggle.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGuiAsync("ChronoV3Setup-3.1",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,false,false,500,800,360,480))
widget.Title="Chrono V3 • Step-by-step setup"
local view=require(script.Editor.View).Mount(widget,{core=script.Core,
 onInstalled=function(object) game:GetService("Selection"):Set({object}) end,
 openScript=function(object)
  game:GetService("Selection"):Set({object})
  if object:IsA("LuaSourceContainer") then
   local opened,reason=game:GetService("ScriptEditorService"):OpenScriptDocumentAsync(object)
   assert(opened,reason)
  end
 end})
toggle.Click:Connect(function() widget.Enabled=not widget.Enabled end)
plugin.Unloading:Connect(function() view.Destroy() widget:Destroy() end)
