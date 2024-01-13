local io     = require "io";
local string = require "string";
local math   = require "math";

--[[ 全局变量定义 ]]
local look   = ''; -- 向前看字符
local lCount = 0;  -- Label计数
local token;       -- 当前的Token
local value;       -- 当前Tkoen对应的字符串

local class;
local typ, sign;

--[[ 关键字定义 ]]
local keywords = {
	__mode = "k, v",
	['IF'] = 'i',
	['ELSE'] = 'l',
	['ENDIF'] = 'e',
	['END'] = 'e',
	['Ident'] = 'x',
	['PROGRAM'] = 'p'
};

--[[ 从输入读取新的字符 ]]
local function getChar()
	look = io.read(1);
end

--[[ 输出一个制表符和字符串 ]]
local function emit(s)
	io.write("\t" .. s);
end

--[[ 输出制表符和指定的字符串，然后换行]]
local function emitLine(s)
	emit(s .. "\n");
end

--[[ 输出指定的字符串，然后换行]]
local function writeLine(s)
	io.write(s .. "\n");
end

--[[ 报告期望的内容 ]]
local function expected(s)
	error(s .. " expected");
end

--[[ 将字符转为大写 ]]
local function upCase(c)
	return string.upper(c);
end

--[[判断给定值是否出现在数组中]]
local function isInArr(s, arr)
	for k, v in pairs(arr)
	do
		if s == v
		then
			return true;
		end
	end
	return false;
end

--[[
--	识别是否是字母
--	string.match() 匹配一个字符模式，其中 %a 模式仅匹配大小写字符，如果
--	匹配失败则返回 nil。Lua 中 nil 和 false 都作为逻辑假处理
--]]
local function isAlpha(c)
	return string.match(c, "%a");
end

--[[ 识别是否是数字。相对的，%d 能够匹配一位数字 ]]
local function isDigit(c)
	return string.match(c, "%d");
end

--[[ 识别是否是字母数字字符 ]]
local function isAlNum(c)
	return isAlpha(c) or isDigit(c)
end

--[[ 识别是否是空白字符 ]]
local function isWhite(c)
	return c == ' ' or c == '\t';
end

--[[ 识别是否是运算符 ]]
local function isOp(c)
	return isInArr(c, { '+', '-', '*', '/', '<', '>', ':', '=' });
end

--[[ 识别是否是加法符号 ]]
local function isAddop(c)
	return c == '+' or c == '-';
end

--[[ 识别是否是乘法符号 ]]
local function isMulop(c)
	return c == '*' or c == '/';
end

--[[ 跳过前导空白字符 ]]
local function skipWhite()
	while isWhite(look)
	do
		getChar();
	end
end

--[[ 跳过CRLF ]]
local function fin()
	if look == '\r'
	then
		getChar();
	end
	if look == '\n'
	then
		getChar();
	end
	skipWhite();
end

--[[ 匹配一个特定的字符 ]]
local function match(c)
	if look == c
	then
		getChar();
	else
		expected(c)
	end
	skipWhite();
end

--[[ 匹配一个特定的字符串 ]]
local function matchString(c)
	if value ~= c
	then
		expected(c)
	end
end

--[[ 读取一个标识符 ]]
local function getName()
	value = look;
	getChar();
	return value;
end

--[[ 读取一个数字 ]]
local function getNum()
	value = '';
	if not isDigit(look)
	then
		expected("integer");
	end
	while isDigit(look)
	do
		value = value .. look;
		getChar();
	end
	token = '#';
	skipWhite();
	return value;
end

--[[ 读取一个标识并扫描其是否为关键字 ]]
local function scan()
	getName();
	local k = keywords[value]
	if not k
	then
		token = 'x';
	else
		token = k;
	end
end

--[[生成一个唯一的标识符]]
local function newLabel()
	local label = 'L' .. string.format("%d", lCount);
	lCount = lCount + 1;
	return label
end

--[[输出一个标识符]]
local function postLabel(label)
	writeLine(label .. ':');
end

--[[处理一个函数声明]]
local function doFunc(name)
    match('(');
    match(')');
    match('{');
    match('}');
    if typ == ' '
    then
        typ = 'i';
    end
    writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' function '.. name);
end

--[[处理一个变量声明]]
local function doData(name)
    if typ == ' '
    then
        expected('Type declaration');
    end
    writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' data '.. name);
    while look == ','
    do
        match(',');
        name = getName();
        writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' data '.. name);
    end
    match(';');
end

--[[获取并存储一个class specifier]]
local function getClass()
    if isInArr(look, {'a', 'x', 's'})
    then
        class = look;
        getChar();
    else
        class = 'a';
    end
end

--[[获取一个type specifier]]
local function getType()
    typ = ''
    if look == 'u'
    then
        sign = 'u';
        typ = 'i';
        getChar();
    else
        sign = 's';
    end

    if isInArr(look, {'i', 'l', 'c'})
    then
        typ = look;
        getChar();
    end
end

--[[处理一个顶层声明]]
local function topDecl()
    local name = getName();
    if look == '('
    then
        doFunc(name);
    else
        doData(name);
    end
end

--[[ 初始化 ]]
local function init()
	lCount = 0;
	getChar();
end

-- 主程序从这里开始
init();
while not(look == io.EOF)
do
    getClass();
    getType();
    topDecl();
end
