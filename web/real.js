/* ---------- real data: everything below replaces the example data ---------- */
const P=Object.assign({name:'David',partner:'',goal:'Hybrid',liftDays:'',runs:'',avail:'',watch:'Garmin',shoes:'',sleepTarget:'',stepGoal:'',cal:'',protein:'',water:''},store.get('hb.profile')||{});
const ENT=store.get('hb.entries')||{};
const SESS=store.get('hb.sessions')||[];const RUNS=store.get('hb.runs')||[];
const SUMS=new Set(['water','caffeine','mindful']);
const isoD=d=>{const x=new Date(d);x.setMinutes(x.getMinutes()-x.getTimezoneOffset());return x.toISOString().slice(0,10);};
const todayIso=isoD(new Date());
const vals=a=>a.filter(v=>v!=null);
function rebuildSeries(){const idx={};days.forEach((d,i)=>idx[isoD(d)]=i);Object.keys(METRICS).forEach(k=>{const a=Array(N).fill(null);(ENT[k]||[]).forEach(e=>{const i=idx[e.d];if(i==null)return;a[i]=SUMS.has(k)?(a[i]||0)+e.v:e.v;});series[k]=a;});}
function saveEntry(k,v){(ENT[k]=ENT[k]||[]).push({d:todayIso,t:Date.now(),v:+v});store.set('hb.entries',ENT);rebuildSeries();}
const lastVal=k=>{const v=vals(series[k]);return v.length?v[v.length-1]:null;};
const emptyNote=(host,msg)=>{host.innerHTML='';host.append(el('div',{class:'emptynote'},msg));};
rebuildSeries();
['hrv','rhr'].forEach(k=>{delete METRICS[k].band;});delete METRICS.exmin.target;
function applyProfile(){
  [['sleep','sleepTarget',v=>METRICS.sleep.fmt(v)+' target'],['steps','stepGoal',v=>v.toLocaleString()+' goal'],['cal','cal',v=>v.toLocaleString()+' target'],['protein','protein',v=>v+' g target'],['water','water',v=>v+' oz goal']].forEach(([k,p,lab])=>{
    if(P[p]){METRICS[k].target=+P[p];METRICS[k].targetLab=lab(+P[p]);}else{delete METRICS[k].target;delete METRICS[k].targetLab;}});
  goal=P.goal||'Hybrid';
  const four=Date.now()-28*864e5;const ls=SESS.filter(s=>s.t>four).length,rs=RUNS.filter(r=>r.t>four);
  $('#sgLift').value=P.liftDays||(ls?Math.round(ls/4):3);$('#sgRuns').value=P.runs||(rs.length?Math.round(rs.length/4):3);
  $('#sgMiles').value=rs.length?Math.round(rs.reduce((a,r)=>a+r.dist,0)/4):0;
  const sl=vals(series.sleep).slice(-7);$('#sgSleep').value=sl.length?avg(sl).toFixed(1):'';$('#sgAvail').value=P.avail||5;}
/* the splits code treats a blank sleep value as unknown, not as low */
lowRecovery=()=>{const g=sig();return (g.sleep>0&&g.sleep<6.5)||g.hrv==='Below';};

