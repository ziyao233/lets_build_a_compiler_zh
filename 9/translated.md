# 动手构建一个编译器！

Jack W. Crenshaw, Ph.D.
24 July 1988

# 第九章：顶层的设计概念

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译

## 引入

在前面的章节中。我们已经学习到了搭建一个成熟的编译器所需的许多技术了。我们完成了赋值语句（包括布尔表达式和算术表达式的）、关系运算符和控制语句的编写。当然我们还没有解决过程或者函数调用的问题，但即便如此，我们也能搭建出一种没有这些语句的小语言了。我一直觉得探索人们到底能将一门最终仍实用的语言构建的到底有多小是很有趣的一件事。而我们**几乎**能做到这点了。唯一的问题是，虽然我们已经知道了如何解析和翻译这些结构，我们仍不知道怎么把它们组合成一种语言。

在之前的章节中，我们程序的搭建总是自底向上的。拿表达式解析为例，我们从最基础的结构、单独的常量和变量开始，再一步一步发展到更复杂的表达式中。

大多数人认为自顶向下的方法比自底向上的会更好一些。虽然我也这么认为，但对于我们所解析的东西而言，我们所用的方式显然看起来更自然一些。

不过，你一定不能认为我们在这个教程中所用的，慢慢增加东西的方法，都是自下而上的。在这章中，我将展示这种方法在自顶向下的方式中依然适用……事实上，可能反而更好。我们会尝试考虑些像例如Pascal或C的语言，并了解一个完整的编译器是如何自顶向下的来搭建的。

在下一章中，我们将会使用一些类似的技巧来为KISS的一个子集语言搭建一个完整的编译器，我将会叫这门语言TINY。但我这系列文章的目的不只是让你知道一个KISS或TINY的编译器是如何工作的，更是想让你能设计自己的语言并为其搭建一个编译器。C和Pascal的例子会很有帮助。而我想让你知道的一件事便是，编译器的结构自然而然的受到其翻译的语言的影响，所以构建编译器的难易程度很大程度上取决于这门语言决定的程序结构。

构建一门能编译C或者Pascal的编译器有点太繁杂了，因此我们不会在此进行完整的尝试。不过我们可以来看下一些顶层的设计概念，来让你知道这一切是如何进行的。

让我们开始吧。

## 顶层设计

在一个自顶向下的设计中，人们所犯的最大错误之一便是从真正的顶部开始。他们认为他们知道整个设计应该是怎样的，于是他们便开始编写了。

当我开始一个新设计时，无论它是什么，我总喜欢从头开始。在一个程序设计语言（program design language，PDL）中，顶部看起来总是类似于这样的一些东西：
```text
begin
    solve the problem
end
```

好吧，我承认这确实没有给我关于下一级是什么的太多信息，不过我仍想将它写下，只为了给我一种我的确是从最顶端开始的信心。

对于我们想解决的问题而言，编译器的总体功能是编译一个完整的程序。而任何以BNF编写的语言定义都从这里开始。那最顶层的BNF看起来是什么样的呢？好吧，这很大程度上取决于你想翻译的语言。让我们以Pascal为例。

## Pascal的结构

大多数关于Pascal的定义都包含一个它的BNF或者“铁道图”。这是其中的前几行：
```BNF
<program> ::= <program-header> <block> '.'

<program-header> ::= PROGRAM <ident>

<block> ::= <declarations> <statements>

```

我们可以像以前所做的那样，为每个元素写一个识别器来处理它。对于每一个元素。我们都将使用熟悉的单字符标识符来表示输入，然后每次增加一些功能。让我们从第一个识别器：程序本身，开始。

让我们复制一份全新的副本来翻译它吧。由于我们又回到了单字符标识符，我们将会使用‘p’来代表‘PROGRAM’。

在这份新的程序副本中加入以下代码，并在主程序中添加对它的调用：
```lua
--[[解析并翻译一个程序]]
local function prog()
	match('p');			--[[处理pargram-header部分]]
	local name = getName()
	prolog(name);
	match('.');
	epilog(name);
end
```

