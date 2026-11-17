// Buble Blast: mini-joc 2D pe canvas (grilă hexagonală 8 coloane, 25 de mutări).
import { $, S, save, upd, toast } from './state.js';

let onClose = () => {};
export const blastOpen = () => !$('bw').hidden;
export function initBlast(cb) {
  onClose = cb;
  $('blast').onclick = () => { $('bw').hidden = false; bInit(); };
  $('bx').onclick = () => { if (G && !G.over) { G.over = true; save(); } closeBlast(false); };
}
function closeBlast(won) {
  $('bw').hidden = true; upd();
  if (won) toast('Monedele au fost adăugate în insulă 🪙');
  onClose(won);
}
export function stepBlast(dt) { if (G) bStep(dt); }

const bc=$('bc'),bt=bc.getContext('2d'),COL=['#2bd4c8','#9a63ff','#ffc83d','#ff6fa8'],RW=14;let G=null;
const cp=(r,c)=>[G.x0+c*2*G.r+(r%2)*G.r,G.y0+r*G.rs];
function nb(r,c){const p=r%2,o=[[r,c-1],[r,c+1]];for(const q of[r-1,r+1])o.push([q,c-1+p],[q,c+p]);return o.filter(a=>a[0]>=0&&a[0]<RW&&a[1]>=0&&a[1]<8)}
function pickc(){const s=new Set();G.g.forEach(r=>r.forEach(v=>v>=0&&s.add(v)));const a=s.size?[...s]:[0,1,2,3];return a[Math.random()*a.length|0]}
function bInit(){const W=innerWidth,H=innerHeight,dpr=Math.min(devicePixelRatio,2);bc.width=W*dpr;bc.height=H*dpr;bt.setTransform(dpr,0,0,dpr,0,0);const r=Math.min(W/17,34);G={W,H,r,rs:r*1.732,x0:(W-17*r)/2+r,y0:100+r,sx:W/2,sy:H-100,g:Array.from({length:RW},()=>Array(8).fill(-1)),score:0,shots:25,mv:null,a:Math.PI/2,over:false,fx:[],msg:'',mt:0};
 for(let i=0;i<6;i++)for(let j=0;j<8;j++)G.g[i][j]=Math.random()*4|0;G.lim=Math.floor((G.sy-2.6*r-G.y0)/G.rs);G.cc=pickc();G.nc=pickc();$('rs').hidden=true}
function dot(x,y,c,r){bt.beginPath();bt.arc(x,y,r*.94,0,7);bt.fillStyle=COL[c];bt.fill();const g=bt.createRadialGradient(x-r*.35,y-r*.35,r*.05,x-r*.2,y-r*.2,r*.8);g.addColorStop(0,'rgba(255,255,255,.9)');g.addColorStop(1,'rgba(255,255,255,0)');bt.fillStyle=g;bt.fill();bt.strokeStyle='rgba(0,0,0,.25)';bt.lineWidth=2;bt.stroke()}
function aim(e){const r=bc.getBoundingClientRect();G.a=Math.max(.2,Math.min(Math.PI-.2,Math.atan2(G.sy-(e.clientY-r.top),e.clientX-r.left-G.sx)))}
bc.onpointerdown=e=>{if(G&&!G.over)aim(e)};bc.onpointermove=e=>{if(G&&!G.over&&e.buttons)aim(e)};
bc.onpointerup=e=>{if(!G||G.over||G.mv)return;aim(e);const s=G.r*30;G.mv={x:G.sx,y:G.sy,vx:Math.cos(G.a)*s,vy:-Math.sin(G.a)*s,c:G.cc};G.cc=G.nc;G.nc=pickc();G.shots--};
function place(){const m=G.mv;G.mv=null;let b=null,bd=1e9;for(let r=0;r<RW;r++)for(let c=0;c<8;c++)if(G.g[r][c]<0){const[x,y]=cp(r,c),d=(x-m.x)**2+(y-m.y)**2;if(d<bd){bd=d;b=[r,c]}}
 if(!b)return end(false);G.g[b[0]][b[1]]=m.c;const st=[b],same=new Set([b+'']);while(st.length){const[r,c]=st.pop();for(const n of nb(r,c))if(G.g[n[0]][n[1]]==m.c&&!same.has(n+'')){same.add(n+'');st.push(n)}}
 let falls=0;if(same.size>=3){same.forEach(k=>{const[r,c]=k.split(',').map(Number);pop(r,c,0);G.score+=10});
  const ok=new Set(),q=[];for(let c=0;c<8;c++)if(G.g[0][c]>=0){ok.add('0,'+c);q.push([0,c])}while(q.length){const[r,c]=q.pop();for(const n of nb(r,c))if(G.g[n[0]][n[1]]>=0&&!ok.has(n+'')){ok.add(n+'');q.push(n)}}
  for(let r=0;r<RW;r++)for(let c=0;c<8;c++)if(G.g[r][c]>=0&&!ok.has(r+','+c)){pop(r,c,1);falls++;G.score+=20}}
 if(falls){G.msg='Reacție în lanț! ×'+falls;G.mt=1.5}
 const empty=G.g.every(r=>r.every(v=>v<0));if(empty)return end(true);if(G.g.some((r,i)=>i>=G.lim&&r.some(v=>v>=0))||G.shots<=0)end(false)}