/* ---- health ---- */
drawReady=function(){
  const pick=k=>{const a=series[k];return a[N-1]!=null?a[N-1]:a[N-2];};const base=k=>{const v=vals(series[k].slice(N-29,N-1));return v.length>=5?v.reduce((x,y)=>x+y,0)/v.length:null;};
  const s=pick('sleep'),h=pick('hrv'),r=pick('rhr'),hb=base('hrv'),rb=base('rhr');
  if(s!=null&&h!=null&&r!=null&&hb&&rb){const need=METRICS.sleep.target||7.5;
    const sc=Math.round(Math.max(0,Math.min(100,72+(s-need)*12+(h-hb)/hb*100-(r-rb)*3)));
    const st=sc>=70?['Ready','var(--good)']:sc>=50?['Go easier','var(--z4)']:['Recover','var(--z5)'];
    $('#rScore').textContent=sc;$('#rState').textContent=st[0];$('#rState').style.color=st[1];$('#rState').style.borderColor=st[1];
    const arc=$('#ringArc');arc.style.stroke=st[1];requestAnimationFrame(()=>arc.style.strokeDashoffset=314.16*(1-sc/100));
    const drv=[['Sleep',METRICS.sleep.fmt(s)+' of '+METRICS.sleep.fmt(need)+' need',s>=need],['HRV',Math.round(h)+' ms, '+(h>=hb?'above':'below')+' your '+Math.round(hb)+' ms average',h>=hb-2],['Resting HR',Math.round(r)+' bpm, '+(r<=rb?'at or below':'above')+' your '+Math.round(rb)+' bpm average',r<=rb+1]];
    $('#drivers').innerHTML='';drv.forEach(([k,t,ok])=>$('#drivers').append(el('div',{class:'drv'},el('span',{class:'mk',style:'color:'+(ok?'var(--good)':'var(--z4)')},ok?'▲':'▼'),el('span',{},el('b',{},k+' '),t))));
    const sp=activeSplit();const d=sp?sp.days[TODAY]:null;const call=$('#todayCall');call.innerHTML='';
    const advice=sc>=70?'Train as planned.':sc>=50?'Train, but keep it easy: drop a set or slow the pace.':'Make today a rest or walking day.';
    call.append(el('div',{style:'min-width:0'},el('div',{class:'label',style:'color:var(--accent)'},'Today\'s plan'),el('div',{style:'font-weight:600'},d?d.type+(d.run?' + '+d.run:''):'No split yet'),el('div',{class:'sub',style:'font-size:12px'},d?advice:'Pick a split to get a plan for each day. '+advice)),
      d&&TPL[d.type]?el('button',{class:'cta',onclick:()=>startDay(sp,TODAY)},'Start'):d&&d.type.includes('run')?el('button',{class:'btn2',onclick:()=>goMain(2)},'Log run'):el('button',{class:'btn2',onclick:()=>goMain(3)},sp?'Splits':'Pick a split'));
    return;}
  $('#rScore').textContent='—';$('#rState').textContent='Waiting for data';$('#rState').style.color='var(--muted)';$('#rState').style.borderColor='var(--line2)';
  $('#ringArc').style.strokeDashoffset=314.16;
  $('#drivers').innerHTML='';$('#drivers').append(el('div',{class:'drv'},el('span',{},'Built from last night\'s sleep, HRV and resting heart rate, compared with your last 4 weeks. Those come from your Garmin through Apple Health.')),el('button',{class:'cxbtn',onclick:()=>HB.openConnections&&HB.openConnections('health')},'Connect Apple Health'));
  const sp=activeSplit();const d=sp?sp.days[TODAY]:null;const call=$('#todayCall');call.innerHTML='';
  call.append(el('div',{style:'min-width:0'},el('div',{class:'label',style:'color:var(--accent)'},'Today\'s plan'),el('div',{style:'font-weight:600'},d?d.type+(d.run?' + '+d.run:''):'No split yet'),el('div',{class:'sub',style:'font-size:12px'},d?'Readiness isn\'t available yet, so go by feel.':'Pick a split to get a plan for each day.')),
    d&&TPL[d.type]?el('button',{class:'cta',onclick:()=>startDay(sp,TODAY)},'Start'):d&&d.type.includes('run')?el('button',{class:'btn2',onclick:()=>goMain(2)},'Log run'):el('button',{class:'btn2',onclick:()=>goMain(3)},sp?'Splits':'Pick a split'));};
drawTiles=function(){const box=$('#tiles');box.innerHTML='';
  ['sleep','hrv','rhr','steps'].forEach(k=>{const m=METRICS[k],v=vals(series[k]),last=v.length?v[v.length-1]:null;
    const t=el('button',{class:'tile'+(k===hMetric?' on':''),'aria-pressed':String(k===hMetric),onclick:()=>{hMetric=k;drawTiles();drawTrend();flash($('#trendCard'));}},
      el('div',{class:'tilehead'},el('span',{class:'sw',style:'background:'+HC[k]}),el('span',{class:'label'},m.name)),
      el('div',{class:'tilev num'},last==null?'—':m.fmt(last)),
      el('div',{class:'tiled',style:'color:var(--muted)'},last==null?'From Apple Health':v.length>1?'Latest of '+v.length+' days':'1 day so far'));
    if(v.length>1)t.insertAdjacentHTML('beforeend',spark(v.slice(-14),HC[k]));box.append(t);});};
