# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第七章：词法扫描

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译

## 简介

在上一张中，我们留下了个除了只能处理单字符标识符以外，几乎完全能工作的编译器。而我们这章的目标就是一劳永逸的摆脱这个限制。不过这意味着我们需要触及到一些语法扫描的概念。

或许我需要先提一提为什么我们需要语法扫描……毕竟直到现在，哪怕我们完全不知道这个概念，也成功的制造出了一个翻译器。我们甚至已经尝试处理过多字符标识符了。

说真的，唯一我们需要它的原因便是关键字。事实上，在计算机中，关键字和其它的标识符并没有任何形式上的不同。除非我们知道了整个单词，我们才能知道它**是不是**一个关键字。例如，“IFILE”这个词，会在我们直到第三个字符才能知道它不是“IF”。在之前的编译器中，我们总是能根据看到的第一个字符就能决定它是个什么东西，但现在却做不到了。我们需要在处理一个单词**之前**就知道它是否是一个关键词。而这正是我们需要扫描器的原因。

在上一节中，我同样承诺了我们可以在不对之前的代码进行大改的情况下做到这点。我没骗你，你马上就会发现这是完全可行的。但每次我开始把这些内容加到我们已经写好的解析器之中时，我都感觉怪怪的，毕竟这件事太像在给程序打补丁了。我最终弄懂了为什：我之前在向程序中添加词法扫描的相关内容时，并没有像你解释它是什么和我们到底可以怎么做。到目前为止，我一直在避免提及大量的理论知识和很多的替代方案，毕竟我不太喜欢像教科书那样，一下给你二十五种完成某事的方案但不告诉你你到底需要什么。我想通过只向你展现**一种能工作**的方案来避免这点。

但这个话题非常的重要。虽然词法扫描器不是编译器中最令人兴奋的部分，但它却对整个语言的“外观和感觉”有着最深远的影响。毕竟，这个部分与用户最为接近。我脑中有个在KISS风格中使用的特定结构的扫描器，并且它很符合我语言想要的语法。但是，它可能根本不适用于**你**想创造的语言。因此，我想让你了解所有可能的选择。

所以我会再次跳出我平常的风格。在这一章中，我们将会比较深入的了解语言和语法的基本理论。我也会谈谈语法扫描在除编译器外的**其它**领域所起到的重要作用。最后，我将会向你展现一些词法扫描的其它方案。而直到在那之后，我们才会回到我们上次写的解析器之中。不过请耐心一些……我相信你会发现这些功夫是值得的。事实上，因为词法扫描在编译器之外是有如此多的应用场景，你可能会发现这是对你来说最有用的一章。

## 词法扫描

词法扫描是一个通过扫描输入的字符流并将其分开为一个个叫做标记的字符串的过程。大多数讲编译器的书都会从这里开始，然后花几章的时间来大谈特谈各种构建它的方法。这种做法有一定的道理，但正如你所见，我们不需要它也可以完成许多事。而且我们之后会完成的扫描器并不会和书上的方法很相近。原因是什么？编译原理的书和它其中写出的解析器必须要能应付一些最通用的情况。但是我们不需要。在真实世界中，我们总能通过定义具体的语法来让一个非常简单的扫描器工作的足够好。和往常一样，我们把KISS作为我们的座右铭。

通常来说，词法扫描器是编译器中单独的一部分，因此解析器本身只能看到输入的标记流。理论上来说，我们现在没有必要把它和我们剩余的解析器分开。理论上我们可以把整个解析器写在一个模块里，因为我们的语言只用了一组语法方程来定义。

那我们为什么要分开呢？答案是因为实践经验也因为理论依据。

在1956年，Noam Chomsky定义了语法的“Chomsky层次结构”。它们是：
- 类型0：无限制（比如英语）
- 类型1：上下文相关语法
- 类型2：上下文无关语法
- 类型3：正则语法

很少一部分典型的编程语言（特别是很古老的那些，比如FORTRAN）的语法结构是类型一，但是对于大多数现代的编程语言只用了最后的两种结构，而这也是我们此处需要处理的结构。

这两种语法结构的好处在于，我们有非常具体的方式来解析它们。例如任何的正则语法都被证明了能用一种特别的抽象机器——状态机（有限自动机）来解析。我们已经在之前的识别器中实现了一些状态机。

与它类似的，类型二（上下文无关）的语法规则总能被递归向下自动机（一种加上了堆栈来进行增强的自动机）来解析。我们同样已经实现过了这些自动机。和真正实现了一个栈不同，我们通过依赖在程序中进行递归所自带的栈来实现，而这也确实是实现一个自定向下解析器的最好方法。

