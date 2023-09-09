# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第六章： 控制语句

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译
> 本文由泠妄在梓瑶的基础上编写代码

## 简介
在这个系列的第五章中，我们研究了一下控制结构，并成功将他们翻译为了汇编代码。最终，我们得到了一系列丰富且有用的结构。

但是在我们上一章中的解析器有一个功能上的大漏洞：我们没有区处理任何的条件！为了让它基本能工作，我给了你一个作为占位符的`condition`假函数，并让我们在之后填上这一点。

而我们在这章中要做的正是通过将`condition`函数变成一个真正的解析/翻译器，来填上这个大洞。

## 计划

在这章中，我们的流程会稍有不同。在其它章里，我们并不会进行多少计划，而是直接从最基本的代码开始，用lua编写出它的最终形式。这种方式一般不是很受欢迎，毕竟这被称作没有规范的编写代码。不过因为数学表达式的规则已经很清楚了，比如我们大家都知道‘+’是什么意思，我们之前可以这么做。而对于分支和循环也是这样的。但是，每种语言实现逻辑表达式的方法都略有不同。所以，在我们开始真正的编写前，我们最好能明确一下我们到底想做些什么。而在BNF级别建立语法规则便是这么做的方法。

## 语法

在此之前，虽然我们已经写了一些数学表达式的BNF结构，但是我们其实从来都没有把它们放在一起看看。现在就让我们来试试吧。它们分别为：
```BNF
<expression>::= <unary op> <term> [<addop> <term>]*
<term>      ::= <factor> [<mulop> factor]*
<factor>    ::= <integer> | <variable> | ( <expression> )
```
（还记得吗？上面这种语法结构可以很好的符合我们现实中的数学运算规则。）

事实上，既然我们要认真的讨论这件事，我想把上面的语法写的更详细一些。事实上，我们之前处理负号的方式有些怪怪的。我发现实际上语法写成下面这样会更好：
```BNF
<expression>    ::= <term> [<addop> <term>]*
<term>          ::= <signed factor> [<mulop> factor]*
<signed factor> ::= [<addop>] <factor>
<factor>        ::= <integer> | <variable> | ( <expression> )
```

这将我们处理负号的工作放在了它真正应该在的地方，也就是`factor`中。

但是这并不意味着你必须要现在就去改写之前的代码，不过你想做的话也不是不可以。总之这就是我们从现在开始要使用的语法。

现在你应该会很自然的想到我们可以以相似的方法来定义布尔表达式的语法。比如一种规范就是：
```BNF
<b-expression>    ::= <b-term> [<orop> <b-term>]*
<b-term>          ::= <not-factor> [AND factor]*
<not-factor> ::= [NOT] <b-factor>
<b-factor>        ::= <b-literal> | <b-variable> | ( <b-expression> )
```

不难注意到，在这个语法中，AND相当于‘*’，OR（和XOR）相当于‘+’。NOT被类比于了负号。这种语法优先级并不一定在所有语言中都适用，在某些语言，例如Ada中，所有的运算符都有着同样的优先级，不过这种语法结构看起来很自然。

同时也要注意到，NOT和负号之间是有一些小差别的。在数学中，负号一般被认为是作用于整个项上的而不是直接出现在一个项中。例如
$a * -b$
或者更糟糕的
$ a - -b $
都是不被允许的。但是在布尔表达式中，形如 `a AND NOT b` 的表达式是非常合理的，并且我们的语法也应该准许这么做。

## 关系运算符

好的，如果你接受我们上面提出的语法的话，那我们就有数学表达式和布尔表达式的语法规则了。但是麻烦的方法是将他们俩连接起来。但是我们为什么要做这件事呢？这是因为我们需要处理与诸如IF这样的控制语句连接的条件。这些条件必须要能得出一个布尔值，也就是必须要能求出真或者假。而是否执行这个分支就取决于这个计算出的值。所以我们想要在`conditon`函数中所做的事，就是求出一个布尔表达式的值。