drawTrend=function(){const m=METRICS[hMetric];$('#tTitle').textContent=m.name;
  const v=series[hMetric].slice(N-hRange),lab=days.slice(N-hRange).map(dlab),nv=vals(v);
  $('#metricChips').innerHTML='';GROUPS.forEach(gr=>$('#metricChips').append(el('button',{'aria-pressed':String(gr===m.group),onclick:()=>{hMetric=Object.keys(METRICS).find(k=>METRICS[k].group===gr);drawTiles();drawTrend();}},gr)));
  const sub=el('div',{class:'chips subchips'});Object.entries(METRICS).filter(([,mm])=>mm.group===m.group).forEach(([k,mm])=>sub.append(el('button',{'aria-pressed':String(k===hMetric),onclick:()=>{hMetric=k;drawTiles();drawTrend();}},mm.name)));
  $('#metricChips').append(sub);
  $('#range').innerHTML='';[7,30,90].forEach(r=>$('#range').append(el('button',{'aria-pressed':String(r===hRange),onclick:()=>{hRange=r;drawTrend();}},r+'D')));
  if(!nv.length){$('#tSub').textContent='No entries in the last '+hRange+' days';emptyNote($('#trendChart'),m.rw==='RW'?'Log '+m.name.toLowerCase()+' with the quick logs on this page, or let it arrive from Apple Health.':m.name+' arrives from Apple Health'+(m.note?' ('+m.note.toLowerCase()+')':'')+'. Import your Health export from Connections to fill it in.');return;}
  $('#tSub').textContent=(hMetric==='mood'?'Most days: '+m.fmt(avg(nv)):nv.length+' day'+(nv.length>1?'s':'')+' logged · average '+m.fmt(avg(nv)));
  chart($('#trendChart'),{labels:lab,type:'line',fmt:m.fmt,target:m.target,targetLab:m.targetLab,yFmt:m.yFmt,yMin:m.yMin,yMax:m.yMax,series:[{name:m.name,color:mColor(hMetric),values:v}]});};
function weekIdx(t){const d=Math.floor((Date.now()-t)/(7*864e5));return 7-d;}
drawLoad=function(){const wk=Array.from({length:8},(_,i)=>{const d=new Date();d.setDate(d.getDate()-7*(7-i));return dlab(d);});
  const run=Array(8).fill(0),lift=Array(8).fill(0);
  RUNS.forEach(r=>{const i=weekIdx(r.t);if(i>=0&&i<8)run[i]+=Math.round(r.sec/60);});SESS.forEach(s=>{const i=weekIdx(s.t);if(i>=0&&i<8)lift[i]+=s.minutes||0;});
  if(!run.some(Boolean)&&!lift.some(Boolean)){$('#loadLegend').innerHTML='';emptyNote($('#loadChart'),'Fills in as you save workouts and runs.');return;}
  legend($('#loadLegend'),[['Running',HC.run],['Strength',HC.lift]]);
  chart($('#loadChart'),{labels:wk,stacked:true,fmt:v=>Math.round(v)+' min',series:[{name:'Running',color:HC.run,values:run},{name:'Strength',color:HC.lift,values:lift}]});};
drawOrm=function(){const cnt={};SESS.forEach(s=>s.exercises.forEach(e=>cnt[e.name]=(cnt[e.name]||0)+1));
  const top=Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,2).map(x=>x[0]);
  if(!top.length){$('#ormLegend').innerHTML='';emptyNote($('#ormChart'),'Your estimated maxes appear after you save a few strength workouts.');return;}
  const wk=Array.from({length:12},(_,i)=>{const d=new Date();d.setDate(d.getDate()-7*(11-i));return dlab(d);});
  const cols=[HC.squat,HC.bench];
  const ser=top.map((n,j)=>{const a=Array(12).fill(null);SESS.forEach(s=>{const i=11-Math.floor((Date.now()-s.t)/(7*864e5));const e=s.exercises.find(x=>x.name===n);if(e&&i>=0){const b=Math.max(...e.sets.filter(x=>x.type!=='W').map(x=>e1rm(x.w,x.r)),0);if(b)a[i]=Math.max(a[i]||0,Math.round(b));}});return {name:n,color:cols[j],values:a};}).filter(s=>vals(s.values).length);
  if(!ser.length){emptyNote($('#ormChart'),'Your estimated maxes appear after you log weighted sets.');return;}
  legend($('#ormLegend'),ser.map(s=>[s.name,s.color]));
  chart($('#ormChart'),{labels:wk,type:'line',fmt:v=>Math.round(v)+' lb',series:ser});};
