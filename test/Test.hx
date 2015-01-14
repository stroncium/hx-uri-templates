private typedef TestSuite = haxe.DynamicAccess<{
  level: Int,
  variables: Dynamic,
  testcases: Array<Array<Dynamic>>,
}>;

private typedef Results = {
  passed:Int,
  failed:Int,
  total:Int,
}

class Test{
  static function readFile(path:String){
    #if js
      return (untyped __js__('require'))('fs').readFileSync(path, 'utf8');
    #else
      #error 'Not implemented for platform'
    #end
  }

  static inline var TESTS_DIR = 'uritemplate-test';
  static function getTests(name:String):TestSuite{
    var file = readFile('$TESTS_DIR/$name.json');
    var json = haxe.Json.parse(file);
    return json;
  }

  static function runTpl(tpl:String, vars:Dynamic):String{
    throw 'not implemented';
  }

  static function runTests(testGroups:TestSuite){
    var log = new StringBuf();
    var suiteRes = {passed:0, failed:0, total:0};
    for(groupName in testGroups.keys()){
      var group = testGroups[groupName];
      write('  Group $groupName (lvl ${group.level}): ');
      var vars = group.variables;
      var res = {passed:0, failed:0, total:group.testcases.length};
      for(test in group.testcases){
        var tpl:String = test[0];
        var exp:Dynamic = test[1];

        var out = null, err = null;

        try{
          out = runTpl(tpl, vars);
        }
        catch(e:Dynamic){
          err = e;
        }

        var good;
        if(exp == false){
          good = out == null && err != null;
        }
        else if(Std.is(exp, String)){
          good = out == exp && err == null;
        }
        else if(Std.is(exp, Array)){
          good = exp.indexOf(out) != -1 && err == null;
        }
        else{
          throw 'invalid testcase';
        }

        if(good){
          res.passed++;
        }
        else{
          res.failed++;
        }
        if(!good) log.add('    "$tpl" => $exp failed\n');
        write(good ? '+' : '-');
      }
      write(' ${res.passed}/${res.total}\n');
      if(res.failed > 0) write(log.toString());

      suiteRes.passed+= res.passed;
      suiteRes.failed+= res.failed;
      suiteRes.total+= res.total;
    }

    return suiteRes;
  }

  public static function main(){
    var good = true;
    for(suiteName in ['extended-tests','negative-tests','spec-examples-by-section','spec-examples']){
      write('Suite $suiteName\n');
      var res = runTests(getTests(suiteName));
      write('== ${res.passed}/${res.total}\n');
      good = good && res.failed == 0;
      write('\n');
    }
    exit(good ? 0 : 1);
  }

  static function write(str:String){
    #if js
      (untyped __js__('process')).stdout.write(str, 'utf8');
    #end
  }

  static function exit(status:Int){
    #if js
      (untyped __js__('process')).exit(status);
    #end

  }
}