PROLOG和1PILOG函数是用来与系统进行交互的，使这个程序能被认为是一个可执行程序。不必说这部分一定是极度依赖于操作系统的。请记住，我在一台基于x86-64指令集，按gcc汇编标准来生成代码。你们可能在使用其它的环境并需要一些别的东西，但我已经无法改变这个环境了！

无论如何，想让gcc能与生成的代码交互还是很简单的。这里是`prolog`和`epilog`的代码：

```lua
--[[程序开始之前的部分]]
local function prolog(name)
	--[[主程序以main开始]]
	io.write(
[[
	.text
	.globl	main
	.type	main, @function
main:
	pushq	%rbp
	movq	%rsp, %rbp
]]);
	emitLine('call	'.. name);
	io.write(
[[
	movq    $0, %rax
	popq    %rbp
	ret
]]);
end

--[[程序结束之后的部分]]
local function epilog(name)
	emitLine('ret');
end
```

和往常一样，把这段代码加进去，然后尝试一下运行我们的“编译器”。目前只有一种合法的输入：
```text
px.
```
（x是这个程序的名称）

好吧，和往常一样，我们的第一次尝试的结果并不是很令人震惊。不过，我现在相信你现在已经知道了事情会越来越有趣了。这里有一个很重要的点：**输出是一份，能工作的，完整的，可执行的程序。**（至少在它被汇编之后是这样的）

这点是很重要的。自顶向下方法的一个很好的特点是，你可以在任何的时候编译一份完整语言子集的代码，并获得一个能在目标机器上运行的程序。从现在开始，我们只需要慢慢添加功能来充实语言的结构。这和我们之前一直做的事情是很相似的，只不过我们这一次是从另一端开始的。

## 充实它

接下来我们只需要一个一个的处理语言特性来充实我们的编译器。我喜欢从一个什么都不做的函数开始，然后向里面添加细节。这样我们从处理一个语句块开始吧，它的结构如上面的PDL所示。我们可以分两阶段完成首先，添加一个空的函数：
```lua
--[[识别并翻译一个pascal语句块]]
function doBlock(name)
end
```

然后修改`prog`来调用它：
```lua
--[[解析并翻译一个程序]]
local function prog()
	match('p');			--[[处理pargram-header部分]]
	local name = getName()
	prolog(name);
	doBlock(name);
	match('.');
	epilog(name);
end
```

这当然不应该改变我们程序目前的任何行为，而它的确没有。但现在，根据定义，`prog`已经完成了，我们可以继续充实`doBlock`。我们从它的BNF定义入手：
```lua
--[[识别并翻译一个pascal语句块]]
local function doBlock(name)
	declarations();
	postLabel(name);
	statements();
end
```

函数`postLabel`在讲述分支的章节中被定义。把它复制到你目前的程序中。

我或许应该解释一下为什么在这里插入这个标识。这与x86汇编的特性有关。与其他的语言不同，x86汇编允许你在程序的任何地方定义一个函数，并在任意地方使用它。你所需要做的就是给这个地方一个名字。而这里对于`postLabel`的调用正好把这个标识放在了函数的第一条可执行语句前。而我们在`main`函数中调用了这个函数，于是它便会跳转到这个Pascal的主函数中执行。（不给这个标识一个function type也是允许的。）

好的，我们现在需要函数`declarations`和`statements`。和之前一样，把它们定义为空函数。

程序还和之前一样可以运行，对吧？那我们可以进入下一部分了。

## 定义

Pascal declarations的BNF如下：
```BNF
<declarations> ::= ( <label list>    |
                    <constant list> |
                    <type list>     |
                    <variable list> |
                    <procedure>     |
                    <function>         )*
```

（请注意，我这里使用的是Turbo Pascal中更自由的定义。在标准Pascal的定义中，这些部分中的每一个都必须相对于其他部分按特定的顺序排列。）

和往常一样，让我们用单字符标识符来表示每个部分的定义。新的`declarations`函数如下：
```lua
--[[识别并翻译定义部分]]
local function declarations()
	while isInArr(look, {'l', 'c', 't', 'v', 'p', 'f'})
	do
		if look == 'l'
		then
			labels();
		elseif look == 'c'
		then
			constants();
		elseif look == 't'
		then
			types();
		elseif look == 'v'
		then
			variables();
		elseif look == 'p'
		then
			doProcedure();
		elseif look == 'f'
		then
			doFunction();
		end
	end
end
```