drawStages=function(){const sub=$('#stages').parentNode.querySelector('.sub');if(sub)sub.textContent='From Apple Health';emptyNote($('#stages'),'Deep, core and REM sleep arrive from your Garmin through Apple Health.');};
drawNutrition=function(){const rows=[['Calories','cal','cal',''],['Protein','protein','protein',' g'],['Carbs','carbs',null,' g'],['Fat','fat',null,' g'],['Water','water','water',' oz']];
  const box=$('#nutrition');box.innerHTML='';
  rows.forEach(([n,k,p,u])=>{const v=series[k][N-1];const t=p&&P[p]?+P[p]:null;
    box.append(el('div',{class:'vb nrow'},el('span',{},n),el('div',{class:'tr'},el('div',{style:`width:${v&&t?Math.min(100,v/t*100):0}%;background:${mColor(k)}`})),el('span',{class:'n'},(v==null?'—':Math.round(v).toLocaleString())+(t?' / '+t.toLocaleString():'')+u)));});
  if(!P.cal&&!P.water)box.append(el('div',{class:'sub',style:'font-size:12px'},'Set your targets in Settings.'));};
function logAndRedraw(k,v,msg){saveEntry(k,v);drawHealth();toast(msg);}
drawLog=function(){const box=$('#quicklog');box.innerHTML='';
  const items=[
   ['+ 8 oz water',()=>logAndRedraw('water',8,'8 oz water logged')],
   ['Weight',()=>logSheet('Log weight',stepperField('lw',lastVal('weight')??180,0.2,'lb'),()=>logAndRedraw('weight',$('#lw').value,$('#lw').value+' lb logged'))],
   ['Body fat',()=>logSheet('Log body fat',stepperField('lbf',lastVal('bodyfat')??20,0.1,'%'),()=>logAndRedraw('bodyfat',$('#lbf').value,$('#lbf').value+'% body fat logged'))],
   ['Waist',()=>logSheet('Log waist',stepperField('lws',lastVal('waist')??34,0.1,'in'),()=>logAndRedraw('waist',$('#lws').value,$('#lws').value+' in waist logged'))],
   ['Mood',()=>{let pick=4;const chips=el('div',{class:'chips'});const draw=()=>{chips.innerHTML='';MOODS.forEach((m,i)=>chips.append(el('button',{'aria-pressed':String(i===pick),onclick:()=>{pick=i;draw();}},m)));};draw();logSheet('How do you feel right now?',chips,()=>logAndRedraw('mood',pick+1,'Mood logged as '+MOODS[pick]));}],
   ['Caffeine',()=>logSheet('Log caffeine',stepperField('lcf',95,5,'mg'),()=>logAndRedraw('caffeine',$('#lcf').value,$('#lcf').value+' mg caffeine logged'))],
   ['Mindful minutes',()=>logSheet('Log mindful minutes',stepperField('lmm',10,1,'min'),()=>logAndRedraw('mindful',$('#lmm').value,$('#lmm').value+' mindful minutes logged'))]];
  items.forEach(([t,f])=>box.append(el('button',{class:'logbtn',onclick:f},t)));
  const sub=box.parentNode.querySelector('.sub');if(sub)sub.textContent='Saved on this device now, and to Apple Health once the iPhone app is connected';};
drawAllData=function(){const box=$('#alldata');box.innerHTML='';
  GROUPS.forEach(gr=>{const card=el('div',{class:'grp'},el('div',{class:'grphead'},el('span',{class:'sw',style:'background:'+GC[gr]}),el('h2',{},gr)));
    Object.entries(METRICS).filter(([,m])=>m.group===gr).forEach(([k,m])=>{const v=vals(series[k].slice(N-14));const last=lastVal(k);
      const row=el('button',{class:'drow',onclick:()=>{hMetric=k;drawTiles();drawTrend();flash($('#trendCard'));$('#trendCard').scrollIntoView({behavior:'smooth',block:'center'});}},
        el('div',{class:'dname'},el('b',{},m.name),m.note?el('span',{class:'sub'},m.note):null),
        el('span',{class:'dval num',style:last==null?'color:var(--dim)':''},last==null?'—':m.fmt(last)),
        el('span',{class:'rw'},el('i',{class:'on'},'Read'),el('i',{class:m.rw==='RW'?'on':''},'Write')));
      if(v.length>1)row.insertAdjacentHTML('beforeend',spark(v,mColor(k)));card.append(row);});
    box.append(card);});
  box.append(el('div',{class:'grp'},el('div',{class:'grphead'},el('span',{class:'sw',style:'background:var(--muted)'}),el('h2',{},'Cycle tracking')),
    el('div',{class:'drow',style:'cursor:default'},el('div',{class:'dname'},el('b',{},'Periods, symptoms and predictions'),el('span',{class:'sub'},'Off by default. Only the person it belongs to can see it, never their partner.')),el('span',{class:'dval'}),el('span',{class:'rw'},el('i',{class:'on'},'Read'),el('i',{class:'on'},'Write')))));};

