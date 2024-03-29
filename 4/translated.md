# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第四章： 解释器

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译, 梓瑶校订
> 本文由泠妄在梓瑶基础上编写代码

## 简介

在这个系列的前三章中，我们学习了如何解析和编译数学表达式，并逐渐从只能处理包含单
个项和单个字符的“表达式”一步步做到能解析更一般的“表达式”。最终，我们得到了一个能
处理多字符的标识符，嵌入在代码中的空白字符，函数调用和完整的赋值语句的编译器。在
这次，我们将会再回顾一次之前所有讲到的东西，不过这次的目标是创造一个解释器而非生
成目标代码的编译器。

但是，既然这是一个编译器主题的系列文章，我们干嘛去管解释器呢？好吧，我只是简单地
展示一下，当我们改变我们的目标时，解析器的本质是如何变化的。同时，我也想统一一下
两种翻译器共同的核心思想，这样我们不仅能看到它们的不同之处，还能看到它们的相同之
处。

让我们考虑下面这一个赋值表达式：
```
x = 2 * y + 3
```
在一个编译器中，我们想让目标 CPU 在**运行时**执行这个赋值语句。这样翻译器本身不会
进行任何的算术运算，而是产生相应的可执行代码来让 CPU 在运行时计算。对于上面这个这
个例子，编译器会生成计算这条表达式并将结果放在变量 x 中的代码。

而对于一个解释器来说，它并不会去生成代码，而是边解析边求值在这个数学表达式。对于
这个例子，x 将在解析完成时就会被被赋为新值了。

我们在这个系列中说到的方案叫做“语法制导翻译（syntax-driven translation）”。如你所
见，整个解析器的结构与我们所解析的语法结构紧密绑定。我们构建了识别每种语法结构的
Lua 代码。对于每一种语法结构（和对应的 Lua 代码）都有一个对应的“动作”，一旦某种
结构被识别，相应的动作就会被执行。在我们目前的编译器中，每个动作都会生成目标代码
。而在一个解释器中，每个动作都会立刻执行某些操作。

我在这里想向你展示的是，整个解析器的布局和架构并不需要被改变。我们只需要改变它的
动作。所以如果你能写出某种语言的解释器，那你也可以写出它的编译器，反之亦然。但因
为所执行的动作不同，识别语法的流程也可能有较为显著的变化。具体来说，在一个解释器
中，解析代码的过程会被写成返回结果数值的函数。而我们的编译器解析时并没有这么做。

事实上，我们的编译器可能可以被称为“纯粹的“”编译器。在每次一个语法结构被识别时，
对应的代码**立刻**就被生成了。（这也是我们生成的代码效率不高的原因之一。）而我们
将要编写的解析器也是“纯粹的”解析器，也就是并没有对源代码进行例如“标识符化
（tokenizing）”之类的翻译处理。这代表了翻译技术的两个极端，因为在现实世界中，翻
译器很少不做任何处理，而是倾向于同时使用一些其它的技术。

我可以给出一些例子。实际上，我已经提到一个例子了：大多数的解释器，以
Microsoft Basic 为例，将会把源代码（标识符化）翻译为一种中间表示，以方便之后实时
解析。

另外一个例子就是汇编器。一个汇编器的目的当然是生成机器码，并且它通常顺序处理每个
表达式：每一行源代码都生成机器码。但是，几乎每个汇编器都允许操作数中含有表达式。
在这种情况下，表达式几乎都是常量表达式，所以汇编器并不应该为它们生成代码，反而应
该“解释”这个表达式以计算其常量结果，并生成对应的机器码。

事实上，我们也可以使用一些这样的技巧。即使对于只涉及常量的表达式，我们之前写出的
翻译器也会为复杂的表达式一一生成代码。在这种情况下，如果这个翻译器能表现得有点像
解释器，计算出表达式的常量结果，那便是极好的。

