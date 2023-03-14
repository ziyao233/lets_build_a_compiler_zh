# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第三章： 更多的表达式

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译
> 本文由泠妄在梓瑶的基础上编写代码

## 简介

在上一章节，我们研究了用于解析和翻译一个常见数学表达式的技术。最后得到
了一个可以处理任意复杂表达式的简单编译器。当然，它还有着以下的限制：

- 只能处理作为因子的数字，而不能处理变量
- 所有的因子都被限制为单个字符

在这一章节中，我们将尝试克服掉这些限制。同时，我们也会在现在的编译器中
添加对赋值语句和函数调用的支持。不过要注意的是，第二个限制是为了简化实
现以更集中注意力于基本概念而添加的。你马上就会看到，这是一个很容易就能
被突破的限制，所以请不要太在意它。在我们有足够的信心去去除它之前，我们
将会继续使用这个技巧。

## 变量

大多数我们在现实中看到的表达式都会涉及到变量，例如：

	$ b * b + 4 * a * c $

一个好的编译器一定能处理它们。

好，我们能很容易地解决这一点。

记住，在我们目前的编译器中，只有两种因子：整数常量和括号内的表达式。
用 BNF 可以描述如下：

```BNF
<factor> ::= <number> | (<expression>)
```

`|` 代表‘或’，意思是这两种形式都是一个合法的因子。同样要记住，这两种形
式可以不费吹灰之力区别开：如果发现最左边是 `(` 就是是一种情况，而是一
个数字就是另一种情况。

可能你听到的时候已经不会惊讶了，变量就只是另一种因子。所以我们可以将
BNF 表达式扩展如下：

```BNF
<factor> ::= <number> | (<expression>) | <variable>
```

这里也一样没有歧义： 如果最左端的字符是一个字母，那这就是一个变量；如
果是一个数位，当然这就是数字。回想一下我们翻译数字的时候，我们只是让代
码加载向 rax 一个作为立即数的数字。现在我们可以做同样的事，只不过我们
读取一个变量。

需要注意的是，为了适应操作系统动态加载的要求，汇编代码通常需要写成地址
无关形式，换句话说一切地址都是相对于 rip 寄存器的偏移量。

在 x86-64 汇编中可以这样加载一个全局变量：

```ASM
movq name(%rip), %rax
```

而name则是变量的名称。
了解这点之后，让我们把 `factor` 函数修改为这样：


```lua

--[[解析并翻译一个数学因子]]
local function factor()
    if look == '('
    then
        match('(');
        expression();
        match(')');
    elseif isAlpha(look)
    then
        emitLn('movq ' .. getName() .. '(%rip),%rax');
    else
        emitLn('movq $' .. getNum() .. ',%rax')
    end
end

```

我之前提过拓展这个编译器由于自顶向下的编程风格而非常容易。此处这个特点
也鲜明地表现了出来。这一次只花费了我们额外的三行代码。同时我们注意到，
`if-else-else` 的代码结构与 BNF 语法非常相似。

好的，让我们编译并尝试下新的编译器。挺容易的，不是吗？

## 函数

大多数的语言同样支持另一种因子：函数调用。现在处理函数调用对于我们来说
还是太早了，因为我们还没有解决传递参数的问题。同时，一个真正的语言会有
对应的机制来支持多种类型，而其中一种就是函数。我们同样也还没有做那么多
。但是，由于下面几个原因，我依然想在现在来处理函数。首先，这会让我们的
编译器更像它最终的样子；其次，这也会带来一个值得一谈的新问题。

直到现在，我们所能写的编译器叫做“预测分析器”，意味着在任何时候，我们都
能通过查看向前看字符来确定接下来要做的事情。但是当增加对函数的支持之后
，这点却不再成立了。每种语言都有一些命名规则告诉我们一个合法的标识符应
该是什么样子。现在我们只是简单的认为标识符就是一个 'a' 到 'z' 的英文字
符。问题是，这样我们的函数名和变量名有着相同的命名规则，那我们怎么知道
它是变量还是函数呢？一种方式是要求标识符都需要在使用之前被声明，这是
Pascal 语言采用的方式。另一种是要求在函数之后必须跟随一个可以为空的参
数表，C语言采用了这种方式。

由于我们还没有定义类型的机制，我们现在使用 C 语言的规则。同样，由于我
们也没有任何的机制来处理参数，我们只能处理空参数表。所以我们的函数调用
将会有以下这样的形式：

```BNF
x()
```

由于我们现在还没有处理参数表，现在我们除了调用函数以外什么都不用做，这
样只需要执行一个 `call`（而非 `movq`）指令。

现在在 `factor` 中 `if isAlpha` 分支就有两种可能性了，让我们在一个单独
的函数中处理它们吧。把当前版本的 `factor` 函数修改为：

```lua

--[[解析并翻译一个数学因子]]
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
		emitLn('movq $' .. getNum() .. ',%rax')
	end
end

```

并在它之前插入一个新的函数：

