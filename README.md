# lua-serialize
serialize support three function:
save(src,[import,loader])
load(savestr[import,saver])
import(table,filter)

this serialize lib is compatible with lua5.14 lua5.32 and luajit2.0
support cycle, not support functions or userdata directly, buy support import and saver/loader for user to catch function,userdata and coroutine.
import policy mark a value(table,string,function,userdata,coroutine) saved as a reference.And link the reference when loading, In the way how a COFF file import external symbols.
if the import policy cannot catch the elment, you can support the saver/loader function. saver trans a function,userdata or coroutine to a value(number string table) that canbe serialize directly, the loader function reover it:

check_equal(dat,loader(saver(dat)))
