require 'trollop'
require 'parser/current'
require 'json'
require_relative 'associator'


RANGE_FUNC = { :irange => "range", :erange => "slice" }

# Names renamed "brutaly" (can include reserved JS keywords)
RENAMED_WORDS = {
  :to_s => "toString",
  :eval => "_eval", :void => "_void"
}

# Functions for which translation is declared as "" here will be
# translated by #specialStdMethodCall().
# Functions which can accept 0 or 1 parameter appear twice
NO_PARAM_FUNC = {
  :strip => "trim", :lstrip => "trimLeft", :rstrip => "trimRight",
  :upcase => "toUpperCase", :downcase => "toLowerCase",
  :split => "split", :chop => "chop", :chomp => "chomp",
  :chop! => "chop!", # will break on purpose
  :sort => "sort", :pop => "pop", :shift => "shift",
  :join => "join", :count => "count",
  :first => "", :last => "", :length => "", :size => "", :keys => "",
  :chr => "", :ord => "", :to_i => "", :to_f => "",
  :rand => "", :round => "",
  :abs => "", :max => "", :now => "",
  :raise => "", :backtrace => "", :message => ""
}
ONE_PARAM_FUNC = {
  :split => "split", :chomp => "chomp", :push => "push",
  :start_with? => "startWith", :end_with? => "endWith",
  :join => "join", :count => "count",
  :find => "some",
  :is_a? => "", :instance_of? => "",
  :slice => "",
  :rand => "", :round => "",
  :raise => ""
}
TWO_PARAM_FUNC = {
  :assert_equal => "assertEqual", :between? => "between",
  :sub => "replace",
  :gsub => "", :slice => "", :[] => ""
}
THREE_PARAM_FUNC = {
  :assert_equal => "assertEqual",
  :assert_in_delta => "main.assertInDelta"
}
FOUR_PARAM_FUNC = {
  :assert_in_delta => "main.assertInDelta"
}

STD_CLASSES = {
  :Object => "Object", :String => "String", :Array => "Array",
  :Fixnum => "'Fixnum'", :Float => "'Float'",
  :Minitest => "main.TestCase"
}

MAIN_CLASS = :main
MAIN_CLASS_PATH = "./"


