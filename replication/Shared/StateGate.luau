-- A sequence is comparable only inside one object lifetime and state revision.
local Sequence=require(script.Parent.Sequence)
local G={}
function G.Check(entity,row,owner)
	if not entity or entity.destroyed then return false,"missing_entity" end
	if owner~=nil and entity.networkOwner~=owner then return false,"wrong_owner" end
	if entity.generation~=row.generation then return false,"old_lifetime" end
	if (entity.ownershipRevision or 0)~=row.ownershipRevision then return false,"old_revision" end
	if not Sequence.Newer(row.sequence,entity._receivedSequence) then return false,"old_sequence" end
	return true
end
return table.freeze(G)