在编译原理中有一个叫做“惰性翻译（lazy translation）”的概念。这个概念指，你并不需
要在执行每个动作时就立刻生成对应的代码。事实上，在最极端的情况下，知道你必须生成
代码之前，你都可以什么都不用做。为了完成这点，与解析时对应的动作通常不生成任何代
码。有些时候它也会这么做，但大多数时候它只是将信息返回给调用者罢了。知道了这些信
息之后，调用者可以更明智地决策。

以下面这个表达式为例：

```
x = x + 3 - 2 - ( 5 - 4 )
```

我们的编译器会忠实的将这个表达式变成 22 行的汇编代码：将参数放到寄存器中，执行数
学计算然后存储结果。而一个更“惰性”一些的实现会认出这个数学计算中的常数是可以在编译
时计算的，并将这个表达式削减为

```
x = x + 0
```

而一个更更“惰性”一些的实现会聪明到足以看出，这就等价于

```
x = x
```

也就是什么都不用做。于是我们可以将22行代码削减到0行！

需要注意的是，这样的优化在我们的翻译器中是不太可行的，因为每个动作都会立刻被执行。

惰性表达式求值可以产出比我们现在生成的更好的代码。当然我必须要警告你：这会显著的
增加我们解析器代码的复杂度，因为现在我们每次都要决定是否要生成代码。惰性求值当然
不是因为它更好被我们编写而这么命名的！

我并不会继续深入此话题，因为我们尽量在此处遵守 “KISS” 原则。我只是想要让你知道在
编译和解释时，可以通过组合两种技巧来获得一些优化。在实际中，你需要知道在一个聪明
的编译器中，解析函数获得的信息一般会返回给调用者，当然有时解析函数也会需要一些信
息。这是我们在这一章想讲述一下解释器的主要原因。

## 解释器

好的，既然我们知道为什么我们需要探索这些，那就让我们开始吧。为了给你一些心理准备
，我们将会从头开始重新构建一个翻译器。当然，这次我们会快一点。

因为我们接下来会想进行一些计算，所要做的第一件事就是更改函数 `getNum`，它之前总
是会返回一个字符（或字符串）。现在，或许让它直接返回一个整数会更好。**复制一下你
之前写好的编译器并保存好！**（不要直接更改写好的编译器本身！）并将`getNum`函数修
改为下面的版本：

```lua

--[[ 获取一个数字 ]]

local function getNum()
    local value = 0;
    if not isDigit(look)
    then
        expected("integer");
    end
    value =string.byte(look) - string.byte('0');
    getChar();
    return value;
end

```

**您可能注意到：我们使用了单字符的版本。这能使程序更为简便，且原理是相通的！**

现在，我们将`expression`函数也改成以下版本的：

```lua
--[[ 解析并翻译一个数学表达式 ]]

function expression()
	return getNum();
end

```

最后，我们在程序的末尾加上这个语句：
```lua
io.write(expression());
io.write('\n');
```

现在这个程序所做的工作就是“解析”并翻译一个单字符的整数“表达式”。当然，您需要确保
它只处理 0~9 之间的数字，并对其它的任何东西报错。这应该不会太费时间！

好的，现在让我们扩展程序来加入对加减法的支持吧！

```lua
--[[ 解析并翻译一个数学表达式 ]]

function expression()
    local value = 0;
    if isAddop(look)
    then
        value = 0;
    else
        value = getNum();
    end
	while isAddop(look)
    do
        if look == '+'
        then
            match('+');
            value = value + getNum();
        elseif look == '-'
        then
            match('-');
            value = value - getNum();
        end
    end

    return value;
end

```

`expression`函数的结构，当然与我们之前的差不多，所以我们应该能相对容易地调试它。
不过，我们已经取得了重大的进展，不是吗？加减法的流程已经被我们解决了！因为执行这
些操作需要两个参数，我可以选择保留目前的结构，并将表达式的值，也就是 value，变为
全局变量。但是似乎让 value 作为一个局部变量会更加清晰，也就意味着加法和减法的代
码需要被放到一行之中。我们最后得到的结果似乎说明，虽然我们目前的简单的翻译结构又
好又干净，但它可能不适用于惰性求值。这是我们会需要记住的一个小细节。

