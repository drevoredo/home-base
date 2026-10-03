/* ---------- Home Base AI: ask, log in plain words, weekly review, sort transactions ---------- */
(function(){
const $=s=>document.querySelector(s);
const el=(t,a={},...kids)=>{const n=document.createElement(t);for(const k in a){if(k==='class')n.className=a[k];else if(k.startsWith('on'))n.addEventListener(k.slice(2),a[k]);else n.setAttribute(k,a[k]);}kids.flat().forEach(c=>c!=null&&n.append(c.nodeType?c:document.createTextNode(c)));return n;};
const toast=m=>{const t=$('#toast');if(!t)return;t.textContent=m;t.classList.add('on');clearTimeout(toast.t);toast.t=setTimeout(()=>t.classList.remove('on'),2400);};
let sample=null;
const ERR={not_granted:'AI is off for this page. You can allow it from the page menu.',rate_limited:'Too many requests at once. Try again in a minute.',sampling_disabled:'AI is turned off for your account.',session_expired:'Your session expired. Reload the page.',tools_unavailable:'AI actions are not available here.',prompt_too_large:'Too much data to send at once.',refused:'Claude could not help with that one.'};
const errText=e=>ERR[e&&e.code]||'Something went wrong. Try again.';

/* ---- a compact snapshot of everything the app knows, sent with each question ---- */
const iso=d=>d.toISOString().slice(0,10);
function snapshot(){const D=HB.data,M=HB.money;if(!D)return'{}';
  const since=iso(new Date(Date.now()-30*864e5));const metrics=D.metrics();const health={};
  Object.entries(D.entries()).forEach(([k,list])=>{const rec=list.filter(x=>x.d>=since);if(rec.length)health[(metrics[k]&&metrics[k].name||k)+(metrics[k]&&metrics[k].unit?' ('+metrics[k].unit+')':'')]=rec.slice(-20).map(x=>[x.d,x.v]);});
  const sessions=D.sessions().slice(-10).map(s=>({date:s.date,title:s.title,minutes:s.minutes,exercises:s.exercises.map(e=>e.name+': '+e.sets.filter(x=>x.type!=='W').map(x=>x.w+'x'+x.r).join(', '))}));
  const runs=D.runs().slice(-10).map(r=>({date:r.date,type:r.type,miles:r.dist,minutes:+(r.sec/60).toFixed(1),effort:r.rpe,notes:r.notes}));
  let money={};if(M){const sp=M.spentBy();money={budgets_this_month:M.budgets().map(b=>({category:b.cat,budget:b.amt,spent:Math.round(sp[b.cat]||0)})),
    spent_this_month_by_category:Object.fromEntries(Object.entries(sp).map(([k,v])=>[k,Math.round(v)])),transaction_count:M.tx().length,
    latest_transactions:M.tx().slice().sort((a,b)=>b.date.localeCompare(a.date)).slice(0,25).map(t=>[t.date,t.desc,t.amt,t.cat||'uncategorized'])};}
  return JSON.stringify({today:D.today(),profile:D.profile(),active_split:D.splitToday(),health_last_30_days:health,recent_workouts:sessions,recent_runs:runs,money});}

const RULES=()=>`You are the assistant inside Home Base, a personal app for health, training and money that David shares with his wife. Units: pounds and miles. Health data comes from Apple Health (Garmin writes to it), food from MacroFactor, money from their CIBC accounts.
Rules: answer from the data below and say plainly when the data is missing rather than guessing. Be brief and practical: lead with the answer, then at most a few short bullets. You are not a doctor or financial advisor; for medical symptoms suggest seeing a professional.
When the user tells you something they did or measured (a workout, a run, weight, water, caffeine, mood, sleep...), save it with the log tools, then confirm in one line what you saved. Do not invent values they did not give. Only log when they clearly describe something that happened.
Use find_transactions for money questions that need more than the latest transactions.
App data (JSON): ${snapshot()}`;

/* ---- tools Claude can call from the chat ---- */
let logged=[];
const TOOLS=()=>[
 {name:'log_health',description:'Save one health measurement for today, e.g. weight in lb, water in oz, caffeine in mg, mood 1-7, sleep in hours, steps. Returns what was saved.',
  inputSchema:{type:'object',properties:{metric:{type:'string',enum:Object.keys(HB.data.metrics())},value:{type:'number'}},required:['metric','value']},
  execute(i){const k=String(i.metric),v=Number(i.value);const t=HB.data.logEntry(k,v);const m=HB.data.metrics()[k];const label=m.name+' '+v+(m.unit?' '+m.unit:'');logged.push({kind:'entry',t,k,label});return'Saved '+label;}},
 {name:'log_run',description:'Save a run done today. Distance in miles, duration in seconds, type one of Easy, Long, Tempo, Intervals, Race, Treadmill, effort 1-10.',
  inputSchema:{type:'object',properties:{dist:{type:'number'},sec:{type:'number'},type:{type:'string'},rpe:{type:'number'},notes:{type:'string'}},required:['dist','sec']},
  execute(i){const t=HB.data.addRun(i);const label=(i.type||'Easy')+' run, '+i.dist+' mi';logged.push({kind:'run',t,label});return'Saved '+label;}},
 {name:'log_workout',description:'Save a strength workout done today. Weights in lb. Each set has w (weight), r (reps) and optional type "W" for warm-up.',
  inputSchema:{type:'object',properties:{title:{type:'string'},minutes:{type:'number'},exercises:{type:'array',items:{type:'object',properties:{name:{type:'string'},sets:{type:'array',items:{type:'object',properties:{w:{type:'number'},r:{type:'number'},type:{type:'string'}}}}}}}},required:['exercises']},
  execute(i){const t=HB.data.addSession(i);const label=(i.title||'Workout')+' ('+i.exercises.length+' exercises)';logged.push({kind:'session',t,label});return'Saved '+label;}},
 {name:'find_transactions',description:'Search bank transactions. Returns up to 60 rows as [date, description, amount (negative is spending), category]. All filters optional.',
  inputSchema:{type:'object',properties:{query:{type:'string'},from:{type:'string',description:'YYYY-MM-DD'},to:{type:'string',description:'YYYY-MM-DD'},category:{type:'string'}}},
  execute(i){const q=String(i.query||'').toLowerCase();const list=HB.money.tx().filter(t=>(!i.from||t.date>=i.from)&&(!i.to||t.date<=i.to)&&(!i.category||t.cat===i.category)&&(!q||t.desc.toLowerCase().includes(q)));
    const total=list.filter(t=>t.amt<0).reduce((a,t)=>a-t.amt,0);return{matches:list.length,total_spent:Math.round(total*100)/100,rows:list.slice(0,60).map(t=>[t.date,t.desc,t.amt,t.cat||'uncategorized'])};}}
];

/* ---- chat sheet ---- */
let turns=[],ctl=null,busy=false;
const SUGGEST=['Write my weekly review','What should I train today?','How is our spending this month?','I drank 16 oz of water and had a coffee'];
function openAsk(prefill,autosend){
  const sheet=$('#sheet'),si=$('#sheetIn');si.innerHTML='';sheet.classList.add('tall');
  const log=el('div',{class:'ailog',id:'aiLog'});
  const box=el('textarea',{id:'aiBox',rows:'1',placeholder:'Ask anything, or tell me what you did','aria-label':'Message'});
  const send=el('button',{class:'cta',id:'aiSend'},'Send');
  const head=el('div',{class:'aihead'},el('div',{},el('h2',{},'Ask Home Base'),el('div',{class:'sub',style:'font-size:12px'},'Reads your health, training and money data in this app. Logs things you tell it.')),
    el('div',{style:'display:flex;gap:6px'},turns.length?el('button',{class:'ghost',onclick:()=>{turns=[];openAsk();}},'New chat'):null,el('button',{class:'ghost',onclick:closeAsk},'Close')));
  si.append(el('div',{class:'grab'}),head,log,el('div',{class:'aichips',id:'aiChips'},SUGGEST.map(s=>el('button',{onclick:()=>{box.value=s;go();}},s))),el('div',{class:'aiin'},box,send));
  const render=()=>{log.innerHTML='';if(!turns.length)log.append(el('div',{class:'emptynote'},'Try a suggestion below. Your data is sent to Claude only when you send a message, and it uses your own Claude plan.'));
    turns.forEach(t=>log.append(bubble(t)));log.scrollTop=log.scrollHeight;$('#aiChips').hidden=!!turns.length;};
  async function go(){const q=box.value.trim();if(!q||busy)return;box.value='';busy=true;send.textContent='Stop';send.onclick=()=>ctl&&ctl.abort();
    turns.push({role:'user',content:q});const ans={role:'assistant',content:'',pending:true,logs:[]};turns.push(ans);render();
    logged=[];ctl=new AbortController();const b=log.lastChild;
    try{const msgs=[{role:'user',content:RULES()},{role:'assistant',content:'Understood.'},...turns.filter(t=>!t.pending).map(t=>({role:t.role,content:t.content}))];
      const {text}=await sample(msgs,{cache:false,signal:ctl.signal,tools:TOOLS(),onText:({text})=>{ans.content=text;ans.pending=false;const nb=bubble(ans);b.replaceWith(nb);}});
      ans.content=text;}
    catch(e){ans.content=(e&&e.text)||'';if(!e||e.code!=='cancelled')ans.error=errText(e);}
    ans.pending=false;ans.logs=logged.slice();busy=false;send.textContent='Send';send.onclick=go;
    if(!ans.content&&!ans.error)turns.splice(turns.indexOf(ans),1);render();}
  send.onclick=go;box.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();go();}});
  render();$('#scrim').classList.add('on');sheet.classList.add('on');
  if(prefill){box.value=prefill;if(autosend)go();}else setTimeout(()=>box.focus(),300);}
