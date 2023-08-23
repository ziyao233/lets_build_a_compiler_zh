local io     = require "io";
local string = require "string";
local math   = require "math";

--[[ 全局变量定义 ]]
local look   = ''; -- 向前看字符
local lCount = 0;  -- Label计数
local token;       -- 当前的Token
local value;       -- 当前Tkoen对应的字符串

--[[ 关键字定义 ]]
local keywords = {
	__mode = "k, v",
	['IF'] = 'i',
	['ELSE'] = 'l',
	['ENDIF'] = 'e',
	['END'] = 'e',
	['Ident'] = 'x'
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
	value = '';
	while look == '\r' or look == '\n'
	do
		fin();
	end
	if not isAlpha(look)
	then
		expected("name");
	end
	while isAlNum(look)
	do
		value = value .. upCase(look);
		getChar();
	end
	skipWhite();
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

--[[ 解析并翻译一个标识符 ]]
local function ident()
	getName();
	if look == '('
	then
		match('(');
		match(')');
		emitLine('callq ' .. value);
	else
		emitLine('movq ' .. value .. '(%rip),	%rax');
	end
end

local forward;
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
		getNum();
		emitLine("movq	$" .. value .. ",	%rax");
	end
end

--[[ 解析并翻译第一个数学因子 ]]
local function signedFactor()
	local sgn = (look == '-');
	if isAddop(look)
	then
		getChar();
		skipWhite();
	end
	factor();
	if sgn
	then
		emitLine('negq %rax');
	end
end

--[[ 识别并翻译一个乘法 ]]
local function multiply()
	match('*');
	factor();
	emitLine('imulq (%rsp)');
end

--[[ 识别并翻译一个除法 ]]
local function divide()
	match('/');
	factor();
	emitLine("xchgq	(%rsp),	%rax");
	emitLine('cqto');
	emitLine('idivq (%rsp)');
end

--[[ 完成数学项解析（由term和fistTerm调用） ]]
local function term1()
	while isMulop(look)
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

--[[ 解析并翻译一个数学项 ]]
local function term()
	factor();
	term1();
end

--[[ 解析并翻译一个可能有着前置符号的数学项 ]]
local function firstTerm()
	signedFactor();
	term1();
end

--[[ 识别并翻译一个加法 ]]
local function add()
	match('+');
	term();
	emitLine('addq (%rsp), %rax');
end

--[[ 识别并翻译一个减法 ]]
local function subtract()
	match('-');
	term();
	emitLine('subq (%rsp), %rax');
	emitLine('negq %rax');
end

--[[ 解析并翻译一个数学表达式 ]]
function expression()
	firstTerm();
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

--[[识别并翻译一个布尔表达式]]
--[[该函数并未被实现]]
local function condition()
	emitLine('<condition>');
end

local block;

--[[识别并翻译一个IF结构]]
local function doIf()
	condition();
	local L1 = newLabel();
	local L2 = L1;
	emitLine('jz ' .. L1);
	block();
	if token == 'l'
	then
		L2 = newLabel();
		emitLine('jmp ' .. L2);
		postLabel(L1);
		block();
	end
	postLabel(L2);
	matchString('ENDIF');
end

--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
	local name = value;
	match('=');
	expression();
	emitLine('movq ' .. name .. '(%rip), %rax');
end

local skip_keywords = {
	__mode = "k, v",
	['e'] = 1,
	['l'] = 1
};

--[[识别并翻译一个语句块]]
function block()
	scan();
	while not skip_keywords[token]
	do
		if token == 'i'
		then
			doIf();
		else
			assignment();
		end
		scan();
	end
end

--[[解析并翻译一个程序]]
local function doProgram()
	block();
	matchString('END');
	emitLine('END');
end

--[[ 初始化 ]]
local function init()
	lCount = 0;
	getChar();
end

-- 主程序从这里开始
init();
doProgram();