在如今实际的语法中，符合正则表达式的部分通常是较为低级的模块，例如对标识符的定义：
```
<ident> ::= <letter> [ <letter> | <digit> ]*
```

既然描述这两种语法需要不同种类的抽象机器，将这些低等级的功能放在一个单独的模块中，也就是基于状态机词法扫描器，是很合理的。这种理念在于使用最简单的解析机器来完成这部分的工作。

这里我们还有一个需要把扫描器和解析器分开的更实际的原因。我们希望认为输入文件是一个从左到右的，不会往回走的字符流。但是现实中这是不可能的。几乎每个语言都有一些关键词，例如`IF`，`WHILE`和`END`。正如之前所说的，我们并不能知道这是否是一个关键字，直到我们完全读完了一个词，如遇到分隔符或者运算符。在这种情况下，我们必须保存足够长的字符串直到能确定我们是否获得了一个关键词。这就是往回找的限制之处。

所以一个经常使用的方法是把编译器的解析功能分为低级的和高级的。词法扫描器处理在字符层面的解析，例如把单个的字符变成字符串等，然后以单个标记的形式传递给解析器。同时我们也一般会让扫描器承担识别关键字的任务。

## 状态机和替代方案

我之前提到过，正则表达式可以用一个状态机来解析。而你会发现，事实上在大多数编译原理的书和现实中大部分编译器上也确实是这么做的。通常里面会有一份，以数字作为当前的状态；并用一张动作表来表示当前状态和输入字符的集的，真正的状态机实现。而如果你使用一些很受欢迎的Unix小工具，例如YACC和LEX来写你编译器的前端的话，这也确实是你会得到的。LEX的输出是用C实现的状态机，和一个对应着你输给LEX的语法的动作表。而YACC也会做相似的事：一个打包好的，以表为驱动的解析器，和一个对应着语法的动作表。

不过，这并不是我们唯一的选择。在上一章中，你可以发现我们可以在没有实现表、栈或者状态变量的情况下写出了一个解析器。还记得吗，在第五章中我警告过你说，如果你发现你需要这些东西，那你大概在哪里已经做错了，并且没有使用LUA赋予你的强大功能。通常而言，定义状态机有两种方法：显示的以状态数字或者代码定义，和隐式的仅仅是因为在执行某个位置的代码（如果遇到了一只很可爱的大佬，那她很可能是梓瑶（x）<!-- 如果今天是周二，那这一定是Belgium -->。我们之前大量的使用了隐式的定义方法，而且我认为你之后也会发现它们在这里也能很有效的工作。

在实际情况下，我们甚至**不必拥有**一个被良好定义的语法扫描器。这并不是我们第一次处理多字符标记了。在第三章，我们就将我们的解析器扩展出了这个功能，而在那时我们甚至**并不需要**一个词法扫描器。这只是因为在我们的那个具体语境下，我们只需要看单个的向前看字符，就知道我们在处理的是一个数字、变量还是一个运算符。最终，我们使用了`getName`和`getNum`函数来建造了一个文法扫描器。

但在加上现在的这些关键字之后，在我们读完了整个标记之前，便都不再能知道我们在处理什么了。这时我们需要单独的扫描器，不过你也会发现，之前我们使用的集成的扫描器依然有它的用途。

## 词法扫描中的一些尝试

在回到我们的编译器之前，不妨让我们来探究一些通用的概念吧。

让我们从两个在目前编程语言中经常能看到的两个定义开始：
```
<ident> ::= <letter> [ <letter> | <digit> ]*
<number> ::= [<digit>]+
```

（还记得吗，`*`表示括号中的内容出现0次及以上，`+`号表示1次及以上）

我们已经在第三章中处理过相似的内容了，让我们和往常一样，从一份裸的编译器代码开始。想必您能够预料到，我们需要一个新的识别函数：
```lua
--[[ 识别是否是字母数字字符 ]]
local function isAlNum(c)
    return isAlpha(c) or isDigit(c)
end
```

在这之后，让我们使用它写两个和我们之前使用到的很像的新函数：
```lua
--[[ 读取一个标识符 ]]
local function getName()
	local name = '';
	if not isAlpha(look)
	then
		expected("name");
	end
	while isAlNum(look)
	do
		name = name .. upCase(look);
		getChar();
	end
	return name;
end

--[[ 读取一个数字 ]]
local function getNum()
	local num = '';
	if not isDigit(look)
	then
		expected("integer");
	end
	while isDigit(look)
	do
		num = num .. upCase(look);
		getChar();
	end
	return num;
end
```

（注意这里`getNum`不像以前会返回一个数字，这里直接返回了字符串）

你可以直接在主程序里调用它们来很方便的进行一些测试，比如：
```lua
writeLine(getName());
```

