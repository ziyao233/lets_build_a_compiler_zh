# 动手构建一个编译器！
Jack W. Crenshaw, Ph.D.
24 July 1988

# 第三章： 更多的表达式
>版权许可
>Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
>本文由泠妄翻译
>本文由泠妄在梓瑶的基础上编写代码

## 简介

在上一章节，我们研究了用于解析和翻译一个常见数学表达式的技术。我们最终得到了一个可以处理任意复杂表达式简单的编译器。当然，它还有着以下的限制：
- 只能有数学因子，而不能有变量
- 所有的因子都被限制在了处理单个字符

在这一章节中，我们将尝试解决这些限制。同时，我们也会在目前的编译器中添加赋值语句和函数调用的支持。不过要注意的是，第二个限制是我们自己为了让我们生活更简单和更集中注意于基本概念而添加的。正如你之后会看到的那样，这是一个很容易就能被解决的限制，所以请不要太在意它。直到我们有足够的信心去去除它之前，我们将会继续使用这个技巧。

## 变量
大多数我们在现实中看到的表达式都会涉及到变量，例如：
$b * b + 4 * a * c$
一个不能处理它们的编译器是不够好的。
幸好，我们能很轻易的解决这一点。

需要记住，在我们目前的编译器中，只有两种因子是被允许的：整数常量和括号内的表达式。在BNF中可以描述如下：
```BNF
<factor> ::= <number> | (<expression>)
```
`|`代表‘或’，意思是这两种形式都是一个合法的因子。同样要记住的是，我们在区分哪种是哪种时并没有困难，因为我们可以发现最左边如果是`(`的是一种情况，而是一个数字的是另一种情况。

不出所料，变量就只是另一种因子。所以我们可以将BNF表达式扩展如下：
```BNF
<factor> ::= <number> | (<expression>) | <variable>
```

同样的，这里也没有歧义： 如果最左端的字符是一个字母字符，那我们便有一个变量；如果是一个数字字符，我们便有一个数字。回到我们翻译数字的时候，我们只是让代码加载一个数字，作为立即数，存入rax。现在我们可以做同样的事，只不过我们读取一个变量。
*（注：原来为68000的寄存器和相关内容，在此处已经换为了x86架构的相关内容）*
*(注2：此处使用AT&T汇编风格，AMD64 ARCH)*

需要注意的是，x86的汇编代码通常需要你将代码写成“地址无关代码”，即意味着一切都是需要与PC相关的。
在x86-64中，地址无关代码也可以写成与`%rip`有关的相对寻址，并让汇编器来生成。
于是加载一个全局变量在x86汇编中可以如下：
```ASM
movq name(%rip), %rax 
```
而name则是变量的名称。
知道了这点之后，让我们将当前`factor`函数的版本修改为：

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

我之前提到过由于这个编译器构建的方式，向其中进行拓展是非常容易地。你可以看到这一点在此处仍然成立。这一次只花费了我们额外的三行代码。同时我们注意到，`if-else-else`的结构与BNF语法非常相似。

好的，让我们编译并尝试下新版的编译器。这并不是很麻烦，不是吗？

## 函数

大多数的语言同样支持另一种因子：函数调用。现在处理函数调用对于我们来说还是太早了，因为我们还没有解决传递参数的问题。同时，一个真正的语言会有支持不止一种类型的机制，而其中一种类型就是函数类型。我们同样也还没有走那么远。
但是我依然由于以下几个原因想在现在来处理函数。首先，它让我们终于能将编译器包装的像其最终的形式；其次，它带来了一个我们还没怎么讨论过的新问题。

直到现在，我们所能写的编译器叫做“递归下降编译器”。这意味着在任何时候，我们都能通过看前瞻字符来确定接下来我们要做什么。但是当我们增加函数之后这点却并不成立。每个语言都有某种命名规则告诉我们什么是一个合法的标识符。现在我们只是简单的认为那是一个英文字符'a'到'z'。问题是，在现在我们的函数名和变量名有着相同的规则，那我们怎么知道它是变量还是函数呢？
一种方式是要求它们都需要在使用之前被声明，这是Pascal语言采用的方式。另一种是要求在函数之后一定要跟一段参数表（可以是空的），C语言采用了这种方式。

由于我们还没有定义类型的机制，让我们现在暂时使用C语言的规则。由于我们同样没有任何的机制来处理参数，我们只能处理空参数表。所以我们的函数调用将会有以下这种形式：
```BNF
x()
```
由于我们现在还没有处理参数表，现在我们除了调用函数以外什么都不用做，我们只需要发起一个`call`而非一个`movq`。

