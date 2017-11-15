do

local tree = {}

local function valstr(v)
	local vtp = type( v )
	assert(vtp ~= 'function')
	if "string" == vtp then
		v = string.gsub( v, "\n", "\\n" )
		if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
	elseif "table" == vtp then
		return tree.tostring(v)
	else
		return tostring(v)
	end
end

local function keystr (k)
  if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. valstr(k) .. "]"
  end
end


function tree.tostring(tbl)
	assert(type(tbl) == 'table')
	local result, iresult, len ={}, {}, #tbl
	
	for i = 1, len do
		table.insert( iresult, valstr(rawget(tbl,i)) )
	end

	for k, v in pairs( tbl ) do
		if type(k) ~= 'number' or k < 1 or len < k then
			table.insert( result, keystr( k ) .. "=" .. valstr(v) )
		end	  
	end

	for _,s in ipairs(iresult) do
		table.insert(result,s)
	end
	
	return "{" .. table.concat( result, "," ).."" .. "}"
end

function tree.istree(tb, visted)
	if type(tb) ~= 'table' then return true end

	visted = visted or {}
	
	if visted[tb] then
		return false
	end
	
	visted[tb] = true
	
	for k, v in pairs(tb) do
		if not (tree.istree(k,visted) and tree.istree(v,visted)) then
			return false
		end
	end
	
	return true
end

function tree.replace(t,fun)
	for k,v in pairs(t) do
		local newk, newv = fun(k,v,t)
		
		if newk ~= k then
			t[k] = nil
		end
		
		t[newk] = newv
		
		if newv == v and type(v) == 'table' then
			tree.replace(newv,fun)
		end
	end
end

local function copyfast(t)
	local ret = {}
	for k,v in pairs(t) do
		
		if type(v) == 'table' then
			v = copyfast(v)
		end
		
		ret[k] = v
	end
	
	return ret
end

function tree.copy(t, fun)
	--fun = fun or function(k,v) return k,v end
	if not fun then return copyfast(t) end

	local ret = {}
	
	for k,v in pairs(t) do
		local newk, newv = fun(k,v,t)
		
		if newv == v and type(v) == 'table' then
			newv = tree.copy(v,fun)
			--setmetatable(newv,getmetatable(v))
		end
		
		ret[newk] = newv
	end
	
	return ret
end

function tree.depthfirsteach(fun, lt, rt)
	for k,v in pairs(rt) do
		local subl,subr = fun(lt,rt,k,v)
		if subl then
			tree.depthfirsteach(fun, subl, subr)
		end
	end
end

local lua_version = tonumber(string.match(_VERSION,'%d.%d'))
local unpack=unpack

if lua_version < 5.2 then

	function tree.fromstring(src,env)
		local fun = assert(loadstring('return '..src))

		if env then 
			setfenv(fun,env) 
		end
		
		local suc, ret = pcall(fun)
		if not suc then
			error(ret)
			return
		end
		return ret
	end
	
else
	unpack = table.unpack
	function tree.fromstring(src,env)	
		local fun = assert(load('return '..src,nil,nil,env or _ENV))
		local suc, ret = pcall(fun)
		if not suc then
			error(ret)
			return
		end
		return ret
	end

end

local function assert_open(fname, mode)
	local fl = io.open(fname, mode)

	if not fl then
		error('fail when open '..fname..' mode='..(mode or 'r'))
	end
	return fl
end

function tree.tofile(tbl, fname)
	local fl = assert_open(fname,'w')
	fl:write(tree.tostring(tbl))
	fl:close()
end

function tree.fromfile(fname, env)
	local fl = assert_open(fname)
	local src = fl:read('*all')
	fl:close()
--use \n to skip last annotation
	return tree.fromstring(src, env)
end

function chainfun(...)
	if select('#',...) == 1 then return select(1,...) end
	local funs = {...}
	return function(...)
		local arg = {...}
		for _,f in ipairs(funs) do
			arg = {f(unpack(arg))}
		end
		return unpack(arg)
	end
end

array = array or {}

function array.find(t,v)
	for i, val in ipairs(t) do
		if val == v then
			return i
		end
	end
end

--string number unless already marked in location 
local _ROOTINDEX, _METATABLEINDEX = '__rootnodeindex','__metatableindex'

local function isatom(k)
	local ktp = type(k)
	return ktp == 'string' or ktp == 'number'
end
local function isref(k)
	local ktp = type(k)
	return ktp == 'table' or ktp == 'function'
end

function tree.markref(root, mark, refed)
	local rootindex = _ROOTINDEX
	mark = mark or {}
	refed = refed or {}	
	mark[root] = {rootindex}
	
	local layer = {root}
	
	while next(layer) ~= nil do
		local nextlayer = {}
		for _, t in ipairs(layer) do
			for k, v in pairs(t) do
				assert(isatom(k))
				if isref(v) then
					assert(v[1] ~= rootindex) 
					local m = mark[v]
					if m then
						refed[v] = m
					else
						local vloc = {unpack(mark[t])}
						table.insert(vloc,mark[k] or k)
						mark[v] = vloc
						table.insert(nextlayer,v)
					end
				end
			end
		end
		layer = nextlayer
	end
	mark[root] = nil
	return mark,refed
end

function tree.breakref(root, mark, refed)
	local rootindex,metaindex = _ROOTINDEX,_METATABLEINDEX
	mark[root] = {rootindex}
	refed = refed or mark
	
	local function getref(t,k,v)
		local vloc = refed[v]
		if vloc then				
			if vloc[#vloc] == k then
				local rloc = mark[t]				
				if not rloc then error('unsolved ref:',unpack(vloc)) end
				
				if #rloc + 1 == #vloc then
					for i = 2, #rloc do
						if vloc[i] ~= rloc[i] then return vloc end
					end
					return
				end
			end
			return vloc
		end
	end
	
	local function docopy(l,t,k,v)
		k = mark[k] or k
		assert(isatom(k))
		local vtp = type(v)
		if vtp == 'table' or vtp == 'function' then
			local vloc = getref(t,k,v)
			if vloc then
				v = vloc				
			else
				assert(vtp=='table')
				local newt, mt = {}, getmetatable(v)
				if mt then newt[metaindex] = mark[mt] end
				l[k] = newt
				return newt,v
			end
		end
		
		l[k] = v
	end
	
	local ret = {}
	tree.depthfirsteach(docopy,ret,root)
	return ret
end

local function ref2t(root,loc)
	for i=2, #loc do
		root = root[loc[i]]
		assert(root)
	end
	return root
end

function tree.linkref(mutable, const)
	local rootindex,metaindex = _ROOTINDEX,_METATABLEINDEX
	if const then 
		setmetatable(mutable,{__index = const}) 
	end

	local function l2t(k,t)
		if type(t)=='table' then 
			if t[1] == rootindex then			
				t = ref2t(mutable, t)
			elseif t[metaindex] then
				setmetatable(t,ref2t(mutable, t[metaindex]))
				t[metaindex] = nil
			end
		end
		return k,t
	end 
	
	tree.replace(mutable,l2t)
	return mutable
end

function tree.refedtostring(mutable,const)
	const = const or {}
	local mark = tree.markref(const)
	local ref = {}
	tree.markref(mutable,mark,ref)
	local data = tree.breakref(mutable,mark,ref)
	return tree.tostring(data)
end

function tree.refedfromstring(s,const,env)
	const = const or {}
	local t = tree.fromstring(s,env)
	return tree.linkref(t,const)
end

return tree

-- close do
end