理论上现在程序会给你打印出你所输入的任何合法标识符，并且对其它的报错。

相似的，测测其它的函数吧。

## 空白字符

我们之前也通过`isWhite`和`skipWhite`处理过了嵌入在其中的空白字符。确保你目前的版本中包含这两个函数，然后在`getName`和`getNum`的结尾加上`skipWhite`。

现在让我们来定义个新函数：
```lua
--[[ 词法扫描器 ]]
local function scan()
	local res;
	if isAlpha(look)
	then
		res = getName();
	elseif isDigit(look)
	then
		res = getNum();
	else
		res = look;
		getChar();
	end
	skipWhite();
	return res;
end
```

然后在主程序里调用它：
```lua
local token;
repeat
	token = scan();
	writeLine(token);
until token == '\r' or token == '\n'
```

现在运行一下程序试试，你会发现它把输入变成了分开的标记了。

## 状态机

目前来看，一个类似于`getName`这样的解析流程确实实现了一个状态机。当前的状态被隐含在了代码的位置中。使用语法图或者“铁轨图”来可视化发生了什么是个非常有用的技巧。在目前的文章中画一副图还是挺有困难的，所以我只会偶尔用下，不过你应该能体会到是什么：
```
           |-----> Other---------------------------> Error
           |
   Start -------> Letter ---------------> Other -----> Finish
           ^                        V
           |                        |
           |<----- Letter <---------|
           |                        |
           |<----- Digit  <----------
```

正如你所见，这幅图展示了当字符被读入时，逻辑是如何执行的。一切当然是从`start`状态开始的，并且在读到最后一个字母数字字符时结束。如果第一个字符不是字母，那就会产生一个错误，否则会一直循环到终止符被找到。

可以注意到在图中的任意时刻，我们的位置都完全取决于过去输入的字符。而在那时我们的动作完全取决于当时的状态和输入的字符。这就是组成一个状态机的全部部分。

不过由于在文章里画语法图有点困难，我接下来还是会直接给你语法表达式。不过我非常推荐你在做任何解析的时候来画下这些图。这样，在经过一些练习之后你应该能发现如何从这种图直接写出一个解析器。并行路径被变成代码段之间的分割（如`IF`或者`CASE`），而串行路径被变成顺序执行的代码。这几乎和直接从一个示意图开始进行是一致的。

我们还没有讨论之前被引入的`skipWhite`，不过它和`getNum`一起也都是状态机。而它们的父流程`scan`也是。小一些的状态机能组成大的状态机。

我想向你展示的一个点是，用这种方法实现状态机是多么的无痛。我个人比起使用动作表实现的状态机更喜欢这个。这同样也给了我们一个更小、更紧凑也更快的扫描器。

## 新的一行

让我们继续改进目前的扫描器来支持超过一行吧。正如我上次所说，最简单的方法就是将换行和回车也视为空白字符。而这也正是C标准库中`iswhite`函数所实现的。我们事前并没有试过这种方法。我现在想向你展示一下，让你感受下结果。

要做到这点，只需要稍稍改一下`isWhite`这个函数：
```lua
--[[ 识别是否是空白字符 ]]
local function isWhite(c)
	return c == ' ' or c == '\t' or c == '\r' or c == '\n';
end
```
由于它现在会跳过换行，我们同样需要给程序一个不同的终止符。让我们使用：
```lua
until token = '.'
```

好，现在让我们来试试运行它。输入几行以`.`结尾的文字。我用了：
```
     now is the time
     for all good men.
```

等等……发生啥了？当我在使这运行这个程序的时候，它并没有获取到最后一个标记，也就是那个句号。而这导致程序并没有停止。实际上，在我狂按了几次回车之后，它依然没有获得那个句号。

如果你的程序还在运行着，你会发现在新的一行里直接打上这个句号，然后回车，会停下这个程序。

这里发生啥了？答案是我们被停在了`skipWhite`函数里。如果你仔细看看这个函数就会发现，只要我们一直换空行，这个循环就不会终止。而在`skipWhite`函数跳过了回车之后，它在尝试获取一个新的字符。但是因为输入流现在已经空了，`getChar`就只能一直去读新行。`scan`函数的确能在读到`.`之后停下，这是好的，但是之后它又调用了`getWhite`来清空，而这个函数在遇到一个新的非空行之前不会返回。

实际上，这个问题并不如你看上去那么严重。在一个真实的编译器中，我们总是从一个文件中而不是命令行来读取字符，而这时的只要我们正确的处理了EOF，程序就不会发生任何问题。但从控制台来读取的时候，这个行为也太奇葩了。这件事会发生的原因是C或Unix这样通过向前看字符跳过换行的结构不太适用于我们的解析器。而Bell  wizards曾今实现的就没有用这套流程，而这也是他需要`ungetc`的原因。

