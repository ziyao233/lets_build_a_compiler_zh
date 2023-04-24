local io		= require "io";
local string		= require "string";
local math		= require "math";

local look = '';		-- 向前看字符
local lCount = 0;       -- Label计数

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

--[[ 将字符转为大写 ]]
local function upCase(c)
    return string.upper(c);
end

--[[判断给定值是否出现在数组中]]
local function isInArr(s, arr)
	for k,v in pairs(arr)
	do
		if s == v
		then
			return true;
		end
	end
	return false;
end

--[[ 跳过前导空白字符 ]]
local function skipWhite(c)
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

--[[ 输出指定的字符串，然后换行]]
local function writeLine(s)
    io.write(s .. "\n");
end

--[[生成一个唯一的标识符]]
local function newLabel()
    local label = 'L' .. string.format("%d",lCount);
    lCount = lCount + 1;
    return label
end

--[[输出一个标识符]]
local function postLabel(label)
    writeLine(label .. ':');
end

--[[ 识别是否是加法符号 ]]
local function isAddop(c)
	return c == '+' or c== '-';
end

--[[ 识别一个Orop ]]
local function isOrop(c)
	return c == '|' or c == '~';
end

--[[ 识别一个关系op ]]
local function isRelop(c)
	return c == '=' or c == '#' or c == '<' or c == '>';
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

--[[ 识别一个布尔变量 ]]
local function isBoolean(c)
    return upCase(c) == 'T' or upCase(c) == 'F';
end

--[[ 获取一个布尔变量 ]]
local function getBoolean()
    if not isBoolean(look)
    then
        expected("Boolean Literal");
    end
    local b = upCase(look) == 'T';
    getChar();
    return b;
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
        emitLine("movq	$" .. getNum() .. ",	%rax");
    end
end

--[[ 解析并翻译第一个数学因子 ]]
local function signedFactor()
	if look == '+'
	then
		getChar();
		if look == '-'
		then 
			getChar();
			if isDigit(look)
			then
				emitLine('movq $-' .. getNum() .. ', %rax');
			else
				factor();
				emitLine('negq %rax');
			end
		end
	else
		factor();
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

--[[ 解析并翻译一个数学项 ]]
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
	term();
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

--[[ 识别并翻译一个等于关系 ]]
local function equals()
	match('=');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('sete %rax');
end

--[[ 识别并翻译一个不等于关系 ]]
local function notEquals()
	match('#');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setne %rax');
end

--[[ 识别并翻译一个小于关系 ]]
local function less()
	match('<');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setl %rax');
end

--[[ 识别并翻译一个大于关系 ]]
local function greater()
	match('>');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setg %rax');
end

--[[ 解析并翻译一个关系 ]]
local function relation()
	expression();
	if isRelop(look)
	then
		emitLine('pushq %rax');
		if look == '='
		then
			equals();
		elseif look == '#'
		then
			notEquals();
		elseif look == '<'
		then
			less();
		elseif look == '>'
		then
			greater();
		end
		emitLine("addq	$8,	%rsp");
		emitLine('test %rax, %rax');
	end
end

--[[ 解析并翻译一个布尔因子 ]]
local function boolFactor()
	if isBoolean(look)
	then
		if getBoolean()
		then
			emitLine('movq $-1, %rax');
		else 
			emitLine('xorq %rax, %rax');
		end
	else
		relation();
	end
end

--[[ 解析并翻译一个带NOT的布尔因子 ]]
local function notFactor()
	if look == '!'
	then
		match('!');
		boolFactor();
		emitLine('xorq $-1, %rax');
	else
		boolFactor();
	end
end

--[[ 解析并翻译一个布尔项 ]]
local function boolTerm()
	notFactor();
	while look == '&'
	do
		emitLine('pushq %rax');
		match('&');
		notFactor();
		emitLine('andq (%rsp), %rax');
		emitLine("addq	$8,	%rsp");
	end
end

--[[ 识别并翻译一个或运算符 ]]
local function boolOr()
    match('|');
    boolTerm();
    emitLine('orq (%rsp), %rax');
	
end

--[[ 识别并翻译一个异或运算符 ]]
local function boolXor()
	match('~');
	boolTerm();
	emitLine('xorq (%rsp), %rax');
end

