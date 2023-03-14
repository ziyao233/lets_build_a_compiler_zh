local io		= require "io";
local string		= require "string";
local math		= require "math";

local look = '';		-- 向前看字符

local table = {};

--[[ 从输入读取新的字符 ]]
local function getChar()
	look = io.read(1);
end

--[[ 报告期望的内容 ]]
local function expected(s)
	error(s .. " expected");
end

--[[ 匹配一个特定的字符 ]]
local function match(c)
	if look == c
	then
		getChar();
	else
		expected(c)
	end
end

--[[ 识别并跳到新的一行 ]]
local function newLine()
    if look == '\r'
    then
        getChar();
    end
    if look == '\n'
    then
        getChar();
    end
end

--[[ 输出一个制表符和字符串 ]]
local function emit(s)
	io.write("\t" .. s);
end

--[[ 输出制表符和指定的字符串，然后换行]]
local function emitLine(s)
	emit(s .. "\n");
end

--[[
--	识别是否是字母
--	string.match() 匹配一个字符模式，其中 %a 模式仅匹配大小写字符，如果
--	匹配失败则返回 nil。Lua 中 nil 和 false 都作为逻辑假处理
--]]
local function isAlpha(c)
	return string.match(c,"%a");
end

--[[ 识别是否是数字。相对的，%d 能够匹配一位数字 ]]
local function isDigit(c)
	return string.match(c,"%d");
end

--[[ 识别是否是字母数字字符 ]]
local function isAlNum(c)
    return isAlpha(c) or isDigit(c)
end

--[[ 识别是否是加法符号 ]]
local function isAddop(c)
	return c == '+' or c== '-';
end

--[[ 识别是否是空白字符 ]]
local function isWhite(c)
    return c == ' ' or c == '\t' or c == '\n';
end

--[[ 跳过前导空白字符 ]]
local function skipWhite(c)
    while isWhite(look)
    do
        getChar();
    end
end

--[[ 读取一个标识符 ]]
local function getName()
	if not isAlpha(look)
	then
		expected("name");
	end
	local name = look;
	getChar();
	return name;
end

--[[ 获取一个数字 ]]
local function getNum()
    local value = 0;
    if not isDigit(look)
    then
        expected("integer");
    end
    while isDigit(look)
    do
        value = 10 * value + string.byte(look) - string.byte('0');
        getChar();
    end

    return value;
end

local expression;

--[[ 解析并翻译一个数学因子 ]]
local function factor()
    local ret;
    if look == '('
    then
        match('(');
        ret = expression();
        match(')');
    elseif isAlpha(look)
    then
        ret = table[getName()];
    else
        ret = getNum();
    end

    return ret;
end

--[[ 解析并翻译一个数学项 ]]
local function term()
	local value = factor();
	while look == '*' or look == '/'
	do
		if look == '*'
		then
            match('*');
			value = value * factor();
		elseif look == '/'
		then
			match('/');
            value = value / factor();
		end
	end

    return value;
end


--[[ 解析并翻译一个数学表达式 ]]
function expression()
    local value = 0;
    if isAddop(look)
    then
        value = 0;
    else
        value = term();
    end
	while isAddop(look)
    do
        if look == '+'
        then
            match('+');
            value = value + term();
        elseif look == '-'
        then
            match('-');
            value = value - term();
        end
    end

    return value;
end

--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name = getName();
    match('=');
    table[name] = expression();
end

--[[ 初始化变量表 ]]
local function initTable()
    for i = string.byte('A'), string.byte('Z') do
        table[string.char(i)] = 0;
    end
end

--[[ 初始化 ]]
local function init()
    initTable();
	getChar();
end

--[[ 输入流程 ]]
local function input()
    match('?');
    table[getName()] = io.read();
end

--[[ 输出流程 ]]
local function output()
    match('!');
    io.write(table[getName()] .. '\n');
end

--[[ 主函数 ]]
init();
repeat
    if look == '?'
    then
        input();
    elseif look == '!'
    then
        output();
    else
        assignment();
    end
    newLine();
until(look == '.')