/* ---- strength ---- */
function lastFor(name){for(let i=SESS.length-1;i>=0;i--){const e=SESS[i].exercises.find(x=>x.name===name);if(e)return e.sets.filter(s=>s.type!=='W');}return null;}
function setsFor(name,count,reps){const last=lastFor(name);if(last&&last.length)return last.map(s=>S('N',s.w,s.r,s.w,s.r));return Array.from({length:count},()=>S('N',0,reps,null,null));}
exs=[];
const dateLab=new Date().toLocaleDateString('en-CA',{weekday:'short',day:'numeric',month:'short'});
$('#lift h1').textContent='Workout';$('#clock').parentNode.firstChild.textContent=dateLab+' · ';
const _render=render;render=function(){_render();if(!exs.length)$('#exList').append(el('div',{class:'emptynote'},'No exercises yet. Start today\'s session from Splits, or add an exercise below. Weights start blank until you\'ve logged an exercise once, then your last numbers fill in.'));};
const _complete=complete;complete=function(ex,s){if(!t0)t0=Date.now();_complete(ex,s);};
$('#addExBtn').onclick=()=>{openSheet(()=>{const wrap=el('div');const q=el('input',{class:'search',placeholder:'Search exercises','aria-label':'Search exercises',id:'exq'});const res=el('div');
  const draw=()=>{res.innerHTML='';library.filter(l=>l[0].toLowerCase().includes(q.value.toLowerCase())).forEach(l=>res.append(el('button',{class:'pick',onclick:()=>{exs.push({id:'x'+(++uid),name:l[0],meta:l[1]+(lastFor(l[0])?' · last time filled in':''),rest:90,ss:null,sets:setsFor(l[0],3,l[3])});closeSheet();render();toast(l[0]+' added');}},el('b',{},l[0]),el('span',{},l[1]))));};
  q.addEventListener('input',draw);draw();wrap.append(el('h2',{style:'margin-bottom:10px'},'Add exercise'),q,res);return wrap;});};
startDay=function(sp,i){const d=sp.days[i];const low=lowRecovery();
  exs=d.ex.map((e,k)=>{const [m,,r]=LIB[e.n];let sets=setsFor(e.n,Math.max(1,e.s-(low?1:0)),r);return {id:'p'+k+'_'+(++uid),name:e.n,meta:MUS[m][0]+' · '+sp.name,rest:LEGGY.has(d.type)&&k<2?150:90,ss:null,sets};});
  $('#lift h1').textContent=DN[i]+' · '+d.type;t0=null;render();goMain(1);toast(d.type+' session ready');};
function drawLiftHist(){const box=$('#liftHist');if(!box)return;box.innerHTML='';
  if(!SESS.length){box.append(el('div',{class:'emptynote'},'Workouts you finish are saved here.'));return;}
  SESS.slice(-8).reverse().forEach(s=>{let sets=0,vol=0;s.exercises.forEach(e=>e.sets.forEach(x=>{if(x.type!=='W'){sets++;vol+=x.w*x.r;}}));
    box.append(el('div',{class:'histrow'},el('div',{style:'min-width:0'},el('b',{},s.title),el('div',{class:'sub',style:'font-size:12px'},new Date(s.t).toLocaleDateString('en-CA',{weekday:'short',month:'short',day:'numeric'})+' · '+s.exercises.map(e=>e.name).join(', '))),el('span',{class:'num sub'},sets+' sets · '+vol.toLocaleString()+' lb')));});}
