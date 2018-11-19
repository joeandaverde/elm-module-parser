Start
  = __ module:Module __ {
    return module;
  }

Ws "ws"
  = "\t"
  / "\v"
  / "\f"
  / " "
  / "\u00A0"
  / "\uFEFF"

LineTerminator
  = [\n\r\u2028\u2029]

LineTerminatorSequence "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028"
  / "\u2029"

// Whitespace / Newline / Any Comment
__ "ws-eol-comment"
  = (Ws / LineTerminatorSequence / Comment)*

// Whitespace or {- comment -} without line terminator
_ "ws-inline-comment"
  = (Ws / MultiLineCommentNoLineTerminator)*

LParen = __ "(" __

RParen = __ ")" __

Equals
  = __ "=" __

Colon
  = __ ":" __

Comma
  = __ "," __

IdentifierPart
  = [a-z0-9_]i

TypeParameterName
  = [a-z]+

OperatorPart
  = [+-/*=.<>:&|^?%!]

Operator
  = $ (OperatorPart+)

ModuleName
  = $ ([A-Z] IdentifierPart*)

Identifier
  = $ ([a-z] IdentifierPart*)

ExposingAllToken
  = ".."

AsToken
  = "as" !IdentifierPart

PortToken
  = "port" !IdentifierPart

ModuleToken
  = "module" !IdentifierPart

ExposingToken
  = "exposing" !IdentifierPart

ImportToken
  = "import" !IdentifierPart

TypeAliasToken
  = "type alias" !IdentifierPart

TypeToken
  = "type" !IdentifierPart

EOS
  = _ SingleLineComment? LineTerminatorSequence
  / _ &")"
  / __ EOF

MultiLineCommentNoLineTerminator
  = "{-" (!("{-" / LineTerminator) .)* "-}"

SingleLineComment "single-line-comment"
  = "--" [^\n]* Ws*

MultiLineComment "multi-line-comment"
  = "{-" (!"-}" ( MultiLineComment / . ))* "-}" Ws*

Comment "comment"
  = SingleLineComment
  / MultiLineComment

ModulePath
  = head:ModuleName tail:("." ModuleName)* { return text(); }

ModuleNameList =
  head:ModuleName
  tail:(Comma m:ModuleName { return m; })* {
    return [head].concat(tail);
  }

ConstructorExport
  = name:(n:ModuleName { return { name: n, location: location(), }; }) LParen exposing:(ExposingAllToken { return 'all'; } / ModuleNameList) RParen {
      return {
        ...name,
        type: 'constructor',
        exposing: exposing === 'all' || exposing == null ? [] : exposing,
        exposes_all: exposing === 'all',
      };
    }

ExportedModule
  = fn:FunctionName { return { type: 'function', name: fn, location: location(), }; }
  / ctor:ConstructorExport { return ctor; }
  / module:ModuleName { return { type: 'type', name: module, location: location(), }; }

ExposingList =
  head:ExportedModule
  tail:(Comma m:ExportedModule { return m; })* {
    return [head].concat(tail);
  }

ModuleExports
  = ExposingToken __
    "(" __ exposing:(ExposingAllToken { return 'all'; } / ExposingList) __ ")" {
      return exposing;
    }

ModuleDeclaration "module declaration"
  = port:(PortToken _)?
    ModuleToken _
    name:(n:ModulePath { return { location: location(), name: n, }; })
    exposing:(__ e:ModuleExports { return e; } )? {
      return {
        ...name,
        type: port ? 'port-module' : 'module',
        exposing: exposing === 'all' || exposing == null ? [] : exposing,
        exposes_all: exposing === 'all',
      };
   }

Statement
  = ImportStatement
  / TypeAlias
  / CustomType
  / PortDeclaration
  / FunctionAnnotation
  / FunctionDeclaration

ModuleAlias "module alias"
  = AsToken __ moduleName:ModuleName { return moduleName; }

FunctionName "function-name"
  = Identifier { return text(); }
  / "(" _ name:Operator _ ")" { return name; }

ImportStatement "import statement"
  = __ i:(ImportToken _
    moduleName:ModulePath
    alias:(__ a:ModuleAlias { return a; })?
    exposing:(__ e:ModuleExports { return e; })? {
      return {
        location: location(),
        type: 'import',
        module: moduleName,
        alias: alias,
        exposing: exposing === 'all' || exposing == null ? [] : exposing,
        exposes_all: exposing === 'all',
      };
    }) __ { return i; }

TopLevelStatementStart
  = LineTerminator (
      TypeToken
    / TypeAliasToken
    / ModuleToken
    / ImportToken
    / FunctionName
    / PortToken
  )

CustomTypeConstructor "custom type constructor"
  = name:(n:ModuleName { return { location: location(), name: n }; }) (!TopLevelStatementStart !"|" .)* {
    return {
      ...name,
      type: 'constructor',
    };
  }

ConstructorList "custom type constructors"
  = head:CustomTypeConstructor t:("|" __ c:CustomTypeConstructor { return c; })* { return [head].concat(t); }

TypeAlias "type alias"
  = LineTerminator* TypeAliasToken __ name:(n:ModuleName { return { location: location(), name: n }; }) __ Equals {
    return {
      ...name,
      type: 'type-alias',
    };
  }

TypeParameterList
  = head:(TypeParameterName) tail:(__ n:(TypeParameterName) { return n; }) {
    return [head].concat(tail);
  }

CustomType "custom type declaration"
    = LineTerminator* TypeToken __ name:(n:ModuleName { return { location: location(), name: n }; }) __ TypeParameterList? __ Equals __ constructors:ConstructorList EOS {
      return {
        ...name,
        constructors: constructors,
        type: 'custom-type',
      };
    }

PortDeclaration "port declaration"
  = LineTerminator* PortToken __ fn:FunctionAnnotation {
    return {
      ...fn,
      type: 'port-declaration'
    }
  }

CommaSeparatedIdentifiers
  = head:Identifier tail:(__ "," __ identifier:Identifier { return identifier; })* {
    return [head].concat(tail);
  }

GrossRecordCapture
  = "{" __ names:CommaSeparatedIdentifiers __ "}" { return names; }

RecordPatternBase
  = GrossRecordCapture
  / ( "(" __ p:GrossRecordCapture __ ")" { return p; })

RecordPattern
  = RecordPatternBase

ConstructorPatternBase
  = "(" __ ModuleName __ params:FunctionParameter __ ")" { return params; }

ConstructorPattern
  = ConstructorPatternBase

PatternBase "pattern"
  = ConstructorPattern / RecordPattern

Pattern "pattern"
  = ("(" __ params:PatternBase __ "as" __ name:Identifier ")" { return [name].concat(params); })
  / PatternBase

FunctionParameter "function parameter"
   = (id:Identifier { return [ id ]; })
   / ('_' { return [ '_' ]; })
   / Pattern

FunctionParams "function parameters"
  = head:(FunctionParameter) tail:(_ n:FunctionParameter { return n; })* {
    return tail.reduce((acc, val) => acc.concat(val), head)
  }

FunctionAnnotation "function annotation"
  = LineTerminator* name:(n:FunctionName { return { name: n, location: location(), }; }) __ ":" {
    return {
      ...name,
      type: 'function-annotation',
    };
  }

FunctionDeclaration "function declaration"
  = LineTerminator* name:(n:FunctionName { return { name: n, location: location(), }; }) __ params:FunctionParams? __ "=" {
    return {
      ...name,
      type: 'function-declaration',
      parameters: params ? params : [],
    };
  }

Module
  = module:ModuleDeclaration
    statements:SourceElements? {
    return {
      ...module,
      imports: statements ? statements.filter(s => s.type === 'import') : [],
      types: statements ? statements.filter(s => s.type === 'custom-type' || s.type === 'type-alias') : [],
      function_annotations: statements ? statements.filter(s => s.type === 'function-annotation') : [],
      function_declarations: statements ? statements.filter(s => s.type === 'function-declaration') : [],
    };
  }

SourceElements
  = head:SourceElement tail:SourceElement* {
    return [head].concat(tail)
  }

EOF
  = !.

AnyLine "skipped"
  = [^\n]* '\n'

SourceElement
  = Statement
  / AnyLine