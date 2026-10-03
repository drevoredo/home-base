import re
T=open('home-base-training-log.html').read()
M=open('home-base-money.html').read()
def between(s,a,b):
    i=s.index(a)+len(a);j=s.index(b,i);return s[i:j]
def rep(s,a,b,c=1):
    assert s.count(a)==c,(a[:70],s.count(a));return s.replace(a,b)

# ---------- CSS ----------
tcss=between(T,'<style>','</style>')
mcss=between(M,'<style>','</style>')
mcss=mcss.replace('.big{','.bignum{').replace('.big small','.bignum small').replace('.field{','.mfield{').replace('.field input,.field select','.mfield input,.mfield select').replace('.check{','.mcheck{')
keep=('.monthbar','.hero','.bignum','.meter','.trio','.review','.bud','.budrow','.bar{','.bar .','.budfoot','.st{','.tx{','.tx:','.txic','.txm','.amt','.needs','.daygrp','.txlist','.filters','.frow','.custom','.sumline','.catbars','.cb{','.cb ','.score','.mfield','.mcheck','.triage','.catgrid','.prog','.slide','@keyframes slide','.plaid','.acct','.sw{')
mkeep='\n'.join(l for l in mcss.split('\n') if l.strip().startswith(keep))
shell_css=r"""
:root{--bad:#ff5a5f;--warn:#f5c542}
.toast:empty{display:none}
/* ---------- real data: empty states and settings ---------- */
.emptynote{border:1px dashed var(--line2);border-radius:12px;padding:14px;color:var(--muted);font-size:13px;line-height:1.45;background:transparent}
.sgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px;margin-top:8px}
.sgrid label{display:flex;flex-direction:column;gap:5px;font-size:12px;color:var(--muted);font-weight:600}
.sgrid input{background:var(--surface2);border:1px solid var(--line);border-radius:10px;padding:10px 12px;color:var(--fg);font:inherit;font-size:15px;font-weight:500;min-width:0}
.sgrid input:focus{outline:2px solid var(--accent);outline-offset:1px}
.facts{margin:8px 0 0;padding-left:18px;display:flex;flex-direction:column;gap:6px;color:var(--muted);font-size:13px;line-height:1.45}
.counts{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:8px}
.counts>div{background:var(--surface2);border-radius:10px;padding:10px;display:flex;flex-direction:column;gap:2px}
.counts b{font-size:18px}.counts span{font-size:11px;color:var(--muted)}
.confirm{border:1px solid var(--bad);border-radius:12px;padding:12px;display:flex;flex-direction:column;gap:10px;font-size:13px}
.histrow{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:12px 14px;background:var(--surface);border:1px solid var(--line);border-radius:12px}
/* ---------- AI ---------- */
#health>#aiCard{grid-column:1/-1}
.aicard{display:flex;flex-direction:column;gap:10px;border-color:#ee7f4b55;background:linear-gradient(135deg,rgba(238,127,75,.08),transparent 60%),var(--surface)}
.aitop{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.aispark{color:var(--accent);font-size:16px;line-height:1}
.aiin{display:flex;gap:8px;align-items:flex-end}
.aiin input,.aiin textarea{flex:1;min-width:0;background:var(--surface2);border:1px solid var(--line);border-radius:12px;padding:11px 12px;color:var(--fg);font:inherit;font-size:15px;resize:none;max-height:140px}
.aiin input:focus,.aiin textarea:focus{outline:2px solid var(--accent);outline-offset:1px}
.aichips{display:flex;gap:6px;flex-wrap:wrap}
.aichips button{border:1px solid var(--line2);border-radius:999px;padding:6px 11px;font-size:12.5px;color:var(--muted);background:transparent}
.aichips button:hover{color:var(--fg);border-color:var(--accent)}
.aihead{display:flex;justify-content:space-between;align-items:flex-start;gap:10px;margin-bottom:10px}
.ailog{display:flex;flex-direction:column;gap:10px;min-height:120px;max-height:calc(100dvh - 300px);overflow:auto;padding:4px 2px 10px}
.msg{max-width:88%;padding:10px 13px;border-radius:14px;font-size:14.5px;line-height:1.5}
.msg.me{align-self:flex-end;background:var(--accent);color:#14100d;border-bottom-right-radius:4px}
.msg.ai{align-self:flex-start;background:var(--surface2);border:1px solid var(--line);border-bottom-left-radius:4px}
.msg p{margin:0 0 6px}.msg p:last-child{margin:0}.msg ul{margin:4px 0 6px;padding-left:18px}.msg li{margin:2px 0}.msg h3{font-size:14px;margin:8px 0 4px}
.thinking{color:var(--muted);animation:aipulse 1.4s ease-in-out infinite}
@keyframes aipulse{50%{opacity:.4}}
.aierr{color:var(--warn);font-size:12.5px;margin-top:6px}
.ailogged{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-top:8px;padding-top:8px;border-top:1px solid var(--line);font-size:12.5px;color:var(--good)}
.ailogged.off{color:var(--muted)}
.aisort{display:flex;flex-direction:column;gap:6px;max-height:55dvh;overflow:auto}
.aifab{display:none}
.aitop .sub{flex-basis:100%;margin-left:26px!important}
.ai-on #reviewCard{flex-wrap:wrap;gap:10px}
.ai-on #reviewCard>div:first-child{flex:1 1 100%}
.ai-on #reviewCard>button{flex:1}
@media (min-width:960px){.aitop .sub{flex-basis:auto;margin-left:auto!important}.ai-on #reviewCard>div:first-child{flex:1 1 auto}.ai-on #reviewCard>button{flex:none}}
.ai-on .aifab{display:grid;place-items:center;position:fixed;right:16px;bottom:calc(76px + env(safe-area-inset-bottom,0px));z-index:34;width:50px;height:50px;border-radius:50%;background:var(--accent);color:#14100d;font-size:20px;box-shadow:0 6px 20px rgba(0,0,0,.45)}
body:has(#a_train:not([hidden])) .aifab{display:none}
@media (min-width:960px){.ai-on .aifab{display:none}}
/* ---------- connections ---------- */
.connhub{display:flex;flex-direction:column;gap:8px}
.csrc{border:1px solid var(--line);border-radius:14px;background:var(--surface2);overflow:hidden}
.csrc summary{list-style:none;display:flex;align-items:center;gap:12px;padding:13px 14px;cursor:pointer}
.csrc summary::-webkit-details-marker{display:none}
.cdot{width:9px;height:9px;border-radius:50%;background:var(--line2);flex:none}
.csrc.ok .cdot{background:var(--good);box-shadow:0 0 8px var(--good)}
.cname{display:flex;flex-direction:column;gap:2px;min-width:0;flex:1}.cname span{font-size:12px;color:var(--muted)}
.csrc .tag{flex:none}.csrc:not(.ok) .tag{color:var(--accent);border-color:var(--accent)}
.cbody{padding:0 14px 14px;border-top:1px solid var(--line)}
.cbody .sub{margin:10px 0 6px;font-size:13px}
.csteps{margin:0 0 12px;padding-left:20px;display:flex;flex-direction:column;gap:6px;font-size:13.5px;line-height:1.45}
.cxbtn{display:inline-flex;margin-top:10px;margin-left:0;border:1px solid var(--accent);color:var(--accent);border-radius:999px;padding:6px 12px;font-size:12.5px;font-weight:600;background:transparent}
.emptynote .cxbtn{display:flex;width:max-content}
.prog{height:6px;border-radius:3px;background:var(--line);overflow:hidden;margin:10px 0}.prog>div{height:100%;background:var(--accent);transition:width .3s}
/* ---------- merged shell: sidebar on laptops, bottom tab bar on phones ---------- */
.chips button{display:inline-flex;align-items:center;gap:6px}
.btn2{white-space:nowrap}
.side{display:none}
.bottom{position:fixed;left:0;right:0;bottom:0;z-index:35;display:grid;grid-template-columns:repeat(4,1fr);background:rgba(10,12,16,.92);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);border-top:1px solid var(--line);padding:6px 8px calc(6px + env(safe-area-inset-bottom,0px))}
.bottom button{display:flex;flex-direction:column;align-items:center;gap:3px;padding:6px 0;font-size:11px;font-weight:600;color:var(--dim);border-radius:10px;transition:color .2s}
.bottom button svg{width:22px;height:22px}
.bottom button[aria-current="page"]{color:var(--accent)}
.area .app{padding-bottom:150px}
.dock{bottom:calc(58px + env(safe-area-inset-bottom,0px));padding-bottom:10px}
.area[hidden]{display:none!important}
.side .nav svg{width:18px;height:18px;flex:none}
@media (min-width:960px){
  .bottom{display:none}
  .side{display:flex;flex-direction:column;gap:18px;position:fixed;top:0;bottom:0;left:0;width:232px;padding:22px 14px;border-right:1px solid var(--line);background:var(--surface);z-index:30;overflow:auto}
  .side .brandbig{font-family:var(--f-display);font-weight:600;font-size:20px;letter-spacing:.02em;padding:0 10px}
  .side .brandbig b{color:var(--accent)}
  .side .grp2{display:flex;flex-direction:column;gap:2px}
  .side .grp2>span{font-size:11px;text-transform:uppercase;letter-spacing:.09em;color:var(--dim);font-weight:600;padding:0 10px 6px}
  .side .nav{display:flex;align-items:center;gap:10px;padding:9px 10px;border-radius:10px;color:var(--muted);font-weight:500;text-align:left;width:100%}
  .side .nav:hover{background:var(--surface2);color:var(--fg)}
  .side .nav[aria-current="page"]{background:var(--surface2);color:var(--fg);box-shadow:inset 3px 0 0 var(--accent)}
  .side .foot{margin-top:auto;display:flex;flex-direction:column;gap:6px}
  .main{margin-left:232px}
  .area .app{max-width:1120px;padding-inline:32px;padding-bottom:120px}
  .area .top .seg{display:none}
  .area .top{padding-top:20px}
  .area .top .brand{font-size:13px}
  .dock{left:232px;bottom:0;padding-bottom:16px}
  .dockin{max-width:560px}
  .sheet{left:calc(50% + 116px);right:auto;top:50%;bottom:auto;width:min(540px,calc(100vw - 280px));padding:0;transform:translate(-50%,-46%);opacity:0;pointer-events:none;transition:transform .3s cubic-bezier(.2,.9,.3,1),opacity .2s}
  .sheet.on{transform:translate(-50%,-50%);opacity:1;pointer-events:auto}
  .sheetin{border-radius:20px;border-bottom:1px solid var(--line2);max-height:86vh;padding-bottom:20px}
  .sheet.tall .sheetin{max-height:90vh}
  .grab{display:none}
  .toast{left:calc(50% + 116px)}
  .examples{text-align:left}
  /* health */
  #health{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;align-items:start}
  #health>*{margin:0!important}
  #health>.sechead,#health>#tiles,#health>#trendCard,#health>#alldata{grid-column:1/-1}
  #health>.ready,#health>.call{align-self:stretch}
  #tiles{grid-template-columns:repeat(4,minmax(0,1fr))}
  #alldata{display:block;columns:3 280px;column-gap:16px}
  #alldata>.grp{break-inside:avoid;margin-bottom:16px}
  /* strength */
  #lift>.note,#lift>.addex{max-width:560px}
  /* run */
  #runLog{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.1fr);column-gap:24px;align-items:start}
  #runLog>:nth-child(1){grid-column:1;grid-row:1}#runLog>:nth-child(2){grid-column:1;grid-row:2}
  #runLog>:nth-child(3){grid-column:2;grid-row:1}#runLog>:nth-child(4){grid-column:2;grid-row:2}
  #runseg,#runBuild{max-width:640px}
  /* splits */
  .pcols{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.15fr);gap:28px;align-items:start}
  .pcol>.sechead:first-child{margin-top:0}
  /* money */
  .cols2{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,1fr);gap:24px;align-items:start}
  .cols2 .sechead:first-child{margin-top:0}
  #ov .hero{margin-top:0}
  .txcols{display:grid;grid-template-columns:300px minmax(0,1fr);gap:24px;align-items:start}
  .txcols .fcol{position:sticky;top:20px}
  #budList{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
  #how{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;align-items:start}
  #how>*{margin:0!important}
  #how>.sechead,#how>:nth-child(2){grid-column:1/-1}
  #how>.sechead{margin-top:20px!important}
}
@media (min-width:1240px){#exList{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));align-items:start;gap:16px}}
.chartwrap svg{display:block}
"""
css=tcss+'\n/* ---------- money ---------- */\n'+mkeep+shell_css

