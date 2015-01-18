# TODO:
# - find comments that were not used and dump them too
# - see if we can get comments at EOL to be attached to previous node
# - count method on Array
# - indexOf returns -1 instead of nil for find_index
# Not handled:
# - if x = f() changed into if (x = f()) not liked by JSHint; but if (x=f()) is OK
# - s << str is replaced by s += str (with error if s is a parameter)
# - chop!
# - local var declared in "then" or "else" stmt but used after the "if" block
# - 2 loops using same var for index => dupe decl in JS
# - self instead of this (we could detect we are in a cb block)
# - method calls with no params can be data members (Warning)
# - object.rw_attrib=(exp); the method is "rw_attrib=" and it works by chance, no issue...
# - break(value)
# - retry exception
# - iterators returned by each, upto, step, etc.
# - in "case" (switch) a break is generated even if last stmt is return or throw (JSHint complains)
# - map[:key] => map['key'] instead of map.key (JSHint complains)

require 'trollop'
require 'parser/current'

INTRO = "//Translated from #{@rubyFile} using babyruby2js\n'use strict';\n\n";
MAIN_CLASS = "main"


class RubyToJs

  def initialize(opts)
    @options = opts
    @classes = {}
    @publicVars = {}
    @publicVoidMethods = {}
    @stmtDecl = []
    @indent = 0
    @indentSize = 4 # in spaces
    @srcDir = @options.src
    @targetDir = @options.target
    @srcDir += "/" if @srcDir[-1]!="/"
    @targetDir += "/" if @targetDir[-1]!="/"
    enterClass(MAIN_CLASS)
  end

  def translateAll
    @showWarnings = false
    sources = getFiles(".")
    2.times do
      sources.each do |src|
        translateFile(src)
      end
      @showWarnings = true
    end
  end

  def getFiles(dir, files=nil)
    files = [] if !files
    Dir.entries(@srcDir+dir).each do |e|
      next if e[0] == "."
      path = dir+"/"+e
      if Dir.exists?(@srcDir+path) # subdir
        getFiles(path, files)
      else
        files.push(path) if e[-3..-1] == ".rb"
      end
    end
    return files
  end

  def translateFile(rubyFile)
    rubyFile += ".rb" if !rubyFile.end_with?(".rb")
    path, cname = buildJsFilename(rubyFile)
    jsFile = "#{@targetDir}#{path}#{cname}.js"
    createTargetDir(@targetDir+path)
    puts "Translating #{rubyFile} into #{jsFile}..."
    rubyFile = rubyFile[path.length..-1]
    @rubyFile = rubyFile
    srcFile = Parser::Source::Buffer.new(rubyFile)
    srcFile.source = File.read(@srcDir+path+rubyFile)
    jsCode = translateSrc(srcFile)
    File.write(jsFile, jsCode)
    puts "Completed #{jsFile}" if @options.debug
  end

  def createTargetDir(path)
    root = Dir.pwd
    path.split("/").each do |d|
      root += "/" + d
      Dir.mkdir(root) if !Dir.exists?(root)
    end
  end

  def buildJsFilename(rubyFile)
    slash = rubyFile.rindex("/")
    path = slash ? rubyFile[0..slash] : "./"
    mod = slash ? rubyFile[slash+1..-1] : rubyFile
    className = classNameFromFileName(mod)
    return path, className
  end

  def translateSrc(srcFile)
    # root = Parser::CurrentRuby.new.parse(srcFile)
    ast, comments = Parser::CurrentRuby.new.parse_with_comments(srcFile)
    @commentMap = Parser::Source::Comment.associate(ast, comments)
    @comments = comments

    if @options.debug
      puts "#{@rubyFile}:"
      p ast
      puts "\ncomments:"
      p @commentMap
      puts "\n"
    end
    
    @dependencies = {}
    code = stmt(ast)
    return INTRO + genDependencies() + code
  end

  def genDependencies
    res = ""
    @dependencies.each do |className,val|
      next if !val
      if val.is_a?(String)
        res += "var #{className} = #{val};#{cr}"
      else
        res += "var #{className} = require('./#{className}');#{cr}"
      end
    end
    return res
  end

  def newClass(name, parent)
    parentName = parent ? constOrClass(parent) : nil
    return {name: name, parent: parentName, methods: {}, members: {}, constants: {}}
  end

  def enterClass(name, parent=nil)
    @class = name
    @curClass = @classes[name]
    if !@curClass
      @curClass = newClass(name, parent);
      @classes[name] = @curClass
    end
    @classMethods = @curClass[:methods]
    @classDataMembers = @curClass[:members]
    @classConstants = @curClass[:constants]
    @private = false
  end

  def classDef(n)
    prevClass = @class
    enterClass(n.children[0].children[1].to_s, n.children[1])

    res = stmt(n.children[2])

    enterClass(prevClass)
    return res
  end

  def cr(indentChange=0)
    res = "\n"
    @indent += indentChange
    1.upto(@indent * @indentSize) { res<<" " }
    return res
  end

  # CR at beginning of block
  def crb
    cr(1)
  end

  # CR at end of block
  def cre
    cr(-1)
  end

  def comments(n)
    res = ""
    @commentMap[n].each do |c|
      txt = c.text[1..-1]
      txt = txt[1..-1] if txt[0]==" "
      res << "// #{txt}#{cr}"
    end
    return res
  end

  def stmt(n, mustReturn=false)
    code = exp(n, true, mustReturn)
    return "#{comments(n)}#{localVarDecl()}#{code}"
  end

  def exp(n, isStmt=false, mustReturn=false)
    return "error_nil_exp()" if n == nil
    semi = isStmt ? ";" : ""
    ret = mustReturn ? "return " : ""
    arg0 = n.children[0]

    case n.type
    when :begin
      return isStmt ? beginBlock(n, mustReturn) : bracketExp(n)
    when :block
      block(n, isStmt, mustReturn)
    when :class
      classDef(n)
    when :def
      newMethod(n)
    when :defs
      newMethod(n, true)
    when :send
      "#{methodCall(n,mustReturn)}#{semi}"
    when :self
      "#{ret}this#{semi}"
    when :int, :float
      "#{ret}#{arg0}#{semi}"
    when :true, :false
      "#{ret}#{n.type}#{semi}"
    when :nil
      return "null" if !isStmt
      return "#{ret}null#{semi}" if mustReturn
      return "//NOP"
    when :str
      str = arg0.to_s.gsub(/[\n\r\t']/, "\n"=>"\\n", "\r"=>"\\r", "\t"=>"\\t", "'"=>"\\'")
      "#{ret}'#{str}'#{semi}"
    when :sym
      "#{ret}'#{arg0.to_s}'#{semi}"
    when :regexp #(regexp (str "\\\"|,") (regopt)) for /\"|,/
      opt = n.children[1].children[1]
      "#{ret}/#{exp(arg0)}/#{opt ? opt : ''}#{semi}" 
    when :dstr #"abc#{@size}efg" -> (dstr (str "abc") (begin (ivar :@size)) (str "efg"))
      "#{ret}#{extrapolStr(n)}#{semi}"
    when :array
      "#{ret}[" + n.children.map{|v| exp(v)}.join(", ") + "]#{semi}"
    when :hash #(hash (pair (int 1) (str "a")) (pair (int 2) (str "b"))...
      "#{ret}{" + n.children.map{|p| "#{exp(p.children[0])}:#{exp(p.children[1])}"}.join(", ") +"}#{semi}"
    when :zsuper, :super
      return superCall(n.children, semi, ret)
    when :const
      "#{ret}#{constOrClass(n)}#{semi}"
    when :casgn #(casgn nil :ERROR (int 3))
      "#{constOrClass(n,true)} = #{exp(n.children[2])}#{semi}"
    when :ivar, :cvar, :lvar, :gvar
      "#{ret}#{varName(n)}#{semi}"
    when :op_asgn #(op_asgn (Xvasgn :@num_groups) :+ (int 1))
      op = n.children[1].to_s
      "#{exp(arg0)} #{op}= #{exp(n.children[2])}#{semi}"
    when :ivasgn, :cvasgn, :gvasgn #(ivasgn :@level (const nil :INFO)))
      return "#{varName(n)}" if !n.children[1] #for op_asgn
      "#{varName(n)} = #{exp(n.children[1])}#{semi}"
    when :lvasgn
      return "#{varName(n)}" if !n.children[1] #for op_asgn
      return localVarAssign(n, isStmt)
    when :masgn # (masgn (mlhs (lvasgn :i)(lvasgn :j)(lvasgn :k)) (lvar :x))
      return "error_masgn('#{arg0.type.to_s}')#{semi}" if arg0.type!=:mlhs
      arg0.children.each { |v| localVar(v) if v.type==:lvasgn }
      value = exp(n.children[1])
      i = -1
      assign = ""
      arg0.children.each { |v| i+=1; assign += "#{exp(v)} = _m[#{i}];#{cr}" }
      return "var _m = #{value};#{cr}#{assign}"
    when :return
      return "return [" + n.children.each.map{|v|exp(v)}.join(", ") + "]#{semi}" if n.children[1]
      return "return #{exp(arg0)}#{semi}" if arg0
      "return#{semi}"
    when :if
      return ifElse(n, isStmt, mustReturn)
    when :case
      return caseWhen(n, isStmt, mustReturn)
    when :while
      cond = exp(arg0)
      return "#{localVarDecl()}while (#{cond}) {#{crb}#{stmt(n.children[1])}#{cre}}"
    when :next
      "continue#{semi}"
    when :break
      return "error_break_value(#{exp(arg0)})#{semi}" if arg0
      "break#{semi}"
    when :or
      "#{exp(arg0)} || #{exp(n.children[1])}"
    when :and
      "#{exp(arg0)} && #{exp(n.children[1])}"
    when :yield
      @hasYield = true
      "#{ret}cb(#{exp(arg0)})#{semi}"
    when :kwbegin
      stmt(arg0)
    when :rescue
      catche = ""
      arg1 = n.children[1]
      if arg1
        asgn = arg1.children[1]
        vname = @curException = asgn ? asgn.children[0].to_s : "_exc"
        catche = " catch (#{vname}) {#{crb}#{stmt(arg1.children[2])}#{cre}}"
      end
      "try {#{crb}#{ret}#{stmt(arg0)}#{cre}}#{catche}"
    else
      "error_unhandled_exp('#{n}')#{semi}"
    end
  end

  def superCall(args, semi, ret)
    method = @curMethod=="initialize" ? "" : ".#{@curMethod}"
    params = args.length>0 ? ", " + args.map{|p| exp(p)}.join(", ") : ""
    return "#{ret}#{@curClass[:parent]}#{method}.call(this#{params})#{semi}"
  end

  def localVar(n)
    vname = n.children[0].to_s
    if !@localVars[vname]
      @localVars[vname] = true
      @stmtDecl.push(vname)
    end
    return vname
  end

  def localVarDecl()
    return "" if @stmtDecl.length==0
    res = "var " + @stmtDecl.join(", ") + ";#{cr}"
    @stmtDecl = []
    return res
  end

  def localVarAssign(n, isStmt)
    vname = localVar(n)
    semi = isStmt ? ";" : ""
    value = exp(n.children[1])
    if isStmt and @stmtDecl.length == 1 and @stmtDecl[0] == vname
      @stmtDecl = []
      return "var #{vname} = #{value}#{semi}" 
    end
    return "#{vname} = #{value}#{semi}" # if !isStmt or @stmtDecl.length==0
  end

  def ifElse(n, isStmt, mustReturn)
    cond = exp(n.children[0])
    res = isStmt ? localVarDecl() : ""
    if isStmt
      if n.children[1]==nil # "unless" has no "then" block but an "else"
        return "#{res}if (!(#{cond})) {#{crb}#{stmt(n.children[2],mustReturn)}#{cre}}"
      end
      res += "if (#{cond}) {#{crb}#{stmt(n.children[1],mustReturn)}#{cre}}"
      return res if !n.children[2]
      if n.children[2].type == :if
        return "#{res} else #{stmt(n.children[2],mustReturn)}" # else if...
      else
        return "#{res} else {#{crb}#{stmt(n.children[2],mustReturn)}#{cre}}"
      end
    else
      ret = mustReturn ? "return " : ""
      ifFalse = n.children[2] ? "#{exp(n.children[2])}" : "error_missing_else()"
      return "#{ret}( #{cond} ? #{exp(n.children[1])} : #{ifFalse} )"
    end
  end

  def caseWhen(n, isStmt, mustReturn)
    res = "switch (#{exp(n.children[0])}) {"
    n.children[1..-1].each do |wh|
      if wh.type == :when
        wh.children[0..-2].each { |val| res += "#{cr}case #{exp(val)}:" }
        res += "#{crb}#{stmt(wh.children[-1],mustReturn)}#{cr}break;"
        @indent -= 1
      else
        res += "#{cr}default: #{crb}#{stmt(wh,mustReturn)}#{cre}"
      end
    end
    return res + "}"
  end

  def extrapolStr(n)
    res = n.children.each.map { |s|
      s.type==:str ? exp(s) : bracketExp(s,true)
    }.join(" + ");
    res = "'' + " + res if n.children.length == 1 and n.children[0].type != :str
    return res
  end

  # This gets both constants and... classes!
  def constOrClass(n, declare=false) #(const nil :INFO) or (const (const nil :Logger) :DEBUG))
    cname = n.children[1].to_s
    if n.children[0] and n.children[0].to_s != @class
      raise "Invalid const declaration outside scope: #{n.children[0]}.#{cname}" if declare
      return "#{exp(n.children[0])}.#{cname}"
    end
    if declare
      @classConstants[cname] = true
    end
    if @classes[cname]
      @dependencies[cname] = true if @dependencies[cname]==nil
      return cname
    end
    return "#{@class}.#{cname}" if @classConstants[cname]
    # nothing specified and unknown so we suppose it is in main class
    return "#{mainClass}.#{cname}"
  end

  def mainClass
    @dependencies[MAIN_CLASS] = true
    return MAIN_CLASS
  end

  def varName(n)
    vname = n.children[0].to_s
    case vname[0]
    when "@"
      if vname[1] == "@"
        return "#{@class}.#{vname[2..-1]}"
      end
      vname = vname[1..-1]
      @classDataMembers[vname] = true
      return "this.#{vname}"
    when "$"
      return "window.globals.#{vname[1..-1]}"
    else
      return vname
    end
  end

  def methodAsLoop(method, args, code)
    return nil if method.type != :send
    methName = method.children[1]
    test = decl = incr = nil
    ndx = args.children.length == 1 ? args.children[0].children[0].to_s : "i"

    case methName
    when :upto
      v1 = exp(method.children[0])
      v2 = exp(method.children[2])
    when :downto
      v1 = exp(method.children[0])
      v2 = exp(method.children[2])
      test = "#{ndx} >= #{v2}"
      incr = "#{ndx}--"
    when :step
      v1 = exp(method.children[0])
      v2 = exp(method.children[2])
      step = method.children[3]
      if step.type == :int
        stepVal = step.children[0]
        if stepVal > 0
          incr = "#{ndx} += #{stepVal}"
        else
          incr = "#{ndx} -= #{stepVal.abs}"
          test = "#{ndx} >= #{v2}"
        end
      else
        stepVar = "_step#{ndx}"
        decl = "var #{ndx} = #{v1}, #{stepVar} = #{exp(step)}"
        test = "(#{v2} - #{ndx}) * #{stepVar} > 0"
        incr = "#{ndx} += #{stepVar}"
      end
    when :times
      v1 = 1
      v2 = exp(method.children[0])
    when :each, :reverse_each
      item = ndx
      ndx = "#{item}_ndx"
      arrayName = "#{item}_array"
      array = exp(method.children[0])
      if methName == :each
        decl = "var #{item}, #{arrayName} = #{array}, #{ndx} = 0"
        test = "#{item}=#{arrayName}[#{ndx}], #{ndx} < #{arrayName}.length"
      else
        decl = "var #{item}, #{arrayName} = #{array}, #{ndx} = #{arrayName}.length - 1"
        test = "#{item}=#{arrayName}[#{ndx}], #{ndx} >= 0"
        incr = "#{ndx}--"
      end
    else
      return nil
    end
    decl = "var #{ndx} = #{v1}" if !decl
    test = "#{ndx} <= #{v2}" if !test
    incr = "#{ndx}++" if !incr
    return "for (#{decl}; #{test}; #{incr}) {#{crb}#{stmt(code)}#{cre}}"
  end

  def newMethod(n, static=false)
    @parameters = {}
    @localVars = {}
    i = 0
    i+=1 if static
    methName = n.children[i].to_s
    jsMethName = normalizedMethodName(methName)
    @curMethod = methName
    @classMethods[methName] = true
    after = ";"
    if methName == "initialize"
      proto = "#{cr}/** @class */#{cr}function #{@class}("
      after = "#{cr}exports = #{@class};"
      parent = @curClass[:parent]
      if parent
        after = "#{cr}inherits(#{@class}, #{parent});" + after
        @dependencies["inherits"] = "require('util').inherits"
      end
    elsif static
      proto = "#{@class}.#{jsMethName} = function ("
    else
      proto = "#{@class}.prototype.#{jsMethName} = function ("
    end
    args = n.children[i+1]
    proto << methodArgs(args)
    @hasYield = false
    @indent += 1
    defaultValues = methodDefaultArgs(args)
    body = "#{stmt(n.children[i+2],true)}"
    @indent -= 1
    # if callback was called in body we need to add it as parameter
    proto << (args.children.length ? ", cb" : "cb") if @hasYield
    if !@private and args.children.length==0 and !@hasYield
      @publicVoidMethods[methName] = @class 
    end
    return "#{cr}#{proto}) {#{crb}#{defaultValues}#{body}#{cre}}#{after}#{cr}"
  end

  def methodArgs(n) #(args (arg :stone) (arg :lives))
    n.children.each do |a|
      vname = a.children[0].to_s
      @localVars[vname] = @parameters[vname] = true
    end
    return n.children.map {|a| a.children[0].to_s}.join(", ")
  end

  def methodDefaultArgs(args) # (args (optarg :size (int 19)))
    defaultValues = ""
    args.children.each do |a|
      if a.type == :optarg
        defaultValues << "if (#{a.children[0]} === undefined) #{a.children[0]} = #{exp(a.children[1])};#{cr}"
      end
    end
    return defaultValues
  end

  # (block (send (int 1) :upto (int 5)) (args (arg :j)) exp
  def block(n, isStmt, mustReturn)
    semi = isStmt ? ";" : ""
    method = n.children[0]
    args = n.children[1]
    code = n.children[2]
    asLoop = isStmt ? methodAsLoop(method, args, code) : nil
    return asLoop if asLoop
    # Ruby: @grid.to_text(false,","){ |s| ... }
    # => (block (send (ivar :@grid) :to_text (false) (str ",")) (args (arg :s)) ...
    func = "function (#{methodArgs(args)}) {#{crb}#{stmt(code,true)}#{cre}}"
    return "#{methodCall(method, mustReturn, func)}#{semi}"
  end

  def beginBlock(n, mustReturn)
    res = ""
    n.children[0..-2].each do |e|
      res += "#{stmt(e)}#{cr}"
    end
    res += "#{stmt(n.children.last, mustReturn)}"
    return res
  end

  def bracketExp(n, inDstr=false)
    raise "error " + n if n.type!=:begin
    raise "error begin_exp>1" if n.children.length>1
    return exp(n.children[0]) if inDstr
    return "(#{exp(n.children[0])})"
  end

  def genRequire(n)
    mod = exp(n)
    mod = mod[1..-2] if mod.start_with?("'")
    slash = mod.rindex("/")
    path = slash ? mod[0..slash] : ""
    mod = slash ? mod[slash+1..-1] : mod
    className = classNameFromFileName(mod)
    @dependencies[className] = false # no need to generate again
    return "var #{className} = require('#{path}#{className}')"
  end

  def classNameFromFileName(fname)
    fname = fname[0..-4] if fname.end_with?(".rb")
    return fname.split("_").map(){|w| w.capitalize}.join
  end

  def methodCall(n, mustReturn=false, block=nil)
    ret = mustReturn ? "return " : ""
    methName = n.children[1].to_s
    objAndMeth = nil
    arg0 = n.children[0]
    case methName
    when "<<"
      lvalue = exp(arg0)
      res = "#{lvalue} += #{exp(n.children[2])}"
      res += " + error_infinf_on_parameter('#{lvalue}')" if @parameters[lvalue]
      return res
    when "[]"
      arg1 = n.children[2]
      if arg1.type == :irange
        return "#{ret}main.newRange(#{exp(arg0)}, #{exp(arg1.children[0])}, #{exp(arg1.children[1])})"
      end
      return "#{ret}#{exp(arg0)}[#{exp(arg1)}]"
    when "[]="
      return "#{exp(arg0)}[#{exp(n.children[2])}] = #{exp(n.children[3])}"
    when "-@", "+@", "!" #unary operators
      return "#{ret}#{methName[0]}#{exp(arg0)}"
    when "="
      return "#{ret}#{exp(arg0)} #{methName} #{exp(n.children[2])}"
    when "+", "-", "*", "/", "<", ">", "<=", ">="
      return "#{ret}#{exp(arg0)} #{methName} #{exp(n.children[2])}"
    when "==", "!="
      return "#{ret}#{exp(arg0)} #{methName}= #{exp(n.children[2])}"
    when "==="
      return "#{ret}#{exp(arg0)}.test(#{exp(n.children[2])})"
    when "slice"
      return "#{ret}#{exp(arg0)}[#{exp(n.children[2])}]" if !n.children[3]
      return "#{ret}#{exp(arg0)}.substr(#{exp(n.children[2])}, #{exp(n.children[3])})"
    when "length"
      return "#{ret}#{exp(arg0)}.length" # not a method in JS
    when "first"
      return "#{ret}#{exp(arg0)}[0]"
    when "last"
      val = exp(arg0)
      return "#{ret}#{val}[#{val}.length-1]"
    when "strip", "lstrip", "rstrip", "downcase", "upcase", "sort"
      equiv = {"strip"=>"trim", "lstrip"=>"trimLeft", "rstrip"=>"trimRight",
        "upcase"=>"toUpperCase", "downcase"=>"toLowerCase", "sort"=>"sort"}
      return "#{ret}#{exp(arg0)}.#{equiv[methName]}()"
    when "pop", "shift", "message"
      return "#{ret}#{exp(arg0)}.#{methName}()" if n.children.length==2
    when "split"
      return "#{ret}#{exp(arg0)}.#{methName}()" if n.children.length==2
      return "#{ret}#{exp(arg0)}.#{methName}(#{exp(n.children[2])})" if n.children.length==3
    when "chop" # "chop!" not handled
      return "#{ret}#{mainClass}.strChop(#{exp(arg0)})"
    when "find_index"
      return "#{ret}#{mainClass}.indexOf(#{exp(arg0)}, #{exp(n.children[2])})"
    when "%" #(send (str "%2d") :% (lvar :j))
      return "#{ret}#{mainClass}.strFormat(#{exp(arg0)}, #{exp(n.children[2])})"
    when "chr"
      return "#{ret}String.fromCharCode(#{exp(arg0)})"
    when "ord"
      return "#{ret}(#{exp(arg0)}).charCodeAt()"
    when "to_i"
      return "#{ret}parseInt(#{exp(arg0)}, 10)"
    when "rand"
      return "Math.random()" if n.children[2]==nil
      return "~~(Math.random()*~~(#{exp(n.children[2])}))"
    when "round"
      return "Math.round(#{exp(arg0)})" if n.children[2]==nil
      arg1 = n.children[2]
      factor = arg1.type==:int ? 10**(arg1.children[0]) : "Math.power(10, #{exp(arg1)})"
      return "(Math.round((#{exp(arg0)})*#{factor})/#{factor})"
    when "abs"
      return "#{ret}Math.abs(#{exp(arg0)})"
    when "max"
      return "#{ret}Math.max.apply(Math,#{exp(arg0)})" if n.children.length==2
    when "now"
      return "#{ret}Date.now()"
    when "puts", "print"
      objAndMeth = "console.log"
    when "raise"
      return "throw #{@curException}" if n.children[2]==nil
      return "throw new Error(#{exp(n.children[2])})"
    when "backtrace"
      return "#{ret}#{exp(arg0)}.stack"
    when "new"
      objAndMeth = "#{ret}new #{exp(arg0)}"
    when "class"
      return "#{ret}#{exp(arg0)}.constructor"
    when "name"
      return "#{ret}#{exp(arg0)}.name"
    when "attr_reader"
      n.children[2..-1].each {|v| @publicVars[v.children[0].to_s] = true }
      return "//public read-only attribute: " + n.children[2..-1].map{|p| p.children[0]}.join(", ")
    when "attr_writer" #(send nil :attr_writer (sym :merged_with) (sym :extra_lives))
      #n.children[2..-1].each {|v| @publicVars[v.children[0]] = true }
      return "//public read-write attribute: " + n.children[2..-1].map{|p| p.children[0]}.join(", ")
    when "private"
      @private = true
      return "//private"
    when "public"
      @private = false
      return "//public"
    when "require_relative"
      return genRequire(n.children[2])
    when "require"
      return "//require #{exp(n.children[2])}"
    when "each" # we get here only if each could not be converted to a for loop earlier
      jsMethName = "forEach"
    else #regular method call
      jsMethName = normalizedMethodName(methName)
    end
    objAndMeth = "#{ret}#{objScope(arg0, methName)}#{jsMethName}" if !objAndMeth
    #add parameters to method or constructor call
    params = n.children[2..-1].map{|p| exp(p)}.join(", ")
    params << "#{params.length > 0 ? ', ' : ''}#{block}" if block
    return "#{objAndMeth}#{noParamsMethCall(methName)}" if params.length==0 and !block
    return "#{objAndMeth}(#{params})"
  end

  def objScope(n, methName)
    return "#{exp(n)}." if n
    return "this." if @classMethods[methName] or @classDataMembers[methName]
    return ""
  end

  def normalizedMethodName(methName)
    lastChar = methName[-1,1]
    case lastChar
    when "?", "!"
      return methName.chomp(lastChar)
    else
      return methName
    end
  end

  # This decides if we put "()" or not for a method call that could be a data accessor too
  # NB:in doubt, () is safer because of runtime error "not a function"
  def noParamsMethCall(methName)
    return "()" if @classMethods[methName] or (methName=="new")
    return "" if @classDataMembers[methName]
    meth = @publicVoidMethods[methName]
    var = @publicVars[methName]
    return "()" if meth and !var
    return "" if var and !meth
    return "() + error_both_var_and_method('#{methName}')" if var and meth
    puts "W001: #{@rubyFile}: #{methName}() unknown method" if @showWarnings
    return "()"
  end

end


opts = Trollop::options do
  opt :src, "Source root directory", :type => :string
  opt :target, "Target root directory", :type => :string
  opt :debug, "Show debug info", :default => false
end
puts "Command line options received: #{opts}"

t = RubyToJs.new(opts)
if opts.src
  t.translateAll
else
  puts "Usage: --src=<dir> [--debug=1]"
end