现在对于在`factor`中的`if isAlpha`分支有两种可能性，让我们在一个单独的函数中处理它们。
让我们把当前的`factor`版本修改为：

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

并在它之前插入新的程序：

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

好的，让我们编译并测试一下这个新的版本。它成功编译所有合法的表达式了吗？它成功的指出了错误的语法了吗？

最重要的事是，虽然我们不再拥有一个预测解析器，我们所采用的递归下降的方法几乎没有给我们增加复杂性。在现在当我们的`factor`函数发现一个标识符（字母）的时候，它并不知道这是一个变量名还是一个函数，但是它也并不关心这点。它只是单纯的把标识符传给`ident`函数并让那个函数来搞清楚。而`ident`函数反过来，则只是简单的隐藏了标识符并多读了一个字符来决定它正在处理的是哪种标识符。

请记住这个非常强大的概念，并将其应用在每一种你看起来需要向前看的模棱两可的情况。哪怕你需要向前查看好几个标识，这条原则依然成立。

## 关于错误处理的更多内容

既然我们在谈论哲学，那就必须要谈论到另一个重要的话题：错误处理。注意到虽然我们的编译器可以处理（几乎）所有的我们能给出的异常表达式，并给出有意义的信息，我们并没有进行在其上花费很多的精力来实现它。事实上，在整个编译器中（从`ident`到`expression`），只有两次调用了错误处理例程`expected`。虽然这并不是必须的，因为如果你再看看`term`和`expression`函数，这个分支永远无法到达。我为了保险在之前的程序中加上了它们，但它们目前不再被需要了。你为什么不现在删了它们呢？

那么我们是如何几乎毫不费力的得到这种不错的错误处理结果的呢？这是因为我小心地避免直接调用`getChar`来读取一个字符。相反，我依靠在`getName`、`getNun`和`match`来处理所有的错误检查。精明的读者同样会注意到一些对`match`的调用同样是非必须的（例如，在`add`和`subtract`）中的，因为当我们遇到的时候我们已经知道那个字符是什么了，但是这给我们的程序增添了一些相似性，而且永远使用`match`而非`gatChar`是一个很好的原则。

我在上面提到了“几乎”，这是因为在某些情况下，我们的错误处理依然不尽人意。现在我们并没有告诉我们的编译器行末是什么样的，也没有告诉怎么处理嵌入的空白字符。所以一个空白字符（或者任何不在可识别字符集里的字符）都会导致编译器终止，或者忽略无法识别的字符。

我们当然可以说在现在这是一个合理的行为。但是在一个“真正”的编译器中，通常在我们处理的语句之后还有另一个，这样任何未被视为当前表达式的字符都会被丢弃或作为下一个语句的一部分。

但，这也是一个很简单就能修复的事，尽管这个修复方式只是临时的。我们所需要做的就是断言表达式需要以一行的结束结尾，也就是一个回车。

要知道我在说什么，请输入下面这一行：
```
1+2 <space> 3+4
```
看到这个空白字符是怎么被当作一个终止符了嘛？现在，让我们添加一行
```lua
if look~='\n' then expect('Newline');
```
在主程序中来正确的指出错误，就在调用`expression`之后。这读取了任何余留在输入流中的内容。*（注：在此处直接将CR当作'\n'处理，而非原文中新定义一个常量）*
同样的，重新编译这个程序并确认它执行了应该要执行的东西。

## 赋值语句

好的，现在我们已经有一个运行的不错的编译器了。我想要指出我们只写了234行可执行的代码。*（注：Lua是一门解释执行的语言，不和原文一样考虑编译后的大小）*
考虑到我们并没有很努力的去尝试缩减源代码的长度，而只是遵循了KISS原则，这真的很令人惊讶。

当然，只是能编译表达式而之后不去做什么并不够棒。表达式通常（虽然不是总是）出现在赋值语句中，形式如下：
```BNF
<Ident> = <Expression>
```
我们距离能编译一个赋值语句只有一步之遥了，那就让我们来完成这最后一步吧。只需要在`expression`函数之后加上一个新的函数：

```lua

--[[解析并翻译一个赋值语句]]
local function assignment()
    local name;
    name = getName();
    match('=');
    expression();
    emitLn('leaq (' .. name .. '), %rbx');
    emitLn('movl %rax, (%rbx)');
    -- emitLn('movq %rax, (' .. name .. ')');
end

```

注意到我们的代码和BNF完全对应。同时注意到错误处理已经无痛的被`getName`和`match`解决。

现在将主函数中对`expression`的调用改为对`assignment`的调用。这就是我们全部所需要做的。

