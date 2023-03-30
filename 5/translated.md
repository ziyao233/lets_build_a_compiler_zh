# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第五章： 控制语句

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译
> 本文由泠妄在梓瑶的基础上编写代码

## 简介

在这个系列的前四章里，我们的主要关注点是解析数学表达式和赋值语句。在这一章里，我们将会进入一个令人激动的新话题：解析和翻译例如IF之类的控制一句。

这个话题最合我意，因为其代表了我自己的一个转折点。我一直在像本系列中所做的那样研究表达式，但我觉得距离我完全掌握如何处理一门完整的语言还有很长的一段路。毕竟，一门**真正**的语言还具有分支、循环和子程序等等。你可能也会有和我一样的想法。但在不久之前，我不得不为我的结构化编译器加上控制结构的支持。相信一下当我发现这比解析表达式简单得多的多时的惊讶吧。我还记得当时想“嘿！这真是太简单了！”。我相信在你阅读完这一章之后，你也会有同样的想法。

## 计划

接下来，我们会和前两次一样，从一个空白的基础开始向上面一层一层的添加东西。我们同样会继续遵循至今仍然保持良好的单字符标识符的理念。虽然这意味着我们的“代码”看起来会有点滑稽：`IF`将会用`i`来指代，而`WHILE`将会用`w`来指代，如此种种。但是这可以让我们在不用担心词法分析的情况下很好的掌握一些概念。不过不要担心，我们最终会来处理“真的”代码。

我也不想让我们在处理分支语句时，陷入处理比如赋值之类的其它语句的泥潭中。毕竟，我们已经证明了我们能处理它们，那我们何必在这次练习时还带着这些包袱呢？所以，我将会用一个叫"other"的匿名语句块来作为出控制语句之外的占位符。我们还是要生成一些代码（我们回到了编译器，而不是解释器），所以对于其它的这些部分我会直接输出输入的东西。

好的，让我们从另一份编译器的副本开始（相信我，你最好保留之前的版本），创建下面的一个函数：

```lua
--[[识别并翻译一个“其它”块]]
local function other()
    emitLine(getName());
end
```

现在让我们在主函数里调用它，也就是：

```lua
-- 主程序从这里开始
init();
other();
```

运行一下这个程序看看生成了什么。这并不是很令人激动。但别急，这只是个开始而已，一切都会越变越好的。

由于单行的分支很受限，我们所要做的第一件事是使其拥有处理多个语句的能力。我们已经在上一章讲述解析器时处理过了这个问题，但是这次让我们更正式的处理这个问题。考虑下面一段BNF描述：
```bnf
<program> ::= <block> END

<block> ::= [ <statement> ]*
```

上面这段BNF一位置，一个程序是一个由END语句(statement)结尾的语句块(block)，而一个语句块，则含有大于等于零个语句。目前为止，我们只有一种语句。

什么代表了一个语句块的结束呢？我们可以简单的认为任何不是`other`语句的结构都可以代表结束。对于现在来说，这意味着我们只有`END`语句。

在知道了上面的这些理念之后，我们可以开始构建自己的解析器了。这个函数的代码（作者把它叫做`doProgram`，因为Pascal会不乐）如下：

```lua
--[[解析并翻译一个程序]]
local function doProgram()
    block();
    if look ~= 'e'
    then
        expected('End');
    end
    emitLine('END');
end
```

注意到我在最后给汇编中输入了一个`END`命令。你可以认为这是输出代码中的一个标记。毕竟我们现在在解析一个完整的程序，这是完全合理的。

`block`函数的代码是：

```lua
--[[识别并翻译一个语句块]]
local function block()
    while look ~= 'e'
    do
        other();
    end
end
```

（从我们讲述的流程中，你可以看出来我们将会每次加入一点东西！）

好的，让我们将上面这些代码放到你的程序中。将`main`函数中对`block`的调用变为对`doProgram`的调用。现在让我们再来试试它是如何工作的。好吧，它依然做不了什么，但是我们距离目标越来越近了！

## 一些基础工作

在我们开始定义多种控制结构之前，先要打一些基础。首先我需要警告一下你：我不会使用和你熟悉的C语言或Pascal语言中相同的语法。例如，Pascal中的`IF`语法如下：