```lua

--[[解析并翻译一个标识符]]
local function ident()
	local name;
	name = getName();
	if look == '('
	then
		match('(');
		match(')');
		emitLn('call ' .. name);
	else
		emitLn('movq ' .. name ..', %qax');
	end
end

```

好了，我们来测试一下这个新的版本。它成功编译所有合法的表达式，指出了错
误的语法了吗？

最重要的事是，虽然我们写的代码不再是一个预测分析器了，所采用的递归下降
的方法也几乎没有给我们增加复杂性。在现在当我们的 `factor` 函数发现一个
标识符（字母）的时候，它并不知道这是一个变量名还是一个函数，但是它也并
不关心这点，而只是把标识符传给 `ident` 函数并让那个函数来处理这一切。
而 `ident` 函数反过来，则只是简单的吃掉了标识符再多读一个字符来决定它
正在处理的是函数还是变量。

请记住这个方案。这是一个很强大的思路，可以应用在每一种你看起因为二义性
而需要向前看的情况。即使你需要向前查看好几个标识，这个办法也有效。

## 关于错误处理的更多内容

既然我们在谈论编程的哲学，就必须要谈论到另一个重要的话题：错误处理。注
意虽然我们的编译器可以处理（几乎）所有的我们能给出的异常表达式，并给出
有意义的信息，我们并没有进行在这一点上花费很多的精力来实现。事实上，在
整个编译器中（从 `ident` 到 `expression` 函数），只有两次调用了错误处
理例程 `expected` 。尽管这并不是必须的....因为如果你再看看 `term` 和
`expression` 函数就会发现这个分支永远无法被执行。保险起见我在之前的程
序中加上了它们，但它们目前没用了。现在删了它们怎么样？

那么，我们是如何几乎毫不费力的得到对错误处理这种不错的结果的呢？这是因
为小心地避免直接调用 `getChar` 来读取一个字符，而是依靠在 `getName` 、
`getNun` 和 `match` 中的错误处理代码来进行所有的错误检查。精明的读者同
样会注意到一些对 `match` 的调用同样是非必须的（例如在 `add` 和
`subtract` 中的），因为当我们遇到的它们时已经知道那是什么了。但是这给
我们的程序增添了一些相似性，而且永远使用 `match` 而非 `getChar`
是一个很好的实践。

我在上面提到了“几乎”，这是因为在某些情况下，我们的错误处理依然不尽人意
。现在我们并没有告诉我们的编译器行末是什么样的，也没有告诉怎么处理行中
的空白字符。所以一个空白字符（或者任何无法被识别的字符）都会导致编译器
终止或者忽略之。

当然可以说在现在这是一个合理的行为。但是在一个“真正”的编译器中，在我们
正在处理的语句之后通常还有下一条语句要处理，这样任何未被在当前表达式处
理的字符都会被丢弃或作为下一个语句的一部分。

但，这也是一个很简单就能修复的问题，尽管这种修复方式只是临时的。我们所
需要做的就是强制表达式需要以一行的结束结尾，也就是一个换行。

要更清楚地理解我的话，请输入下面这一行：

```
1+2 <space> 3+4
```

看到这个空白字符是被当作一个终止符了吗？现在，让我们添加几行

```lua
if look~='\n'
then
	expect('Newline');
end
```

来在主程序中在调用 `expression` 之后正确地指出错误，就这读取了全部余留
在输入流中的内容。

同样的，重新运行这个程序并确认它执行正确。

## 赋值语句

好的，现在我们已经有一个运行的不错的编译器了。我想要指出我们只写了
234 行可执行的代码。考虑到我们并没有很努力的去尝试缩减源代码的长度，而
只是遵循了 KISS 原则，这已经是个很喜人的结果了。

当然，只是能编译表达式却之后什么都不去做并不够棒。表达式通常（虽然并不
总是）以如下的形式出现在赋值语句中：

```BNF
<Ident> = <Expression>
```

我们距离能编译一个赋值语句只有一步之遥了，让我们来完成吧。只需要在
`expression` 函数之后加上一个新的函数：

```lua
--[[解析并翻译一个赋值语句]]
local function assignment()
	local name;
	name = getName();
	match('=');
	expression();
	emitLn('leaq (' .. name .. '), %rbx');
	emitLn('movl %rax, (%rbx)');			XXX
	-- emitLn('movq %rax, (' .. name .. ')');
end

```

注意到我们的代码和 BNF 相当一致。同时注意到错误处理已经被 `getName` 和
`match` 不费吹灰之力解决了。

现在将主代码块中对 `expression` 的调用改为对 `assignment` 的调用，这样
一切就完成了。

大功告成！我们现在确实能编译出一个赋值语句了。如果整个语言中只有赋值语
句，我们只需要把它放进一个循环里就有一个完整的编译器了。

啊，当然当然不止有这一种语句，还有一些例如控制语句（分支和循环），变量
声明等等。但是别灰心。我们一直处理到现在的算术表达式是其中最具挑战性的
。和我们正在做的事情比起来，控制语句很简单。我将会在第 15 章讲述它们。
同时只要我们遵循 KISS 原则，所有其它的语句都会一步步完成的。

