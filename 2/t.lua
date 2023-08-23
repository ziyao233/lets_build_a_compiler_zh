local io     = require "io";
local string = require "string";
local math   = require "math";

local look   = ''; -- 向前看字符

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

--[[ 读取一个数字 ]]
local function getNum()
	if not isDigit(look)
	then
		expected("integer");
	end
	local num = look;
	getChar();
	return num;
end

--[[ 输出一个制表符和字符串 ]]
local function emit(s)
	io.write("\t" .. s);
end

--[[ 输出制表符和指定的字符串，然后换行]]
local function emitLine(s)
	emit(s .. "\n");
end

--[[ 初始化 ]]
local function init()
	getChar();
end

-- 识别一个 addop（加号或者减号）
local function isAddop(c)
	return c == '+' or c == '-';
end

local expression;

local function factor()
	if look == '('
	then
		match('(');
		expression();
		match(')');
	else
		emitLine("movq	$" .. getNum() .. ",	%rax");
	end
end

local function multiply()
	match('*');
	factor();
	emitLine("imulq	(%rsp)");
end

local function divide()
	match('/');
	factor();
	emitLine("xchgq	(%rsp),	%rax");
	emitLine("cqto");
	emitLine("divq	(%rsp)");
end

local function term()
	factor();
	while look == '*' or look == '/'
	do
		emitLine("pushq	%rax");
		if look == '*'
		then
			multiply();
		elseif look == '/'
		then
			divide();
		else
			expected("mulop");
		end
		emitLine("addq	$8,	%rsp");
	end
end

local function add()
	match('+');
	term();
	emitLine("addq	(%rsp),	%rax");
end

local function substract()
	match('-');
	term();
	emitLine("subq	(%rsp),	%rax");
	emitLine("negq	%rax");
end

expression = function()
	if isAddop(look)
	then
		emitLine("xorq	%rax,	%rax"); -- 清零
	else
		term();
	end

	while isAddop(look)
	do
		emitLine("pushq	%rax");
		if look == '+'
		then
			add();
		elseif look == '-'
		then
			substract();
		else
			expected("Addop");
		end
		emitLine("addq	$8,	%rsp");
	end
end

-- 主程序从这里开始

init();
expression();