但是实际中却不止于此。一个只有布尔变量的表达式确实可以用来处理诸如
```
IF a AND NOT b THEN ...
```
这样的控制语句。但是更普遍的，布尔表达式通常是下面下这个形式的：
```
IF ( x >= 0 ) and ( x <= 100 ) THEN ...
```
在这个表达式中，and左右的两项都是布尔值，但是其中的每项却对x、0、100这些数学项进行了比较。**关系运算符**正式将布尔值和和数学项连接起来的桥梁。

现在，正如上面那个式子所展现的，和一个项进行比较的就是：另一个项。换一个更普遍的说法，两端都是数学表达式。所以我们可以将**关系**定义为如下的形式：
```BNF
<relation> ::= <expression> <relop> <expression>
```
而其中的expression就是我们之前讨论过的数学表达式。而relop就是关系运算符`=, <> / != / ~=, <, <=, >, >=`。

如果你思考一下，你就会发现既然这项运算符产生的结果就是一个单独的布尔值TRUE或者FALSE，它其实就是另外一种布尔项而已。所以我们可以将一个布尔项的定义扩展为下面这种形式：
```BNF
<b-factor> :: =   <b-literal>
                | <b-variable>
                | ( <b-expression> )
                | <relation>
```

而这正是它们之间的联系！关系运算符和关系定义了两种运算之间的联系。值得注意的是，这同时让数学运算符的优先级高于了所有的布尔值，因此也高于了所有的布尔运算符。如果你写出所有运算符的优先级，那你会得到下面的一张表：

|优先级|语法结构|运算符|
|---|---|---|
|0|数学因子|数字，变量|
|1|有符号数学因子|一元运算符|
|2|数学项|*，/|
|3|数学表达式|+，-|
|4|布尔因子|字面量，变量，关系|
|5|非-因子|NOT|
|6|布尔项|AND|
|7|布尔表达式|OR，XOR|

这种语法结构看起来很合理，如果你愿意接受这么多优先级的话。只可惜……这没法用啊！这个优先级看起来非常合理，但在一个自顶向下解析器中这一点都不实用。我们来看看下面这个例子来找找问题：
```
IF (((((( A + B + C ) < 0 ) AND ... 
```

当解析器尝试解析这个代码时，它知道IF后面一定是一个布尔表达式。那它可以开始准备求解这个表达式了。但是它遇到的第一个却是个**算术**表达式`A + B + C`！更糟糕的是，在开始求值之后，它读了这么多东西：
```
IF ((((((A
```

但是却依然不知道它该处理什么。这是因为我们必须要识别出两种不同的情况。当然如果我们能接受任意多的回溯来处理错误的情况的化，我们确实能不去动上面定下的优先级。但是任何一个正常人写编译器时都不会这么做。

这里是优雅的BNF语法遇到编译技术的实际情况是出现的问题。

为了解决这个情况，编写编译器的人必须为了不让解析器回溯而对语法进行取舍。

## 解决语法上的问题

之所以我们会遇到这个问题，是因为布尔表达式和算术表达式都能包含报告。既然我们的定义是递归进行的，我们可以套无数层的括号，于是解析器便不知道它到处理的是什么。

而解决方案虽然会从根本上破坏我们之前的语法结构，但是却非常简单。我们只需要让括号仅能出现在一种表达式中即可。每种语言实现这个功能的方法都有所不同。我们并不能找到一个统一的标准。

当Niklaus Wirth设计Pascal语言的时候，他希望让语言具有更少的优先级（毕竟，这可以减少解析的流程）。所以OR和XOR被和Addop一样对待，同时在数学表达式中区处理它们。类似的，AND和Mulop一样被对待，并在数学项中处理。它的优先级列表是：
|优先级|语法元素|运算符|
|---|---|---|
|0|因子|字面量 变量|
|1|有符号因子|负号 NOT|
|2|项|* / AND|
|3|表达式|+ - OR|