## 多字符的标识符

在这个系列中，我一直小心地限制我们处理的所有词法单元都是单字符的，同时
保证扩展到多字符时也不会太难。我不知道你是否会相信这一点，但有一些怀疑
也很正常。我在之后的章节中将会继续使用这种方法来避免复杂性，但是为了支
持我的说法，我也会给你展示扩展到多字符有多简单。同时，我们也会添加对嵌
入其中的空白字符的支持。

在你进行如下的更改之前，请将当前版本的编译器存储到另一个文件中，我将会
在下一章继续使用它，继续在单字符版本的基础上进行更改。

大多数的编译器会用一个叫词法解析器的单独模块来分离处理输入流。这个扫描
器会把字符一个一个的读入，并在一个流输出为一些分离的单元（叫做 token，
即词法单元）。或许将来我们也需要要做类似的事，但现在并不必要。我们只需
要在 `getName` 和 `getNum` 中做一些微小的内部调整就能处理多字符的标识
符。

通常而言，标识符的第一个字符必须是一个字母，但是其余的部分可以是字符或
数字。为了处理它们，我们需要另一个识别函数：

```lua

--[[识别一个字母或数字]]
local function isAlNum(c)
	return isAlpha(c) or isDigit(c)
end

```

把这个函数放到你的编译器之中，我把它放在了 `isDigit` 函数之后。在时候
不妨把这个函数也永久的放到你的程序中。

现在，让我们修改 `getName` 函数来返回一个字符串而非单个字符：

```lua

--[[ 读取一个标识符 ]]
local function getName()
	local token;
	token = '';
	if not isAlpha(look)
	then
		expected("name");
	end
	while isAlNum(look)
	do
		token = token .. look;
		getChar();
	end
	return token;
end

```

同样的，让我们修改一下 `getNum` 函数：

```lua

--[[ 读取一个数字 ]]
local function getNum()
	local value;
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
	return value;
end

```

很出人意料的是，我们对编译器只需做出这些修改！保存这些修改，并重新运行
进行测试。**现在**你相信我们可以只简单的更改来做到这些了吗？

## 空白字符

在我们将这个编译器告一段落之前，让我们来解决空白字符的问题。现在，编译
器遇到一个嵌入在输入流任何位置的空白字符都将会拒绝它（或是直接终止）。
这很不友好。因此让我们来解决这个限制从而使这个程序变得更“人性化”一些。

处理空白字符的关键，是定义一个关于解析器将会如何处理输入流的简单规则，
并将它应用到各处。截至现在，因为我们不允许空白字符的出现，向前看字符
`look` 中一定保存着下一个有意义字符，这样我们立刻就可以检查它。而我们
的设计是完全基于这一原则的。

这个规则在我听起来很棒，因此我们将会继续应用它。这意味着我们将会跳过输
入流中的每个空白字符，并将下一个非空白的字符放入向前看字符中。幸运的是
，我们小心地在几乎每个处理输入的地方都使用了 `getName`、`getNum` 和
`match` 函数，我们只需要修改这些函数（和 `init` 函数）即可。

当然，我们需要另一个识别空白字符的函数：

```lua

--[[识别一个空白字符]]
local function isWhite(c)
	return c == ' ' or c == '\t';
end

```

我们同样需要一个把所有空白字符吃掉的函数（直到遇到一个非空白的字符）：

```lua

--[[跳过前导空白字符]]
local function skipWhite(c)
	while isWhite(look)
	do
		getChar();
	end
end

```

现在，让我们在 `match`、`getName` 和 `getNum` 中调用 `skipWhite` 函数
。代码如下：

```lua 

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
	local token;
	token = '';
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
    local value;
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
    skipWhite();
    return value;
end
```

（需要注意我把 `match` 函数修改了一下，当然这不会改变它的功能。）

最后，我们需要在 `init` 函数中去掉前导空白来正常初始化程序：

```lua

--[[ 初始化 ]]
local function init()
	getChar();
	skipWhite();
end

```

应用上面的更改然后重新编译程序。你可能会注意到需要把 `match` 函数移动
到 `skipWhite` 函数之后来避免报错。测试这个程序并确保它工作正常。


鉴于我们在这一章中做了不少的更改，我将会在下面放上整个编译器的代码。

```lua
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

```

现在我们拥有一个拥有完整特性的，能处理一行代码的“编译器”了。把它保存在
一个安全的地方吧。接下来，虽然我们仍然要谈一谈表达式，但我们将会转入一
个新的主题。在下一章，我想要谈一谈编译器的反面：解释器，并展示一下当我
们改变程序的行为时需要对它进行怎样的更改。哪怕你并不关心解释器，在那里
学到的知识也会有利于我们接下来的学习。下次见~

> 版权声明
> Copyright (c) 1988 Jack W. Crenshaw. 保留一切权利。
> 本文由泠妄翻译，梓瑶校订
> 本文由泠妄在梓瑶的基础上编写代码