# ---------- training markup ----------
tbody=between(T,'</style>','<script>')
tbody=rep(tbody,'<div class="seg" id="seg" role="tablist" style="--n:4">','<div class="seg" id="seg" role="tablist" style="--n:3">')
tbody=rep(tbody,'      <button role="tab" aria-selected="true" id="tabHealth">Health</button>\n      <button role="tab" aria-selected="false" id="tabLift">Strength</button>','      <button role="tab" aria-selected="true" id="tabLift">Strength</button>')
# split out health section
hs=tbody.index('  <!-- HEALTH -->');he=tbody.index('</section>',hs)+len('</section>')
health=tbody[hs:he];tbody=tbody[:hs]+tbody[he:]
# splits columns
tbody=rep(tbody,'    <span class="label" style="display:block;margin:0 2px 8px">Active split</span>','    <div class="pcols"><div class="pcol">\n    <span class="label" style="display:block;margin:0 2px 8px">Active split</span>')
tbody=rep(tbody,'    <div class="sechead"><h2>Find a split</h2></div>','    </div><div class="pcol">\n    <div class="sechead"><h2>Find a split</h2></div>')
tbody=rep(tbody,'    <div class="stack" id="browse" style="margin-top:12px"></div>','    <div class="stack" id="browse" style="margin-top:12px"></div>\n    </div></div>')
# pull global overlays out of the training app wrapper
ds=tbody.index('<div class="dock" id="dock">')
train_app=tbody[:ds].strip()
overlays=tbody[ds:].strip()
health_app='''<div class="app">
  <header class="top">
    <div class="toprow">
      <div class="brand">Home <b>Base</b> · Today</div>
      <button class="sync" onclick="HB.openSync()" aria-label="Health connections"><span class="dot" style="background:var(--line2)"></span>Apple Health</button>
    </div>
  </header>
'''+health.replace('<section id="health">','<section id="health">',1)+'''
  <p class="examples">Your health data stays in this browser on this device until the iPhone and Mac app can sync it.</p>
</div>'''

