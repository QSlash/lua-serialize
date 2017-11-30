
local unpack=unpack or table.unpack
local rawlen=rawlen or function(t)return #t end

local loadsource = setfenv and function(src,env)
	local fun,msg = loadstring(src)
	if not fun then return fun,msg end
	
	if env then 
		return setfenv(fun,env)
	end
	
	return fun
end or function(src,env)
	return load(src,'serialize result','t',env or _ENV)
end

local isint=math.type and function(v)
	return math.type(v) =='integer' 
end or function(v)
	return math.floor(v)==v
end

local function shollowcopy(src,dst)
	dst=dst or {}
	for k,v in next,src do
		rawset(dst,k,v)
	end	
	return dst
end

local move=table.move and function(src,dst)
	table.move(src,1,#src,#dst+1,dst)
	return shollowcopy(src,dst)--map part not move
end or shollowcopy

local movepush=table.move and function(src,dst)
	table.move(src,1,#src,#dst+1,dst)
end or function(src,dst)
	for _,v in next,src do
		table.insert(dst,v)
	end
end

local function defaultlocflit(k,v,t)
	local kt,vt=type(k),type(v)
	return (kt=='number' and isint(k) or kt=='string') and vt~='number' and vt~='boolean'
end

local function importloc(t,flit)
	if t==nil then return end
	
	local ret={}
	local kstack={}
	flit=flit or defaultlocflit
	local function impl(t)
		for k,v in pairs(t) do		
			if (type(k)=='string' or type(k)=='number') and ret[v]==nil and flit(k,v,t) then
				local loc=shollowcopy(kstack)
				table.insert(loc,k)
				ret[v]=loc
				if type(v) == 'table' then
					table.insert(kstack,k)
					impl(v)
					table.remove(kstack)
				end
			end
		end
	end
	
	impl(t)
	return ret
end

local function endtable(t)
	local l=#t
	if t[l] == ',' then t[l]= '}' else table.insert(t,'}') end
	return t
end

local function idpool(t)
	local nid=0
	return function(k)
		local id = t[k]
		local isnew=not id
		if isnew then
			nid=nid+1
			id,t[k]=nid,nid			
		end
		return id,isnew
	end
end

local function writenbn(v,text)--number boolean nil
	local vt=type(v)
	if vt=='number' then 
		table.insert(text,v) 
	elseif vt=='boolean' or v==nil then
		table.insert(text,tostring(v))
	else
		return false
	end
	
	return true
end

local function _tostring(target,import,datagetter)
	import=import or {}
	
	local allt={}
	local ipool,tpool,vpool=idpool{},idpool{},idpool{}
	local nt=0
	local sflit,lflit,nameflit=6,100,8
	local itext,vtext,ttext={'local I=IMPORTV{'},{'\nlocal V={'},{'\nreturn '}

	local function write(v)
		if writenbn(v,ttext) then
			return 
		end
		
		local loc=import[v]
		if loc then
			local id,isnew=ipool(v)
			table.insert(ttext,('I[%d]'):format(id))
			
			if isnew then
				table.insert(itext,'{')
				for _,v in ipairs(loc)do
					if not writenbn(v,itext) then table.insert(itext,string.format('%q',v)) end
					table.insert(itext,',')
				end
				endtable(itext)
				table.insert(itext,',')
			end
			return
		end
		
		local vt=type(v)
			
		if vt=='string' then
			if #v<sflit then
				table.insert(ttext,string.format('%q',v))
			else
				local id,isnew=vpool(v)
				table.insert(ttext,('V[%d]'):format(id))
				
				if isnew then
					table.insert(vtext,string.format('%q',v))
					table.insert(vtext,',')
				end
			end
		elseif vt=='table' then--local table
			local tr=allt[v]
			if tr then
				if tr<0 then--headpos
					nt=nt+1
					ttext[-tr]=('R(%d){'):format(nt)
					tr,allt[v]=nt,nt
				end
				table.insert(ttext,('T(%d)'):format(tr))
				return
			end

			table.insert(ttext,'{')
			local headpos=#ttext
			allt[v]=-headpos
			
			
			local tlen,done=rawlen(v),{}

			for i=1,tlen do
				local subv=rawget(v,i)
				if subv~=nil then done[i]=true end
				write(subv)
				table.insert(ttext,',')
			end
			
			for k,subv in next,v do
				if not done[k] then 
					local kt=type(k)
					if kt=='string' and #k<nameflit and k:match("^[_%a][_%a%d]*$") then								
						table.insert(ttext,k)
						table.insert(ttext,'=')
					else
						table.insert(ttext,'[')
						write(k)
						table.insert(ttext,']=')
					end
						
					write(subv)
					table.insert(ttext,',')
				end
			end
						
			local mt=getmetatable(v)
			if mt then
				if ttext[headpos]=='{' then
					ttext[headpos]='M{'
				end
				table.insert(ttext,'[M]=')
				write(mt)
			end

			endtable(ttext)
		else		
			table.insert(ttext,'C(')
			write(datagetter(v))
			table.insert(ttext,')')
		end
	end
	
	write(target)
	
	local alltxt={ttext}
	
	if #vtext > 1 then table.insert(alltxt,endtable(vtext)) end
	if #itext > 1 then table.insert(alltxt,endtable(itext)) end
	
	for i=#alltxt-1,1,-1 do-- print(i,'SUB:',table.concat(alltxt[i]))
		movepush(alltxt[i],alltxt[#alltxt])
	end
	
	return table.concat(alltxt[#alltxt])
end

local function getloc(t,loc)
	local suc
	for i,k in ipairs(loc) do
		if type(t) ~= 'table' and not getmetatable(t) then
			error(('cannot index type<%s>'):format(type(t))..table.concat(loc,'.',1,i-1))
		end
		t=t[k]
		if t==nil then
			error('not found IMPORT symbol:'..table.concat(loc,'.',1,i))
		end
	end
	return t
end

local function makeenv(import,create)
	local reft={}

	local function IMPORTV(locs)
		local loclist={}
		for _,loc in ipairs(locs) do 
			table.insert(loclist,getloc(import,loc)) 
		end
		return loclist
	end
	
	local function M(t)
		local mt=rawget(t,M)
		rawset(t,M,nil)
		return setmetatable(t,mt)
	end
	--local building,refed=1,2
	local function R(id)
		local mark=reft[id]
		if not mark then
			mark={{},1}
			reft[id]=mark
		end
				
		return function(t)
			if mark[2]==2 then
				t=move(t,mark[1])
			else
				mark[1]=t
			end

			table.remove(mark)
			
			local mt=t[M]
			if mt then
				rawset(t,M,nil)
				setmetatable(t,mt)
			end
			
			return t
		end
	end
	
	local function T(id)
		local mark=reft[id]
		if not mark then
			mark={{},2}
			reft[id]=mark
		elseif mark[2]==1 then
			mark[2] = 2
		end

		return mark[1]
	end

	return {M=M,T=T,R=R,IMPORTV=IMPORTV,C=create}
end

local function dostring(savestr,import,create)
	local fun,msg=loadsource(savestr,makeenv(import or {},create or error))
	if fun then
		return pcall(fun)
	else
		return false,msg
	end
end

--local function ttostring(target,import, importflit, datagetter)
--	return _tostring(target,importloc(import or {},importflit or defaultlocflit),datagetter or error)
--end
--using import when saving
return {load=dostring,save=_tostring, import=importloc}