```Pascal
IF <condition> THEN <statement>
```

（而语句当然可能是符合语句）

C语言的版本很类似：

```C
if ( <condition> ) <statement>
```

我将使用的结构与它们都不相似，而是更像Ada中的格式：

```
IF <condition> <block> ENDIF
```

换种说法，IF结构游曳哥专门的结束标识符。这避免了Pascal中无法确定的`else`、C中所需的大括号`{}`，或begin-end之类的结构。之所以要用我给你展现的这种结构，是为了我们可以在之后的章节中更好的使用KISS原则。类似的，其它的结构也会有些许不同。这应该对你来说不是问题。毕竟在看到我们是如何处理这些结构的之后，你就会意识到你处理的语法格式具体是什么样并不重要。一旦语法格式被确定之后，我们能很直接的把它们转换为代码。

现在，对于所有我们需要处理的结构，都会涉及到流程跳转，也就是在汇编语言中对应的条件和/或无条件分支。例如，对于下面这个简单的IF语句：
```
IF <condition> A ENDIF B ....
```
必须被翻译为
```
    Branch if NOT condition to L
    A
L:  B
    ....
```

很显然，我们需要一些函数来帮我们处理这些分支。我在下面定义了两个这样的函数。`newLabel` 函数能生成唯一的标识符。这是通过简单的将每个标识符叫做`Lxx`，其中`xx`是一个从0开始的数字。而`postLabel`函数将这些标识符放到合适的位置。

这是两个函数的代码：
```lua
--[[生成一个唯一的标识符]]
local function newLabel()
    local label = 'L' .. string.format("%d",lCount);
    lCount = lCount + 1;
    return label
end

--[[输出一个标识符]]
local function postLabel(label)
    writeLine(label, ':');
end
```

注意到我们增加了一个新的全局变量`lCount`，所以你需要更改一下在程序最上方的变量定义：
```lua
local look = '';		-- 向前看字符
local lCount = 0;       -- Label计数
```

现在我想给你展示一种新的符号系统。如果你将IF语句的结构和我们必须对其生成的汇编代码相比，你能观察到语句中的每个关键词都与某个动作相关联：
```
IF :    首先，获取条件并为其生成代码
        接下来，创建一个新的标识符并生成如果条件为假的分支

ENDIF : 输出标识符
```

这些动作可以用下面这种语法来简单的描述：

```
IF
<condition> {   Condition;
                L = newLabel;
                emit(Branch False to L); }
<block>
ENDIIF      {   postLabel(L); }
```

这是语法驱动翻译(syntax-directed translation)的一个例子。我们其实一直在使用它，知识从未以这种形式写出来罢了。这种表示方法最好的地方在于，它不经展示出了我们需要识别的东西，还展现了我们需要执行的动作，以及该用哪种顺序来执行。一旦我们有了这个语法，代码几乎就已经自动写出来了。

唯一剩下的是就是`Branch if false`的定义更明确一些。

我假设在`<condition>`中需要执行的代码会使用布尔变量，并计算出一些代码。它同样需要根据结果设置条件标志。在如今，一种比较通用的方法是使用`64'b0`表示"false"（假），而其它的任何数就表示"true"（真）（也有些使用`64'b1`或者`64'b01`）。

在x86-64中，条件标志会在数据被移动或是计算时被设置。如果数据是`64'b0`（也就是代表假），则为零标志将会被置一。对应的的代码便是`jz`当zf被置一（也就是false）。所以对我们这里的目的来说：

```
    jz  <=> Brance if false
    jnz <=> Branch if true
```

应该不难想到我们大部分分支使用到的都会是`jz`指令。否则我们将会跳过需要执行的指令，并到达其它的分支。

## IF语句

经过上面的一些讲解之后，我们总算准备好编写解析IF语句的代码了。事实上，我们几乎已经写完了！和以前一样，我们将会遵循单字符的原则，并以字符'i'代表IF，字符'e'代表ENDIF（同时也代表END，因为这两个定义并不会产生冲突）。我现在也会暂时跳表示分支条件的字符，让我们像往常一样的在之后再定义它们。

函数`doIf`的代码如下：