注意到两种表达式都使用了同一套语法结构。根据这个语法，表达式 $ x + (y AND NOT z) / 3 $ 是完全合法的。实际上，在Pascal中，这是合法的……如果你把它当成一个特性而不是bug的话。Pascal语言不允许数学量和布尔变量被混在一起使用，并且这个报错并不是在解析时抛出的，而是在编译它们时在**语义**层面被检查并抛出。

而C语言的设计者们则采取了一个完全不同的做法：它把运算符都区别对待，并且优先级设计的更像我们的七级优先级。事实上，在C语言里有超过17级优先级！这是因为C中还有诸如`=`,`+=`,`-=`且`<<`,`>>`,`++`,`--`等等都有类似版本。奇怪的是，虽然在C语言中数学运算符和布尔运算符是被分开对待的，但是变量却**并不是**……在C中并没有逻辑变量（实际上0被认为是false，其它的都是true），所以你可以对任何整形进行布尔运算。

我们会用一个比较折中的方案。我曾希望尽量靠近看起来比较容易实现的Pascal的方法，方式这会产生一些我不喜欢的高校结果，比如表达式`IF (c >= 'A') and (c <= 'Z') then ...`，and两边的括号是**必须的**否则表达式不合法。由于之前并没有任何人或者我写的编译器来详细解释这一点，我并不知道这是为什么。但是我们现在知道了AND和乘法有同样的优先级，而显然这个优先级是比关系运算符的高的。所以如果我们不加括号的话，表达式实际相当于`IF C >= ('A' and c) <= 'Z' then ...`而这一点也不合理。

因此，我想则了将运算符分到不同的优先级中。当然，没有C语言中那么多。
```
 <b-expression> ::= <b-term> [<orop> <b-term>]*
 <b-term>       ::= <not-factor> [AND <not-factor>]*
 <not-factor>   ::= [NOT] <b-factor>
 <b-factor>     ::= <b-literal> | <b-variable> | <relation>
 <relation>     ::= <expression> [<relop> <expression>]
 <expression>   ::= <term> [<addop> <term>]*
 <term>         ::= <signed factor> [<mulop> factor]*
 <signed factor>::= [<addop>] <factor>
 <factor>       ::= <integer> | <variable> | (<b-expression>)
```

这个语法和之前七级优先级的语法是同一种。事实上……它们几乎相同。它只是去除了带括号的b-expression可能是一个b-factor，并让relation成为了一个合法的b-factor。

而让整一套东西能工作的是一个微小但是却非常关键的改变。让我们注意relation中的方括号，这意味着第二个expression和其间的relop都是**可选的**。

这个奇怪语法的结果（在C语言中也是）就是**每个**表达式都三一个潜在的布尔表达式。解析器永远会尝试去找一个布尔表达式，但是它最终会在算术中“停下”。说实在的，这会让解析器因为要走更多层的调用而变得更慢。这也是为什么Pascal的编译器总比C语言编译器快的一个原因。如果你单纯的就是想要速度，那么你可能更应该区贴近Pascal的语法。

## 解析器

在我们做完决定之后，我们终于可以开始编写一个解析器了。你应该已经进行过很多次这个流程了，所以你应该知到：从一份之前代码的拷贝开始，并一个个的添加函数。让我们开始吧。

让我们从像编写数学表达式时那样，只是处理的时布尔值而非变量开始。这给了我们一种新的输入，所以我们需要一个读入它和识别它的新流程。让我们就从编写这两个新函数开始吧：
```Lua
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
```

将它们添加到你的程序之中吧。你可以通过在主函数中添加这条语句来进行测试：
```Lua
writeLn(getBoolean());
```

好哒，让我们运行以下试试看。和之前一样，一开始并不是很惊艳，但是很快就会了。

在之前我们处理数字量的时候，我们需要生成代码来把它的值放到D0中。对于布尔量，我们也需要做相同的事。一般而言，对于一个布尔值，我们会用0来代表FALSE，而一个其它的值代表TRUE。很多语言，包括C，都用1来表示TRUE。但是我更希望用-1（或者0xFFFFFFFFFFFFFFFF）来代表FALSE，因为这样的话，一个对每位进行NOT就相当于一个布尔运算的NOT。我们需要一些正确代码来生成这些值。所以我们制作一个布尔表达式解析器的第一步就是：（boolExpression函数，废话）