$('#finish').onclick=()=>{const done=exs.map(ex=>({name:ex.name,sets:ex.sets.filter(s=>s.done).map(s=>({type:s.type,w:s.w,r:s.r}))})).filter(e=>e.sets.length);
  if(!done.length){toast('Check off at least one set first');return;}
  let vol=0,n=0;done.forEach(e=>e.sets.forEach(s=>{if(s.type!=='W'){vol+=s.w*s.r;n++;}}));const minutes=t0?Math.max(1,Math.round((Date.now()-t0)/60000)):0;
  openSheet(()=>el('div',{},el('h2',{},$('#lift h1').textContent+' complete'),el('p',{class:'sub'},n+' working sets · '+vol.toLocaleString()+' lb volume'+(minutes?' · '+minutes+' min':'')),
    el('p',{class:'sub',style:'font-size:12px'},'Saved on this device. It also goes to Apple Health as a strength workout once the iPhone app is connected.'),
    el('button',{class:'cta wide',style:'margin-top:10px',onclick:()=>{SESS.push({date:todayIso,t:Date.now(),title:$('#lift h1').textContent,minutes,exercises:done});store.set('hb.sessions',SESS);
      exs=[];t0=null;$('#lift h1').textContent='Workout';$('#clock').textContent='00:00';closeSheet();render();drawLiftHist();$('#rest').hidden=true;toast('Workout saved');}},'Save workout')));};

/* ---- run ---- */
const imp=$('#runLog .import');imp.innerHTML='';imp.append(el('div',{class:'src'},'Garmin via Apple Health'),el('div',{style:'font-weight:600;margin-top:4px'},'Your runs land here automatically'),el('div',{class:'sub',style:'font-size:13px;margin-top:4px'},'Once the iPhone app is connected, each run from your watch shows up with its splits and heart rate, ready to save with one tap. Until then, enter runs by hand.'));
['#dist','#hh','#mm','#ss'].forEach(s=>$(s).value='');$('#dist').placeholder='0.00';$('#mm').placeholder='00';$('#ss').placeholder='00';$('#hh').placeholder='0';
const _calc=calcPace;calcPace=function(){_calc();const d=parseFloat($('#dist').value)||0;if(!d)$('#pace').firstChild.textContent='—';};calcPace();
drawChips=function(){$('#runType').innerHTML='';types.forEach(t=>$('#runType').append(el('button',{'aria-pressed':String(t===runType),onclick:()=>{runType=t;drawChips();}},t)));
  const sh=(P.shoes||'').split(',').map(s=>s.trim()).filter(Boolean);$('#shoes').innerHTML='';
  if(!sh.length)$('#shoes').append(el('span',{class:'sub',style:'font-size:13px'},'Add your shoes in Settings to track their miles.'));
  sh.forEach((s,i)=>{const mi=RUNS.filter(r=>r.shoe===s).reduce((a,r)=>a+r.dist,0);$('#shoes').append(el('button',{'aria-pressed':String(i===shoe),onclick:()=>{shoe=i;drawChips();}},s+(mi?' · '+mi.toFixed(0)+' mi':'')));});};
drawChips();
function drawRunHist(){const box=$('#runHist');if(!box)return;box.innerHTML='';
  if(!RUNS.length){box.append(el('div',{class:'emptynote'},'Runs you save are listed here.'));return;}
  RUNS.slice(-8).reverse().forEach(r=>box.append(el('div',{class:'histrow'},el('div',{},el('b',{},r.type+' run'),el('div',{class:'sub',style:'font-size:12px'},new Date(r.t).toLocaleDateString('en-CA',{weekday:'short',month:'short',day:'numeric'})+(r.notes?' · '+r.notes:''))),el('span',{class:'num sub'},r.dist.toFixed(2)+' mi · '+fmt(r.sec/r.dist)+' /mi'))));}
$('#saveRun').onclick=()=>{const d=parseFloat($('#dist').value)||0;const sec=(+$('#hh').value||0)*3600+(+$('#mm').value||0)*60+(+$('#ss').value||0);
  if(!d||!sec){toast('Add a distance and a time first');return;}
  const sh=(P.shoes||'').split(',').map(s=>s.trim()).filter(Boolean);
  RUNS.push({date:todayIso,t:Date.now(),type:runType,dist:d,sec,rpe:+$('#rpe').value,shoe:sh[shoe]||'',notes:$('#runNotes').value.trim()});store.set('hb.runs',RUNS);
  ['#dist','#hh','#mm','#ss','#runNotes'].forEach(s=>$(s).value='');calcPace();drawRunHist();drawChips();toast(runType+' run saved: '+d.toFixed(2)+' mi');};