```lua
local block;
local forward;

--[[识别并翻译一个IF结构]]
local function doIf()
    match('i');
    local L = newLabel();
    condition();
    emitLine('jz ' .. L);
    block();
    match('e');
    postLabel(L);
end
```

将这个函数添加到你的程序之中，并将`block`函数更改为如下形式：

```lua
--[[识别并翻译一个语句块]]
local function block()
    while look ~= 'e'
    do
        if look == 'i'
        then
            doIf();
        else
            other();
        end
    end
end
```

注意到上面使用了一个`condition`函数。最后我们将会限一个解析并翻译任何给出的布尔表达式的函数。但是，这需要完整的一章来讲述（事实上，就是下一章）。现在，让我们先创造一个假函数来输出一些文字。让我们编写下面这个函数：

```lua
--[[识别并翻译一个布尔表达式]]
--[[该函数并未被实现]]
local function condition()
    emitLine('<condition>');
end
```

在函数`doIf`之前插入这个这个函数。现在让我们试着运行这个程序。你可以尝试一下输入下面这个字符串：
`aibece`

你会发现lua报错了，这是因为我们使用了一个叫`writeLine`的函数。在原作者Pascal中I/O函数就是`WriteLn`，但是在lua中并没有这个东西。那，为什么我们不直接使用emitLine函数呢？在汇编中，我们一般会在指令之前加上缩进，而标识符之前不加缩进。而emitLine会自动加上缩进！虽然这不会影响汇编器，但是你看起来就不太好看了……

所以，让我们再加上一个函数：
```lua
--[[ 输出指定的字符串，然后换行]]
local function writeLine(s)
    io.write(s .. "\n");
end
```

现在我们再试试？

正如你所见，解析器似乎认出了结构并在正确的地方插入了代码。现在我们尝试将IF嵌套起来再试试，比如：
`aibicedefe`

它看起来不错吧！

现在既然我们知道了大体该怎么组（以及帮助我们这么做的工具，例如新的记号和函数`newLabel`、`postLabel`），现在在我们的解析器中很容易就能加入对其它结构的支持。我们要处理的第一个（也是最棘手的之一）结构，就是在IF后面加上ELSE。BNF表示如下：
```bnf
IF <condition> <block> [ ELSE <block> ] ENDIF
```

它很棘手是因为这是一个可选的部分，而在之前我们并没有处理过这种结构。

这个结构应该输出如下格式的代码：
```
    <condition>
    jz L1
    <block>
    jmp L2
L1: <block>
L2: ...
```

这让我们有了如下的语法驱动翻译：

```
IF
<condition>     { L1 = newLabel();
                  L2 = newLabel();
                  emitLine(jz L1); }
<block>
ELSE            { emitLine(jmp L2);
                  postLabel(L1); }
<block>
ENDIF           { postLabel(L2); }
```

只要将其和没有ELSE的IF比较一下，我们就能得到一些如何处理两种情况的线索。下面的代码便做了这件事（注意我在这里使用了字符'l'来代表ELSE，毕竟我们已经在上面使用了字符'e'）：

```lua
--[[识别并翻译一个IF结构]]
local function doIf()
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
```

现在你就有了一个使用19行代码就能处理一个完整IF语句的解析器/翻译器。

让我们来测试一下，比如:
`aiblcede`

好吧……你会发现它仍然不能运行……这是因为我们没有在`block`中排除关键字`l`，导致其认为是一个`other`结构！让我们加上`and look ~= 'l'`再试试。

它现在正常工作了吗？让我们再来测试一下没有ELSE的情况，确保它没有破坏之前已经完成的东西。比如试试
`aibece`

现在让我们再来试试把IF嵌套起来的情况。事实上，试试任何你想到的代码吧，它甚至可以是错误的。但是得记住，'e'和'l'字符不是一个合法的"other"结构。

说起来……我还想谈谈一件小事。注意到我们需要在`block`中排除所有的关键字了吗？当我们加入越来越多的关键字之后，`and`连接会变得很不好用……我们需要一些新的方法。对此，我们当然可以遍历一个数组来寻找是否在其中（我放了一个`isInArr`函数在代码中，你可以去看看）；但是更好的方法是利用lua里的弱引用表。其形式如下：
```lua
local keywords = {
	__mode="k, v",
	['e'] = 1,
	['l'] = 1
};

while not keywords[look] -- 判断是否在表中
```