```lua

--[[ 解析并翻译一个布尔表达式 ]]
local function boolExpression()
	if not isBoolean(look)
    then
        expected("Boolean Literal");
    end
    if getBoolean()
    then
        emitLine("movq %rax, $-1");
    else
        emitLine("xor %rax, %rax");
    end
end

```

把这个函数加到你的程序里，然后在主函数里调用它。我们现在还没有一个完整的解析器，不过它的输出已经开始有一些道理了！

接下来当然，我们需要把这个函数扩展到对b-expression的定义。我们已经有了它的BNF语法：
```BNF
<b-expression> ::= <b-term> [<orop> <b-term>]*
```

因为我们这里是单字符的版本，所以我会用这些符号'|'和'~'来代表或和非，而不是和Pascal或Python那样的'OR'和'XOR'。下一个版本的`boolExpression`函数几乎和数学版本的`expression`函数一样：
```lua

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

--[[ 解析并翻译一个布尔表达式 ]]
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

```

而其中识别函数`isOrop`，也几乎是和`isAddop`一样的：
```lua
--[[ 识别一个Orop ]]
local function isOrop(c)
	return c == '|' or c == '~';
end
```

好的，让我们吧之前那个`boolExpression`函数重命名为`boolTerm`函数，然后把上面这些代码加上去。让我们试试现在这个版本。现代它输出的结果看起来开始有点不错了。当然，只能对一些布尔常量进行运算不太合理，不过我们马上就会扩展到能处理这个问题的版本。

你可能已经猜到下一步是：布尔类型版本的`term`函数。

把当前的`boolTerm`函数变成`notFactor`函数，然后把下面`boolTerm`函数的代码加进去。由于这里没有除法，它看起来比数字版本的简洁多了：
```lua
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
```

现在我们几乎要完成了。虽然它依然只能处理常量，但是它能处理一些复杂的布尔表达式了。下一步是把NOT加进去。编写下面的函数：
```lua
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
```

然后继续把上面那个东西重命名为`boolFactor`（你应该知道是那个一直被改来改去名字的函数了吧）现在让我们再试试它。它现在应该能处理我们丢给它的任意布尔表达式了对吧！同时，它也应该能找出不正确的表达式了。

如果你是从数学表达式的解析器一路跟过来的话，你应该在想我们下一步该怎么把变量和括号加进去了。不过我们没必要在布尔项中来解决它们，因为下一步的函数将会来关照这些小东西的。我们只需要加一行来处理关系运算：
```lua
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
```

现在你大概在想：我们到底会在哪里处理变量和被括起来的布尔表达式了？答案是：我们**不会**去处理！别忘了，我们之前已经把这些东西拿出了我们的语法之中。我现在所在做的是，把我们之前认可的语法给编写成代码把了。编译器它本身并不能找出布尔版本的和数学版本的，一个表达式或变量之间的区别…它们两种版本都会在`relation`中被处理。

当然，这里如果我们已经有了`relation`函数的代码将会很棒。不过…我对在测试好我们已经编写好的代码之前就加入更多的东西不太放心。所以我们先写一个占位版本的`relation`函数来吃掉一个字符，并输出一条提示信息：
```lua
--[[ 解析并翻译一个关系 ]]
local function relation()
	writeLine("<Relation>")
    getChar();
end
```

好的，让我们把它插入进去然后试一试…之前的这些东西应该都能正常的工作，同时你能对AND,OR和NOT生成正确的代码。同时，俄uguo你输入了字母或任何它不认识的，它应该会在布尔因子所在的地方给你一个`<relation>`的占位符。如果你获得了正确的输出结果的话。让我们开始编写完整版本的`relation`函数吧。

在开始做这件事之前，我们需要先打一些基础。回想一下relation的定义：
```BNF
<relation> ::= | <expression> [<relop> <expression>]
```