# ---------- money markup ----------
mbody=between(M,'</style>','<div class="scrim"')
mbody=rep(mbody,'''    <div class="toprow">
      <div class="brand">Home <b>Base</b> · Money</div>''','''    <div class="toprow">
      <div class="brand">Home <b>Base</b> · Money</div>''')
mbody=rep(mbody,'<div class="seg" id="seg" role="tablist">','<div class="seg" id="mseg" role="tablist" style="--n:4">')
mbody=rep(mbody,'''    <div class="card hero" id="hero"></div>
    <div class="card review" id="reviewCard"></div>
    <div class="sechead"><h2>Closest to the limit</h2>''','''    <div class="cols2"><div class="col">
    <div class="card hero" id="hero"></div>
    <div class="card review" id="reviewCard"></div>
    </div><div class="col">
    <div class="sechead"><h2>Closest to the limit</h2>''')
mbody=rep(mbody,'''    <div class="txlist" id="ovTx"></div>
  </section>''','''    <div class="txlist" id="ovTx"></div>
    </div></div>
  </section>''')
mbody=rep(mbody,'''  <section id="txs" hidden>
    <div class="filters">''','''  <section id="txs" hidden>
    <div class="txcols"><div class="fcol">
    <div class="filters">''')
mbody=rep(mbody,'''    <div class="sumline" id="sumline"></div>
    <div id="txGroups"></div>
  </section>''','''    <div class="sumline" id="sumline"></div>
    </div><div>
    <div id="txGroups"></div>
    </div></div>
  </section>''')
