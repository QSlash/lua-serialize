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

local valimportflit={boolean=true,number=true}

local function importloc(t,flit)
	if t==nil then return end
	
	local ret={}
	local kstack={}
	flit=flit or defaultlocflit
	local function impl(t)
		for k,v in pairs(t) do		
			local orgloc=ret[v]
			if (orgloc==nil or #orgloc>#kstack+1) and flit(k,v,t) then				
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

--local endtableName={N='n', R='r', M='m', A='a', S='s'}
local tableHeadTran={N='R',n='r'}

local function _tostring(target,import,datagetter)
	import=import or {}
	
	local allt={}
	local ipool,tpool,vpool=idpool{},idpool{},idpool{}
	local nt=0
	local sflit,nameflit=4,8
	local itext,vtext,ttext={'local I=IMPORTV{'},{'\nlocal V={'},{'\nreturn {'}

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
			if #v<sflit then --save directly may use less charcter
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
					local endc=tableHeadTran[ttext[-tr]]--assert(ttext[-tr]=='n',or ttext[-tr]=='N')

					ttext[-tr]=string.format('%d,%s',nt,endc)
					tr,allt[v]=nt,nt
				end
				table.insert(ttext,tr)
				table.insert(ttext,',T')
				return
			end

			table.insert(ttext,'N')
			local headpos=#ttext
			allt[v]=-headpos
			
			local tlen,done=rawlen(v),{}

			for i=1,tlen do
				local subv=rawget(v,i)
				if subv~=nil then done[i]=true end
				table.insert(ttext,',')
				write(subv)
			end
			
			if tlen > 0 then table.insert(ttext,',A') end
			local tailpos=#ttext
			for k,subv in next,v do
				if not done[k] then 
					table.insert(ttext,',')
					write(k)
					table.insert(ttext,',')
					write(subv)
				end
			end
			
			if tailpos~=#ttext then table.insert(ttext,',S') end
						
			local mt=getmetatable(v)
			if mt then
				table.insert(ttext,',')
				write(mt)
				table.insert(ttext,',')
				table.insert(ttext,'M')
			end

			ttext[#ttext]=string.lower(ttext[#ttext])
		else		
			write(datagetter(v))
			table.insert(ttext,',C')
		end
	end
	
	write(target)
	endtable(ttext)
	local alltxt={ttext}
	
	if #vtext > 1 then table.insert(alltxt,endtable(vtext)) end
	if #itext > 1 then table.insert(alltxt,endtable(itext)) end
	
	for i=#alltxt-1,1,-1 do
		movepush(alltxt[i],alltxt[#alltxt])
	end
	
	return table.concat(alltxt[#alltxt])
end


local function removen(t,n)
	for i=1,n do table.remove(t) end
end

local function newtable_end(stack)
	table.insert(stack,{})
end

local function newtable(stack,_,tstack)
	table.insert(stack,{})
	table.insert(tstack,#stack)
end

local function newreftable_end(stack,reft)
	local l,t=#stack,{}
	local idx=stack[l]
	reft[idx]=t
	stack[l]=t
end

local function newreftable(stack,reft,tstack)
	newreftable_end(stack,reft)
	table.insert(tstack,#stack)
end

local function reftable(stack,reft)
	local l=#stack
	stack[l]=reft[stack[l]]
end

local function _setmetatable(stack)
	local l=#stack
	setmetatable(stack[l-1],stack[l])
	table.remove(stack)
end

local function setmetatable_end(stack,_,tstack)
	_setmetatable(stack) 
	table.remove(tstack)
end

local function setarray(stack,_,tstack)
	local l=#stack	
	local tidx=tstack[#tstack]
	local n=l-tidx
	local t=stack[tidx]

	for i=1,n do t[i]=stack[tidx+i] end
	removen(stack,n)
end
local function setarray_end(stack,_,tstack)
	setarray(stack,_,tstack) 
	table.remove(tstack)
end

local function setmap(stack,_,tstack)
	local l=#stack
	local tidx=tstack[#tstack]
	local n=l-tidx
	local t=stack[tidx]

	for i=1,n,2 do rawset(t,stack[tidx+i],stack[tidx+i+1]) end
	removen(stack,n)
end

local function setmap_end(stack,_,tstack)
	setmap(stack,_,tstack) 
	table.remove(tstack)
end

local function buildrpn(t,env)
	local stack,reft,tstack,isfun={},{},{},{}
	for _,k in next,env do isfun[k]=true end
	
	for _,v in next,t do
		if isfun[v] then
			v(stack,reft,tstack)
		else
			table.insert(stack,v)
		end
	end

	return unpack(stack)
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
local function makeenv(import,creator)
	local function locatelist(locs)
		local loclist={}
		for _,loc in ipairs(locs) do 
			table.insert(loclist,getloc(import,loc)) 
		end
		return loclist
	end
	
	local function create(stack)
		local l=#stack
		stack[l]=creator(stack[l])
	end
	
	return {
		N=newtable,n=newtable_end,
		M=_setmetatable,m=setmetatable_end,
		T=reftable,
		R=newreftable,r=newreftable_end,
		A=setarray,a=setarray_end,
		S=setmap,s=setmap_end,
		IMPORTV=locatelist,C=create
		}	

end

local function dostring(savestr,import,create)
	local env=makeenv(import or {},create or error)
	local t,s=loadsource(savestr,env)
	if not t then return t,s end
	s,t=pcall(t)
	if not s then return s,t end	
	return true,buildrpn(t,env)
end

return {load=dostring,save=_tostring, import=importloc, flit=defaultlocflit}
