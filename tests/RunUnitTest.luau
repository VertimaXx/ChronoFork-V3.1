-- Built-in harness: isolated case modules with deterministic injected dependencies.
local E={}
function E.equal(a,b) if a~=b then error("expected "..tostring(b)..", got "..tostring(a),2) end end
function E.truthy(a) if not a then error("expected truthy",2) end end
function E.falsy(a) if a then error("expected falsy",2) end end
function E.near(a,b,tol) if type(a)~="number" or a~=a or math.abs(a-b)>(tol or 1e-6) then error("expected "..tostring(b).." near "..tostring(a),2) end end
function E.throws(fn) local ok=pcall(fn) if ok then error("expected error",2) end end
return function(filter)
	local report={run=0,passed=0,failed=0,failures={},cases={}}
	local start=os.clock()
	for _,module in script.Parent.Cases:GetChildren() do
		if module:IsA("ModuleScript") and (not filter or module.Name:find(filter,1,true)) then
			local t={expect=E}
			function t.test(name,fn)
				report.run+=1
				local done,ok,err=false,false,nil local cpu=os.clock()
				task.spawn(function() ok,err=pcall(fn) done=true end)
				local waited=0 while not done and waited<15 do waited+=task.wait() end
				local pass=done and ok
				local row={name=module.Name.." / "..name,passed=pass,seconds=os.clock()-cpu}
				table.insert(report.cases,row)
				if pass then report.passed+=1 print("[PASS] "..row.name)
				else report.failed+=1 row.error=tostring(err or "timeout") table.insert(report.failures,row) warn("[FAIL] "..row.name.." | "..row.error) end
			end
			local ok,err=pcall(function() require(module)(t) end)
			if not ok then report.run+=1 report.failed+=1 table.insert(report.failures,{name=module.Name,error=tostring(err)}) end
		end
	end
	report.seconds=os.clock()-start
	print(string.format("[SUMMARY] %d run, %d passed, %d failed",report.run,report.passed,report.failed))
	return report
end
