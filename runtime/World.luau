-- Conservative static obstacle scope. Irregular objects use bounding boxes.
-- Does not reconstruct terrain/moving walls; select a historical provider for those.
local W={}
function W.Capture(previous,folder,time,limit,S)
 if not folder or not folder:IsDescendantOf(workspace) then return nil,"obstacle_folder_missing" end
 local rows={} local count=0
 for _,p in folder:GetDescendants() do
  if p:IsA("BasePart") and p.CanQuery and p.CanCollide then
   count+=1 if count>limit then return nil,"obstacle_limit" end
   if not p.Anchored then return nil,"static_obstacle_not_anchored" end
   local ok,shape=pcall(S.Box,p.CFrame,p.Size) if not ok then return nil,"obstacle_shape_out_of_bounds" end
   rows[p]={frame=p.CFrame,size=p.Size,group=p.CollisionGroup,shape=shape}
  end
 end
 local changed=not previous
 if previous then
  for p,row in rows do local old=previous.rows[p] if not old or row.frame~=old.frame or row.size~=old.size or row.group~=old.group then changed=true break end end
  for p in previous.rows do if not rows[p] then changed=true break end end
 end
 return {rows=rows,boundary=if changed then time else previous.boundary,count=count}
end
function W.Check(record,time,query,S)
 if not record or time<record.boundary then return {covered=false} end
 local first
 for _,row in record.rows do local f=S.Intersect(query,row.shape) if f and (not first or f<first) then first=f end end
 return {covered=true,blocked=first~=nil,fraction=first or 1}
end
return W