/* ---- settings ---- */
const KNOWN=['Weights in pounds, distances in miles','Strength logging with warm-up sets and supersets','Garmin watch, read through Apple Health (direct Garmin sync waits until Garmin reopens its developer program)','Apple Health is the only health source; Strava is off','Home Base writes workouts, weight, body fat, waist, water, caffeine, mood and mindful minutes to Apple Health','Food comes from MacroFactor through Apple Health','Bank: CIBC, connected through Plaid','Shared with your wife; cycle tracking stays private to each person','Dark look with an orange accent'];
function openSettings(){$('#sheet').classList.add('tall');
  openSheet(()=>{const f=(key,label,type='text',ph='')=>{const i=el('input',{id:'set_'+key,type,value:P[key]??'',placeholder:ph,'aria-label':label});return el('label',{},label,i);};
    let g=P.goal||'Hybrid';const gchips=el('div',{class:'chips'});const drawG=()=>{gchips.innerHTML='';['Strength','Muscle','Running','Hybrid','General'].forEach(x=>gchips.append(el('button',{'aria-pressed':String(x===g),onclick:()=>{g=x;drawG();}},x)));};drawG();
    const counts=[['Health entries',Object.values(ENT).reduce((a,x)=>a+x.length,0)],['Workouts',SESS.length],['Runs',RUNS.length],['Transactions',(store.get('hbm.real.tx')||[]).length]];
    const clearBox=el('div');const drawClear=(ask)=>{clearBox.innerHTML='';clearBox.append(ask?el('div',{class:'confirm'},el('span',{},'Delete everything Home Base saved on this device? This can\'t be undone.'),el('div',{style:'display:flex;gap:8px'},el('button',{class:'btn2',onclick:()=>drawClear(false)},'Keep it'),el('button',{class:'btn2',style:'color:var(--z5);border-color:var(--z5)',onclick:()=>{try{Object.keys(localStorage).filter(k=>/^hbm?\./.test(k)).forEach(k=>localStorage.removeItem(k));}catch(e){}location.reload();}},'Delete'))):el('button',{class:'btn2',style:'color:var(--z5)',onclick:()=>drawClear(true)},'Delete my data on this device'));};drawClear(false);
    return el('div',{},
      el('div',{class:'edtop'},el('span',{style:'width:64px'}),el('b',{},'Settings'),el('button',{class:'ghost',onclick:closeSheet},'Close')),
      el('div',{class:'label',style:'margin-top:14px'},'Profile'),
      el('div',{class:'sgrid'},f('name','Your name'),f('partner','Partner\'s name','text','Not set'),f('watch','Watch','text','e.g. Garmin Forerunner 265')),
      el('div',{class:'label',style:'margin-top:14px'},'Training'),el('div',{style:'margin-top:6px'},gchips),
      el('div',{class:'sgrid'},f('liftDays','Lift days a week','number','Not set'),f('runs','Runs a week','number','Not set'),f('avail','Days you can train','number','Not set'),f('shoes','Running shoes','text','Comma separated')),
      el('div',{class:'label',style:'margin-top:14px'},'Daily targets'),
      el('div',{class:'sgrid'},f('sleepTarget','Sleep (hours)','number','Not set'),f('stepGoal','Steps','number','Not set'),f('cal','Calories','number','Not set'),f('protein','Protein (g)','number','Not set'),f('water','Water (oz)','number','Not set')),
      el('button',{class:'cta wide',style:'margin-top:14px',onclick:()=>{['name','partner','watch','liftDays','runs','avail','shoes','sleepTarget','stepGoal','cal','protein','water'].forEach(k=>P[k]=$('#set_'+k).value.trim());P.goal=g;store.set('hb.profile',P);applyProfile();drawAll();drawChips();drawHealth();closeSheet();toast('Settings saved');}},'Save settings'),
      el('div',{class:'label',style:'margin-top:20px'},'What Home Base already knows about you'),
      el('ul',{class:'facts'},KNOWN.map(k=>el('li',{},k))),
      el('div',{class:'label',style:'margin-top:16px'},'Connections'),
      el('div',{style:'display:flex;gap:8px;flex-wrap:wrap;margin-top:8px'},el('button',{class:'btn2',onclick:()=>{closeSheet();setTimeout(openSync,320);}},'Health connections'),el('button',{class:'btn2',onclick:()=>{closeSheet();setTimeout(()=>document.getElementById('connBtn').click(),320);}},'Bank accounts')),
      el('div',{class:'label',style:'margin-top:16px'},'Saved on this device'),
      el('div',{class:'counts'},counts.map(([k,v])=>el('div',{},el('b',{class:'num'},v),el('span',{},k)))),
      el('p',{class:'sub',style:'font-size:12px'},'Everything stays in this browser until the iPhone and Mac app can sync it. Nothing is uploaded.'),
      clearBox);},true);}