当然，我们需要为每一种定义写一个假函数。不过这次，他们不能是空函数，否则会创造出一个无限while循环。至少，每个识别函数必须吃掉引入它的标识符。向其中添加下列函数：
```lua
--[[处理label语句]]
local function labels()
	match('l');
end

--[[处理const语句]]
local function constants()
	match('c');
end

--[[处理type语句]]
local function types()
	match('t');
end

--[[处理var语句]]
local function variables()
	match('v');
end

--[[处理过程定义]]
local function doProcedure()
	match('p');
end

--[[处理函数定义]]
local function doFunction()
	match('f');
end
```

现在在我们的编译器中尝试几个具有代表性的例子。只要程序的最后一个字符是代表程序结束的‘.’，你可以按你的想法混合任意的定义。当然，这些定义实际上并没有定义任何东西，所以你不需，也不能使用除了关键字以外的任何字符。

我们可以使用类似的方法充实statement部分。它的BNF定义如下：
```BNF
<statements> ::= <compound statement>

<compound statement> ::= BEGIN <statement>
                            (';' <statement>) END
```
注意，statements可以以任何不是END的标识符开头。所以函数`statements`的下一个假程序如下:
```lua
--[[识别并翻译语句部分]]
local function statements()
	match('b');
	while not(look == 'e')
	do
		getChar();
	end
	match('e');
end
```

现在编译器能接受任意数量的声明，接着跟一个主函数的begin块。这个块中能接受除了END以外的任意字符，但END必须在最后出现。

现在最简单的输入如下：
```text
pxbe.
```

试试它吧，也试试其他的任何组合。故意犯一些错误，看看它会怎么做。

现在，你应该看出来这一切是如何进行的了。我们从处理这个程序的一个假翻译器开始，接下来根据它的BNF一次充实它的一个功能。正如低层次的BNF增加了细节，并更详细的说明了高层BNF的结构，低层级的识别函数也会解析输入程序的更多细节。当最后的一个假函数被扩展开来时，整个编译器就被完成了。这是最纯粹的自顶向下的设计/实现过程。

你可能会注意到，虽然我们一直在添加函数，这个程序的输出并没有改变。而这正是我们所期望的。在这些更高的层级上，没有代码需要被生成。这些识别函数正如，识别器，那样工作。它们接受输入的语句，找出错误的那些，并把正确的导向应该去的地方，所以它们的确在做应该做的工作。如果我们再坚持这个过程一段时间，代码就可以开始被生成了。

下一步我们扩展函数的应该是函数`statements`。Pascal对其的定义如下：
```BNF
<statement> ::= <simple statement> | <structured statement>

<simple statement> ::= <assignment> | <procedure call> | null

<structured statement> ::= <compound statement> |
                            <if statement>       |
                            <case statement>     |
                            <while statement>    |
                            <repeat statement>   |
                            <for statement>      |
                            <with statement>
```

这看起来有些熟悉了。事实上，你已经有了对赋值语句和控制结构进行解析和生成代码的经历。这正是我们自顶向下的方法和之前自底向上的方法相遇的时刻。Pascal的结构和之前使用的KISS的结构会有些不同，但这些不同应该是你所能处理的。

我认为你现在已经了解到这个过程的大致概念了。我们从一个描述该语言的完整BNF开始。从最顶端的层级开始，我们为这部分的BNF编写一个识别器，并用假函数代替次一层级的识别器。接下来我们一个接一个的充实这些低层级的语句。

碰巧的是Pascal的定义非常适用于用BNF进行表示，BNF对该语言的描述比比皆是。有了这些描述，你会发现继续我们上面开始的过程非常简单。

你可能会为了想继续感受一下这个过程，继续去充实其中的一些结构。我不期望你在此能完成一个完整的Pascal编译器……有太多我们还未解决的东西，比如程序和类型……但尝试一些更加熟悉的结构可能会对你有所帮助。看到可执行程序从另一端出来会对你很有好处。

我宁愿在KISS的语法下解决那些我们还没有涉及到的问题。我们现在还没有尝试构建一个完整的Pascal编译器，所以我将会在这里停下对Pascal编译器的扩展。让我们来看看另一种截然不同的语言。