class RubyToJs

  def initialize(opts)
    @options = opts
    readConfig

    @classes = {}
    @publicVars = {}
    @publicMethods = {}
    @stmtDecl = []
    @indent = 0
    @indentSize = @cfg["tabSize"] # in spaces
    @camelCase = @cfg["camelCase"]

    @cur_comments = ""
    @cur_deco = ""
    @stacked_com = {}
    @stacked_com["C"] = []
    @stacked_com["D"] = []

    @rubyFilePath = MAIN_CLASS_PATH
    enterClass(MAIN_CLASS) # also needed to know class "main" is in root dir
    enterMethod(:"")
  end

  def readConfig
    configFile = File.dirname(__FILE__) + "/config.json"
    cfg = JSON.parse(File.read(configFile))
    @replacements = cfg["replacements"]
    localConfigFile = "./ruby2js.json"
    puts "Looking for config file #{localConfigFile}..."
    if File.exists?(localConfigFile)
      localCfg = JSON.parse(File.read(localConfigFile))
      @replacements.merge!(localCfg["replacements"])
      cfg.merge!(localCfg)
    end
    @cfg = cfg

    @srcDir = @options.src ? @options.src : cfg["src"]
    @targetDir = @options.target ? @options.target : cfg["target"]
    if (!@srcDir and !@options.file) or !@targetDir
      puts "Invalid arguments. Use --help or -h for help."
      exit
    end
  end

  def translateAll(single_file)
    sources = getFiles(".")
    # we "visit" all files once to learn about all classes
    sources.each { |src| translateFile(src, true) }
    # ...then we translate 1 or all of them
    if single_file
      translateFile(single_file)
    else
      sources.each { |src| translateFile(src) }
    end
  end

  def translateFile(filename, simple_visit=false)
    @showErrors = !simple_visit
    @jsFile, @rubyFilePath, @rubyFile = parseRubyFilename(filename)
    targetDir = path_join(@targetDir, @rubyFilePath)
    jsFile = "#{targetDir}#{@jsFile}.js"
    createTargetDir(targetDir)
    puts "Translating #{@rubyFile} into #{jsFile}..." unless simple_visit
    srcFile = Parser::Source::Buffer.new(@rubyFile)
    srcFile.source = File.read(path_join(@srcDir, @rubyFilePath) + @rubyFile)
    jsCode = translateSrc(srcFile)
    File.write(jsFile, jsCode) unless simple_visit
  end

  def getFiles(dir, files=nil)
    files = [] if !files
    Dir.entries(path_join(@srcDir, dir)).each do |e|
      next if e[0] == "."
      path = dir+"/"+e
      if Dir.exists?(path_join(@srcDir, path)) # subdir
        getFiles(path, files)
      else
        files.push(path) if e[-3..-1] == ".rb"
      end
    end
    return files
  end

  def createTargetDir(path)
    root = Dir.pwd
    path.split("/").each do |d|
      root += "/" + d
      Dir.mkdir(root) if !Dir.exists?(root)
    end
  end

  def translateSrc(srcFile)
    # Parse the source and comments
    ast, comments = Parser::CurrentRuby.new.parse_with_comments(srcFile)
    p ast if @options.debug
    associator = Parser::Source::Comment::Associator.new(ast, comments)
    @commentMap = associator.associate(true) # map_using_locations=true
    @usedComments = {}
    @errors = ""
    @unknownMethods = {}
    @dependencies = {}
    @blocks = []
    code = stmt(ast)
    trackMissingComments(comments, srcFile.source)

    intro = "//Translated from #{@rubyFile} using babyruby2js\n'use strict';\n\n"
    return doReplacements(intro + genAddedRequire() + code + @errors) + "\n"
  end

  def logError(level, code, msg)
    return unless @showErrors
    puts "  #{@rubyFile}: #{level}#{'%02d' % code}: #{msg}" 
    @errors << "\n// #{level}#{'%02d' % code}: #{msg}"
  end

  def doReplacements(jsCode)
    @replacements.each do |key,val|
      jsCode = jsCode.gsub(key, val)
    end
    return jsCode
  end

  def cr(code=nil)
    return "" if code == ""
    res = "#{code ? code : ''}\n"
    1.upto(@indent * @indentSize) { res<<" " }
    return res
  end

  # CR at beginning of block
  def crb
    @indent += 1
    cr
  end

  # CR at end of block
  def cre
    @indent -= 1
    cr
  end

  #--- Class

  def enterClass(name, parent=nil)
    parentName = parent ? const(:class, parent) : nil
    @class = name
    @curClass = @classes[name]
    if !@curClass
      @classes[name] = @curClass = {
        name: name, parent: parentName, directory: @rubyFilePath,
        methods: {}, members: {}, constants: {}
      }
    else
      @curClass[:parent] = parentName
    end
    @classMethods = @curClass[:methods]
    @classDataMembers = @curClass[:members]
    @classConstants = @curClass[:constants]
    @private = false
  end

  def classDef(n)
    prevClass = @class
    enterClass(n.children[0].children[1], n.children[1])
    body = n.children[2]

    # Pick up the initialize methods first
    constructorCode = ""
    if body and body.type == :begin
      init = body.children.find { |m| m.type == :def && m.children[0] == :initialize }
      if init
        storeComments(n) # class comments go with contructor
        attributes(body)
        constructorCode << cr(newMethod(init, true))
      end
    end
    if constructorCode == "" # no constructor
      if @jsFile == @class # if filename matches class name we create an empty constructor
        constructorCode = "#{cr}/** @class */#{cr}function #{@class}() {}#{cr}module.exports = #{@class};#{cr}#{cr}"
      else # filename does not match class name => we are extending a class in a separate file
        @dependencies[@class] = true
      end
    end

    classCode = constructorCode + stmt(body)

    enterClass(prevClass)
    return classCode
  end

  def attributes(body)
    body.children.each do |a|
      next if a.type != :send or a.children[0] != nil
      meth = a.children[1]
      attribute(a) if meth == :attr_reader or meth == :attr_writer
    end
  end

  #(send nil :attr_writer (sym :a) (sym :b))
  def attribute(n)
    names = ""
    n.children[2..-1].each do |v|
      symbol = v.children[0]
      jsname = jsName(symbol)
      checkConflictWithStdFunc(symbol, jsname, 0)
      @publicVars[symbol] = true
      storeComments(v)
      names << ", #{jsname}"
    end
    type = n.children[1] == :attr_writer ? "write" : "read-only"
    @cur_comments << "// public #{type} attribute: #{names[2..-1]}#{genCom('D')}#{cr}"
  end

  #--- Comments

  def _pushCom(n)
    return "","" if !n or !n.location
    comments = @commentMap[n.location]
    comments.each do |c|
      next if @usedComments[c.location]
      txt = c.text[1..-1]
      txt = txt[1..-1] if txt[0] == " "
      if c.location.line >= n.location.line
        @cur_deco << " // #{txt}"
        @stacked_com["D"].push(c)
      else
        @cur_comments << "// #{txt}#{cr}"
        @stacked_com["C"].push(c)
      end
    end
  end

  def _popCom(mode)
    case mode
    when "C", "R" #comments, raw comments
      res = @cur_comments
      @cur_comments = ""
      if mode=="R"
        res = res[3..-1].gsub(/\/\/ /, " *  ")+" " if res!=""
        mode = "C"
      end
    when "D" #decorative comments
      res = @cur_deco
      @cur_deco = ""
    end
    @stacked_com[mode].each { |c| @usedComments[c.location] = true }
    @stacked_com[mode].clear
    return res
  end

  # Stores the comments of a node, ready for JavaScript format
  def storeComments(n)
    _pushCom(n)
  end

  # Returns the stored comments for given mode (C, D or P)
  # If a node is passed, its comments are stored first
  def genCom(mode, node=nil)
    _pushCom(node) if node
    case mode
    when "C", "D", "R"
      return _popCom(mode)
    when "P" #parameters
      res = _popCom("C") + _popCom("D")
      return res == "" ? "" : "#{res}#{cr}"
    else
      raise "Invalid comment mode: #{mode}"
    end
  end

  def getCommentAssoc(c, src)
    nodeLoc = @commentMap.each_key.find { |nloc| @commentMap[nloc].find_index(c) }
    return "???" if !nodeLoc
    code = src[nodeLoc.expression.begin_pos...nodeLoc.expression.end_pos].split("\n")
    return code.length > 1 ? "#{code.first.strip}...#{code.last.strip}" : "#{code.first.strip}"
  end

  def trackMissingComments(comments, src)
    if @options.debug
      comments.each do |c|
        assoc = getCommentAssoc(c, src)
        puts "Comment: #{c.text} <- line #{c.location.line}: [#{assoc}]"
      end
    end
    return if comments.length == @usedComments.length
    comments.each do |c|
      next if @usedComments[c.location]
      assoc = getCommentAssoc(c, src)
      logError("W", 1, "lost comment: #{c.text} <- line #{c.location.line}: [#{assoc}]")
    end
  end

  #--- Statements and expressions

  def stmt(n, mustReturn=false)
    return "" if n == nil
    code = exp(n, true, mustReturn)
    return "#{genCom('C',n)}#{code}#{genCom('D')}"
  end

  def pexp(n)
    e = exp(n)
    return e if n.type != :send
    case n.children[1]
    when :+, :-, :*, :/, :%, :modulo, :==, :"!=" then return "(#{e})"
    else return e
    end
  end

  def exp(n, isStmt=false, mustReturn=false)
    return "error_nil_exp()" if n == nil
    semi = isStmt ? ";" : ""
    ret = mustReturn ? "return " : ""
    arg0 = n.children[0]
    storeComments(n) if !isStmt

    case n.type
    when :send
      call = "#{methodCall(n,mustReturn)}"
      call != "" ? "#{call}#{semi}" : "" #e.g. empty require do not generate a lone ";"
    when :begin then return isStmt ? beginBlock(n, mustReturn) : bracketExp(n)
    when :block then block(n, isStmt, mustReturn)
    when :class then classDef(n)
    when :def, :defs then newMethod(n)
    when :self then "#{ret}#{this}#{semi}"
    when :int, :float then "#{ret}#{arg0}#{semi}"
    when :true, :false then "#{ret}#{n.type}#{semi}"
    when :nil
      return "null" if !isStmt
      return "#{ret}null#{semi}" if mustReturn
      "//NOP"
    when :str
      str = arg0.to_s.gsub(/[\n\r\t']/, "\n"=>"\\n", "\r"=>"\\r", "\t"=>"\\t", "'"=>"\\'")
      "#{ret}'#{str}'#{semi}"
    when :sym then "#{ret}'#{arg0}'#{semi}"
    when :regexp #(regexp (str "\\\"|,") (regopt)) for /\"|,/
      opt = n.children[1].children[0]
      "#{ret}/#{exp(arg0)[1..-2]}/#{opt ? opt : ''}#{semi}" # we strip the str quotes
    when :dstr #"abc#{@size}efg" -> (dstr (str "abc") (begin (ivar :@size)) (str "efg"))
      "#{ret}#{extrapolStr(n)}#{semi}"
    when :array then "#{ret}[" + n.children.map{|v| exp(v)}.join(", ") + "]#{semi}"
    when :hash #(hash (pair (int 1) (str "a")) (pair (int 2) (str "b"))...
      "#{ret}{" + n.children.map{|p| "#{exp(p.children[0])}:#{exp(p.children[1])}"}.join(", ") +"}#{semi}"
    when :zsuper, :super then return superCall(n.children, semi, ret)
    when :const then "#{ret}#{const(:use,n)}#{semi}"
    when :casgn #(casgn nil :ERROR (int 3))
      "#{const(:decl,n)} = #{exp(n.children[2])}#{semi}"
    when :ivar, :cvar, :lvar, :gvar then "#{ret}#{varName(n)}#{semi}"
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
      return "( #{exp(arg0)} ? #{exp(n.children[1])} : #{exp(n.children[2])} )" if !isStmt
      return ifElse(n, mustReturn)
    when :case then return caseWhen(n, isStmt, mustReturn)
    when :while then return enterBlock + exitBlock("while (#{exp(arg0)}) {#{crb}#{stmt(n.children[1])}#{cre}}")
    when :next then return "continue#{semi}"
    when :break
      return "error_break_value(#{exp(arg0)})#{semi}" if arg0
      "break#{semi}"
    when :or then return "#{exp(arg0)} || #{exp(n.children[1])}"
    when :and then return "#{exp(arg0)} && #{exp(n.children[1])}"
    when :yield
      @hasYield = true
      "#{ret}cb(#{exp(arg0)})#{semi}"
    when :kwbegin then return stmt(arg0)
    when :rescue
      catche = ""
      arg1 = n.children[1]
      if arg1
        asgn = arg1.children[1]
        vname = @curException = asgn ? jsName(asgn.children[0]) : "_exc"
        catche = " catch (#{vname}) {#{crb}#{stmt(arg1.children[2])}#{cre}}"
      end
      "try {#{crb}#{ret}#{stmt(arg0)}#{cre}}#{catche}"
    else
      "error_unhandled_exp('#{n}')#{semi}"
    end
  end

  def superCall(args, semi, ret)
    method = @curMethod == :initialize ? "" : ".prototype.#{jsName(@curMethod)}"
    ret = "" if @curMethod == :initialize
    if args.length > 0
      params = ", " + args.map{|p| exp(p)}.join(", ")
    elsif @parameters.length > 0
      params = ", " + @parameters.map{|p| jsName(p)}.join(", ")
    else
      params = ""
    end
    return "#{ret}#{@curClass[:parent]}#{method}.call(#{this}#{params})#{semi}"
  end

  def localVar(n)
    vname = n.is_a?(String) ? n.to_sym : n.children[0]
    jsname = jsName(vname)
    if !@localVars[vname]
      @localVars[vname] = true
      @stmtDecl.push(jsname)
    end
    return jsname
  end

  def localVarDecl
    return "" if @stmtDecl.length==0
    res = "var " + @stmtDecl.join(", ") + ";#{cr}"
    @stmtDecl = []
    return res
  end

  def localVarAssign(n, isStmt)
    vname = localVar(n)
    semi = isStmt ? ";" : ""
    value = exp(n.children[1])
    if isStmt and @stmtDecl.last == vname
      @stmtDecl.pop
      return "var #{vname} = #{value}#{semi}" 
    end
    return "#{vname} = #{value}#{semi}"
  end

  def this
    return "this" if !@insideBlockFunc
    return "self" if @localVars[:self] # already declared above here
    @localVars[:self] = true
    # in all the blocks above...
    (@blocks.count - 1).downto(0) do |i|
      block = @blocks[i]
      block[0][:self] = true # 0=localVars
      next if block[2] # 2=insideBlockFunc
      # the block on top declares "self"
      block[1].push("self = this") # 1=stmtDecl
      return "self"
    end
    raise "Invalid state - self"
  end

  def enterBlock(type=:stmt)
    @blocks.push([@localVars, @stmtDecl, @insideBlockFunc])
    @localVars = @localVars.clone if type != :stmt
    @stmtDecl = []
    @insideBlockFunc = @insideBlockFunc || type == :func
    return ""
  end
  
  def exitBlock(code)
    decl = localVarDecl
    @localVars, @stmtDecl, @insideBlockFunc = @blocks.pop
    return decl + code
  end

  def ifElse(n, mustReturn)
    enterBlock
    cond = n.children[0]
    if !n.children[1] # "unless" has no "then" block but an "else"
      return exitBlock("if (!#{pexp(cond)}) {#{genCom('D')}#{crb}#{stmt(n.children[2],mustReturn)}#{cre}}")
    end
    ifPart = "if (#{exp(cond)}) {#{genCom('D')}"
    if !n.children[2] # if without else - variables in stmt can be declared in stmt
      return exitBlock(ifPart) + "#{crb}" + enterBlock + exitBlock(stmt(n.children[1],mustReturn)) + "#{cre}}"
    end
    ifPart << "#{crb}#{stmt(n.children[1],mustReturn)}#{cre}}"
    if n.children[2].type == :if # elsif
      return exitBlock("#{ifPart} else #{stmt(n.children[2],mustReturn)}")
    else # if else
      return exitBlock("#{ifPart} else {#{crb}#{stmt(n.children[2],mustReturn)}#{cre}}")
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
  def const(type, n) #(const nil :INFO) or (const (const nil :Logger) :DEBUG))
    cname = n.children[1]
    isConst = cname.upcase == cname
    if n.children[0] and n.children[0] != @class
      raise "Invalid const declaration outside scope: #{n.children[0]}.#{cname}" if type==:decl
      return "#{exp(n.children[0])}.#{cname}"
    end
    if type == :decl
      mainClass if @class == MAIN_CLASS # identify dependency on class "main"
      @classConstants[cname] = true
    end
    return STD_CLASSES[cname] if STD_CLASSES[cname]
    if @classes[cname]
      @dependencies[cname] = true if @dependencies[cname]==nil
      return cname
    end
    return "#{@class}.#{cname}" if @classConstants[cname]
    # nothing specified so we look in main class
    if !@classes[MAIN_CLASS][:constants][cname]
      logError("W", 2, "unknown #{isConst ? 'constant' : 'class'} supposed to be attached to #{MAIN_CLASS}: #{cname}")
    end
    return "#{mainClass}.#{cname}"
  end

  def mainClass
    @dependencies[MAIN_CLASS] = true
    return MAIN_CLASS
  end

  def varName(n)
    symbol = n.children[0]
    vname = jsName(symbol)
    case vname[0]
    when "@"
      if vname[1] == "@"
        return "#{@class}.#{vname[2..-1]}"
      end
      vname = vname[1..-1]
      varSym = symbol[1..-1].to_sym
      if !@classDataMembers[varSym] # first time we see this data member?
        logError("E", 6, "data overwrites method: #{vname}") if @classMethods[varSym] == vname
        @classDataMembers[varSym] = vname
      end
      return "#{this}.#{vname}"
    when "$"
      return "#{mainClass}.#{vname[1..-1]}"
    else
      return vname
    end
  end

  # method=(send (int 1) :upto (int 5))  args=(args (arg :i))  code=exp
  def methodAsLoop(n, args, code)
    return nil if n.type != :send or args.children.length > 1
    methName = n.children[1]
    decl = test = incr = nil
    ndx = args.children.length == 1 ? localVar(args.children[0]) : localVar("_i")
    declNdx = @stmtDecl.last == ndx ? "var " : nil
    @stmtDecl.pop if declNdx # we will declare the index inside the "for"

    case methName
    when :upto
      v1 = exp(n.children[0])
      v2 = exp(n.children[2])
    when :downto
      v1 = exp(n.children[0])
      v2 = exp(n.children[2])
      test = "#{ndx} >= #{v2}"
      incr = "#{ndx}--"
    when :step
      v1 = exp(n.children[0])
      v2 = exp(n.children[2])
      step = n.children[3]
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
        decl = "#{declNdx}#{ndx} = #{v1}, #{stepVar} = #{exp(step)}"
        test = "(#{v2} - #{ndx}) * #{stepVar} > 0"
        incr = "#{ndx} += #{stepVar}"
      end
    when :times
      v1 = 0
      test = "#{ndx} < #{exp(n.children[0])}"
    when :each, :reverse_each
      item = ndx
      ndx = "#{item}_ndx"
      arrayName = "#{item}_array"
      array = exp(n.children[0])
      if methName == :each
        decl = "#{declNdx}#{item}, #{arrayName} = #{array}, #{ndx} = 0"
        test = "#{item}=#{arrayName}[#{ndx}], #{ndx} < #{arrayName}.length"
      else
        decl = "#{declNdx}#{item}, #{arrayName} = #{array}, #{ndx} = #{arrayName}.length - 1"
        test = "#{item}=#{arrayName}[#{ndx}], #{ndx} >= 0"
        incr = "#{ndx}--"
      end
    when :each_key
      return "for (#{declNdx}#{ndx} in #{exp(n.children[0])}) {#{crb}#{stmt(code)}#{cre}}"
    when :loop
      return "for (;;) {#{crb}#{stmt(code)}#{cre}}"
    else
      return nil
    end
    decl = "#{declNdx}#{ndx} = #{v1}" if !decl
    test = "#{ndx} <= #{v2}" if !test
    incr = "#{ndx}++" if !incr
    return "for (#{decl}; #{test}; #{incr}) {#{genCom('D')}#{crb}#{stmt(code)}#{cre}}"
  end

  def enterMethod(methName)
    @parameters = []
    @localVars = {}
    @insideBlockFunc = false
    @curMethod = methName
    jsname = jsName(methName)
    if @classDataMembers[methName] == jsname
      jsname = "_" + jsname if @private
      logError("E", 5, "both data and method: #{methName}") if !@private
    end
    @classMethods[methName] = jsname
    @publicMethods[methName] = @class if !@private
    mainClass if @class == MAIN_CLASS and methName != :"" # identify dependency on class "main"
    return jsname
  end

  def newClassConstructor(n)
    @dependencies[@class] = false
    parent = @curClass[:parent]
    proto = "#{cr}/** @class #{genCom('R',n)}*/#{cr}function #{@class}("
    export = "#{@class}"
    export = "#{mainClass}.tests.add(#{export})" if parent == "#{MAIN_CLASS}.TestCase.Test"
    afterConstr = "#{cr}module.exports = #{export};"
    if parent
      afterConstr = "#{cr}inherits(#{@class}, #{parent});" + afterConstr
      @dependencies[:inherits] = "require('util').inherits"
    end
    return proto, afterConstr
  end

  def newMethod(n, doInitialize=false)
    isStatic = n.type == :defs
    i = isStatic ? 1 : 0
    symbol = n.children[i]
    return "" if symbol == :initialize and !doInitialize
    jsname = enterMethod(symbol)
    enterBlock(:meth)
    after = ";"
    if symbol == :initialize
      proto, after = newClassConstructor(n)
    elsif isStatic
      proto = "#{@class}.#{jsname} = function ("
    else
      proto = "#{@class}.prototype.#{jsname} = function ("
    end
    args = n.children[i+1]
    proto << methodArgs(args)
    lastParamCom = genCom("D")
    @hasYield = false
    @indent += 1
    defaultValues = methodDefaultArgs(args)
    body = "#{exitBlock(stmt(n.children[i+2],true))}"
    @indent -= 1
    # if callback was called in body we need to add it as parameter
    proto << (args.children.length ? ", cb" : "cb") if @hasYield
    checkConflictWithStdFunc(symbol, jsname, args.children.length + (@hasYield?1:0))
    return "#{proto}) {#{lastParamCom}#{crb}#{defaultValues}#{body}#{cre}}#{after}#{cr}"
  end

  def methodArgs(n) #(args (arg :stone) (arg :lives) (blockarg :fn))
    return "" if n.children.length==0
    res = jsname = ""
    n.children.each do |a|
      vname = a.children[0]
      jsname = jsName(vname)
      @localVars[vname] = true
      @parameters.push(vname)
      storeComments(a)
      break if a == n.children.last # for last param we don't want a "," and we want to leave its comments
      res << "#{jsname}, #{genCom('P')}"
    end
    return res + jsname
  end

  def methodDefaultArgs(args) # (args (optarg :size (int 19)))
    defaultValues = ""
    args.children.each do |a|
      if a.type == :optarg
        vname = jsName(a.children[0])
        defaultValues << "if (#{vname} === undefined) #{vname} = #{exp(a.children[1])};#{cr}"
      end
    end
    return defaultValues
  end

  # (block (send (int 1) :upto (int 5)) (args (arg :j)) exp)
  def block(n, isStmt, mustReturn)
    semi = isStmt ? ";" : ""
    method = n.children[0]
    args = n.children[1]
    code = n.children[2]
    asLoop = isStmt ? methodAsLoop(method, args, code) : nil
    return asLoop if asLoop
    # Ruby: @grid.to_text(false,","){ |s| ... }
    # => (block (send (ivar :@grid) :to_text (false) (str ",")) (args (arg :s)) ...
    func = "#{enterBlock(:func)}function (#{methodArgs(args)}) {#{genCom('D',args)}#{crb}" +
      exitBlock(stmt(code, true)) + "#{cre}}"
    return "#{methodCall(method, mustReturn, func)}#{semi}"
  end

  # Handles list of methods/constants in a class, list of statements in a method, etc.
  def beginBlock(n, mustReturn)
    res = ""
    n.children[0..-2].each { |e| res += cr(stmt(e)) }
    return res + stmt(n.children.last, mustReturn)
  end

  def bracketExp(n, inDstr=false)
    raise "error " + n if n.type!=:begin
    raise "error begin_exp>1" if n.children.length>1
    return exp(n.children[0]) if inDstr
    return "(#{exp(n.children[0])})"
  end

  def genRequire(n, standard=false)
    mod = exp(n)
    if standard
      requ = "//require #{mod}"
    else
      className, path = parseRubyFilename(mod)
      @dependencies[className] = false # no need to generate again
      requ = "var #{className} = require('#{path}#{className}')"
    end
    requ = @replacements[requ] if @replacements[requ]
    return requ
  end

  def genAddedRequire
    res = ""
    @dependencies.each do |className,val|
      next if !val
      if val.is_a?(String) # special dependencies (we stored what to translate as a string)
        requ = "var #{className} = #{val}"
      else
        cl = @classes[className]
        file = cl ? relative_path(@rubyFilePath, cl[:directory]) : "./"
        logError("E", 3, "unknown class: #{className}") if !cl
        requ = "var #{className} = require('#{file}#{className}')"
      end
      requ = @replacements[requ] if @replacements[requ]
      res += "#{requ};#{cr}" if requ != ""
    end
    return res
  end

  # e.g. "test/","test/ai/" => "./ai/"
  #   or "test/ai/","test/" => "../"
  def relative_path(from, to)
    res = ""
    f = from.split("/")
    t = to.split("/")
    while f.first == "." do f.shift end
    while t.first == "." do t.shift end
    while f.first and f.first == t.first do f.shift; t.shift end
    f.size.times do res << "../" end
    res << t.join("/") + "/" if t.first
    res = "./" + res if !res.start_with?(".")
    return res
  end

  def path_join(path1, path2)
    path = (path1.end_with?("/") ? path1 : path1 + "/")
    return path + (path2.start_with?("./") ? path2[2..-1] : path2)
  end

  # e.g. "./test/test_stone" => [:TestStone, "./test/", "test_stone.rb"]
  def parseRubyFilename(fname)
    fname = fname[1..-2] if fname.start_with?("'") or fname.start_with?('"')

    fname = fname.gsub(/\\/, "/")
    slash = fname.rindex("/")
    path = slash ? fname[0..slash] : "./"
    path = "./" + path if !path.start_with?(".")
    fname = fname[slash+1..-1] if slash
    fname = fname.chomp(".rb")
    
    className = fname.split("_").map{|w| w.capitalize}.join.to_sym
    return className, path, fname+".rb"
  end

  # e.g. :play_at! => "playAt", :@_all_enemies => "_allEnemies"
  def jsName(rubyName)
    renamed = RENAMED_WORDS[rubyName]
    return renamed if renamed
    name = rubyName.to_s
    name = name.chomp("?").chomp("!")
    return name if !@camelCase
    # NB: we want to "preserve" a leading underscore hence using split("_") is awkward
    pos = 0
    while name[pos] == "@" do pos += 1 end
    pos += 1 # skip 1st char (or 1st after @)
    while (pos = name.index("_", pos)) do
      name = name[0..pos-1] + name[pos+1..-1].capitalize
    end
    return name
  end

  # if there is std method with same # parameters but != translation, it will go wrong
  def checkConflictWithStdFunc(funcName, jsname, num_param)
    return if !@showErrors
    stdFunc = getStdMethodInfo(funcName, num_param)
    if stdFunc and stdFunc != jsname
      logError("E", 4, "user method hidden by standard one: #{funcName}")
    end
  end

  def methodNew(arg0, num_param, block)
    return "new #{exp(arg0)}" if arg0.type != :const
    storeComments(arg0)
    klass = const(:class,arg0)
    # for 0 or 1 param JS is same as Ruby (except items are filled with "undefined" instead of null)
    return "Array.new" if klass == "Array" and (num_param > 1 or block)
    return "new #{klass}"
  end

  #  method handled here should be added to NO_PARAM_FUNC and others
  def specialStdMethodCall(n, ret, block)
    arg0 = n.children[0]
    num_param = n.children.length - 2

    case n.children[1]
    when :slice, :[] # NB: ruby's slice is different than JS one - we only do the string one
      return "#{ret}#{exp(arg0)}[#{exp(n.children[2])}]" if num_param==1
      return "#{ret}#{exp(arg0)}.substr(#{exp(n.children[2])}, #{exp(n.children[3])})"
    when :first then return "#{ret}#{exp(arg0)}[0]"
    when :last
      val = exp(arg0)
      return "#{ret}#{val}[#{val}.length-1]" # we could also implement .last()
    when :length, :size then return "#{ret}#{exp(arg0)}.length" # length is not a method in JS
    when :keys then return "#{ret}Object.keys(#{exp(arg0)})"
    when :to_i then return "#{ret}parseInt(#{exp(arg0)})"
    when :to_f then return "#{ret}parseFloat(#{exp(arg0)})"
    when :chr then return "#{ret}String.fromCharCode(#{exp(arg0)})"
    when :ord then return "#{ret}#{pexp(arg0)}.charCodeAt()"
    when :gsub
      pattern = "#{exp(n.children[2])}"
      return "#{ret}#{exp(arg0)}.replace(#{pattern}g, #{exp(n.children[3])})" if n.children[2].type == :regexp
      return "#{ret}#{exp(arg0)}.replaceAll(#{pattern}, #{exp(n.children[3])})"
    when :rand # rand or rand(number) (global method in ruby)
      return "#{ret}Math.random()" if num_param==0
      return "#{ret}~~(Math.random()*~~(#{exp(n.children[2])}))"
    when :round # number.round([number])
      return "#{ret}Math.round(#{exp(arg0)})" if num_param==0
      arg1 = n.children[2]
      factor = arg1.type==:int ? 10**(arg1.children[0]) : "Math.power(10, #{exp(arg1)})"
      return "#{ret}(Math.round(#{pexp(arg0)} * #{factor}) / #{factor})"
    when :abs then return "#{ret}Math.abs(#{exp(arg0)})"
    when :max then return "#{ret}Math.max.apply(Math, #{exp(arg0)})" # array.max
    when :now then return "#{ret}Date.now()" # Time.now
    when :raise # raise or raise exp
      return "throw #{@curException}" if num_param==0
      return "throw new Error(#{exp(n.children[2])})"
    when :backtrace then return "#{ret}#{exp(arg0)}.stack" # exception.backtrace
    when :message then return "#{ret}#{exp(arg0)}.message" # message is not a method in JS
    when :is_a?
      klass = n.children[2]
      logError("W", 3, "isA('Float',n) is true for all numbers") if klass.type==:const and klass.children[1]==:Float
      return "#{ret}#{mainClass}.isA(#{exp(klass)}, #{exp(arg0)})"
    when :instance_of? then return "#{ret}#{mainClass}.instanceOf(#{exp(n.children[2])}, #{exp(arg0)})"
    else
      return nil
    end
  end

  def getStdMethodInfo(symbol, num_param)
    case num_param
    when 0 then return NO_PARAM_FUNC[symbol]
    when 1 then return ONE_PARAM_FUNC[symbol]
    when 2 then return TWO_PARAM_FUNC[symbol]
    when 3 then return THREE_PARAM_FUNC[symbol]
    when 4 then return FOUR_PARAM_FUNC[symbol]
    else return nil
    end
  end

  def stdMethodCall(n, ret, block)
    arg0 = n.children[0]
    symbol = n.children[1]
    num_param = n.children.length - 2 + (block ? 1 : 0)
    func = getStdMethodInfo(symbol, num_param)
    return nil if !func
    return specialStdMethodCall(n, ret, block) if func == ""
    return "#{ret}#{func}(#{genMethParam(n, block)})" if !arg0
    return "#{ret}#{pexp(arg0)}.#{func}(#{genMethParam(n, block)})"
  end

  def methodCall(n, mustReturn=false, block=nil)
    ret = mustReturn ? "return " : ""
    std = stdMethodCall(n, ret, block)
    return std if std

    arg0 = n.children[0]
    symbol = n.children[1]
    num_param = n.children.length - 2
    objAndMeth = nil

    case symbol
    when :<<
      lvalue = exp(arg0)
      res = "#{lvalue} += #{exp(n.children[2])}"
      res += " + error_infinf_on_parameter('#{lvalue}')" if @parameters.find_index(lvalue)
      return res
    when :[]
      arg1 = n.children[2]
      range = RANGE_FUNC[arg1.type]
      return "#{ret}#{exp(arg0)}.#{range}(#{exp(arg1.children[0])}, #{exp(arg1.children[1])})" if range
      return "#{ret}#{exp(arg0)}[#{exp(arg1)}]"
    when :[]=
      return "#{exp(arg0)}[#{exp(n.children[2])}] = #{exp(n.children[3])}"
    when :-@, :+@, :! # unary operators
      return "#{ret}#{symbol[0]}#{exp(arg0)}"
    when :"=", :+, :-, :*, :/, :<, :>, :<=, :>= # binary operators
      return "#{ret}#{exp(arg0)} #{symbol} #{exp(n.children[2])}"
    when :==, :!= # become === or !== in JS
      return "#{ret}#{exp(arg0)} #{symbol}= #{exp(n.children[2])}"
    when :=== # regexp test
      return "#{ret}#{exp(arg0)}.test(#{exp(n.children[2])})"
    when :%, :modulo # modulo or format (send (str "%2d") :% (lvar :j))
      return "#{ret}#{exp(arg0)}.format(#{exp(n.children[2])})" if arg0.type==:str
      return "#{ret}#{exp(arg0)} % #{pexp(n.children[2])}" # % operator (modulo) on numbers
    when :new then objAndMeth = methodNew(arg0, num_param, block)
    when :class then return "#{ret}#{exp(arg0)}.constructor"
    when :name then return "#{ret}#{exp(arg0)}.name"
    when :attr_reader, :attr_writer then return "" # see attributes()
    when :private
      @private = true
      return "//private"
    when :public
      @private = false
      return "//public"
    when :require, :require_relative then return genRequire(n.children[2], symbol == :require)
    when :each # see also methodAsLoop
      objAndMeth = "#{ret}#{exp(arg0)}.forEach"
    when :puts, :print, :p
      objAndMeth, ret = "console.log", "" if arg0==nil
    when :call then objAndMeth = "#{exp(arg0)}"
    end # else = user method call

    if objAndMeth
      isSpecial = true
    else
      jsname = jsName(symbol)
      methName = isMethod(symbol, num_param + (block ? 1 : 0), jsname)
      jsname = methName if methName
      objAndMeth = "#{objScope(arg0, symbol)}#{jsname}"
    end
    
    #add parameters to method "obj.name"
    params = genMethParam(n, block)
    params = "(#{params})" if isSpecial or methName # all "special ones" here are methods
    return "#{ret}#{objAndMeth}#{params}"
  end

  def genMethParam(n, block)
    params = n.children[2..-1].map{|p| exp(p)}.join(", ")
    params << "#{params.length > 0 ? ', ' : ''}#{block}" if block
    return params
  end

  # This decides if we put "()" or not for a method call that could be a data accessor too
  # NB:in doubt, () is safer because of runtime error "not a function"
  # Returns the jsname that should be used (or nil if not a method)
  def isMethod(methName, num_param, jsname)
    return @classMethods[methName] if @classMethods[methName] # we could compare the # of arguments
    return nil if num_param == 0 and @classDataMembers[methName]
    isMeth = @publicMethods[methName]
    isVar = num_param == 0 ? @publicVars[methName] : false
    return jsname if isMeth and !isVar
    return nil if isVar and !isMeth
    
    return jsname if !@showErrors # in doubt use "()" is safer
    if isVar and isMeth
      logError("E", 1, "both variable and method exist: #{methName}")
    elsif !@unknownMethods[methName]
      logError("E", 2, "unknown method: #{methName}(#{num_param>0 ? '...' : ''})")
      @unknownMethods[methName] = true # so we show it only once per file
    end
    return jsname
  end

  def typeofClassMember(name)
    klass = @curClass
    loop do
      return 0 if !klass
      return 1 if klass[:members][name]
      return 2 if klass[:methods][name]
      klass = @classes[klass[:parent]]
    end
  end

  def objScope(n, methName)
    return "#{pexp(n)}." if n
    return "#{this}." if typeofClassMember(methName) != 0
    return ""
  end

end


opts = Trollop::options do
  opt :src, "Source root directory (can be in ruby2js.json as well)", :type => :string
  opt :debug, "Debug test file (optional)", :type => :string
  opt :file, "Single source file (optional)", :type => :string
  opt :target, "Target root directory (can be in ruby2js.json as well)", :type => :string
end

t = RubyToJs.new(opts)
if opts.debug
  t.translateFile(opts.debug)
else
  t.translateAll(opts.file)
end