mbody=mbody.replace('<input type="file" id="csvFile" accept=".csv,text/csv" hidden>','').strip()
money_app=mbody
csv_input='<input type="file" id="csvFile" accept=".csv,text/csv" hidden>'

# ---------- scripts ----------
tjs=between(T,'<script>','</script>')
tjs=rep(tjs,"const show=id=>{['#health','#lift','#run','#plan'].forEach(x=>$(x).hidden=x!==id);$('#dock').hidden=id!=='#lift';window.scrollTo({top:0});};",
 "const show=id=>{['#lift','#run','#plan'].forEach(x=>$(x).hidden=x!==id);$('#dock').hidden=id!=='#lift';window.scrollTo({top:0});};")
rep(tjs,"function tabs(segId,list){","function tabs(segId,list){")
tjs=rep(tjs,"const go=i=>{seg.style.setProperty('--i',i);","const go=i=>{seg.style.setProperty('--i',i);if(segId==='#seg')HB.mark('train',i);")
tjs=rep(tjs,"const goMain=tabs('#seg',[['#tabHealth',()=>{show('#health');if(window.drawHealth)drawHealth();}],['#tabLift',()=>show('#lift')],['#tabRun',()=>show('#run')],['#tabPlan',()=>show('#plan')]]);",
 "const trainGo=tabs('#seg',[['#tabLift',()=>show('#lift')],['#tabRun',()=>show('#run')],['#tabPlan',()=>show('#plan')]]);\nconst goMain=i=>{if(i===0)HB.area('health');else{HB.area('train');trainGo(i-1);}};\nHB.trainGo=i=>{HB.area('train');trainGo(i);};")
