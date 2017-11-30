# lua-serialize
persionnal practice including sample lib such as serialize

serialize has three function:
save(src,[import,loader])
load(savestr[import,create])
import(table,filter)

this serialize lib compatible with lua5.14 lua5.32 and luajit2.0

support number boolen string table serialize directly, table can be value, key or metatable:
t={}
t[t]=t
setmetatable(t,{})
ring-reference is handled well.
for userdata, or function, it canbe serialized by import or loadr/saver function
