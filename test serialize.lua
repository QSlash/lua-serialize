local slz=require'serialize'

local function shollowcopy(src,dst)
	dst=dst or {}
	for k,v in next,src do
		rawset(dst,k,v)
	end	
	return dst
end
local unpack=unpack or table.unpack
local keykey='ID'

local function randtable(nelm,randomseed)
	local ret={[keykey]=1}
	local allt={ret}
	local arrayctl=5
	randomseed=randomseed or nelm

	local function randint()
		randomseed=randomseed+1 --Respawn bug by given same nelm,randomseed
		return randomseed
	end
	
	local function randselect(t)
		return t[1+randint()%#t]
	end
	
	local function randref()
		return randselect(allt)
	end
	
	local function newtable()
		table.insert(allt,{[keykey]=#allt+1})
		return allt[#allt]
	end
	
	local function randreal()
		return randint()*0.1
	end
	
	local function randstring()
		local cbegin,cend=(' ~'):byte(1,2)
		
		local slen,t=1+(randint()%6)^2,{}
		for i=1,slen do
			table.insert(t,string.char(cbegin+randint()%(cend-cbegin)))
		end
		
		local ret = table.concat(t)
		return ret==keykey and randstring() or ret		
	end
	
	local function randboolean()
		return randint()%2==1
	end
	
	local valtable=
	{
		randref,randboolean,
		randint,randstring,newtable
	}	
	
	local function randarray(t)
		local n = nelm > arrayctl and (1+randint()%math.floor(nelm/arrayctl)) or 0
		for i=1,n do
			table.insert(t,randselect(valtable)())
		end
		nelm = nelm-n
	end
	
	local function randmetatable(t)
		nelm = nelm-1
		setmetatable(t,randref())
	end
	
	local functable=
	{
		randmetatable,
		randarray,
		randint,randstring
		--unpack(valtable)
	}
	
	while nelm > 0 do
		local t=randref()
		local k=randselect(functable)(t)
		if k then
			if rawget(t,k) then table.insert(t,k) 
			else rawset(t,k,randselect(valtable)())
			end
			
			nelm=nelm-1
		end	
	end
	
	return ret
end

local function difference(l,r)
	local stk,visted={},{}
	
	local function _difference(l,r)
		if l~=r then
			if type(l)=='table' and type(r)=='table' then
				if visted[l] and visted[r] then return end
				visted[l],visted[r]=true,true
				local lkm={}
				
				table.insert(stk,false)
				local last=#stk
				for k,v in next,l do
					if type(k)=='table' then
						local kk=rawget(k,keykey)
						if kk then 
							assert(lkm[kk]==nil)
							lkm[kk]=k 
						end
					else
						stk[last]=tostring(k)
						if _difference(v,rawget(r,k)) then
							return stk
						end
					end
				end
				
				for k,v in next,r do
					if type(k)=='table' then
						local kk = rawget(k,keykey)
						if kk then
							stk[last]=('<%d>'):format(kk)
							local lk=lkm[kk]
							lkm[kk]=nil
							if _difference(v,rawget(l,lk)) then
								return stk
							end							
						end
					elseif rawget(l,k)== nil then
						stk[last]=tostring(k)
						return stk
					end	
				end
				if next(lkm) then
					local t={'misskey'}
					for k,_ in next,lkm do
						table.insert(t,k)
					end
					stk[last]=table.concat(t,'.')
					return stk
				end
				
				stk[last]='*META TABLE*'
				if _difference(getmetatable(l),getmetatable(r)) then
					return stk
				end
				
				table.remove(stk)
			else
				table.insert(stk,('<%s~=%s>'):format(tostring(l),tostring(r)))
				return stk
			end
		end
	end	
	
	return _difference(l,r)
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
	print(savestr,'<=Save String')
	local suc,t1=slz.load(savestr,lib,loader)
	
	if not suc then
		print(t1)
		print'FAILED'
		return
	end
	
	print(dumpstring(t),'=>')
	print(dumpstring(t1))
	return t1
end

local function testrandserialize(t)
	local tbeg=os.clock()
	local savestr=slz.save(t)
	local suc,t1=slz.load(savestr)
	local cost=os.clock()-tbeg
	if not suc then
		print(t1)
		print'FAILED'
		return false,savestr
	end
		
	local dif=difference(t,t1)
	if dif then
		print(dumpstring(t),'=>')	
		print(dumpstring(t1))
		print(savestr,'Save String')
		print(table.concat(dif,'.'))
	end
	
	return savestr,cost
end


local tt={1,2,3,4,A='Hello'}
local function testbasic()
	testserialize(tt)
end
testbasic()	
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
testimport()	
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
testsaver()
local function myflit(k,v,t)
	return slz.flit(k,v,t) and type(v) ~= 'string'
end

local function testflit()	
	testserialize(tt,lib,saveprint,loadprint,myflit)--lib.AT stringAT will not be imported.remove {"AT"} from IMPORTV{}
end
testflit()

local function deepth(t)
	local visted={}
	local function _d(t)
		visted[t]=true
		local maxd=0
		for k,v in next,t do
			if type(k)=='table' and not visted[k] then maxd=math.max(maxd,_d(k)) end
			if type(v)=='table' and not visted[v] then maxd=math.max(maxd,_d(v)) end
		end
		return maxd+1
	end
	
	return _d(t)
end

local function respawnBug(t)
	print('DEEPTH:',deepth(t))
	local savestr=slz.save(t)
	savestr=savestr:gsub('},','},\n')
	local nb,tm=slz.load(savestr)
	if not nb then
		local fname=('ErrorSource%d.lua'):format(#savestr)
		print('Save in',fname)
		local fl=io.open(fname,'w')
		fl:write(savestr)
		fl:close()
	
		print(tm)
		os.execute'pause' 
	end
end

local function testrandserialize1000()
	local cost,bytes=0,0
	for i=1,1000 do
		local n,seed=i+100,i+100
		local t=randtable(n,seed)
		local savestr,tm=testrandserialize(t)
		if not savestr then
			respawnBug(t)
			os.execute'pause'
		else			
			bytes,cost=bytes+#savestr,cost+tm
		end
	end
	print(('%.3f seconds for loading %d bytes, %.3f MB/S'):format(cost,bytes,bytes/cost/1000000))
	os.execute'pause' 
end
--testrandserialize1000()--562 2359
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