好的，让我们现在来修了这个问题吧。为了做到这点，我们需要先把`getWhite`函数换回老版本（删除跳过换行和回车的部分），然后使用我上次给过的`fin`函数。如果你现在的版本中没有函数，那加上它吧。

同样的，把主函数修改一下来让它工作：
```lua
-- 主程序从这里开始
init();
local token;
repeat
	token = scan();
	writeLine(token);
	if token == "\r" or token == "\n"
	then
		fin();
	end
until token == "."
```

现在`fin`函数也会在被遇到换行或回车这个状态时被调用了。而这正是让这一套东西运行起来，并确保我们不要在其它地方读到换行标记的方法。如果去看看上一章中处理换行部分的代码，你会发现其实我悄悄把对`fin`的调用散布到了代码中每个可能需要处理换行的角落。这是我之前提到的真正会影响语言风格的部分。我想在此时催促你试试你自己喜欢什么样风格的代码。如果你希望你的语言是完全自由的，那换行符应该是可以任意出现的。在这种情况下，一个更好的方法实在`scan`的**开头**放上：
```lua
while look == "\r" or look == "\n"
do
	fin();
end
```

而如果你是想要一种以行为分界的代码，比如汇编、Python、Basic或者Fortran（甚至于Ada……注意它有着以换行结束的注释），那你需要让`scan`把换行作为一个标记来返回。由于现在计算机中可能不区分CR和LF（也就是只有`\n`，你可能需要处理两种情况，而非向原文一样返回CR并吞掉LF）

而对于其它的语言风格，你需要用其它的代码排列。在上一章中，我只允许换行在特定的地方出现，所以我当时其实相当于处于这两种风格的语言之间。在这章剩下的部分，我将会使用我所喜爱的方式，不过我想让你自己选择你所喜欢的风格。


## 运算符

对于我们的需要而言，我们完全可一停在这并获得一个很可用的扫描器了。在我们KISS理念下目前的编译器所具有的多字符标记，也只有标识符和数字罢了。所有我们目前所有的运算符都是单字节的。唯一我能想到的例外就是关系运算符`<=`、`>=`和`<>`，比不过它们可以被特殊处理。

不过当然，其它语言是有多字符运算符的，例如Pascal中的`:=`或者C中的`++`、`>>`等。所以虽然我们目前不需要它们，但以防万一最好还是了解一下处理它们的方法。

不用说大概也能猜到，我们处理运算符的方法和处理其它标记非常相像。让我们从识别它们开始：
```lua
--[[ 识别是否是运算符 ]]
local function isOp(c)
	return isInArr(c, { '+', '-', '*', '/', '<', '>', ':', '=' });
end
```

值得注意到，我们**并没有必要**把每种可能的运算符都加到这张表里。例如，括号和结尾的句号都不在表里。目前的版本的`sacn`就已经足够应对单字符运算符了，而上表只包含了具有多字符版本的运算符。（当然，对于不同的语言来说我们总是可以编辑这张表的。）

现在让我们魔改一下`scan`函数来读入：
```lua
--[[ 读取一个运算符 ]]
local function getOp()
	local op = '';
	if not isOp(look)
	then
		expected("operator");
	end
	while isOp(look)
	do
		op = op .. upCase(look);
		getChar();
	end
	skipWhite();
	return op;
end

--[[ 词法扫描器 ]]
local function scan()
	while look == "\r" or look == "\n"
	do
		fin();
	end
	local res;
	if isAlpha(look)
	then
		res = getName();
	elseif isDigit(look)
	then
		res = getNum();
	elseif isOp(look)
	then
		res = getOp();
	else
		res = look;
		getChar();
	end
	skipWhite();
	return res;
end
```

试一下目前的版本。你应该能发现它能把所扔给它的任何字符都很好的分解为单个的标记。

## 列表，逗号和命令行

在回到我们学习的主线任务之前，我想来和你先聊聊另一个话题。

你遇到了多少次一个语言或者操作系统有强制性的关于你要如何分开一个列表中元素的规则？有些语言要求你用一个分隔符分开，有些要求你用一个逗号。更糟糕的是，有些语言要求你在不同的地方运用不同的规则。并且它们大多数都严格的不允许你违反这些规则。

我认为完全没有必要来加上这些规则。毕竟写一个能灵活处理空格和逗号的解析器真的很简单。考虑下下面这个流程：
```lua
--[[ 跳过一个逗号 ]]
local function skipComma()
	skipWhite();
	if look == ','
	then
		getChar();
		skipWhite();
	end
end
```

