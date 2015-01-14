class UriTplError{
  var txt:String;
  var src:String;
  public function new(src, txt){
    this.src = src;
    this.txt = txt;
  }

  public function toString() return 'UriTpl Error: $txt in "$src"';
}

enum UTExp{
  Lit(str:String);
  Exp(type:UTExpType, binds:Array<{n:String, f:Int}>);
}

@:enum abstract UTExpType(Int){
  inline var Simple = 1;
  inline var Reserved = 2;
  inline var Fragment = 3;
  inline var Label = 4;
  inline var Path = 5;
  inline var PathParameter = 6;
  inline var FormQuery = 7;
  inline var FormCont = 8;
}

class UriTpl{
  var src:String;
  var exprs:Array<UTExp>;
  public function new(src:String){
    this.src = src;

    var exprs = exprs = [];
    var firstPos = 0;
    var pos;
    // trace('parsing $src');
    while((pos = src.indexOf('{', firstPos)) != -1){
      // trace('rem: ${src.substr(pos)}');
      if(pos > firstPos) exprs.push(lit(src.substr(firstPos, pos - firstPos)));
      var endPos = src.indexOf('}', pos+1);
      if(endPos == -1) throw error(src, 'Unclosed "{"');
      exprs.push(exp(src.substr(pos+1, endPos - pos - 1)));
      firstPos = endPos+1;
    }
    if(firstPos < src.length) exprs.push(lit(src.substr(firstPos)));
    // trace('$src => $exprs');
  }

  static inline function lit(src:String){
    if(src.indexOf('}') != -1) throw error(src, 'Unopened "}"');
    return Lit(urlEncode(src)); //TODO
  }

  static var reVars = ~/^[a-zA-Z0-9_.%]+(:[1-9][0-9]{0,3}|\*)?(,[a-zA-Z0-9_.%]+(:[1-9][0-9]{0,3}|\*)?)*$/;
  static function exp(src:String){
    var type = switch(src.charCodeAt(0)){
      case '+'.code: Reserved;
      case '#'.code: Fragment;
      case '.'.code: Label;
      case '/'.code: Path;
      case ';'.code: PathParameter;
      case '?'.code: FormQuery;
      case '&'.code: FormCont;
      case _: Simple;
    }
    if(type != Simple) src = src.substr(1);
    if(!reVars.match(src)) throw 'not implemented';
    var binds = [for(str in src.split(',')){
      var idx = str.indexOf(':');
      if(idx != -1) {n:str.substr(0, idx), f:Std.parseInt(str.substr(idx+1))};
      else if(str.charCodeAt(str.length-1) == '*'.code) {n:str.substr(0, str.length-1), f:0};
      else {n:str, f:-1};
    }];
    return Exp(type, binds);
  }

  public static function compile(src:String) return new UriTpl(src);


  static function objToString(o:haxe.DynamicAccess<Dynamic>){
    var buf = new StringBuf();
    var notFirst = false;
    for(k in o.keys()){
      var v = o[k];
      if(v != null){
        if(notFirst) buf.add(',');
        buf.add(specialEncode(k));
        buf.add(',');
        buf.add(specialEncode(v));
        notFirst = true;
      }
    }
    return buf.toString();
  }