但是，我们现在并不准备去谈论语法（我们还要写一个编译器呢！），其具体的解释会放在comment中。现在，让我们回到主线中吧！

## WHILE循环语句

既然我们已经有了前面那些基础，下面这种语句应该会很简单。对于WHILE语句，我选择的语法形式是：
```bnf
WHILE <condition> <block> ENDWHILE
```

好吧，好吧……我知道我们**真的**没必要将每种结构的终结符分成不同的形式……你可以从我们单字符的版本中，无论是哪种终结符都用字母'e'来表示。但是我也记得**许多**Pascal的调试器试着去追踪一个编译器认为我应该放到另一个地方的END语句。这使我觉得尽管不同的终结符增加了语言的关键字数量，但是却能用编译器处理其的一些额外工作换来一些错误寻找时的便利，这是很合算的。

现在，让我们考虑一下WHILE语句该被翻译成什么样的结构。结构应该是：
```
L1: <condition>
    jz L2
    <block>
    jmp L1
L2:
```

就和之前一样，让我们写成表示每次该做什么的语法：
```
WHILE       { L1 = newLabel();
              postLabel(L1); }
<condition> { emitLine(jz L2); }
<block>
ENDWHILE    { emitLine(jmp L1);
              postLabel(L2) }
```

代码在语法写出时就立刻被生成了：

```lua
--[[识别并翻译一个WHILE语句]]
local function doWhile()
	local L1, L2;
	match('w');
	L1 = newLabel();
	L2 = newLabel();
	postLabel(L1);
	condition();
	emitLine('jz ' .. L2);
	block();
	match('e');
	emitLine('jmp ' .. L1);
	postLabel(L2);
end
```

既然我们有了一个新的语句，让我们在`block`函数中调用它：
```lua
local skip_keywords = {
	__mode="k, v",
	['e'] = 1,
	['l'] = 1
};

--[[识别并翻译一个语句块]]
function block()
    while not skip_keywords[look]
    do
        if look == 'i'
        then
            doIf();
		elseif look == 'w'
		then
			doWhile();
        else
            other();
        end
    end
end
```

我们并不需要做出其它的更改。

好，让我们来试试新的程序吧。容易注意到，这次`<condition>`出现在了我们期望的地方，也就是最初标识的后面。试试吧循环嵌套起来吧。再试试加上IF的时候，比如IF在WHILE里面；或者WHILE在IF里面。不要害怕你对该输入什么样的代码而感到疑惑，毕竟你也在其它的语言中写过bug吧！我们之后会将关键词变为完整的单词，这样将会看起来意思更清楚一些了。

我相信你现在已经感受到了这件事真的很简单。当我们想要加入一个新的结构时，我们所需要做的仅仅是写出它的语法驱动翻译就完事了。此时代码几乎就自己出现在那了，并且这些代码并不会影响其它的结构。一旦你完全理解了这件事，添加一个新结构的速度反而会受限于你想到这种结构的速度。

## LOOP语句

我们现在已经有了一个可用的语言了，我们完全可以就此停下。很多该机语言其实也只有两个结构：IF和WHILE，毕竟它们已经足够你写出结构化的代码了。但是我们正因为发现了新方法在激动着呢！所以让我们再增加一点结构再其中吧。

下面这个结构简单极了，毕竟它不需要处理任何的条件语句。这就是无限循环。但等等，我们需要这个结构的意义在哪里？如果只有它自己的话，那确实没啥意义。但是之后我们会加入能给我们跳出这个循环的`break`语句。这让我们的语言比Pascal更丰富了，毕竟它没有`break`语句。同时，这也避免了C和Pascal中的`WHILE(1)`或者`WHILE TRUE`，我觉得这两种写法有点搞笑。

它的语法很简单：
```BNF
LOOP <block> ENDLOOP
```

而它的语法驱动翻译则是：
```
LOOP        { L = newLabel();
              postLabel(L); }
<block>
ENDLOOP     { emitLn(jmp L); }
```