这8行代码会跳过一个字符串中的任意个（包括零个）空白字符，和零个或一个逗号。

让我们暂时把对`skipWhite`的调用换成对`skipComma`的调用，然后试着输入一些列表来看看结果。这不错吧？目前，我发现在z80机器的汇编语言中加上等效于`skipComma`的汇编代码总共只多用了6个额外的字节。哪怕对于一个只有64k的机器，为了交互友好性而加上这段代码代价也是很低的。

我觉得你大概能猜到我为什么要和你讲这些了。纵然你这辈子不会碰任何一行编译器的代码，几乎每个程序都会有用到解析这个概念的地方。任何需要处理传入的命令的程序都需要使用它。实际上，如果你仔细想想就能发现，每次你在给一个程序写处理用户输入的部分时，你其实就是在定义一门新的语言。人们有语言来交流，而你程序中隐式定义的语法也定义了一种语言。唯一真正的问题是：你是要明确和强制性的定义这种语法，还是让你的程序能解析任何的内容？

我确信如果你花时间来显示的定义一下语法，你会有一个更好也更用户友好的程序。写一下语法表达式或者画一下铁轨图，然后使用一些我在这里交给你的关于解析的技巧。你会有一个更容易被实现、运行也更好的程序。

---

## 变得花哨一点

好，那么现在我们已经有了一个可以把输入流分开为一个个标记的挺不错的词法扫描器了。我们可以就用现在的这个版本并获得一个可用的编译器。但是对于词法扫描这个话题我还有一些方面需要讲讲。

<!-- <__label0__> -->
这里我们需要提一些技术上的细节以便于更好的理解……如果你研究过Lua或者Java等语言中，在进行字符串比较时的细节时，你会发现它们使用了诸如字符串哈希、常量池和字符串缓存等技术来实现了在 $\theta(1)$ 内进行比较。但这不是必然的。如果你回顾C、C++和作者使用的Pascal中比较字符串的方法时，你会发现它们真的是逐字进行的：你的字符串有多长，它就会花多久。

而这便带来了个最主要的问题：低下的令人发指的效率。还记得当我们处理单字符标识的时候，我们每次比较都只是在`look`和一个字节的常量之间进行。

但是当我们现在处理`scan`返回的多字符标识符时，所有的比较都变成了字符串之间的。在其它的语言中，这可慢多了。而且，当这出现在那些只有一个字符的标识符如`=`，`+`和其它运算符上时，使用字符串匹配也太显得浪费了。

当然，使用字符串比较并不是不可能的。实际上，Ron Cain就在他写的Small C中使用了这种方法。自然我们这里在遵循KISS原则，我们也理应直接使用这种方式。但如果就到此为止的话，我就无法告诉你在**真正的**编译器中所使用的一个关键方法了。

你需要记住一点：词法扫描器将会被调用的**超级频繁**。实际上不难想到，对于源程序中的每个标识都会调用一次它。实验证明编译一个程序的时间平均有20%到40%被花在了词法扫描上。如果有哪里值得我们为了效率来多想想的话，那就必然是这里了。

因此，大多数编译器编写者都会让词法扫描器多做一些工作：把输入流“标识符化”。这个想法便是对于源程序中每个标识符都和一个可被接受的关键词和运算符进行比较，并对每个识别到的标识返回一个唯一的代码。而对于普通的变量名和数字，我们则直接返回他们是什么种类的标识，然后把实际的字符串存储在别处。

我们所需要做的第一件事便是识别出关键字。我们当然可以通过一系列的`if`来一个一个试，但如果我们能有一个直接将字符串和所给表中的关键字进行比较的通用流程会更好。（顺便，我们的确需要这个流程来处理之后会遇到的符号表）。

或许你会想到enum、map等方法来建立这张表（在C和C++中也的确如此），但我们可以很方便的使用Lua中的表来完成这点。首先，让我们来创建这张表：

```lua
local keywords = {
	__mode = "k, v",
	['IF'] = 1,
	['ELSE'] = 2,
	['ENDIF'] = 3,
	['END'] = 4
};
```

在lua中，这相当于同时创建了一个映射（可以通过keywords['END']来获取4）和一个枚举（可以通过keywords.END来获取4），于是我们不需要一个专门通过字符串获得映射结果的函数了。很方便对吧？

现在让我们来试试吧。向你的程序开头加入这两行：
```lua
local token  = 0;  -- 当前的Token
local value    = ''; -- 当前Tkoen对应的字符串

local keywords = {
	__mode = "k, v",
	['IF'] = 1,
	['ELSE'] = 2,
	['ENDIF'] = 3,
	['END'] = 4,
	['Ident'] = 5,
	['Number'] = 6,
	['Operator'] = 7
};
```

