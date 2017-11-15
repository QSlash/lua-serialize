local tree=require'treeserialize'
do
local a = {1,2,3}
local b = {t=1,a=a,b=a}
local sstr = tree.refedtostring(b)
print(sstr)
local bcopy = tree.refedfromstring(sstr)
print(bcopy.t,bcopy.a,bcopy.b)
for i,v in pairs(bcopy.a) do
	print(i,v)
end

end