下面就是对应的代码。因为我已经把字符`l`给ELSE了，我这次使用了字符`p`,也就是LOOP的最后一个字符，来作为关键字。

```lua
--[[识别并翻译一个LOOP语句]]
local function doLoop()
	match('p');
	local L = newLabel();
	postLabel(L);
	block();
	match('e');
	emitLine('jmp ' .. L);
end
```

当你加入这个语句时，别忘了再block函数里调用它。

## REPEAT-UNTIL

这是一个我从Pascal中抄来的结构。它的语法是：
```BNF
REPEAT <block> UNTIL <condition>
```

它的语法驱动翻译是：
```
REPEAT         { L = newLabel();
                 postLabel(L); }
<block>
UNTIL
<condition>    { emitLine(jmp L); }
```

和之前一样，代码很快就出来了：

```lua
--[[识别并翻译一个REPEAT语句]]
local function doRepeat()
	match('r');
	local L = newLabel();
	postLabel(L);
	block();
	match('u');
	condition();
	emitLine('jz ' .. L);
end
```

和往常一样，记得在`block`中调用`doRepeat`。不过这次有一点点不同。我决定用字符`r`来代表REPEAT（不然呢？），但是我同时决定了用字符`u`来代表UNTIL。这意味着你必须在`block`中也排除掉字符`u`。这些字符是退出当前语句块的标志……用专业编程的术语来说，也就是“跟随”字符("follow" charaters)。

```lua
--[[识别并翻译一个语句块]]
function block()
    while not skip_keywords[look]
    do
        if look == 'i'
        then
            doIf();
		elseif look == 'w'
		then
			doWhile();
		elseif look == 'p'
		then
			doLoop();
		elseif look == 'r'
		then
			doLoop();
        else
            other();
        end
    end
end
```

## FOR循环

FOR循环是很值得拥有的一个结构，但是翻译它有点难做。这并不是因为它的结构有多复杂……毕竟这只是个循环……这只是因为我们很难在汇编语言中实现它罢了。不过一旦我们搞清楚了代码该是什么样的，翻译它就是小菜一碟了。

喜欢C语言的人很喜欢这门语言里FOR循环的结构（事实上，这种结构也更容易实现），但是我决定转而使用像古老的BASIC语言中的语法：
```BNF
FOR <ident> = <expr1> TO <expr2> <block> ENDFOR
```

而对FOR循环翻译的难度就和你选择加入它一样，同时这取决于你设定的FOR循环的规定很你如何处理限制。expr2需要在每次循环时都要求值吗？还是直接把它转换成一个固定的常量作为限制呢？你要和FORTRAN一样至少执行一遍循环吗，还是不用这么做呢？不过如果把它翻译成下面这个等效形式，一切都会简单一点点：
```
<ident> = <expr1>
TEMP = <expr2>
WHILE <ident> <= TEMP 
<block>
ENDWHILE
```

需要注意在这个定义中，如果`<expr1>`最初就大于`<expr2>`的话，`<block>`根本就不会被执行。
用汇编代码来实现这个，比我们之前任何写过的东西都麻烦多了。我为此做了许多的尝试，比如把计数器和上限都放在栈里，或者都在不同的寄存器里……我最后想到而了一种混合了两种的方法：把计数器放在变量里（这样它就可以在循环里被使用了），然后把上界放在栈里。翻译后的代码长下面这样：
```
    <ident>                     // the name of the loop counter
    <expr1>                     // the initial value (lower limit) for the counter
    dec %rax                    // predecrement the counter
    movq <ident>(%rip), %rax    // save the counter
    <expr1>                     // the upper limit
    push %rax                   // save on the stack

L1: movq %rax, <ident>(%rip)    // fetch the counter
    inc %rax                    // increasement
    movq <ident>(%rip), %rax    // save the counter
    cmp %rax, (%rsp)            // check the range
    jgt L2                      // out of the loop
    <block>
    jmp L1                      // next loop
L2: addq %rsp, $8               // balance the stack
```

哇……这个语句的代码真多啊，你甚至都快找不到`<block>`
了。但是这已经是我能做到的最好的结果了……不过认为注意到这只有13行或许会打消一些关于长度的顾忌。如果你有更优的版本，请务必让我知道（并更改它）。