然后更改一下读取字符串的扫描器：
```lua
--[[ 词法扫描器 ]]
local function scan()
    while look == "\r" or look == "\n"
    do
        fin();
    end
    local k;
    if isAlpha(look)
    then
        value = getName();
        k = keywords[value]
        if not k
        then
            token = keywords.Ident;
        else
            token = k;
        end
    elseif isDigit(look)
    then
        value = getNum();
        token = keywords.Number;
    elseif isOp(look)
    then
        value = getOp();
        token = keywords.Operator;
    else
        value = look;
        token = keywords.Operator;
        getChar();
    end
    skipWhite();
end
```

最后，让我们更改下主程序来输出：
```lua
-- 主程序从这里开始
init();
repeat
    scan();
    if token == keywords.Ident
    then
        io.write('Ident ');
    elseif token == keywords.Number
    then
        io.write('Number ');
    elseif token == keywords.Operator
    then
        io.write('Operator ');
    elseif token == keywords.IF or token == keywords.ELSE or
        token == keywords.ENDIF or token == keywords.END
    then
        io.write('Keyword ');
    end
    writeLine(value);
until token == keywords.END
```

我们所在这里做的无非就是使用我们新的枚举替换了原来的字符串标识符。`scan`将标识符类型放在`token`中，并把对应的字符串放在新变量`value`中。

好的，让我们来试试这个程序。如果一切无误的话，你应该能看见我们现在能识别关键字了。

我们很轻易的更改除了现在的结果，并且它运行一切正常。但是，我觉得这个程序依然有点点“忙”。我们可以通过让`getName`、`getNum`、`getOp`来和`scan`一起使用全局变量`token`和`value`来去掉局部变量。同时，我们还可以将获取token的过程放到`getName`里来显得更合理一些。这四个函数变为：
```lua
--[[ 读取一个标识符 ]]
local function getName()
    value = '';
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
    local k = keywords[value]
    if not k
    then
        token = keywords.Ident;
    else
        token = k;
    end
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
    skipWhite();
    token = keywords.Number;
end

--[[ 读取一个运算符 ]]
local function getOp()
    value = '';
    if not isOp(look)
    then
        expected("operator");
    end
    while isOp(look)
    do
        value = value .. look;
        getChar();
    end
    skipWhite();
    token = keywords.Operator;
end

--[[ 词法扫描器 ]]
local function scan()
    while look == "\r" or look == "\n"
    do
        fin();
    end
    local k;
    if isAlpha(look)
    then
        getName();
    elseif isDigit(look)
    then
        getNum();
    elseif isOp(look)
    then
        getOp();
    else
        value = look;
        token = keywords.Operator;
        getChar();
    end
    skipWhite();
end
```

## 返回一个字符

对于很多的扫描器都用了我之前所属的枚举方法。这当然是一个可行的方法，但却不是我所见过的最简洁的方法。

最显而易见的一个问题便是可能的符号种类会变得很多。在这里，我用了单个符号“Operator”来代表所有的运算符，但我却的确见过有对每种不同的运算符都返回一个不同的符号的设计。

而当然，还有一个更简单的方式便是直接返回一个字符。例如，对于`+`，与其返回枚举成员“Operator”，我们直接返回加号本身又有什么问题呢？一个字符和其他用来编码标识符类型的变量类型一样好，它也比许多其它类型更容易使用。还有什么更简介的呢？

*注：如果你在使用C/C++等语言，这可能会有一些疑惑：返回一个字符和枚举时获得的数字类型有什么区别吗（即char和int都是数字类型）。这是因为在原作者的Pascal中，枚举成员并不是数字而特殊的成员；同样的，在Lua单个字符也是一个字符串而非一个数字类型。*

另外，我们已经对把标识符编码为单字节的字符很有经验了。毕竟我们之前的代码就基于这种方式实现，采用这种方法会建校我们对已完成代码的更改。

有些人可能会觉得这种返回字符类型的想法有点滑稽。我必须承认，这对于像“<=”这样的多字符运算符来说有点尴尬。你当然可以选择保留着枚举类型。但在下面的部分，我想向你展示如何改变我们上面的代码来变为这种方法。

首先，将上面的关键字表更改如下：
```lua
local keywords = {
	__mode = "k, v",
	['IF'] = 'i',
	['ELSE'] = 'l',
	['ENDIF'] = 'e',
	['END'] = 'e',
	['Ident'] = 'x'
};
```
（需要注意我把所有Ident编码为了‘x’）