## C的结构

正如你即将看到的那样，C语言完全是另外一回事。关于C结构的讲解很少会包含一份它的BNF。这可能是因为很难为这种语言编写BNF定义。（事实上，C语言的官方文档中有着它的BNF……很复杂）

向你展示这它的结构的一个原因是，我想让你清楚地认识到以下两个事实：
1. 语言的定义驱动了编译器的结构。对一种语言很有效的结构可能对另外一种语言而言是一种灾难。因此试图将给定的结构强加给编译器是一个非常糟糕的主意。相反，就像我们之前所做的那样，您应该让BNF驱动这种结构。

2. 难以编写BNF的语言可能也很难为其写一个编译器。C是一门很受欢迎的语言，并且以几乎允许你做你想做的任何事而闻名。尽管在Small C上取得了一些成功，C**并不是**一门易于解析的语言。

与Pascal程序相比，C程序的结构要更少。在顶层，C中的所有内容都是要么是数据，要么是函数的静态声明。我们可以如下的捕捉这种想法：
```BNF
<program> ::= ( <global declaration> )*

<global declaration> ::= <data declaration>  |
                        <function>
```

在Small C中，函数只能有未声明的默认类型int。这使得输入易于被解析：第一个标识符只能是“int”、“char”或者函数名。在Small C，中预处理命令也由编译器来处理，因此语法为：
```BNF
<global declaration> ::= '#' <preprocessor command>  |
                        'int' <data list>           |
                        'char' <data list>          |
                        <ident> <function body>     |
```

虽然我们对完整的C更有兴趣，我将会向你展示与Small C顶层结构相对应的代码：
```lua
--[[解析并翻译一个程序]]
local function prog()
    while not look == io.EOF
    do
        if look == '#'
        then
            preProc();
        elseif look == 'i'
        then
            intDecl();
        elseif look == 'c'
        then
            charDecl();
        else
            doFunction('int');
        end
    end
end
```

需要注意，这里我使用了EOF来表示输入的结束。 C语言没有END或者‘.’之类的来表示结束的标识。