既然现在我们有了一些新的运算符，我们需要一个新的函数来识别它们。因为我们单字符的限制，我使用了`=`而不是`==`来代表等于；`#`而不是`!=`来代表不等于：
```lua
--[[ 识别一个关系op ]]
local function isRelop(c)
	return c == '=' or c == '#' or c == '<' or c == '>';
end
```

（此部分见comment）
现在回想一下我们选用了0和-1来表示一个布尔值（在此忠于原作者），同时用这个来设置循环的标志位。想要在amd64上实现这个可棘手得多了。

因为是否循环只依赖于标志位，我们可以只设置标志位而不用把任何东西存进rax（同时性能也会更好一些）。但是布尔值可能在**任何**地方被使用，这导致我们有些时候必须在变量中存储这个值。而我们无法分辨这两种情况，所以我们必须设计一种通用的方法。

毕竟指令集已经自带了cmp指令，让数字进行比较是很容易的…但是比较只会设置标志位而非寄存器。

在amd64上解决这一问题的是指令setxx，其可以根据标志位把对应寄存器设置为0或1。而后我们需要将其转变为0或-1.这里有两个办法：乘上-1；减去1然后取反。但是不管哪种都会影响标志位，所以我们还要再test一下rax来确定值到底是多少。

这简直就是脱裤子放屁一样：我们得到了比较的结果，放入rax，再把它转换到0/-1，然后再检查比较的结果，然后再设置标志位…完全是在原地打转。不过，这是让一切能工作的一种很直接的方式，而且也只是多了几条指令而已。

在这里我想提一嘴，这便是编译器生成的代码和手工优化过的汇编代码最大的不同。哪怕我之后想向你展示一些优化的方法，但我们已经在数学运算中损失了很多性能了；我们也看到了控制语句其实可以更有效率一些，但优化IF和WHILE生成的代码真的很麻烦。但是几乎我见过所有简单的编译器生成的代码，特别是对于关系运算来说，和手工汇编对比起来都挺糟糕的。其原因就是我上面提到的那样。当我在直接编写汇编代码时，我会怎么方便怎么来，同时让分支朝着我想的方向走。但是简单的编译器并不能做到这点（在实际上），同时它也无法分辨我们的意图（是存储还是控制流程）。所以它必须按照一个很严格的顺序来生成代码，并且常常会存储之后根本用不到的东西。

你从这里也应该能感觉到，现在这些能把你整个函数乃至类都优化掉的编译器，到底留存了多少头发！

无论如何，现在我们已经准备好看看`relation`的代码了。它和它的小跟班被展示在下面：
```lua
--[[ 识别并翻译一个等于关系 ]]
local function equals()
	match('=');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('sete %al');
	emitLine('movzbq %al, %rax');
	emitLine('subq $1, %rax');
	emitLine('notq %rax');
end

--[[ 识别并翻译一个不等于关系 ]]
local function notEquals()
	match('#');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setne %al');
	emitLine('movzbq %al, %rax');
	emitLine('subq $1, %rax');
	emitLine('notq %rax');
end

--[[ 识别并翻译一个小于关系 ]]
local function less()
	match('<');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setg %al');
	emitLine('movzbq %al, %rax');
	emitLine('subq $1, %rax');
	emitLine('notq %rax');
end

--[[ 识别并翻译一个大于关系 ]]
local function greater()
	match('>');
	expression();
	emitLine('cmpq (%rsp), %rax');
	emitLine('setl %al');
	emitLine('movzbq %al, %rax');
	emitLine('subq $1, %rax');
	emitLine('notq %rax');
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
		emitLine("addq $8,	%rsp")
		emitLine('test %rax, %rax');
	end
end
```

在这里对于`expression`的调用是不是看起来好熟悉！这就是我们目前采用的架构的好处。我们已经在之前编写过`expression`和它的相关代码了，你可以直接把单字符版本的它们复制过来。不过我还是把相关的代码放在了下面。如果你足够细心的话，你还能发现我做了一些小改动。这是为了让它更符合我们的新语法。不过这些改动并**不是**必要的，所以你可以再确定一切正常之后再去动它们。