  public function render(vars:Dynamic):String{
    var buf = new StringBuf();
    for(expr in exprs) switch(expr){
      case Lit(str): buf.add(str);
      case Exp(type, binds):
        var done = 0;
        var sep = switch(type){
          case Simple, Reserved: ',';
          case Fragment: ',';
          case Label: '.';
          case Path: '/';
          case PathParameter: 
            for(bind in binds){
              var val:Dynamic = Reflect.field(vars, bind.n);
              if(Std.is(val, String)){
                if(val != null){
                  buf.add(';');
                  buf.add(bind.n);
                  if(val != ''){
                    buf.add('=');
                    var str:String = val;
                    if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                    buf.add(specialEncode(str));
                  }
                }
              }
              else if(Std.is(val, Array)){
                if(bind.f == 0){
                  var pref = ';'+bind.n+'=';
                  for(val in (val:Array<Dynamic>)){
                    if(val != null && val != ''){
                      buf.add(pref);
                      var str = Std.string(val);
                      buf.add(specialEncode(str));
                    }
                  }
                }
                else{
                  buf.add(';');
                  buf.add(bind.n);
                  if(val != null && val != ''){
                    buf.add('=');
                    var str = (val:Array<Dynamic>)
                      .filter(function(v) return v != null)
                      .map(function(v) return specialEncode(Std.string(v)))
                      .join(',');
                    if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                    buf.add(str);
                  }
                }
              }
              else if(Reflect.isObject(val)){
                if(bind.f == 0){
                  for(key in Reflect.fields(val)){
                    var val = Reflect.field(val, key);
                    if(val != null){
                      buf.add(';');
                      buf.add(key);
                      buf.add('=');
                      buf.add(specialEncode(Std.string(val)));
                    }
                  }
                }
                else{
                  buf.add(';');
                  buf.add(bind.n);
                  buf.add('=');
                  buf.add(objToString(val));
                }
              }
              else{
                if(val != null){
                  buf.add(';');
                  buf.add(bind.n);
                  if(val != ''){
                    buf.add('=');
                    var str = Std.string(val);
                    if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                    buf.add(specialEncode(str));
                  }
                }
              }
            }
            continue; null;
          case FormQuery:
            for(bind in binds){
              var val:Dynamic = Reflect.field(vars, bind.n);
              if(Std.is(val, String)){
                if(val != null){
                  buf.add(done == 0 ? '?' : '&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str:String = val;
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(specialEncode(str));
                  done++;
                }
              }
              else if(Std.is(val, Array)){
                if(bind.f == 0){
                  for(val in (val:Array<Dynamic>)){
                    if(val != null && val != ''){
                      buf.add(done == 0 ? '?' : '&');
                      buf.add(bind.n);
                      buf.add('=');
                      var str = Std.string(val);
                      buf.add(specialEncode(str));
                      done++;
                    }
                  }
                }
                else if(val.length > 0){
                  buf.add(done == 0 ? '?' : '&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str = (val:Array<Dynamic>)
                    .filter(function(v) return v != null)
                    .map(function(v) return specialEncode(Std.string(v)))
                    .join(',');
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(str);
                  done++;
                }
              }
              else if(Reflect.isObject(val)){
                if(bind.f == 0){
                  for(key in Reflect.fields(val)){
                    var val = Reflect.field(val, key);
                    if(val != null){
                      buf.add(done == 0 ? '?' : '&');
                      buf.add(key);
                      buf.add('=');
                      buf.add(specialEncode(Std.string(val)));
                      done++;
                    }
                  }
                }
                else if(Reflect.fields(val).length > 0){
                  buf.add(done == 0 ? '?' : '&');
                  buf.add(bind.n);
                  buf.add('=');
                  buf.add(objToString(val));
                  done++;
                }
              }
              else{
                if(val != null && val != ''){
                  buf.add(done == 0 ? '?' : '&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str = Std.string(val);
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(specialEncode(str));
                  done++;
                }
              }
            }
            continue; null;
          case FormCont:
            for(bind in binds){
              var val:Dynamic = Reflect.field(vars, bind.n);
              if(Std.is(val, String)){
                if(val != null){
                  buf.add('&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str:String = val;
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(specialEncode(str));
                  done++;
                }
              }
              else if(Std.is(val, Array)){
                if(bind.f == 0){
                  for(val in (val:Array<Dynamic>)){
                    if(val != null && val != ''){
                      buf.add('&');
                      buf.add(bind.n);
                      buf.add('=');
                      var str = Std.string(val);
                      buf.add(specialEncode(str));
                      done++;
                    }
                  }
                }
                else if(val.length > 0){
                  buf.add('&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str = (val:Array<Dynamic>)
                    .filter(function(v) return v != null)
                    .map(function(v) return specialEncode(Std.string(v)))
                    .join(',');
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(str);
                  done++;
                }
              }
              else if(Reflect.isObject(val)){
                if(bind.f == 0){
                  for(key in Reflect.fields(val)){
                    var val = Reflect.field(val, key);
                    if(val != null){
                      buf.add('&');
                      buf.add(key);
                      buf.add('=');
                      buf.add(specialEncode(Std.string(val)));
                      done++;
                    }
                  }
                }
                else{
                  buf.add('&');
                  buf.add(bind.n);
                  buf.add('=');
                  buf.add(objToString(val));
                  done++;
                }
              }
              else{
                if(val != null && val != ''){
                  buf.add('&');
                  buf.add(bind.n);
                  buf.add('=');
                  var str = Std.string(val);
                  if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
                  buf.add(specialEncode(str));
                  done++;
                }
              }
            }
            continue; null;

        }
        for(bind in binds){
          var val:Dynamic = Reflect.field(vars, bind.n);
          if(val != null){
            if(Std.is(val, String)){
              var str:String = val;
              if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
              buf.add(done == 0 ? (type == Fragment ? '#' : type == Label ? '.' : type == Path ? '/' : '') : sep);
              str = switch(type){
                case Simple, Label, Path: specialEncode(str);
                case Reserved, Fragment: urlEncode(str);
                case _: throw 'unreachable';
              }
              buf.add(str);
              done++;
            }
            else if(Std.is(val, Array)){
              var locSep = bind.f == 0 ? sep : ',';
              for(val in (val:Array<Dynamic>)){
                buf.add(done == 0 ? (type == Fragment ? '#' : type == Label ? '.' : type == Path ? '/' : '') : locSep);
                var str = Std.string(val);
                str = switch(type){
                  case Simple, Label, Path: specialEncode(str);
                  case Reserved, Fragment: urlEncode(str);
                  case _: throw 'unreachable';
                }
                buf.add(str);
                done++;
              }
            }
            else if(Reflect.isObject(val)){
              if(bind.f == 0 || bind.f == -1){
                var sep2, locSep;
                if(bind.f == 0){
                  locSep = sep;
                  sep2 = '=';
                }
                else{
                  locSep = ',';
                  sep2 = ',';
                }
                for(key in Reflect.fields(val)){
                  var val = Reflect.field(val, key);
                  if(val != null){
                    buf.add(done == 0 ? (type == Fragment ? '#' : type == Label ? '.' : type == Path ? '/' : '') : locSep);
                    buf.add(typedEncode(type, key));
                    buf.add(sep2);
                    buf.add(typedEncode(type, val));
                    done++;
                  }
                }
              }
              else{
                throw 'check what to do';
              }
            }
            else{
              var str = Std.string(val);
              if(bind.f > 0 && str.length > bind.f) str = str.substr(0, bind.f); 
              buf.add(done == 0 ? (type == Fragment ? '#' : type == Label ? '.' : type == Path ? '/' : '') : sep);
              str = switch(type){
                case Simple, Label, Path: specialEncode(str);
                case Reserved, Fragment: urlEncode(str);
                case _: throw 'unreachable';
              }
              buf.add(str);
              done++;
            }
          }
        }
    }
    return buf.toString();
  }

  static function typedEncode(type, str){
    return switch(type){
      case Simple, Label, Path: specialEncode(str);
      case Reserved, Fragment: urlEncode(str);
      case _: throw 'unreachable';
    }
  }

  static var CHAR_MAP = [for(char in ' ":?#[]@!$&\'()*+,;=/%<>{}'.split('')) char => '%'+hex(char.charCodeAt(0))];
    
  static inline function urlEncode(str:String):String{
    return (~/[ %]/g).map(str, reMapper);
  }

  static function reMapper(re:EReg) return CHAR_MAP[re.matched(0)];

  static function specialEncode(str:String){
    return (~/[ ":?#@!$&'()*+,;=\[\]\/%<>\{\}]/g).map(str, reMapper);
  }

  public static function run(src:String, vars:Dynamic):String{
    return compile(src).render(vars);
  }

  static inline function error(src, txt) return new UriTplError(src, txt);

  static inline function hex(num:Int) return StringTools.hex(num, 2);
}

    // pct-encoded    =  "%" HEXDIG HEXDIG
    // unreserved     =  ALPHA / DIGIT / "-" / "." / "_" / "~"
    // reserved       =  gen-delims / sub-delims
    // gen-delims     =  ":" / "/" / "?" / "#" / "[" / "]" / "@"
    // sub-delims     =  "!" / "$" / "&" / "'" / "(" / ")" /  "*" / "+" / "," / ";" / "="     