在完整的C中，事情并没有这么简单。这是因为，在完整的C中，函数同样能有类型。所以当函数见到如int这样的关键字时，它仍然不知道这是一个变量定义或是一个函数定义。而下一个标识可能也不是名字，让这一切变得更加复杂……它可能以一个‘*’或‘(’，或这两者的任意组合开头。

更具体地说，完整C的BNF开头如下：
```BNF
<program> ::= ( <top-level decl> )*

<top-level decl> ::= <function def> | <data decl>

<data decl> ::= [<class>] <type> <decl-list>

<function def> ::= [<class>] [<type>] <function decl>
```

你现在可以看到问题在哪了：变量和函数的声明的前两部分可以是相同的。由于上面语法中的歧义，它并不是一个适合递归下降解析的语法。我们能转换这种语法让它变得可以被解析吗？当然，这需要一些努力。假如我们将BNF写成如下的形式：
```BNF
<top-level decl> ::= [<class>] <decl>

<decl> ::= <type> <type decl> | <function decl>

<typed decl> ::= <data list> | <function decl>
```

我们便可以为type和class写一个解析函数，将其结果存储在某处并继续，而不需要让它们“知道”现在正在处理的是一个变量声明还是一个函数定义。

首先，这个版本的关键主程序如下：
```lua
-- 主程序从这里开始
init();
while not(look == io.EOF)
do
    writeLine("BEG2");
    getClass();
    writeLine("BEG3");
    getType();
    writeLine("BEG4");
    topDecl();
end
```

对于现在而言，只要让这三个假函数除了调用`getChar`以外，不做任何事。

这个程序能正确运行吗？好吧，很难说它**不能**，毕竟我们并没有真正让它做任何事。有人说，C编译器几乎可以接受任何输入而不会阻塞。**这个**编译器到的确如此，因为它所做的实际上只是吃掉输入字符，直到找到EOF。

接下来，让我们让GetClass做一些有价值的事情吧。声明一个全局变量：
```lua
local class;
```

然后将`getClass`改为如下形式：
```lua
--[[获取并存储一个class specifier]]
local function getClass()
    if isInArr(look, {'a', 'x', 's'})
    then
        class = look;
        getChar();
    else
        class = 'a';
    end
end
```

这里我用了三个字符来表示三种存储形式：“auto”、“extern”和“static”。这些不是所有可能的种类……还有“register”和“typedef”，不过这些应该足以让你知道我们要怎么做了。需要注意默认的类型是“auto”。

我们可以对类型做类似的事，在接下来的函数中编写如下的代码：
```lua
local typ, sign;
--[[获取一个type specifier]]
local function getType()
    typ = ''
    if look == 'u'
    then
        sign = 'u';
        typ = 'i';
        getChar();
    else
        sign = 's';
    end

    if isInArr(look, {'i', 'l', 'c'})
    then
        typ = look;
        getChar();
    end
end
```

别忘了加入全局变量，`sign`和`typ`。

随着这两个函数的完成，编译器将会处理存储类型和类型声明，并且将他们的发现存储在某处。我们接下来就可以来处理声明的剩余部分了。

我们目前还没有走出困境，这是因为在我们了解真正的数据或是函数的名称之前，在类型的定义中就存在着许多的复杂性。让我们暂时假设我们已经解决了这些问题，且输入流的下一个东西就是名字。如果名称的后面跟了一个左括号，我们就有了一个函数声明。否则我们至少会有一个数据，或一个列表，其中的每个元素都可以有一个初始值。

添加如下版本的`topDecl`：
```lua
--[[处理一个顶层声明]]
local function topDecl()
    local name = getName();
    if look == '('
    then
        doFunc(name);
    else
        doData(name);
    end
end
```

（需要注意，既然我们已经获得了名字，我们必须要将它传给正确的函数流程。）

最终添加两个函数`doFunc`和`doData`：
```lua
--[[处理一个函数声明]]
local function doFunc(name)
    match('(');
    match(')');
    match('{');
    match('}');
    if typ == ' '
    then
        typ = 'i';
    end
    writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' function '.. name);
end

--[[处理一个变量声明]]
local function doData(name)
    if typ == ' '
    then
        expected('Type declaration');
    end
    writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' data '.. name);
    while look == ','
    do
        match(',');
        name = getName();
        writeLine(class .. ' ' .. sign .. ' ' .. typ .. ' data '.. name);
    end
    match(';');
end
```

由于我们离生成可执行的代码还有很长的一段距离，我决定让这两个函数告诉我们他们找到了什么。

好的，测试下这个新程序吧。对于变量声明，你可以给出一个以，分隔的列表。不过我们现在还无法处理初始值。我们同样无法处理函数的参数表，不过字符“(){}”依然应当跟在后面。

我们距离一个完整的C编译器还有很长的路要走，但我们已经开始处理正确的输入，并识别好的和坏的输入了。在这个过程中，编译器的结构开始自然的形成。

我们能继续这么做直到得到一个更像编译器的程序吗？当然了。但我们应该这么做吗？这就是另外一件事了。我不知道你如何想，但我已经开始有些头晕了，毕竟我们连光是完成变量声明都有很长的一段路要走。

现在我想呢，可以看到编译器的结构是如何从语言的定义演变而来的了。我们在Pascal和C这两种不同的语言中看到的结构天差地别。 Pascal的设计在一定程度上是为了易于解析，而这也反映在了编译器中。总的来说，在Pascal中有更多的结构，而我们对每种结构该出现在哪也有一个更好的了解。另一方面，在C语言中，程序本质上就是一个在文件尾结束的声明列表。

我们的确可以更深入的研究这两种语言的结构。但请记住，我们这里的目的并不是构造一个Pascal或C的编译器，而是研究编译器更一般的结构。对于那些**的确**想研究Pascal和C的人，我希望我已经给了你足够从这里开始的东西了（尽管你很快就会需要一些我们还没有讲到的东西，例如类型和过程调用）。对于其他的人，下一章中我们再见。在哪里，我将会带你们完成KISS的一个子集，TINY的完成编译器的编写。

下次见:)

> 版权许可
> Copyright (C) 1988 Jack W. Crenshaw. 保留一切权力
> 本文由泠妄翻译