不过，我们依然能很简单的写出它的代码：
```lua
--[[解析并翻译一个FOR语句]]
local function doFor()
	match('f');
	local L1 = newLabel();
	local L2 = newLabel();
	local name = getName();
	match('=');
	expression();
	emitLine("deq %rax");
	emitLine("movq <ident>(%rip), %rax");
	expression();
	emitLine("push %rax");
	postLabel(L1);
	emitLine("movq %rax, <ident>(%rip)");
	emitLine("inc %rax");
	emitLine("movq <ident>(%rip), %rax");
	emitLine("cmp %rax, (%rsp)");
	emitLine("jgt " .. L2);
	block();
	match('e');
	emitLine("jmp " .. L1);
	postLabel(L2);
	emitLine("addq %rsp, $8")
end
```

既然我们目前的解析器还没实现`expression`（是的以前我们实现过……但是现在我们还没理清其它代码呢？），我和`condition`一样写了一个占位：
```lua
--[[识别并翻译一个表达式]]
--[[该函数并未被实现]]
local function expression()
    emitLine('<expr>');
end
```

让我们试试它吧。别忘了在`block`中加入新的调用！因为我们还没有给假的`expression`添加任何输入，所以一个典型的输入将会是：
`afi=bece`

好吧……它生成了一大堆代码呢。但是至少这些代码是**正确**的。

## DO语句

上面这个麻烦的FOR语句不禁让我想实现个简单点的版本。毕竟前面的需要一个能在循环里访问的变量作为循环及数据。如果我们只是想让一个循环执行特定次数的话，那可以有一个更简单的实现。这会是我们最后一个循环语句了。

那么它的语法翻译后是：
```
DO
<expr>      { L = newLabel();
              postLabel(L);
              emitLine(dec %rax )
              emitLine(push %rax )} 
<block>
ENDDO       { emitLine(pop %rax);
              emitLine(cmp %rax, $0);
              emitLine(jge L); }
```

这可简单多了！这将会执行`<expr>`次代码。
这是代码：

```lua
--[[解析并翻译一个DO语句]]
local function doDo()
	match('d');
	local L = newLabel();
	expression();
	postLabel();
	emitLine("dec %rax");
	emitLine("push %rax");
	block();
	emitLine("pop %rax");
	emitLine("cmp %rax, $0");
	emitLine("jgt " .. L)
end
```
我想你肯定会同意，这可比经典的for循环简单多了！同样的，在block里放下它。

## BREAK语句

之前我和你说过，我会写一个BREAK语句来配合LOOP语句。实际上，我很自豪于实现了这件事。在表面上看来，BREAK语句看起来很棘手。我的第一个想法是把它用作另一个结束语句块的方法，并像我在加上ELSE时对IF做的那样，用它将循环分为两部分。但实际上这是不可行的，毕竟BREAK几乎可以肯定不会出现在和循环一样级别的语句块中。它最有可能出现的地方是在IF的后面，而上面这种方法只会退出IF语句，而不是循环，这可是一个大大的错误。BREAK自己被好几层IF套着，它也得能跳出外层的循环。

我的另一个想法是将循环结束的标识符存在某个地方，比如全局变量中。可惜的是，这在一个外层循环有BREAK，内层循环也有BREAK的情况下不能被使用。于是这个全局变量得是一个栈。事情逐渐变得棘手起来。

最终我决定听听我之前给自己的建议。还记得上一章我们发现内置的栈对我们的递归下降解析器是多么的有用嘛？我还说过，当你觉得你需要使用一个在外部的栈时，你可能就开始做错什么了。好吧……这次我确实。实际上我们确实可以直接让我们的递归下降解析器做这些事，并且最终的解决方案会简单到令你惊讶。

这个方法的秘密在于：每个BREAK语句都必须出现在一个语句块中。毕竟……它还能在哪呢？所以我们唯一需要做的就是将最内层循环的结束地址一级一级的在每个语句块中传递下去。最终，这将会传到BREAK语句所在的语句块中并让我们能翻译它。既然IF语句并不会改变循环的层级，`doIf`指令除了将标识符传进所有的语句块（两个都要）外，什么也不用做。而循环语句**会**改变层级，每个循环结构只需要忽略任何传给它的标识符，并将它自己的传进去。