```lua
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
	end
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
	signedFactor();
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
```

现在你有了一个能同时处理数学表达式和布尔表达式的解析器，而这一切是通过关系运算符联系起来的。不过下一步我们要把它重构，我建议你为了在未来有份参照，把现在这个版本好好保存起来吧。

## 加入流程控制

那么现在，让我们翻出之前编写的流程控制语句解析器。还记得我们之前写的占位`condition`和`expression`函数嘛，现在你已经有真正的版本了。

不过这个过程中你可能得有点主观能动性，所以慢慢来，花时间让它跑起来吧。你所需要的是把从`ident`到`boolExpression`之间的程序复制到含有流程控制的解析器中，并用它们替换现在的占位函数。接下来把每个对`condition`函数的调用改为`boolExpression`函数，最后，把附属的函数也复制过去。这应该能让它正常运行了。

让我们运行以下试试。由于我们一段时间没碰它了，你可能得回顾一下IF, WHILE等语句分别是用什么标识符来代替的。同时也别忘了，任何不是关键字的字符都会被直接输出。

试试
```
ia=bxlyee
```

它的意思是
```
IF a=b
	X
else
	Y
ENDIF
END
```

结果还不错！再试试其它的例子吧。

## 加入赋值语句

现在我们已经有能解析运算语句的解析器了，我们可能会想把`block`换成真正的赋值语句。这不会很难，毕竟我们已经做过这件事了。不过在做这件事之前，我们需要先修一修其它地方。

我们很快就会发现，由于我们这个程序单行的限制，我们会遇到一点麻烦。现在我们的程序由于不认识换行字符，也就是回车CR，和换行LF。所以我们不妨县堵上这个洞再去做其它的事。

这里有许多种处理换行的方法。一种方法就是认为它们和空白字符无异，然后直接忽略他们（C/Unix的做法）。这并不是一种坏做法，不过这会在我们目前的解析器中产生一些不妙的结果。如果它能像一个知名的编译器一样读入文件，这种做法将会没有任何问题。但是我们现在是从键盘读入的，并且我们希望在按下回车时能有些反映。但是如果我们直接跳过它们的话，那将会什么都不发生（你可以去试试）。所以我在这里想使用另一种在长期运行时并不是最好的方法。你可以认为它是我们为了进行下一步的妥协吧。

与其跳过CR/LF，我们不妨让解析器找到它们，然后就像`skipWhite`一样只在“合法”的地方跳过它们。
```lua
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
```

然后像下面这样把它加到函数`block`中：
```lua
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
            other();
        end
		fin();
    end
end
```

x现在你可以处理一些“多行”的“程序”了，不过限制是你不能吧IF、WHILE和它们的分支关键字分开。

现在我们准备好添加赋值语句了。只要简单的把`block`中对`other`的调用改成对`assignment`的不过注意这里的`assignment`要调用的是`boolExpression`而不是`expression`，这样才能处理布尔变量。
```lua
--[[ 解析并翻译一个赋值语句 ]]
local function assignment()
    local name = getName();
    match('=');
    boolExpression();
	emitLine('movq ' .. name .. '(%rip), %rax');
end
```

在添加了以上的更变之后，虽然我们仍然受到单字符的限制，但你应该能写出比较接近于真实的程序了。我本来想去除掉这个限制的，但是这需要对我们现在的程序进行一些比较大的改动。我们需要一个真正的词法扫描器，而这需要我们对程序结构进行一些调整。当然，它们不是什么大的直接重构整个程序的变更，实际上这些变更可以只有很少一部分。不过我们确实需要注意一下这点。

这一张已经很长啦，同时其中还有着比较硬核的内容。所以我决定把这些内容留到下一章，这样你可以在消化完之前的内容并且有空余时间的时候再继续。

在下一章中，我们将会搭建一个词法扫描器，并一劳永逸的去除单字符的限制。我们同样也会在我们这章内容的基础上，写出我们的第一个完整的编译器。下次见！:)


> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译
> 本文由泠妄~~&copilot~~编写代码