HB.openSettings=openSettings;

/* data access for the AI assistant */
HB.data={
  profile:()=>P,entries:()=>ENT,sessions:()=>SESS,runs:()=>RUNS,today:()=>todayIso,
  metrics:()=>Object.fromEntries(Object.entries(METRICS).map(([k,m])=>[k,{name:m.name,unit:m.unit||'',group:m.group||''}])),
  splitToday:()=>{try{const s=mySplits.find(x=>x.id===activeId);return s?{split:s.name}:null;}catch(e){return null;}},
  logEntry(k,v){if(!METRICS[k])throw new Error('Unknown metric "'+k+'". Use one of: '+Object.keys(METRICS).join(', '));v=+v;if(!isFinite(v))throw new Error('Value must be a number');saveEntry(k,v);drawHealth();return ENT[k][ENT[k].length-1].t;},
  addRun(r){const t=Date.now();RUNS.push({date:todayIso,t,type:String(r.type||'Easy'),dist:+r.dist||0,sec:+r.sec||0,rpe:+r.rpe||5,shoe:'',notes:String(r.notes||'')});store.set('hb.runs',RUNS);drawRunHist();drawHealth();return t;},
  addSession(s){const t=Date.now();const ex=(s.exercises||[]).map(e=>({name:String(e.name),sets:(e.sets||[]).map(x=>({type:x.type==='W'?'W':'N',w:+x.w||0,r:+x.r||0}))})).filter(e=>e.sets.length);
    if(!ex.length)throw new Error('A workout needs at least one exercise with sets');SESS.push({date:todayIso,t,title:String(s.title||'Workout'),minutes:+s.minutes||0,exercises:ex});store.set('hb.sessions',SESS);drawLiftHist();drawHealth();return t;},
  undo(kind,t,k){if(kind==='entry'){ENT[k]=(ENT[k]||[]).filter(x=>x.t!==t);store.set('hb.entries',ENT);rebuildSeries();}
    else if(kind==='run'){const i=RUNS.findIndex(x=>x.t===t);if(i>=0)RUNS.splice(i,1);store.set('hb.runs',RUNS);drawRunHist();}
    else if(kind==='session'){const i=SESS.findIndex(x=>x.t===t);if(i>=0)SESS.splice(i,1);store.set('hb.sessions',SESS);drawLiftHist();}
    drawHealth();}
};

HB.data.importHealth=function(data){Object.entries(data.entries).forEach(([k,list])=>{if(!METRICS[k])return;ENT[k]=(ENT[k]||[]).filter(e=>e.src!=='health').concat(list.map(e=>({d:e.d,t:Date.parse(e.d+'T12:00:00'),v:e.v,src:'health'})));});
  store.set('hb.entries',ENT);for(let i=RUNS.length-1;i>=0;i--)if(RUNS[i].src==='health')RUNS.splice(i,1);
  data.runs.forEach(r=>RUNS.push(Object.assign({rpe:5,shoe:'',notes:'From Apple Health',src:'health'},r)));RUNS.sort((a,b)=>a.t-b.t);store.set('hb.runs',RUNS);
  store.set('hb.healthImport',{at:Date.now(),records:data.count,from:data.from,to:data.to,runs:data.runs.length});
  rebuildSeries();applyProfile();drawHealth();drawRunHist();};
HB.data.healthImport=()=>store.get('hb.healthImport');
openSync=function(){HB.openConnections&&HB.openConnections();};
/* initial real-data render */
applyProfile();
if(!mySplits.length)activeId=null;
drawAll();drawLiftHist();drawRunHist();