接下来把我们上面那四个函数变为下面这种形式：
```lua
--[[ 读取一个标识符 ]]
local function getName()
    value = '';
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
    local k = keywords[value]
    if not k
    then
        token = 'x';
    else
        token = k;
    end
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
    skipWhite();
    token = '#';
end

--[[ 读取一个运算符 ]]
local function getOp()
    value = '';
    if not isOp(look)
    then
        expected("operator");
    end
    while isOp(look)
    do
        value = value .. look;
        getChar();
    end
    skipWhite();
    if string.len(value) == 1
    then
        token = value;
    else
        token = '?';
    end
end

--[[ 词法扫描器 ]]
local function scan()
    while look == "\r" or look == "\n"
    do
        fin();
    end
    local k;
    if isAlpha(look)
    then
        getName();
    elseif isDigit(look)
    then
        getNum();
    elseif isOp(look)
    then
        getOp();
    else
        value = look;
        token = '?';
        getChar();
    end
    skipWhite();
end

-- 主程序从这里开始
init();
repeat
    scan();
    if token == 'x'
    then
        io.write('Ident ');
    elseif token == '#'
    then
        io.write('Number ');
    elseif token == 'i' or token == 'l' or token == 'e'
    then
        io.write('Keyword ');
	else
        io.write('Operator ');
    end
    writeLine(value);
until token == 'END'
```

这个版本的代码应该会和上个版本的一样能正常工作。的确它们在结构上会有一些不同，不过这在我看起来会更简单一些。

<!-- </__label0__> -->

----

## 分布式扫描器和中心化扫描器

我向你展示的这个词法扫描器的结构是很平凡的，且世界上99%的编译器都在使用类似的结构。但是这并不是唯一一种——甚至不是最好的一种结构。

这种通常结构的最大问题便是，扫描器对于语境一无所知。例如，它分不清赋值运算符`=`和关系运算符`=`（这也可能是C和Pascal使用了不同的东西的原因）。扫描器所能做的所有事便是将这些运算符给到解析器，并希望它能根据语境给出这些运算符代表什么。同样的，虽然关键字`IF`无法出现在一个数学表达式的中间，但扫描器并不会认为如果一个IF出现在那里有什么问题，并且会返回一个好好的`IF`给解析器。

在这样的流程下，我们并没有好好利用处理过程中获得的所有信息。例如，在一个数学表达式的中间，解析器知道没必要在这里去找一个关键字，但是它并没有办法告诉扫描器这个信息。于是扫描器指挥继续去找这些关键字。这当然会减慢编译的速度。

在真正的编译器中，设计者通常会让扫描器和解析器之间传递一些信息来避免这样的问题。但是这么做可能会很尴尬且肯定会牺牲很多这种结构下模块化的部分。
另一种方式是寻找一种方法来利用来自解析器中目前位置的语义信息。而这带我们来到了分布式扫描器的概念中，即根据目前的上下文调用扫描器的不同的模块。

根据KISS原则，大多数语言中关键字**只会**出现在一个语句的开头。而在诸如不澳大适中的地方则是不允许的。同样的，由于大多数运算符都是单字符的且一些小例外（如多字符的关系运算符）能被很简单的处理，我们根本就不需要`getOp`。

所以对于多字符标识而言，除了在语句的一开始，我们依然可以通过只看目前的向前看字符就能知道下一个标识的种类。

哪怕到了现在，我们唯一能接受的标识也就是标识符。也就是说我们只需要确定标识符是否是一个关键字还是一个赋值语句的目标变量。

最终，我们能发现我们会像最早的几章一样只需要`getName`和`getNum`。

乍一看，这可能像是在开倒车，甚至是一种相当原始的做法。事实上，因为我们能仅在需要的地方使用对应的扫描器，这反而是一种对传统扫描器的改进。在不允许使用关键字的地方，我们不会因为寻找关键字而减慢速度。

## 合并扫描器和解析器

现在既然我们已经知晓了关于词法扫描所需的一切理论知识和大概的方法，我终于准备好回到我最开始所说的，通过一些在之前代码上的小小改动来支持多字节的标识。为了简洁一些，我在这里只会允许之前的一小部分语法来演示更改：即我只允许一个控制结构（IF语句）并且没有布尔表达式。不过这已经足够我来演示如何解析关键字和表达式了。对整个程序的更改在完成这些学习之后应该是很显然的。

所有用于解析这个子集语法的流程都是存在于之前单字符标识版本的程序里的。我通过有选择性的复制来完成了这个**原始**程序，不过我不会让你们也尝试这么做。为了避免任何模糊的地方，整个**原始的**程序如下所示：