向你直接展示代码比直接向你描述并讲清楚它要简单多了。我将会用LOOP，也就是最简单的循环语句来展示：

```lua
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
```

要注意现在和之前的一个标识符不同，`doLoop`现在有**两个**标识符了。第二个标识符是为了给BREAK的跳转一个目标。当然，如果循环中没有BREAK，那我们就会浪费一个标识符并让代码复杂了一点。不过这么做是没有任何副作用的。

同时注意到现在`block`有一个参数了：循环的退出地址。新版的`block`函数如下：

```lua
--[[识别并翻译一个语句块]]
function block(L)
    while not skip_keywords[look]
    do
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
    end
end
```

同样注意到，尽管这些标识符需要被传到`doIf`和`doBreak`中，但是不需要传到任何的循环结构中。毕竟，它们有着自己的标识符。

新版的`doIf`是：

```lua
--[[识别并翻译一个IF结构]]
local function doIf(L)
    match('i');
    condition();
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
```

这里我们唯一需要更改的，就是把标识符作为参数，继续传进`block`中。一个IF语句并不会更改循环嵌套的级数，所以`doIf`只要传下去就行了。

不过要记住，`doProgram`函数同样也需要调用`block`函数，所以它也需要传进一个标识符。一个退出最外层语句块的尝试是错误，所以`doProgram`传了一个空标识符，并且由`doBreak`来报错：

```lua
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

--[[解析并翻译一个程序]]
local function doProgram()
    block('');
    if look ~= 'e'
    then
        expected('End');
    end
    emitLine('END');
end
```

上面这种方法**几乎**解决了所有事情。试试它吧，看看你能不能“打破”循环。不过你大概得注意一点……我们现在用了很多字母作为关键字，你可能得花一点功夫才能找出不是关键字的字母了。记住：在你测试你的新程序之前，别忘了在每个其它的`block`中传入新的参数，就和我之前在LOOP中做的那样。

我在上面说了**几乎**……因为我们有个小问题：如果你现在仔细看看DO语句生成的代码，你会发现，如果你直接跳出这个循环的话……计数器可还留在栈上呢。我们得修修这个问题！可惜的是……虽然这是一个比较简单的结构，但是这并没有帮助我们们更多。这是没有这个问题的全新版本：

```lua
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
```

多出来的subq和addq这两条语句帮我们成功平衡了栈。

## 结论

现在我们已经添加了很多的控制语句了……实际上，这些语句已经比很多其它的语言丰富了。以及，除了FOR之外，我们不费吹灰之力就做到了。甚至就连FOR也只是因为汇编语言才麻烦的。

那就让我们在此处结束这章吧。为了使事情简单一点，相比于使用这些米老鼠式的单字符，我们真的该来弄一些关键字了。在之前的章节，你已经看到了我们能很轻易的就扩展到多字符的版本。但是，这将会极大的提升我们输入代码的观感。我将会把这些留到下章再讲了。同时，在下一章中，我们将会讨论一下布尔表达式。这样我们就能摆脱现在`condition`的假代码了。我们下次见:)

为了提供一些参照，这是这章的完整解析器的代码。

```lua
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

--[[识别并翻译一个表达式]]
--[[该函数并未被实现]]
local function expression()
    emitLine('<expr>');
end

--[[识别并翻译一个布尔表达式]]
--[[该函数并未被实现]]
local function condition()
    emitLine('<condition>');
end

local block;
local forward;

--[[识别并翻译一个IF结构]]
local function doIf(L)
    match('i');
    condition();
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
	condition();
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
	condition();
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
	emitLine("movq <ident>(%rip), %rax");
	expression();
	emitLine("push %rax");
	postLabel(L1);
	emitLine("movq %rax, <ident>(%rip)");
	emitLine("inc %rax");
	emitLine("movq <ident>(%rip), %rax");
	emitLine("cmp %rax, (%rsp)");
	emitLine("jgt " .. L2);
	block(L2);
	match('e');
	emitLine("jmp L1 " .. L1);
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
```

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译
> 本文由泠妄在梓瑶的基础上编写代码