--[[ 识别并翻译一个布尔表达式 ]]
local function boolExpression()
	boolTerm();
	while isOrop(look)
	do
		emitLine('pushq %rax');
		if look == '|'
		then
			boolOr();
		elseif look == '~'
		then
			boolXor();
		end
		emitLine("addq	$8,	%rsp");
	end
end

local block;

--[[识别并翻译一个IF结构]]
local function doIf(L)
    match('i');
    boolExpression();
	local L1 = newLabel();
	local L2 = L1;
    emitLine('jz ' .. L1);
    block(L);
	if look == 'l'
	then
		match('l');
		L2 = newLabel();
		emitLine('jmp ' .. L2);
		postLabel(L1);
		block(L);
	end
    match('e');
    postLabel(L2);
end

--[[识别并翻译一个WHILE语句]]
local function doWhile()
	local L1, L2;
	match('w');
	L1 = newLabel();
	L2 = newLabel();
	postLabel(L1);
	boolExpression();
	emitLine('jz ' .. L2);
	block(L2);
	match('e');
	emitLine('jmp ' .. L1);
	postLabel(L2);
end

--[[识别并翻译一个LOOP语句]]
local function doLoop()
	match('p');
	local L1 = newLabel();
	local L2 = newLabel();
	postLabel(L1);
	block(L2);
	match('e');
	emitLine('jmp ' .. L);
	postLabel(L2);
end

--[[识别并翻译一个REPEAT语句]]
local function doRepeat()
	match('r');
	local L1 = newLabel();
	local L2 = newLabel();
	postLabel(L1);
	block(L2);
	match('u');
	boolExpression();
	emitLine('jz ' .. L1);
	postLabel(L2);
end

--[[解析并翻译一个FOR语句]]
local function doFor()
	match('f');
	local L1 = newLabel();
	local L2 = newLabel();
	local name = getName();
	match('=');
	expression();
	emitLine("deq %rax");
	emitLine("movq " .. name .. "(%rip), %rax");
	expression();
	emitLine("push %rax");
	postLabel(L1);
	emitLine("movq %rax, " .. name .. "(%rip)");
	emitLine("inc %rax");
	emitLine("movq " .. name .. "(%rip), %rax");
	emitLine("cmp %rax, (%rsp)");
	emitLine("jgt " .. L2);
	block();
	match('e');
	emitLine("jmp " .. L1);
	postLabel(L2);
	emitLine("addq %rsp, $8")
end

--[[解析并翻译一个DO语句]]
local function doDo()
	match('d');
	local L1 = newLabel();
	local L2 = newLabel();
	expression();
	postLabel(L1);
	emitLine("dec %rax");
	emitLine("push %rax");
	block(L2);
	emitLine("pop %rax");
	emitLine("cmp %rax, $0");
	emitLine("jgt " .. L1);
	emitLine("subq %rsp, $8");
	postLabel(L2);
	emitLine("addq %rsp, $8")
end

--[[解析并翻译一个BREAK语句]]
local function doBreak(L)
	match('b');
	if L ~= ''
	then
		emitLine('jmp ' .. L);
	else
		error('No loop to break from');
	end
end

--[[识别并翻译一个“其它”块]]
local function other()
    emitLine(getName());
end

--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name = getName();
    match('=');
    boolExpression();
	emitLine('movq ' .. name .. '(%rip), %rax');
end

local skip_keywords = {
	__mode="k, v",
	['e'] = 1,
	['l'] = 1,
	['u'] = 1
};

--[[识别并翻译一个语句块]]
function block(L)
    while not skip_keywords[look]
    do
		fin();
        if look == 'i'
        then
            doIf(L);
		elseif look == 'w'
		then
			doWhile();
		elseif look == 'p'
		then
			doLoop();
		elseif look == 'r'
		then
			doRepeat();
        elseif look == 'f'
		then
			doFor();
		elseif look == 'd'
		then
			doDo();
		elseif look == 'b'
		then
			doBreak(L);
        else
            assignment();
        end
		fin();
    end
end

--[[解析并翻译一个程序]]
local function doProgram()
    block('');
    if look ~= 'e'
    then
        expected('End');
    end
    emitLine('END');
end

--[[ 初始化 ]]
local function init()
	getChar();
end

-- 主程序从这里开始
init();
doProgram();
