
local slz=require'serialize'

local function shollowcopy(src,dst)
	dst=dst or {}
	for k,v in next,src do
		rawset(dst,k,v)
	end	
	return dst
end

local function dumpstring(t)
	local visted = {}
	local count=0
	local function impl(t,tab)		
		if type(t)=='table' then
			local name=visted[t]
			if name then return name end
			
			count=count+1
			name=('T<%d>'):format(count)
			visted[t]=name
			
			tab=tab..'  '
			local txt={}
			for k,v in pairs(t) do
				table.insert(txt,impl(k,tab)..'='..impl(v,tab))
			end
			
			local mt=getmetatable(t)
			if mt then
				table.insert(txt,'<METATABLE>='..impl(mt,tab))
			end
			
			return table.concat{name,'{\n',tab,'  ',table.concat(txt,','),'\n',tab,'}'}
		else
			return tostring(t)
		end
	end
	
	return impl(t,'')
end


local function testserialize(t,lib,saver,loader,iflit)
	local import=slz.import(lib,iflit)

	local savestr=slz.save(t,import,saver)
	local suc,t1=slz.load(savestr,lib,loader)
	print(savestr,'Save String')
	
	if not suc then
		print(t1)
		print'FAILED'
		return
	end
	
	print(dumpstring(t),'=>')
	
	print(dumpstring(t1))
	return t1
end
local tt={1,2,3,4,A='Hello'}
local function testbasic()
	testserialize(tt)
end
local lib={mt={__index=function(t,k)return k end,mt={__index=function(t,k)return k..k end}},AT='stringAT'}
local function testimport()	
	local s='menmenmjielieforksitrguo'
	shollowcopy({a=1,shorts='ab',longs=s,at=lib.AT,C={str=s}},tt)
	tt.b=tt
	tt[tt.b]=tt.b
	setmetatable(tt,lib.mt)
	setmetatable(tt.C,lib.mt.mt)
	local t=testserialize(tt,lib)
	print(t.Hello,t.C.world)
end

local function saveprint(fun)
	if fun==print then return 'print' end
end

local function loadprint(name)
	if name=='print' then return print end
end

local function testsaver()
	tt.print=print
	local t=testserialize(tt,lib,saveprint,loadprint)
	t.print'Printing'
end

local function myflit(k,v,t)
	return type(v) ~= 'string'
end

local function testflit()	
	testserialize(tt,lib,saveprint,loadprint,myflit)--lib.AT stringAT will not be imported.remove {"AT"} from IMPORTV{}
end

local function _testspeed(t)
	local tbeg=os.clock()
	local import=slz.import(lib)
	local savestr=slz.save(t,import)
	local cost=os.clock()-tbeg
	print(('%.3f seconds for saving %d bytes, %.3f MB/S'):format(cost,#savestr,#savestr/cost/1000000))
	
	tbeg=os.clock()
	local suc,t1=slz.load(savestr,lib)
	cost=os.clock()-tbeg
	print(('%.3f seconds for loading %d bytes, %.3f MB/S'):format(cost,#savestr,#savestr/cost/1000000))
end
local function testspeed()
	local atom={1,2,3,4,5,6,7,8,A='Hello',B=lib.mt}
	for i=1,4000 do table.insert(atom,i) end
	
	local bigt={ref=atom, val=shollowcopy(atom),shollowcopy(atom)}
	for i=1,16 do
		bigt={ref=bigt,val={shollowcopy(bigt),shollowcopy(bigt)},shollowcopy(atom),shollowcopy(atom),shollowcopy(atom),shollowcopy(atom)}
	end
	_testspeed(bigt)
	for i=1,2^20 do table.insert(atom,i) end
	_testspeed(atom)
end
testspeed()