（脏话）！我们现在真的能编译出一个赋值语句了。如果赋值语句是整个语言中唯一的语句，我们只需要把它放进一个循环里，然后我们就有一个完整的编译器了。

好吧……当然这不是唯一的一种语句，还有一些比如控制语句（分支和循环），变量声明等等。但是别灰心。我们一直在处理的算术表达式是其中最具挑战性的。和我们所完成的比起来，控制语句很简单。我将会在第15章讲述它们。同时只要我们遵循KISS原则，那所有其它的语句都会被完成。

## 多字符的标识符

在这个系列中，我一直小心地限制我们所有处理的标识符都是单字符的，同时保证扩展到多字符时不会太难。我不知道你是否会相信我，但我不会因为你有一些怀疑而责怪你。我将会继续再之后的章节中使用这种方法来避免复杂性。但是我想给你展示再编译器中扩展出这一功能是多么简单来支持我的说法。同时，我们也会添加对嵌入其中的空白字符的支持。
在你进行如下的更改之前，请将当前版本的编译器存储到另一个文件中，我将会在下一章继续使用它，同时我们也会继续在单字符的版本上进行更改。

大多数的编译器会用一个叫词法扫描器的单独模块来分离处理输入流。这个扫描器会把字符一个一个的读入，并在一个流输出为一些分离的单元（叫做token）。或许将来我们也会想要做类似的事，但现在并不需要。我们只需要在`getName`和`getNum`中做一些微小的和内置的调整就能处理多字符的标识符。

通常而言，标识符的第一个字符必须是一个字母，但是其余的部分可以是字符或数字。为了处理它们，我们需要另一个识别函数：

```lua

--[[识别一个字母数字字符]]
local function isAlNum(c)
    return isAlpha(c) or isDigit(c)
end

```

把这个函数放到你的编译器之中，像我就把它放在了`isDigit`函数之后。在这做这件事的时候，不妨把这个函数也永久的放到你的程序中。

现在，让我们修改`getName`函数来返回一个字符串而非单个字符：

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

同样的，让我们修改一下`getNum`函数：

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

令人惊讶的是，这就是我们所有所需要对编译器做出的修改！*（注：由于Lua为动态类型语言，你并不需要在其它函数中修改变量类型为string。如果你是用的是和原文一样的非动态类型语言，请将`ident`和`assignment`函数中的`name`变量改为string（char[8])类型。原文中此处字符串长度不超过8，你可以自行决定。）*
保存这些改动，并重新编译进行测试。**现在**你相信我们可以只简单的更改来做到这些了吗？

## 空白字符

在我们将这个编译器告一段落之前，让我们来解决空白字符的问题。在现在，编译器遇到一个嵌入在输入流任何位置的空白字符都将会拒绝（或是直接终止）。这很不友好。因此，让我们来消除这个限制从而使这个程序变得更“人性化”一些。

处理空白字符的关键，是想出一个关于解析器将会如何处理输入流的简单的规则，并将它应用到各个地方。到现在为止，因为我们不允许空白字符的出现，在前瞻字符`look`中一定有着下一个可以让我们检测到的有意义的字符。而我们的设计是完全基于这一原则的。

这个规则在我听起来并没有什么问题，因此我们将会继续应用它。这意味着我们将会跳过输入流中的每个空白字符，并将下一个非空白的字符放入前瞻字符中。幸运的是，我们小心的在几乎每个处理输入的地方都使用了`getName`、`getNum`和`match`函数，我们只需要修改这些函数（和`init`函数）。

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

现在，让我们在`match`、`getName`和`getNum`中调用`skipWhite`函数。代码如下：

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

（需要注意我把`match`函数修改了一下，当然这不会改变它的功能。）

最后，我们需要在`init`函数中去掉前导空白来正常初始化程序：

```lua

--[[ 初始化 ]]
local function init()
    getChar();
    skipWhite();
end

```

应用上面的更改然后重新编译程序。你可能会注意到需要把`match`函数移动到`skipWhite`函数之后来避免报错。测试这个程序并确保它工作正常。


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

现在我们拥有一个拥有完整特性的，能处理一行代码的“编译器”。把它保存在一个安全的地方吧。
接下来，虽然我们仍然要谈一谈表达式，但我们将会转入一个新的主题。在下一章，我想要谈一谈编译器的反面：解释器，并展示一下当我们改变程序的行为时需要对它进行怎样的更改。哪怕你并不关心解释器，在那里学到的知识也会有利于我们接下来的学习。下次见~

>版权声明
>Copyright (c) 1988 Jack W. Crenshaw. 保留一切权利。
>本文由泠妄翻译
>本文由泠妄在梓瑶的基础上编写代码
