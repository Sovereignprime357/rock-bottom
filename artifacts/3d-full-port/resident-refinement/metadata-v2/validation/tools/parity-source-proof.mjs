// Conservative executable-token proof. No evaluation and no parser dependency.
const identifierStart=/[A-Za-z_$]/;
const identifierPart=/[A-Za-z0-9_$]/;
const controls=new Set(['if','for','while','switch','catch','with']);
const expressionStart=new Set(['return','throw','case','delete','void','typeof','new','in','instanceof','yield','await','else','do']);
const operators=['===','!==','>>>','**=','&&=','||=','??=','=>','==','!=','<=','>=','++','--','&&','||','??','?.','+=','-=','*=','%=','&=','|=','^=','<<','>>','**','...'];

export function executableTokens(source) {
  if(typeof source!=='string')return null;
  let at=0;
  function stringToken(quote) {
    const start=at++;let escaped=false;
    while(at<source.length){
      const ch=source[at++];
      if(ch===quote)return {kind:'string',value:escaped?null:source.slice(start+1,at-1)};
      if(ch==='\n'||ch==='\r')throw Error('Unclosed string');
      if(ch==='\\'){escaped=true;if(at>=source.length)throw Error('Unclosed escape');if(source[at]==='\r'&&source[at+1]==='\n')at++;at++;}
    }
    throw Error('Unclosed string');
  }
  function templateToken() {
    at++;
    while(at<source.length){
      if(source[at]==='\\'){at+=2;continue;}
      if(source[at]==='`'){at++;return {kind:'template',value:null};}
      if(source[at]==='$'&&source[at+1]==='{'){at+=2;scan(true);continue;}
      at++;
    }
    throw Error('Unclosed template');
  }
  function regexToken() {
    at++;let characterClass=false;
    while(at<source.length){
      const ch=source[at++];
      if(ch==='\n'||ch==='\r')throw Error('Unclosed regex');
      if(ch==='\\'){if(at>=source.length||source[at]==='\n'||source[at]==='\r')throw Error('Unclosed regex escape');at++;continue;}
      if(ch==='[')characterClass=true;
      else if(ch===']')characterClass=false;
      else if(ch==='/'&&!characterClass){while(at<source.length&&/[A-Za-z]/.test(source[at]))at++;return {kind:'regex',value:null};}
    }
    throw Error('Unclosed regex');
  }
  function scan(interpolation=false) {
    const tokens=[];const stack=[];let canEnd=false;
    function emit(kind,value,start,after){tokens.push({kind,value,start,end:at,depth:stack.length});canEnd=after;}
    while(at<source.length){
      const ch=source[at];const start=at;
      if(/\s/.test(ch)){at++;continue;}
      if(source.startsWith('//',at)){at=source.indexOf('\n',at+2);if(at<0)at=source.length;continue;}
      if(source.startsWith('/*',at)){const end=source.indexOf('*/',at+2);if(end<0)throw Error('Unclosed comment');at=end+2;continue;}
      if(ch==='"'||ch==="'"){const token=stringToken(ch);emit(token.kind,token.value,start,true);continue;}
      if(ch==='`'){const token=templateToken();emit(token.kind,token.value,start,true);continue;}
      if(ch==='/'){
        if(canEnd==='ambiguous')throw Error('Ambiguous slash after brace');
        if(!canEnd){const token=regexToken();emit(token.kind,token.value,start,true);}
        else {at+=source[at+1]==='='?2:1;emit('punct',source.slice(start,at),start,false);}
        continue;
      }
      if(identifierStart.test(ch)){
        at++;while(at<source.length&&identifierPart.test(source[at]))at++;
        const value=source.slice(start,at);emit('identifier',value,start,!expressionStart.has(value));continue;
      }
      if(/[0-9]/.test(ch)){
        at++;while(at<source.length&&/[A-Za-z0-9_.]/.test(source[at]))at++;
        emit('number',source.slice(start,at),start,true);continue;
      }
      if('({['.includes(ch)){
        const previous=tokens.at(-1);at++;emit('punct',ch,start,false);
        stack.push({open:ch,token:tokens.length-1,control:ch==='('&&previous?.kind==='identifier'&&controls.has(previous.value)});continue;
      }
      if(')}]'.includes(ch)){
        if(interpolation&&ch==='}'&&stack.length===0){at++;return tokens;}
        const open=stack.pop();if(!open||'({['.indexOf(open.open)!==')}]'.indexOf(ch))throw Error('Unbalanced delimiters');
        at++;emit('punct',ch,start,ch==='}'?'ambiguous':!open.control);
        tokens[open.token].close=tokens.length-1;continue;
      }
      const operator=operators.find(value=>source.startsWith(value,at));
      if(operator){at+=operator.length;emit('punct',operator,start,operator==='++'||operator==='--');continue;}
      if(';,:.?~!+-*%&|^=<>'.includes(ch)){at++;emit('punct',ch,start,false);continue;}
      throw Error('Unsupported lexical token');
    }
    if(interpolation||stack.length)throw Error('Unclosed lexical scope');
    return tokens;
  }
  try{return scan();}catch{return null;}
}

function namesAt(tokens,brace) {
  if(tokens[brace]?.value!=='{'||!Number.isInteger(tokens[brace].close))return null;
  const end=tokens[brace].close;const names=[];let wantName=true;
  for(let i=brace+1;i<end;i++){
    const token=tokens[i];
    if(wantName){if(token.kind!=='identifier')return null;names.push(token.value);}
    else if(token.value!==',')return null;
    wantName=!wantName;
  }
  return {names,end};
}
function exportedFunctions(tokens,symbol) {
  return tokens.flatMap((token,index)=>token.depth===0&&token.kind==='identifier'&&token.value==='export'&&tokens[index+1]?.value==='function'&&tokens[index+2]?.kind==='identifier'&&tokens[index+2]?.value===symbol&&tokens[index+3]?.value==='('? [index]:[]);
}
export function proveAlias(source,canonical,symbol) {
  if(typeof symbol!=='string'||!/^[$A-Za-z_][$\w]*$/.test(symbol))return false;
  const own=executableTokens(source);const target=executableTokens(canonical);
  if(!own||!target||exportedFunctions(target,symbol).length!==1)return false;
  let imported=0;let exported=0;
  for(let index=0;index<own.length;index++){
    const token=own[index];if(token.depth!==0||token.kind!=='identifier')continue;
    if(['function','const','let','var','class'].includes(token.value)&&own[index+1]?.value===symbol)return false;
    if(!['import','export'].includes(token.value))continue;
    const group=namesAt(own,index+1);if(!group)continue;
    if(token.value==='import'){
      if(own[group.end+1]?.value==='from'&&own[group.end+2]?.kind==='string'&&own[group.end+2]?.value==='./sprite_toolkit.js'&&own[group.end+3]?.value===';')imported+=group.names.filter(name=>name===symbol).length;
    }else if(own[group.end+1]?.value===';')exported+=group.names.filter(name=>name===symbol).length;
  }
  return imported===1&&exported===1;
}
export function proveEmptyInitializer(source,symbol) {
  if(typeof symbol!=='string'||!/^[$A-Za-z_][$\w]*$/.test(symbol))return false;
  const tokens=executableTokens(source);if(!tokens)return false;
  const found=exportedFunctions(tokens,symbol);if(found.length!==1)return false;
  const index=found[0];
  return tokens[index+3]?.close===index+4&&tokens[index+4]?.value===')'&&tokens[index+5]?.value==='{'&&tokens[index+5]?.close===index+6&&tokens[index+6]?.value==='}';
}
