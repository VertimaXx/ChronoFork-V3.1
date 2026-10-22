-- Stable field order and plain-language help shared by the form and validation messages.
local F={}
F.Order={"name","kind","targets","shape","width","height","depth","radius","forward","length","opens","closes","maxTargets","seconds","maxGap","maxRewind","maxSpeed","maxRadius","rules"}
F.Items={
	name={label="Name for the added code",page=2,hint="This name appears in Explorer under ServerScriptService. Example: Football contact. Existing code with the same name will not be replaced."},
	kind={label="Object type name",page=2,hint="A short name your scripts use to group objects. Examples: player, ball, fighter. Use the same spelling in your game code. This is the code field kind."},
	targets={label="Object types this move can touch",page=3,hint="Separate names with commas. Example: player, ball. These names must match the kinds you register with Track."},
	shape={label="Hitbox shape",page=3,hint="Choose an invisible gameplay shape. The picture below is a preview; it does not read or change your map."},
	width={label="Box width",page=3,min=0.01,max=64,unit="studs",hint="Side-to-side size. A stud is Roblox's distance unit."},
	height={label="Total height",page=3,min=0.02,max=64,unit="studs",hint="Bottom-to-top size. For a capsule (a cylinder with round ends), include both round ends."},
	depth={label="Box depth",page=3,min=0.01,max=64,unit="studs",hint="Front-to-back size. Larger values let the move reach farther in that direction."},
	radius={label="Radius: center to edge",page=3,min=0.01,max=32,unit="studs",hint="Radius 1.5 makes a ball 3 studs wide. A capsule's width is also twice its radius."},
	forward={label="Distance in front of the object",page=3,min=0,max=512,unit="studs",hint="The hitbox center stays this far in front of the saved position. It turns with the object. Zero centers it on the object."},
	length={label="Distance to check along the line",page=3,min=0.01,max=4096,unit="studs",hint="Check straight ahead for this distance. A line has no thickness; a moving-ball check also uses the radius."},
	opens={label="Wait before the move can hit",page=3,min=0,max=10,unit="seconds",hint="Time after your server accepts the move. Example: 0.12 seconds is 120 milliseconds (ms). Zero allows an immediate hit."},
	closes={label="Stop checking hits after",page=3,min=0,max=10,unit="seconds",hint="Measured from the same move start. Example: wait 0.12 and stop at 0.35 means a 0.23-second hit period."},
	maxTargets={label="Maximum objects touched per move",page=3,min=1,max=256,unit="objects",hint="This is a total for the whole move. Each object is returned at most once for that move reference."},
	seconds={label="How long to keep past positions",page=4,min=0.05,max=10,unit="seconds",hint="History means saved earlier positions and hitboxes. Old records are removed. Keeping them longer uses more memory."},
	maxGap={label="Largest allowed gap between records",page=4,min=0.001,max=1,unit="seconds",hint="Chrono can estimate between nearby records. It refuses to guess across a larger gap. 0.075 seconds is 75 ms."},
	maxRewind={label="Maximum time allowed into the past",page=4,min=0,max=10,unit="seconds",hint="Rewind means checking earlier positions. Zero is the simplest start. A larger limit still needs a server function that approves each delay."},
	maxSpeed={label="Maximum allowed movement speed",page=2,min=0,max=4096,unit="studs / second",hint="The largest speed your game allows for the reference position. A faster unexplained jump pauses recording. Approved teleports need a tracking reset."},
	maxRadius={label="Farthest allowed hitbox edge",page=2,min=0.01,max=512,unit="studs",hint="Measure from the object's reference position to the farthest edge of any target hitbox. Include both its offset and size."},
	rules={label="Example target rule",page=4,hint="Your game decides which targets are allowed. Team, immunity, possession and round rules belong in this function."},
}
F.Shapes={{code="Box",label="Box",help="A rectangular box. Useful for broad tackle or melee volumes."},
	{code="Sphere",label="Ball (sphere)",help="A round ball. Useful for a football or a round area."},
	{code="Capsule",label="Body with round ends (capsule)",help="A cylinder with half a ball at each end. Useful for a simple body shape."},
	{code="Ray",label="Thin line (ray)",help="A straight line with no thickness. Useful for an instant line check."},
	{code="SweptSphere",label="Ball along a line (sweep)",help="Check a ball at every point along a straight line, not only at its end."}}
return F