好的，我们的翻译器能正常工作吗？那让我们来进行下一步吧。我们并不难想象出该怎么处
理一个项。只需要把 `expression` 函数中每个对 `getNum` 函数的调用改成`term`，并将
`term` 函数修改为以下的版本：

```lua
--[[ 解析并翻译一个数学项 ]]
local function term()
	local value = getNum();
	while look == '*' or look == '/'
	do
		if look == '*'
		then
            match('*');
			value = value * getNum();
		elseif look == '/'
		then
			match('/');
            value = value / getNum();
		else
			expect("mulop");
		end
	end

    return value;
end

```

*注：原文中此处只能处理整数乘法，因此类似于`1/3`的输出将会是0。但是我们现在用的
是Lua，所以它也能输出小数！（多棒！）*

现在，让我们尝试一下吧。不要忘记，虽然我们能输出多位数，但我们的输入依然是一位数
的版本。

既然我们之前已经看到将 `getNum` 扩展为多字符的版本是多么的容易，这看起来似乎是一
个挺蠢的限制。那么让我们现在来修复这个问题吧。新的代码将会是：

```lua

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

```

如果你已经测试了这个新版本的解释器，那么下一步将会是编写函数 `factor`，并处理带
括号的表达式。不过，我们会在之后再来处理变量名。现在，让我们将 `term` 函数中对
`getNum` 的调用改为`factor`，这样它们就会去调用`factor`函数了。然后让我们完成
`factor`函数的代码：

```lua
local expression;

--[[ 解析并翻译一个数学因子 ]]
local function factor()
    local ret;
    if look == '('
    then
        match('(');
        ret = expression();
        match(')');
    else
        ret = getNum();
    end

    return ret;
end
```

这很简单，对吧？我们已经很接近一个可用的解释器了！

## 一点编程哲学

在我们继续之前，我必须要让你注意到一些东西。这是关于我在这之前都没有怎么提到却
贯穿这几章的一个原则。我觉得现在是时候讲一下它了。这个原则是如此的强大和实用，
使得解释器的结构从复杂和难以处理变得简单和平凡。

在编译技术才开始发展的时候，人们很难弄清楚该怎么处理运算符之间的优先级。也就是
先进行乘除在进行加减，如此之类……我仍然记得之前的一个大学生发现该如何处理这件事
时欣喜若狂的场面。他使用的技术包含处理两个堆栈，并将每个操作符和操作数放到其中
。每个操作符都有一个优先级，而规则是当你栈顶的操作符优先级大于下一个时，才真的
进行计算。为了让生活更“有趣”一些，一个诸如 `)` 这样的操作符更根据其是否已经在
栈里面而具有不同的优先级。你必须在将其放到栈上时给它一个优先级，并在决定是否让
它出栈时再给一个。为了试验一下这个方案，我曾经尝试了写一下，我可以告诉你这很棘
手……

*注：如果你上过数据结构的话……这将会唤醒一些关于逆波兰表达式的记忆。*

很高兴我们还没有做任何这样的事！事实上，我们现在解析算术语句的方法应该连小孩都
看得懂。我们是如何做到如此幸运的？而那些处理优先级的栈又去哪了？

而在我们的解释器中也出现了相似的事。你当然**知道**为了计算算术语句（而不只是解
析它们），我们必须要在某个地方将数字放在堆栈中。但是这个栈又去哪了呢？