function pop(r,c,fall){const[x,y]=cp(r,c),col=G.g[r][c];G.g[r][c]=-1;if(fall)G.fx.push({x,y,vx:(Math.random()-.5)*120,vy:-100,c:col,big:1,t:1.2});for(let i=0;i<5;i++)G.fx.push({x,y,vx:(Math.random()-.5)*300,vy:(Math.random()-.5)*300,c:col,t:.5})}
function end(w){if(G.over)return;G.over=true;const co=Math.floor(G.score/4)+(w?100:0);S.coins+=co;S.xp+=Math.floor(G.score/5)+(w?30:0);S.mis.blast=1;save();upd();$('rs').hidden=false;$('rs').innerHTML=`<div><h2>${w?'Nivel finalizat! 🎉':'Sfârșit de rundă'}</h2><p>Scor: ${G.score}</p><p>Ai câștigat 🪙 ${co} monede</p><button id="rb">Înapoi pe insulă</button></div>`;$('rb').onclick=()=>closeBlast(true)}
function bStep(dt){const g=G;if(g.mv){for(let s=0;s<4&&g.mv;s++){const m=g.mv,d=dt/4;m.x+=m.vx*d;m.y+=m.vy*d;const L=g.x0-g.r,Rt=L+17*g.r;if(m.x<L+g.r){m.x=L+g.r;m.vx=-m.vx}if(m.x>Rt-g.r){m.x=Rt-g.r;m.vx=-m.vx}let hit=m.y<=g.y0;if(!hit)for(let r=0;r<RW&&!hit;r++)for(let c=0;c<8;c++)if(g.g[r][c]>=0){const[x,y]=cp(r,c);if((x-m.x)**2+(y-m.y)**2<(1.75*g.r)**2){hit=true;break}}if(hit)place()}}
 g.fx=g.fx.filter(f=>(f.t-=dt)>0);g.fx.forEach(f=>{f.x+=f.vx*dt;f.y+=f.vy*dt;f.vy+=(f.big?900:200)*dt});if(g.mt>0)g.mt-=dt;
 bt.clearRect(0,0,g.W,g.H);bt.strokeStyle='rgba(255,255,255,.25)';bt.setLineDash([8,8]);bt.beginPath();const ly=g.y0+g.lim*g.rs-g.r;bt.moveTo(0,ly);bt.lineTo(g.W,ly);bt.stroke();bt.setLineDash([]);
 for(let r=0;r<RW;r++)for(let c=0;c<8;c++)if(g.g[r][c]>=0){const[x,y]=cp(r,c);dot(x,y,g.g[r][c],g.r)}
 if(!g.mv&&!g.over){bt.fillStyle='#fff9';for(let i=1;i<9;i++)bt.fillRect(g.sx+Math.cos(g.a)*i*g.r*1.6-2,g.sy-Math.sin(g.a)*i*g.r*1.6-2,5,5)}
 if(g.mv)dot(g.mv.x,g.mv.y,g.mv.c,g.r);dot(g.sx,g.sy,g.cc,g.r);dot(g.sx-g.r*3.2,g.sy+g.r*.6,g.nc,g.r*.7);
 g.fx.forEach(f=>{bt.globalAlpha=Math.min(1,f.t*2);if(f.big)dot(f.x,f.y,f.c,g.r);else{bt.fillStyle=COL[f.c];bt.beginPath();bt.arc(f.x,f.y,g.r*.25,0,7);bt.fill()}});bt.globalAlpha=1;
 bt.fillStyle='#fff';bt.font='bold 20px system-ui';bt.textAlign='left';bt.fillText('Scor '+g.score,14,60);bt.textAlign='center';bt.fillText('Mutări: '+g.shots,g.W/2,60);if(g.mt>0){bt.fillStyle='#ffd86b';bt.font='bold 26px system-ui';bt.fillText(g.msg,g.W/2,g.H/2)}}
