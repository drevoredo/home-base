/* ---------- Connections: one place to connect every source, plus Apple Health export import ---------- */
(function(){
const $=s=>document.querySelector(s);
const el=(t,a={},...kids)=>{const n=document.createElement(t);for(const k in a){if(k==='class')n.className=a[k];else if(k.startsWith('on'))n.addEventListener(k.slice(2),a[k]);else n.setAttribute(k,a[k]);}kids.flat().forEach(c=>c!=null&&n.append(c.nodeType?c:document.createTextNode(c)));return n;};
const toast=m=>{const t=$('#toast');if(!t)return;t.textContent=m;t.classList.add('on');clearTimeout(toast.t);toast.t=setTimeout(()=>t.classList.remove('on'),3000);};
const fmtDate=t=>new Date(t).toLocaleDateString('en-CA',{month:'short',day:'numeric',year:'numeric'});
const sheetOpen=(node,tall)=>{const sh=$('#sheet'),si=$('#sheetIn');si.innerHTML='';si.append(el('div',{class:'grab'}),node);sh.classList.toggle('tall',!!tall);$('#scrim').classList.add('on');sh.classList.add('on');};
const sheetClose=()=>{$('#scrim').classList.remove('on');$('#sheet').classList.remove('on');setTimeout(()=>{if(!$('#sheet').classList.contains('on'))$('#sheet').classList.remove('tall');},400);};

const hfile=el('input',{type:'file',id:'healthFile',accept:'.zip,.xml,application/zip,text/xml',hidden:''});document.body.append(hfile);

/* status of each source, worked out from what is saved on this device */
function sources(){const hi=HB.data&&HB.data.healthImport();const tx=HB.money?HB.money.tx():[];const ent=HB.data?HB.data.entries():{};
  const has=k=>(ent[k]||[]).some(e=>e.src==='health');
  return [
   {id:'health',name:'Apple Health',what:'Sleep, HRV, resting heart rate, steps, weight, runs and everything else on the Today screen.',
    status:hi?{ok:true,text:'Imported '+fmtDate(hi.at)+' · '+hi.from+' to '+hi.to}:{ok:false,text:'Not connected'},
    steps:['On your iPhone, open the Health app and tap your picture at the top right.','Tap Export All Health Data, then Export. It can take a few minutes.','Save the file to Files or AirDrop it to your Mac, then pick it here.'],
    action:['Import Health export',()=>hfile.click()],later:'Live sync comes with the iPhone app. Until then, import a fresh export whenever you want to update.'},
   {id:'garmin',name:'Garmin',via:'Apple Health',what:'Runs with heart rate, sleep, HRV, resting heart rate and steps from your watch.',
    status:has('hrv')||has('sleep')?{ok:true,text:'Data arriving'}:{ok:false,text:'No data yet'},
    steps:['Open Garmin Connect on your iPhone.','Tap More (or your profile), then Settings, then Connected Apps, then Apple Health.','Turn on every category it offers, then import your Health export above.']},
   {id:'macrofactor',name:'MacroFactor',via:'Apple Health',what:'Calories, protein, carbs, fat and water.',
    status:has('cal')||has('protein')?{ok:true,text:'Data arriving'}:{ok:false,text:'No data yet'},
    steps:['Open MacroFactor and go to More, then Integrations, then Apple Health.','Turn on writing nutrition to Apple Health.','Import your Health export above.']},
   {id:'cibc',name:'CIBC',what:'Transactions for Money: activity, budgets and How we did.',
    status:tx.length?{ok:true,text:tx.length+' transactions from files'}:{ok:false,text:'Not connected'},
    steps:['Sign in to CIBC Online Banking on a computer.','Open an account, choose Download transactions, pick the dates and the spreadsheet (CSV) format.','Pick the file here. Do this for chequing and your credit card.'],
    action:['Import CIBC file',()=>{sheetClose();setTimeout(()=>$('#csvFile').click(),50);}],later:'Connecting through Plaid for automatic updates comes with the iPhone and Mac app.'}
  ];}

function openConnections(focus){
  const list=sources();const wrap=el('div',{class:'connhub'});
  wrap.append(el('div',{class:'aihead'},el('div',{},el('h2',{},'Connections'),el('div',{class:'sub',style:'font-size:12px'},'Where Home Base gets your data. Anything not connected yet has its steps here.')),el('button',{class:'ghost',onclick:sheetClose},'Close')));
  list.forEach(s=>{const open=focus?focus===s.id:!s.status.ok;
    const body=el('div',{class:'cbody'},el('p',{class:'sub'},s.what),el('ol',{class:'csteps'},s.steps.map(x=>el('li',{},x))),
      s.action?el('button',{class:'cta',onclick:s.action[1]},s.action[0]):null,s.later?el('p',{class:'sub',style:'font-size:12px;margin:8px 0 0'},s.later):null);
    const card=el('details',{class:'csrc'+(s.status.ok?' ok':''),id:'conn_'+s.id},el('summary',{},
      el('span',{class:'cdot'}),el('div',{class:'cname'},el('b',{},s.name),el('span',{},s.via?'Through '+s.via+' · '+s.status.text:s.status.text)),
      el('span',{class:'tag'+(s.status.ok?' ok':'')},s.status.ok?'Connected':'Connect')),body);
    if(open)card.setAttribute('open','');wrap.append(card);});
  wrap.append(el('div',{class:'label',style:'margin:16px 0 4px'},'Home Base will write back to Apple Health'),
    el('p',{class:'sub',style:'font-size:12.5px;margin:0'},'Strength workouts, runs you enter by hand, weight, body fat, waist, water, caffeine, mood and mindful minutes. This starts with the iPhone app.'));
  sheetOpen(wrap,true);
  if(focus)setTimeout(()=>{const n=$('#conn_'+focus);if(n)n.scrollIntoView({block:'center',behavior:'smooth'});},300);}

/* ---------- Apple Health export reader (zip or export.xml), all in the browser ---------- */
const QTY={StepCount:['steps','sum'],DistanceWalkingRunning:['dist','sum'],ActiveEnergyBurned:['energy','sum'],AppleExerciseTime:['exmin','sum'],FlightsClimbed:['flights','sum'],
 VO2Max:['vo2','avg'],HeartRateVariabilitySDNN:['hrv','avg'],RestingHeartRate:['rhr','avg'],WalkingHeartRateAverage:['walkhr','avg'],RespiratoryRate:['resp','avg'],OxygenSaturation:['spo2','avg'],
 BodyMass:['weight','last'],BodyFatPercentage:['bodyfat','last'],LeanBodyMass:['lean','last'],WaistCircumference:['waist','last'],BodyMassIndex:['bmi','last'],
 DietaryEnergyConsumed:['cal','sum'],DietaryProtein:['protein','sum'],DietaryCarbohydrates:['carbs','sum'],DietaryFatTotal:['fat','sum'],DietaryWater:['water','sum'],DietaryCaffeine:['caffeine','sum'],
 BloodPressureSystolic:['bp','avg'],BloodGlucose:['glucose','avg'],RunningPower:['rpower','avg'],RunningStrideLength:['stride','avg'],RunningGroundContactTime:['gct','avg'],RunningVerticalOscillation:['vosc','avg']};
function conv(k,v,u){u=(u||'').toLowerCase();
  if((k==='weight'||k==='lean')&&u==='kg')return v*2.20462;
  if(k==='waist'&&u==='cm')return v/2.54;
  if(k==='dist'){if(u==='km')return v*0.621371;if(u==='m')return v/1609.34;}
  if(k==='energy'&&u==='kj')return v/4.184;
  if(k==='cal'&&u==='kj')return v/4.184;
  if(k==='water'){if(u==='ml')return v/29.5735;if(u==='l')return v*33.814;}
  if(k==='caffeine'&&u==='g')return v*1000;
  if((k==='spo2'||k==='bodyfat')&&u==='%'&&v<=1)return v*100;
  if(k==='stride'&&u==='m')return v*3.28084;
  if(k==='vosc'&&u==='cm')return v/2.54;
  if(k==='gct'&&u==='s')return v*1000;
  if(k==='glucose'&&/^mmol/.test(u))return v*18.016;
  return v;}
const toDate=s=>new Date(s.replace(' ','T').replace(/ ([+-]\d\d)(\d\d)$/,'$1:$2'));
const attrs=s=>{const o={};s.replace(/(\w+)="([^"]*)"/g,(_,k,v)=>{o[k]=v;return'';});return o;};

async function xmlStream(file){
  if(/\.xml$/i.test(file.name))return file.stream();
  // find export.xml inside the zip from the central directory, then inflate just that entry
  const tail=new DataView(await file.slice(Math.max(0,file.size-66000)).arrayBuffer());let e=-1;
  for(let i=tail.byteLength-22;i>=0;i--)if(tail.getUint32(i,true)===0x06054b50){e=i;break;}
  if(e<0)throw new Error('That file is not a Health export zip.');
  let cdSize=tail.getUint32(e+12,true),cdOff=tail.getUint32(e+16,true);
  if(cdOff===0xFFFFFFFF||cdSize===0xFFFFFFFF){const l=e-20;if(l>=0&&tail.getUint32(l,true)===0x07064b50){const off64=Number(tail.getBigUint64(l+8,true));const z=new DataView(await file.slice(off64,off64+56).arrayBuffer());cdSize=Number(z.getBigUint64(40,true));cdOff=Number(z.getBigUint64(48,true));}}
  const cd=new DataView(await file.slice(cdOff,cdOff+cdSize).arrayBuffer());let p=0,hit=null;const dec=new TextDecoder();
  while(p+46<=cd.byteLength&&cd.getUint32(p,true)===0x02014b50){const method=cd.getUint16(p+10,true);let csize=cd.getUint32(p+20,true),usize=cd.getUint32(p+24,true);const nlen=cd.getUint16(p+28,true),xlen=cd.getUint16(p+30,true),clen=cd.getUint16(p+32,true);let loff=cd.getUint32(p+42,true);
    const name=dec.decode(new Uint8Array(cd.buffer,p+46,nlen));
    if(/(^|\/)export\.xml$/.test(name)){let q=p+46+nlen;const end=q+xlen;while(q+4<=end){const id=cd.getUint16(q,true),sz=cd.getUint16(q+2,true);if(id===1){let r=q+4;if(usize===0xFFFFFFFF){usize=Number(cd.getBigUint64(r,true));r+=8;}if(csize===0xFFFFFFFF){csize=Number(cd.getBigUint64(r,true));r+=8;}if(loff===0xFFFFFFFF){loff=Number(cd.getBigUint64(r,true));}}q+=4+sz;}
      hit={method,csize,loff};break;}
    p+=46+nlen+xlen+clen;}
  if(!hit)throw new Error('No export.xml inside that zip. Pick the export.zip from the Health app.');
  const lh=new DataView(await file.slice(hit.loff,hit.loff+30).arrayBuffer());const start=hit.loff+30+lh.getUint16(26,true)+lh.getUint16(28,true);
  const raw=file.slice(start,start+hit.csize).stream();
  if(hit.method===0)return raw;
  if(typeof DecompressionStream==='undefined')throw new Error('This browser cannot open zip files. Unzip it and pick export.xml instead.');
  return raw.pipeThrough(new DecompressionStream('deflate-raw'));}

async function importHealth(file,onProgress){
  const days=365,cutoff=new Date(Date.now()-days*864e5).toISOString().slice(0,10);
  const agg={},sleep={},inbed={},mind={},runs=[];let count=0,wk=null,minD='9999',maxD='0000';
  const put=(k,how,d,src,v)=>{const a=agg[k]=agg[k]||{};const x=a[d]=a[d]||{};if(how==='sum'){x[src]=(x[src]||0)+v;}else if(how==='avg'){x.s=(x.s||0)+v;x.n=(x.n||0)+1;}else{x.v=v;}};
  const finish=()=>{if(wk){const sec=Math.round(parseFloat(wk.duration)*((wk.durationUnit||'min')==='min'?60:1));
    runs.push({date:wk.startDate.slice(0,10),t:toDate(wk.startDate).getTime(),type:'Easy',dist:+(wk.mi||0).toFixed(2),sec,notes:'From '+(wk.sourceName||'Apple Health')});}wk=null;};
  const reader=(await xmlStream(file)).pipeThrough(new TextDecoderStream()).getReader();let buf='',read=0;
  const re=/<(Record|WorkoutStatistics|Workout|\/Workout)\b([^>]*)>/g;
  for(;;){const {value,done}=await reader.read();if(done)break;buf+=value;read+=value.length;
    let last=0,m;re.lastIndex=0;
    while((m=re.exec(buf))){last=re.lastIndex;const tag=m[1],s=m[2];
      if(tag==='Record'){const ti=s.indexOf('type="HK');if(ti<0)continue;const a=attrs(s);const d=(a.startDate||'').slice(0,10);if(d<cutoff)continue;
        const t=a.type.replace(/^HK(Quantity|Category)TypeIdentifier/,'');const src=a.sourceName||'?';
        if(QTY[t]){const [k,how]=QTY[t];const v=conv(k,parseFloat(a.value),a.unit);if(!isFinite(v))continue;put(k,how,d,src,v);count++;}
        else if(t==='SleepAnalysis'){const hrs=(toDate(a.endDate)-toDate(a.startDate))/36e5;const dd=(a.endDate||'').slice(0,10);if(!(hrs>0))continue;
          const tgt=/Asleep/.test(a.value)?sleep:/InBed/.test(a.value)?inbed:null;if(tgt){const x=tgt[dd]=tgt[dd]||{};x[src]=(x[src]||0)+hrs;count++;}}
        else if(t==='MindfulSession'){const min=(toDate(a.endDate)-toDate(a.startDate))/6e4;const x=mind[d]=mind[d]||{};x[src]=(x[src]||0)+min;count++;}
        if(d<minD)minD=d;if(d>maxD)maxD=d;}
      else if(tag==='Workout'){finish();const a=attrs(s);wk=/Running/.test(a.workoutActivityType||'')&&(a.startDate||'').slice(0,10)>=cutoff?a:null;
        if(wk&&a.totalDistance)wk.mi=conv('dist',parseFloat(a.totalDistance),a.totalDistanceUnit);
        if(/\/\s*$/.test(s))finish();}
      else if(tag==='WorkoutStatistics'){if(wk&&/DistanceWalkingRunning/.test(s)){const a=attrs(s);wk.mi=conv('dist',parseFloat(a.sum),a.unit);}}
      else if(tag==='/Workout')finish();}
    buf=buf.slice(Math.max(last,buf.lastIndexOf('<')));onProgress&&onProgress(read,count);}
  finish();
  // one value per day per metric; for totals, use the source with the most (iPhone and watch both count steps)
  const best=o=>Math.max(...Object.values(o));const entries={};
  Object.entries(agg).forEach(([k,byDay])=>{const how=Object.values(QTY).find(q=>q[0]===k)[1];entries[k]=Object.entries(byDay).map(([d,x])=>({d,v:+(how==='sum'?best(x):how==='avg'?x.s/x.n:x.v).toFixed(2)}));});
  const fromSrc=(o,k)=>{entries[k]=Object.entries(o).map(([d,x])=>({d,v:+best(x).toFixed(2)}));};fromSrc(sleep,'sleep');fromSrc(inbed,'inbed');fromSrc(mind,'mindful');
  if(!count&&!runs.length)throw new Error('No health data from the last year was found in that file.');
  return{entries,runs,count,from:minD,to:maxD};}

hfile.onchange=async e=>{const f=e.target.files[0];e.target.value='';if(!f)return;
  const bar=el('div',{class:'prog'},el('div',{style:'width:0%'}));const msg=el('p',{class:'sub'},'Reading '+f.name+'…');
  const box=el('div',{},el('h2',{},'Importing Apple Health'),msg,bar,el('p',{class:'sub',style:'font-size:12px'},'The file is read on this device and never uploaded. Big exports take a minute.'));sheetOpen(box);
  try{const r=await importHealth(f,(read,n)=>{msg.textContent=n.toLocaleString()+' records read…';bar.firstChild.style.width=Math.min(95,read/(f.size*(/\.zip$/i.test(f.name)?12:1))*100)+'%';});
    HB.data.importHealth(r);chips();bar.firstChild.style.width='100%';
    const kinds=Object.keys(r.entries).filter(k=>r.entries[k].length).length;
    msg.textContent='Done. '+r.count.toLocaleString()+' records from '+r.from+' to '+r.to+', '+kinds+' kinds of data and '+r.runs.length+' runs.';
    box.append(el('button',{class:'cta wide',style:'margin-top:12px',onclick:()=>{sheetClose();HB.area('health');}},'See Today'));}
  catch(err){msg.textContent=(err&&err.message)||'Could not read that file.';msg.style.color='var(--warn)';}};

/* ---------- wire every entry point to Connections ---------- */
function chips(){const hi=HB.data&&HB.data.healthImport();document.querySelectorAll('.sync[aria-label="Health connections"] .dot').forEach(d=>{d.style.background=hi?'var(--good)':'var(--line2)';d.style.boxShadow=hi?'':'none';});}
chips();
HB.openConnections=openConnections;HB.openSync=()=>openConnections();HB.importHealthFile=importHealth;
[['#syncBtn'],['#sendWatch'],['#hSrc']].forEach(([s])=>{const n=$(s);if(n)n.onclick=()=>openConnections();});
const cb=$('#connBtn');if(cb)cb.onclick=()=>openConnections('cibc');

// any empty state about missing data gets a Connect button
function decorate(n){if(n.dataset.cx)return;const t=n.textContent;let id=null;
  if(/Apple Health|Garmin|watch/i.test(t))id=/MacroFactor/i.test(t)?'macrofactor':'health';else if(/import|CIBC|transactions/i.test(t)&&!(HB.money&&HB.money.tx().length))id='cibc';
  if(!id)return;n.dataset.cx='1';n.append(el('button',{class:'cxbtn',onclick:ev=>{ev.stopPropagation();openConnections(id);}},id==='cibc'?'Connect CIBC':'Connect Apple Health'));}
const scan=()=>document.querySelectorAll('.emptynote:not([data-cx])').forEach(decorate);
new MutationObserver(()=>{clearTimeout(scan.t);scan.t=setTimeout(scan,50);}).observe(document.body,{childList:true,subtree:true});scan();
})();