tjs=rep(tjs,"host.innerHTML='';const W=340,H=170,L=34,","host.innerHTML='';const W=Math.max(340,Math.round(host.clientWidth||340)),H=Math.max(170,Math.min(230,Math.round(W*.3))),L=34,")
tjs=rep(tjs,"\ngoMain(0);\n})();","\nHB.openSync=openSync;\nHB.area('health');\n})();")
mjs=between(M,'<script>','</script>')
mjs=mjs.replace("$('#seg')","$('#mseg')")
mjs=rep(mjs,"const W=340,H=170,L=44,","const W=Math.max(340,Math.round($('#monthChart').clientWidth||340)),H=Math.max(170,Math.min(240,Math.round(W*.32))),L=44,")
mjs=rep(mjs,"function drawAll(){drawOverview();drawTx();drawBudgets();drawHow();}","function drawAll(){drawOverview();drawTx();drawBudgets();drawHow();}\nHB.moneyDraw=drawAll;")
mjs=rep(mjs,"function goMain(i){$('#mseg').style.setProperty('--i',i);","function goMain(i){HB.mark('money',i);$('#mseg').style.setProperty('--i',i);")
mjs=rep(mjs,"window.scrollTo({top:0});drawAll();}","window.scrollTo({top:0});drawAll();}\nHB.moneyGo=i=>{HB.area('money');goMain(i);};")
mjs=mjs.replace(".big num'",".bignum num'").replace("{class:'big num'}","{class:'bignum num'}")
mjs=mjs.replace("{class:'field'}","{class:'mfield'}").replace("{class:'check'}","{class:'mcheck'}")
# money's own sheet/toast/escape helpers duplicate the training ones on the same elements; keep them (same markup)
icons={
 'today':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h4l2-6 4 12 2-6h6"/></svg>',
 'train':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 7v10M18 7v10M3 10v4M21 10v4M6 12h12"/></svg>',
 'money':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18M16 15h2"/></svg>',
 'link':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 14a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 10a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></svg>',
 'gear':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></svg>',
 'dot':'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/></svg>'}
