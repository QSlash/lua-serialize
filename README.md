# lua-serialize
serialize support 4 functions:

save(src,[import=nil,loader=error])
import is returned from import function

load(savestr,[import=nil,saver=error])


import(table,[filt=flit]) filter(k,v,root) return true if the value shall be refed


flit(k,v,t)--default by import import默认过滤函数


import{1,A=96,[3.14]='PI',[true]='TURE'} 等效于 import{1,A=96,[true]='TURE'}
import{1,A=96,[3.14]='PI',[true]='TURE'} equal to import{1,A=96,[true]='TURE'}

	function flit(k,v,t)
		local kt,vt=type(k),type(v)
		return ( (kt=='number' and isint(k)) or kt=='string' or kt=='boolean') and vt~='number' and vt~='boolean'
	end

this serialize lib is compatible with lua5.14 lua5.32 and luajit2.0
support cycle, not support functions or userdata directly, use import and saver/loader for to catch function,userdata and coroutine.
能够处理环形引用, 不能直接function closure thread userdata，使用import导入引用表，或者通过saver函数转化成直接支持的类型，再通过loader函数返回


example:


  	local slz=require'serialize'
  
--basic usage support cycle

--基本用法 可以处理 boolen number nil table 类型。环形引用

	local tt={1,2,3,4,str='Hello'}
	tt.root=tt --cycle
	local str=slz.save(tt)
	local tc=slz.load(str)
	print(str,tc.str,unpack(tc))


通过import函数使用引用方式存储函数
  
	local mt={__index=function(t,k)return 'INDEX:'..k end}
	local lib={mt,Str='Language', notused='notused'}
	tt.strref=lib.Str
	setmetatable(tt,mt)

	str=slz.save(tt,slz.import(lib))
load时使用的表只需要提供被tt引用的成员即可(mt,Str), 值不必相同，可以用这种办法来使旧数据兼容新程序
	tc=slz.load(str,{mt,Str='语言'})
	print(str,tc.strref,tc.NotExist)
  
  
默认过滤函数：
	function flit(k,v,t)
		local kt,vt=type(k),type(v)
		return ( (kt=='number' and isint(k)) or kt=='string' or kt=='boolean') and vt~='number' and vt~='boolean'
	end
  
import{1,A=96,[3.14]='PI',[true]='TURE'} 等效于 import{1,A=96,[true]='TURE'}
import{1,A=96,[3.14]='PI',[true]='TURE'} equal to import{1,A=96,[true]='TURE'}
	
给入flit函数使序列化时不引用lib.Str 
use flit by avoid referencing lib.Str
	str=slz.save(tt,slz.import(lib,function(k,v,t)return slz.flit(k,v,t) and v~=lib.Str end))
	tc=slz.load(str,{mt,Str='String Three Not import'})
	print(tc.strref)
	
如果要存储的值类型是function closure thread userdata 又不在import列表里 会调用saver函数 默认saver为error 直接报错
if a is not a function closure thread or userdata,and not imported, saver willbe called，the default saver function is error.
	local function saveprint(fun)
		if fun==print then return 'print' end
	end

	local function loadprint(name)
		if name=='print' then return print end
	end
	
	tt={p=print}
	str=slz.save(tt,nil,saveprint)
	tc=slz.load(str,nil,loadprint)
	tc.p'printing:Hello Word'