最后，在一些讲编译原理的书中，还会有许多地方讨论堆栈和其它结构。在另一种主流的
解析方法（LR）中，需要使用一个显式的栈。事实上，这个技术很像处理数学表达式的一
种老方法。另一个概念是解析树。编者喜欢画一副，关于将每个语句中的每个标识符用计
算符和内部节点连成一棵树，的图。同样的，在我们使用的方法中，这些树和栈又去哪了
呢？我们并没有见到。对于以上的答案是，这些结构在我们的程序中都是隐式的而非显式
的。在计算机语言中，每当你进行一次函数调用时，其实都会使用一个栈。无论什么时候
这个函数被调用，返回地址都会被放在 CPU 栈上。当函数结束时，这个地址会被出栈，
并将执行的流程变回那个地址。在一门允许递归的语言（例如 C 和 Pascal 中），局部
变量同样会被放到栈上，同样的，根据需要返回值。

例如，在函数 `expression` 中有一个叫做 `value` 的局部变量，其将会在调用 `term`
函数后被赋值。我们不妨假设为了得到第二个值我们调用了 `term` 函数，`term` 函数
又调用了 `factor` 函数，其又递归的调用了 `expression` 函数。最后这个
`expression` 函数拥有它自己的，与第一个 `expression` 函数中取值不同的 `value`
变量。那么第一个 `value` 变量发生了什么？答案是：它依然在 CPU 栈上，并会当返回到
第一个 `expression` 函数的执行过程时再次出现在 `value` 中。

换一种说法来说，我们因为将变成语言提供的资源使用到了极致，而使得一切看起来是如此
的简单。运算符优先级和解析树当然还是存在，但是它们被藏在了解析器的代码结构中，并
在函数调用的流程顺序中被自动的处理。现在你知道了我们是如何处理的，你可能很难想象
使用另一种方法处理这件事有多复杂。但是，我可以告诉你，编写者们花了许多年才变得如
此聪明。早期的编译器都复杂到难以想象。而有趣的是在经过一些实践后这件事变得简单多
了。

我提到这一切是既想让你知道这个知识，也想给你一个警告。这个知识是：当你用正确的方
法去做一件事时事情就会变得很简单。而警告则是：审视你目前所在做的事情。如果你在自
己进行探索时，发现你真的需要一个单独的栈或者树结构，这就是你问自己你是否正确看待
一个事情的时候。或许你只是没有好好使用你本可以使用的语言功能。



下一步是添加对变量名的支持。但是现在，我们有一些小问题。对于一个编译器来说，我们
在处理变量名时并没有什么问题。我们只需要将变量名告诉汇编器，然后让它来自动帮忙处
理剩下的事，例如分配空间来存储它们。但是在这里，我们必须要能获得这些变量的值并返
回，就像 `factor` 函数返回一个值一样。我们需要一种存储这些变量的方法。

在出现个人电脑的早期，有一种语言叫做 Tiny BASIC。它允许26个可能的变量：每一个都
是字母表中的一个字符。这很符合我们单字符标识符的概念，所以我们将会使用同样的技巧
。在你解释器代码的开始处，就在定义`look`变量之后，插入这一行代码：

```lua
local table = {};
```

我们同样需要初始化它，所以让我们添加下面这个函数：

```lua

--[[ 初始化变量表 ]]
local function initTable()
    for i = string.byte('A'), string.byte('Z') do
        table[string.char(i)] = 0;
    end
end

```

你同样需要在 `init` 函数中添加上对 `initTable` 函数的调用。**千万不要忘了！**，
否则结果可能会惊到你。

现在我们有了一个变量表，我们可以修改 `factor` 函数来使用它。因为我们目前还没有给
变量赋值的功能，`factor` 函数永远会对它们返回0，不过我们可以先继续，并之后再来处
理这件事情。这是`factor`函数的新版本：

```lua
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
```

同样的，测试一下新版本的程序。虽然现在所有的变量都是0，至少我们可以正确解析完整
的表达式，并准确的找出错误的表达式了。

我认为你已经意识到了下一步要做什么了：我们需要实现一种赋值语句，这样我们才可以在
这些变量中**放入**些什么。

现在，我们就只处理一行语句吧，不过我们很快就能处理多语句的版本了。

新的赋值流程与我们之前的差不多：

```lua
--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name = getName();
    match('=');
    table[name] = expression();
end
```