side=f'''<nav class="side" aria-label="Home Base">
  <div class="brandbig">Home <b>Base</b></div>
  <div class="grp2"><span>Health & training</span>
    <button class="nav" data-area="health" data-sub="-1">{icons['today']}Today</button>
    <button class="nav" data-area="train" data-sub="0">{icons['train']}Strength</button>
    <button class="nav" data-area="train" data-sub="1">{icons['dot']}Run</button>
    <button class="nav" data-area="train" data-sub="2">{icons['dot']}Splits</button>
  </div>
  <div class="grp2"><span>Money</span>
    <button class="nav" data-area="money" data-sub="0">{icons['money']}Overview</button>
    <button class="nav" data-area="money" data-sub="1">{icons['dot']}Activity</button>
    <button class="nav" data-area="money" data-sub="2">{icons['dot']}Budgets</button>
    <button class="nav" data-area="money" data-sub="3">{icons['dot']}How we did</button>
  </div>
  <div class="foot">
    <button class="nav" onclick="HB.openConnections()">{icons['link']}Connections</button>
    <button class="nav" onclick="HB.openSettings()">{icons['gear']}Settings</button>
  </div>
</nav>'''
bottom=f'''<nav class="bottom" aria-label="Sections">
  <button data-area="health">{icons['today']}Today</button>
  <button data-area="train">{icons['train']}Train</button>
  <button data-area="money">{icons['money']}Money</button>
  <button onclick="HB.openSettings()">{icons['gear']}Settings</button>
</nav>'''
router=r"""<script>
window.HB=(function(){
  const sub={health:-1,train:0,money:0};let cur='health';
  function paint(){document.querySelectorAll('[data-area]').forEach(b=>{const a=b.dataset.area,s=b.dataset.sub;const on=a===cur&&(s===undefined||+s===sub[a]);b.toggleAttribute('aria-current',false);if(on)b.setAttribute('aria-current','page');});}
  const api={
    area(a){cur=a;document.querySelectorAll('.area').forEach(x=>x.hidden=x.id!=='a_'+a);
      const dock=document.getElementById('dock');if(dock)dock.hidden=!(a==='train'&&!document.getElementById('lift').hidden);
      if(a==='health'&&window.drawHealth)window.drawHealth();
      window.scrollTo({top:0});paint();},
    mark(a,i){sub[a]=i;if(a===cur)paint();},
    go(a,i){if(a==='train'&&api.trainGo)api.trainGo(i);else if(a==='money'&&api.moneyGo)api.moneyGo(i);else api.area(a);}
  };
  document.addEventListener('click',e=>{const b=e.target.closest('[data-area]');if(!b||!b.closest('.side,.bottom'))return;
    const a=b.dataset.area,s=b.dataset.sub;if(s===undefined||+s<0){a==='health'?api.area('health'):api.go(a,sub[a]);}else api.go(a,+s);});
  let rt;window.addEventListener('resize',()=>{clearTimeout(rt);rt=setTimeout(()=>{if(cur==='health'&&window.drawHealth)window.drawHealth();if(cur==='money'&&api.moneyDraw)api.moneyDraw();},200);});
  return api;})();
</script>"""

out=f'''<title>Home Base</title>
<meta name="description" content="Home Base: health, training and money in one app">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500;600&display=swap">
<style>{css}</style>
{side}
<div class="main">
<div class="area" id="a_health">
{health_app}
</div>
<div class="area" id="a_train" hidden>
{train_app}
</div>
<div class="area" id="a_money" hidden>
{money_app}
</div>
</div>
{bottom}
{overlays}
{csv_input}
{router}
<script>{tjs}</script>
<script>{mjs}</script>
<script>{open('ai.js').read()}</script>
<script>{open('connect.js').read()}</script>
'''
open('home-base.html','w').write(out)
print(len(out))
