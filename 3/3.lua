local io		= require "io";
local string		= require "string";
local math		= require "math";

local look = '';		-- 向前看字符

--[[ 从输入读取新的字符 ]]
local function getChar()
	look = io.read(1);
end

--[[ 报告期望的内容 ]]
local function expected(s)
	error(s .. " expected");
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
    return c == ' ' or c == '\t';
end

--[[ 跳过前导空白字符 ]]
local function skipWhite(c)
    while isWhite(look)
    do
        getChar();
    end
end


--[[ 匹配一个特定的字符 ]]
local function match(c)
	if look ~= c
	then
		expected(c);
	else
        getChar();
        skipWhite();
	end
end

--[[ 读取一个标识符 ]]
local function getName()
    local token = '';
	if not isAlpha(look)
	then
		expected("name");
	end
	while isAlNum(look)
    do
        token = token .. look;
        getChar();
    end
    skipWhite();
    return token;
end

--[[ 读取一个数字 ]]
local function getNum()
    local value = '';
	if not isDigit(look)
	then
		expected("integer");
	end
	while isDigit(look)
    do
        value = value .. look;
        getChar();
    end
    skipWhite();
    return value;
end

--[[ 输出一个制表符和字符串 ]]
local function emit(s)
	io.write("\t" .. s);
end

--[[ 输出制表符和指定的字符串，然后换行]]
local function emitLine(s)
	emit(s .. "\n");
end

--[[ 解析并翻译一个标识符 ]]
local function ident()
    local name;
    name = getName();
    if look == '('
    then 
        match('(');
        match(')');
        emitLine('callq ' .. name);
    else
        emitLine('movq ' .. name ..'(%rip),	%rax');
    end
end

local expression;

--[[ 解析并翻译一个数学因子 ]]
local function factor()
    if look == '('
    then
        match('(');
        expression();
        match(')');
    elseif isAlpha(look)
    then
        ident();
    else
        emitLine("movq	$" .. getNum() .. ",	%rax");
    end
end

--[[ 解析并翻译一个乘法 ]]
local function multiply()
	match('*');
	factor();
	emitLine('imulq (%rsp)');
end

--[[ 解析并翻译一个除法 ]]
local function divide()
	match('/');
	factor();
	emitLine("xchgq	(%rsp),	%rax");
	emitLine('cqto');
	emitLine('idivq (%rsp)');
end

--[[ 解析并翻译一个数学表达式中的项 ]]
local function term()
	factor();
	while look == '*' or look == '/'
	do
		emitLine('pushq %rax');
		if look == '*'
		then
			multiply();
		elseif look == '/'
		then
			divide();
		end
		emitLine("addq $8,	%rsp")
	end
end

--[[ 解析并翻译一个加法 ]]
local function add()
	match('+');
	term();
	emitLine('addq (%rsp), %rax');
end

--[[ 解析并翻译一个减法 ]]
local function subtract()
	match('-');
	term();
	emitLine('subq (%rsp), %rax');
	emitLine('negq %rax');
end

--[[ 解析并翻译一个数学表达式 ]]
function expression()
	if isAddop(look)
	then
		emitLine('xorq %rax, %rax');
	else
		term();
	end
	while isAddop(look)
	do
		emitLine('pushq %rax');
		if look == '+'
		then
			add();
		elseif look == '-'
		then
			subtract()
		end
		emitLine("addq	$8,	%rsp");
	end
end

--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name;
    name = getName();
    match('=');
    expression();
    emitLine('leaq ' .. name .. '(%rip), %rbx');
    emitLine('movq %rax, (%rbx)');
    -- emitLine('movq %rax, (' .. name .. ')');
end

--[[ 初始化 ]]
local function init()
	getChar();
	skipWhite();
end

-- 主程序从这里开始

init();
assignment();
if look ~= '\n'
then
	expected('NewLine');
end