别忘了将最后的对 `expression` 的调用变为 `assignment` 的！

为了测试其是否工作正常，我增加了一个临时的语句来打印变量‘A’的值。然后，在其上面
测试了多个不同的赋值语句。

当然，一门只能接受单行语句的解释性语言并不是很有用。所以我们将会想处理多条语句。
这意味着在一个循环中调用 `assignment` 函数。那让我们现在开始吧。但是我们该怎么决
定什么时候退出循环呢？很高兴你问了这个问题！因为这提到了我们之前能一直忽略的一件
事。

对任何编译器来说最难的事情之一，就是决定什么时候跳出一种结构然后去寻找一些其它的
字符。这对我们目前来说并不是一个问题……因为我们只允许一种结构：一个表达式或者一个
赋值语句。但当我们开始增加对多种语句的循环时，我们必须非常小心的来处理什么时候正
确的终止一个循环。如果我们将解释器放到一个循环中，我们需要一个方式来跳出循环。在
新的一行终止并不是一个好想法，这是我们必须要换一种方式的原因。我们当然可以通过一
个不认识的字符来将我们带出循环，但这会在每次结束时都输出一条错误信息，这不太好。

我们所需要的是一个终止符。我选择了Pascal的结束符('.')。一个小问题是每行都会以几
个字符结尾。此处有两种标准：LF 和 CRLF（即只有换行字符`\n`，和回车-换行两个字符
`\r\n`）。无论用哪种标准，在每行的结尾，我们都需要在处理新行之前吃掉这些字符。
一种自然的做法是在 `match` 函数中，期望 `match` 函数的报错打印出这两个字符：CR
和 LF，这种做法看起来当然不是很好。我们真正所需要的是一个会不断使用的特殊流程来
处理这件事。这里可以这么做：

```lua
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
```

把这个函数放到任何一个方便的地方吧，我把它放在了 `match` 函数之后。现在将主函数
变成这样：

```lua
--[[ 主函数 ]]
init();
repeat
    assignment();
    newLine();
until(look == '.')
```

注意到现在对于 LF 的测试已经不存在了，而对`newLine`的测试也没有什么问题。因为任
何项中的伪字符都会在下一条赋值语句开始时被发现。

好的，现在我们有了一个能工作的解释器了。但是它依然不很完整，因为我们没有方式去读
取或者打印出任何数据。加入一些I/O（输入输出）会更有帮助。

让我们以加上I/O方法来结束这一章吧。因为我们一直在处理单字符的标识符，我将会使用
'?' 来代表读出语句，使用 '!' 来作为写入语句，并在其后面立刻加入一个字符来作为“参
数”。这是需要实现的函数：

```lua
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
```

我承认……这并不是很花哨。例如，输入时没有提示字符。但是，它们能完成所需的工作。

对应的在主函数中需要的变化在下面。需要注意我们使用了通过看向前看字符来决定做什么
的小技巧。

```lua
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
```

现在你已经完成了一个真实且可用的解释器。它的确拥有很多不足，但是就像“大男孩”一样
能工作。它拥有三种类型的语句（并且能分辨它们的不同！），26 个变量和 I/O 语句。我
们最后真正所缺少的，就是流程控制语句，函数和开发环境。我将会跳过开发环境部分。毕
竟，我们是来学习东西的，不是真的要写出一个产品。我们将会在下一部分完成流程控制语
句，并在不久之后完成对函数的支持。我急切地想要讲述这些内容，所以我们只把解释器做
到这里。

我相信你现在已经很清楚可以很轻松的解决单字符和空白字符的限制，毕竟我们上一章已经
做过这些事情了。这一次，如果你想扩展程序解决这些问题的话……不妨认为它们是“课后作
业”吧。下次见~！

> 版权声明
> Copyright (c) 1988 Jack W. Crenshaw. 保留一切权利。
> 本文由泠妄翻译, 梓瑶校订
> 本文由泠妄在梓瑶基础上编写代码