function closeAsk(){$('#scrim').classList.remove('on');$('#sheet').classList.remove('on');setTimeout(()=>{if(!$('#sheet').classList.contains('on'))$('#sheet').classList.remove('tall');},400);}
function bubble(t){const n=el('div',{class:'msg '+(t.role==='user'?'me':'ai')});
  if(t.pending)n.append(el('span',{class:'thinking'},'Thinking…'));else n.append(fmt(t.content));
  if(t.error)n.append(el('div',{class:'aierr'},t.error));
  (t.logs||[]).forEach(l=>{const row=el('div',{class:'ailogged'},el('span',{},'✓ Saved: '+l.label));
    row.append(el('button',{class:'ghost',onclick:()=>{HB.data.undo(l.kind,l.t,l.k);t.logs=t.logs.filter(x=>x!==l);row.replaceWith(el('div',{class:'ailogged off'},'Removed: '+l.label));toast('Removed '+l.label);}},'Undo'));n.append(row);});
  return n;}
/* minimal markdown: paragraphs, bullets, bold */
function fmt(s){const wrap=el('div');let ul=null;
  const inline=line=>{const p=el('span');line.split(/(\*\*[^*]+\*\*)/).forEach(part=>{if(/^\*\*[^*]+\*\*$/.test(part))p.append(el('b',{},part.slice(2,-2)));else if(part)p.append(part);});return p;};
  String(s||'').split('\n').forEach(line=>{const m=line.match(/^\s*(?:[-*•]|\d+\.)\s+(.*)/);
    if(m){if(!ul){ul=el('ul');wrap.append(ul);}ul.append(el('li',{},inline(m[1])));}
    else{ul=null;if(line.trim()){const h=line.match(/^#+\s*(.*)/);wrap.append(el(h?'h3':'p',{},inline(h?h[1]:line)));}}});
  return wrap;}

/* ---- sort transactions with AI (money review card) ---- */
async function sortTx(btn){const M=HB.money;const need=M.tx().filter(t=>!t.cat).slice(0,80);if(!need.length)return;
  btn.disabled=true;btn.textContent='Sorting…';
  try{const cats=M.cats();const res=await sample.json(`Categorize these Canadian bank transactions. Allowed categories: ${cats.join(', ')}.
Reply with only a JSON object mapping each id to one allowed category, e.g. {"t1":"Groceries"}. Use "Other" when unsure.
Transactions as [id, description, amount]: ${JSON.stringify(need.map(t=>[t.id,t.desc,t.amt]))}`,{modelTier:'quick'});
    const map={};Object.entries(res||{}).forEach(([id,c])=>{if(cats.includes(c))map[id]=c;});
    showSorted(need,map);}
  catch(e){toast(errText(e));}
  btn.disabled=false;btn.textContent='Sort with AI';}
function showSorted(need,map){const sheet=$('#sheet'),si=$('#sheetIn');si.innerHTML='';sheet.classList.remove('tall');
  const rows=need.filter(t=>map[t.id]);
  si.append(el('div',{class:'grab'}),el('h2',{},'Suggested categories'),el('p',{class:'sub',style:'margin:4px 0 10px'},rows.length+' of '+need.length+' sorted. Check them, then apply. You can change any one later.'),
    el('div',{class:'aisort'},rows.map(t=>el('div',{class:'histrow'},el('div',{style:'min-width:0'},el('b',{},t.desc),el('div',{class:'sub',style:'font-size:12px'},t.date+' · $'+Math.abs(t.amt).toFixed(2))),el('span',{class:'tag'},map[t.id])))),
    el('div',{style:'display:flex;gap:8px;margin-top:14px'},el('button',{class:'btn2',onclick:closeAsk},'Cancel'),
      el('button',{class:'cta',style:'flex:1',onclick:()=>{const n=HB.money.setCats(map);closeAsk();toast(n+' transactions categorized');}},'Apply all')));
  $('#scrim').classList.add('on');sheet.classList.add('on');}

/* ---- entry points ---- */
function mount(){
  // Today: ask card
  const health=$('#health');if(health&&!$('#aiCard')){
    const inp=el('input',{id:'aiQuick',placeholder:'e.g. "Ran 4 miles easy in 38 min" or "How did I sleep this week?"','aria-label':'Ask or log'});
    const card=el('div',{class:'card aicard',id:'aiCard'},
      el('div',{class:'aitop'},el('span',{class:'aispark'},'✦'),el('b',{},'Ask Home Base'),el('span',{class:'sub',style:'font-size:12px;margin-left:auto'},'Log in plain words or ask about your data')),
      el('form',{class:'aiin',onsubmit:e=>{e.preventDefault();const v=inp.value.trim();inp.value='';openAsk(v,!!v);}},inp,el('button',{class:'cta',type:'submit'},'Go')),
      el('div',{class:'aichips'},el('button',{type:'button',onclick:()=>openAsk('Write my weekly review: training, recovery, and money. What went well, what slipped, and one focus for next week.',true)},'Weekly review'),
        el('button',{type:'button',onclick:()=>openAsk('What should I train today, and how hard?',true)},'What to train today'),
        el('button',{type:'button',onclick:()=>openAsk()},'Open chat')));
    const tiles=$('#tiles');if(tiles)tiles.before(card);else health.prepend(card);}
  // sidebar + phone button
  const foot=$('.side .foot');if(foot&&!$('#aiNav')){const b=el('button',{class:'nav',id:'aiNav',onclick:()=>openAsk()},el('span',{class:'aispark',style:'width:18px;text-align:center'},'✦'),'Ask Home Base');foot.prepend(b);}
  if(!$('#aiFab'))document.body.append(el('button',{class:'aifab',id:'aiFab','aria-label':'Ask Home Base',onclick:()=>openAsk()},'✦'));
  // money: sort uncategorized with AI
  const rc=$('#reviewCard');if(rc){const add=()=>{if(!rc.hidden&&rc.childElementCount&&!rc.querySelector('.aisortbtn')){const b=el('button',{class:'btn2 aisortbtn',onclick:()=>sortTx(b)},'Sort with AI');const cta=rc.querySelector('.cta');if(cta)cta.before(b);else rc.append(b);}};
    new MutationObserver(add).observe(rc,{childList:true,attributes:true,attributeFilter:['hidden']});add();}
  document.documentElement.classList.add('ai-on');}

if(window.claude&&claude.use)claude.use('sample').then(s=>{if(!s)return;sample=s;mount();}).catch(()=>{});
HB.openAsk=(...a)=>sample?openAsk(...a):toast('AI works when Home Base is opened in Claude');
})();