```lua
local io     = require "io";
local string = require "string";
local math   = require "math";

local look   = ''; -- 向前看字符
local lCount = 0;  -- Label计数

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

--[[ 读取一个标识符 ]]
local function getName()
    local name = '';
    while look == '\r' or look == '\n'
    do
        fin();
    end
    if not isAlpha(look)
    then
        expected("name");
    end
    name = upCase(look);
    getChar();
    skipWhite();
    return name;
end

--[[ 读取一个数字 ]]
local function getNum()
    local num = '';
    if not isDigit(look)
    then
        expected("integer");
    end
    num = look;
    getChar();
    skipWhite();
    return num;
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
    local name;
    name = getName();
    if look == '('
    then
        match('(');
        match(')');
        emitLine('callq ' .. name);
    else
        emitLine('movq ' .. name .. '(%rip),	%rax');
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
        emitLine("movq	$" .. getNum() .. ",	%rax");
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
local function doIf(L)
    match('i');
    condition();
    local L1 = newLabel();
    local L2 = L1;
    emitLine('jz ' .. L1);
    block();
    if look == 'l'
    then
        match('l');
        L2 = newLabel();
        emitLine('jmp ' .. L2);
        postLabel(L1);
        block();
    end
    match('e');
    postLabel(L2);
end

--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name = getName();
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
function block(L)
    while not skip_keywords[look]
    do
        if look == 'i'
        then
            doIf(L);
        elseif look == '\r' or look == '\n'
        then
            while look == '\r' or look == '\n'
            do
                fin();
            end
        else
            assignment();
        end
    end
end

--[[解析并翻译一个程序]]
local function doProgram()
    block();
    if look ~= 'e'
    then
        expected('End');
    end
    emitLine('END');
end

--[[ 初始化 ]]
local function init()
    lCount = 0;
    getChar();
end

-- 主程序从这里开始
init();
local token;
doProgram();

```

一些注释：
1. 表达式解析器的结构和之前的有些不同，如使用了`firstTerm`等。不过，这仍是在同一个大框架下的一个变体罢了。不过这个改动并不是必须的，不要让它吓到你了。
2. 需要注意我使用了调用函数`fin`的策略来处理多行程序。

在我们对它增加任何的更改前，请复制它并确认目前能正确编译程序。别忘了单字符版本的“语法”：‘i’指“IF”，‘l’指“ELSE”，而‘e’指“END”或“ENDIF”。

如果这个程序没有bug的话，那让我们继续吧。有一个系统的计划将对我们将扫描器添加到程序中产生很大的帮助。在我们目前所编写的所有版本的解析器中，我们都遵守着当前的前瞻字符总是一个非空白字符的约定。我们在init中加载第一个前瞻字符，并通过不断泵入前瞻字符保持程序的运行。为了保证当出现新行时这一切依然能正常工作，我们需要进行一些修改以便将换行符也当作一个合法的标识符。

在多字符的版本中，这一约定依然是相似的：前瞻字符中要么指向下一个标识的开头，要么指向一个新行。

多字符版本的程序将不ibei展示如下。我在原始程序上进行了如下的更改：
- 添加了变量`token`和`value`，以及`lookup`所需的变量定义。
- 添加了对`keywords`的定义。
- 添加了`lookup`。
- 将`getName`和`getNum`函数替换为了多字符的版本（需要注意对`lookup`的更新也已到了其中，这样就不用再`expression`中更新了。）
- 添加了名为`scan`的函数：调用`getName`并扫描关键字。
- 添加了新的函数`matchString`：查找一个特定的关键字。需要注意不同于`match`函数，`matchString`**并不会**读取下一个关键字。
- 在`block`中调用了`scan`。
- 更改了一些对于`fin`的调用。`fin`现在在函数`getName`中被调用。

接下来是整个更改后的程序：
```lua
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

```

如果你把这个版本和单字符的版本进行一些比较的话，你应该也会认为它们间的差别不大。

## 结论

目前为止，你已经学习了如何解析和编译表达式、布尔表达式和控制语句的代码了。你同样也学习到了如何写一个文法扫描器，并将其与其他部分整合成一个完整翻译器所需的知识。当然，你目前还没有见到将所有的元素整合进同一个程序中，不过在我们目前所打下的基础上，你应该能很轻易的将扫描器扩展到原有的程序中去。

我们距离学完编写一个真正能工作的编译器所需的知识已经不远了。不过我们还差了一些东西，也就是函数调用和类型定义。我们将会花费接下来几章的时间几章中来讨论它们。不过在那之前，我觉得先将我们上面的翻译器变成一个真正的编译器会更好玩一些。那这也就是我们下一张所需要做的事了。

而知道目前为止，我们目前都在使用一个自底向上的流程来进行我们的解析器的搭建：也就是从最基本的结构开始一步一步向上搭建。而在下一张中，我们同时会自顶向下的看看，并讨论一下语法的定义是如何影响我们翻译器的结构的。

下次见！:)

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译