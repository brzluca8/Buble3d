// Lumea 3D: insula plutitoare, clădirile, mascota, norii. Port din legacy/buble.html (r128) pe three r187.
import * as THREE from 'three';
import { S, B } from './state.js';
import { mergeStatic } from './merge.js';

const mobile = matchMedia('(pointer: coarse)').matches;
export const R = new THREE.WebGLRenderer({ canvas: document.getElementById('c'), antialias: !mobile || devicePixelRatio < 2, alpha: true, powerPreference: 'high-performance' });
R.setPixelRatio(Math.min(devicePixelRatio, 1.5)); // buget pentru telefoane (2× = de 4 ori mai mulți pixeli decât 1×)
R.shadowMap.enabled = true;
R.shadowMap.type = THREE.PCFShadowMap; // moale din r182
R.toneMapping = THREE.ACESFilmicToneMapping;
R.toneMappingExposure = 1.15;

export const sc = new THREE.Scene();
export const cam = new THREE.PerspectiveCamera(45, 1, .1, 300);
export function resize() { R.setSize(innerWidth, innerHeight); cam.aspect = innerWidth / innerHeight; cam.updateProjectionMatrix(); }
addEventListener('resize', resize); resize();

// Lumină fizică (r155+): intensitățile vechi × π ca să păstrăm aspectul original.
sc.add(new THREE.HemisphereLight(0xcfe6ff, 0x7a5aa0, .95 * Math.PI));
const sun = new THREE.DirectionalLight(0xfff0d0, 1.7 * Math.PI);
sun.position.set(9, 16, 11); sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
Object.assign(sun.shadow.camera, { left: -11, right: 11, top: 11, bottom: -11, near: 1, far: 50 });
sun.shadow.bias = -.0006; sun.shadow.normalBias = .02;
sc.add(sun);

let sd=7;export const rnd=()=>(sd=sd*16807%2147483647)/2147483647;
const M=(c,o={})=>new THREE.MeshStandardMaterial(Object.assign({color:c,roughness:.6},o));
const add=(p,g,m,x=0,y=0,z=0)=>{const o=new THREE.Mesh(g,m);o.position.set(x,y,z);o.castShadow=o.receiveShadow=true;p.add(o);return o};
const cyl=(a,b,h,s=24)=>new THREE.CylinderGeometry(a,b,h,s),sph=(r,w=24,h=16)=>new THREE.SphereGeometry(r,w,h),bx=(w,h,d)=>new THREE.BoxGeometry(w,h,d),tor=(r,t)=>new THREE.TorusGeometry(r,t,8,32);
const cream=M(0xf3e6cf),gold=M(0xf2b630,{metalness:.8,roughness:.3}),teal=M(0x20a8a6,{metalness:.3,roughness:.35}),vio=M(0x6d3fc0),stone=M(0xd9c7a3),brown=M(0x7a4a2a),green=M(0x4ea04a),glass=M(0xbfeeff,{transparent:true,opacity:.3,roughness:.1,side:2}),warm=M(0xffd27a,{emissive:0xffa030,emissiveIntensity:.9});
const dome=(p,r,x,y,z=0,m=teal)=>{const d=add(p,new THREE.SphereGeometry(r,24,12,0,Math.PI*2,0,Math.PI/2),m,x,y,z);add(p,cyl(r*.07,r*.07,r*.5,8),gold,x,y+r+.15,z);add(p,sph(r*.13,8,8),gold,x,y+r+.42,z);return d};
const win=(p,x,y,z)=>add(p,bx(.28,.5,.08),warm,x,y,z);
export const isl=new THREE.Group();sc.add(isl);
// rock + grass
const rg=new THREE.CylinderGeometry(7,1.8,6.5,14,5),pa=rg.attributes.position;for(let i=0;i<pa.count;i++)if(pa.getY(i)<3){pa.setX(i,pa.getX(i)+(rnd()-.5)*.8);pa.setZ(i,pa.getZ(i)+(rnd()-.5)*.8);pa.setY(i,pa.getY(i)+(rnd()-.5)*.4)}rg.computeVertexNormals();
add(isl,rg,M(0x8a7a8e,{flatShading:true,roughness:.9}),0,-3.75,0);
add(isl,cyl(7.2,7,.5,40),M(0x6fbf4a,{roughness:.9}),0,-.25,0);
for(let i=0;i<5;i++){const a=i*1.3+.4,k=add(isl,new THREE.ConeGeometry(.35,1.4,5),M(0x5fe0e0,{emissive:0x2bb8b0,emissiveIntensity:.8}),Math.cos(a)*2.2,-5.2,Math.sin(a)*2.2);k.rotation.x=Math.PI}
const ring=add(isl,new THREE.RingGeometry(2.3,3.3,48),stone,0,.02,.3);ring.rotation.x=-Math.PI/2;
add(isl,bx(1.8,.04,4.6),stone,0,.02,5.1);
// fountain
add(isl,cyl(1.6,1.7,.5),stone,0,.25,.3);add(isl,cyl(1.35,1.35,.1),M(0x5fd8ff,{emissive:0x2aa0d0,emissiveIntensity:.6,transparent:true,opacity:.85}),0,.5,.3);add(isl,cyl(.18,.25,1.1,12),stone,0,1,.3);add(isl,cyl(.75,.5,.2),stone,0,1.5,.3);
export const gem=add(isl,new THREE.IcosahedronGeometry(.25),M(0x7ffff0,{emissive:0x20d8c8,emissiveIntensity:1}),0,2,.3);
// buildings
const mk={
palat(g){add(g,bx(4.6,1.8,1.8),cream,0,.9,0);add(g,cyl(1.35,1.45,3.4),cream,0,1.7,.1);dome(g,1.45,0,3.4,.1);for(const s of[-1,1]){add(g,cyl(.8,.85,2.6),cream,s*2.2,1.3,0);dome(g,.9,s*2.2,2.6);win(g,s*2.2,1.5,.85);add(g,bx(.35,1,.06),vio,s*.95,1.9,1.5)}add(g,bx(.8,1.3,.1),warm,0,.7,1.5);add(g,bx(1,.12,.12),gold,0,1.4,1.52);for(let i=0;i<3;i++)add(g,bx(1.8,.12,.4),stone,0,.06+i*.12,2.2-i*.35)},
obs(g){add(g,cyl(1.3,1.4,1.8),cream,0,.9,0);add(g,tor(1.35,.06),gold,0,1.8,0).rotation.x=Math.PI/2;dome(g,1.3,0,1.8,0,vio);const t=add(g,cyl(.16,.2,2),gold,.7,3,.7);t.rotation.set(-1,0,-.5);win(g,0,1,1.32);win(g,.9,1,1);add(g,bx(1.6,1,1.2),cream,0,.5,1.4);add(g,bx(.6,.8,.1),warm,0,.4,2.02)},
turn(g){add(g,cyl(.8,.95,4.2),cream,0,2.1,0);add(g,tor(.85,.06),gold,0,3,0).rotation.x=Math.PI/2;dome(g,1,0,4.2);add(g,bx(.5,1.1,.05),vio,0,2.4,.9);add(g,bx(.5,.9,.1),brown,0,.45,.93);win(g,0,1.6,.88);win(g,0,3.5,.8)},
mag(g){add(g,bx(2.8,1.6,2.2),cream,0,.8,0);const r=add(g,cyl(0,2.1,1.1,4),teal,0,2.15,0);r.rotation.y=Math.PI/4;const a=add(g,bx(2.9,.1,1),vio,0,1.45,1.5);a.rotation.x=.4;add(g,bx(1.8,.9,.1),warm,0,.8,1.12);add(g,bx(.5,.5,.5),brown,-1.2,.25,1.5);add(g,sph(.3),green,1.2,.35,1.5)},
sera(g){add(g,cyl(1.7,1.8,.3),stone,0,.15,0);add(g,new THREE.SphereGeometry(1.65,24,12,0,Math.PI*2,0,Math.PI/2),glass,0,.3,0);for(let i=0;i<3;i++)add(g,tor(1.65,.04),gold,0,.3,0).rotation.y=i*Math.PI/3;add(g,tor(1.65,.04),gold,0,.3,0).rotation.x=Math.PI/2;for(let i=0;i<7;i++){const a=i*.9;add(g,sph(.35,10,8),green,Math.cos(a)*.7,.6,Math.sin(a)*.7);add(g,sph(.12,8,6),M(i%2?0xff6fa8:0xb07cff),Math.cos(a)*.7,.95,Math.sin(a)*.7)}}
};
// ---- modele detaliate ----
const ped=M(0xcdb690),iv1=M(0x3f9a44),iv2=M(0x5cba50),gemM=M(0x7ffff0,{emissive:0x20d8c8,emissiveIntensity:1}),sky=M(0x1a1a66,{emissive:0x5b3fd0,emissiveIntensity:.9});
const onion=(p,r,x,y,z=0,m=teal)=>{const pts=[[r,0],[r*1.06,r*.28],[r*.96,r*.62],[r*.5,r*.95],[r*.14,r*1.2],[0,r*1.45]].map(a=>new THREE.Vector2(a[0],a[1]));add(p,new THREE.LatheGeometry(pts,28),m,x,y,z);add(p,tor(r*1.06,.04),gold,x,y+r*.28,z).rotation.x=Math.PI/2;add(p,tor(r*.96,.035),gold,x,y+r*.62,z).rotation.x=Math.PI/2;add(p,tor(r,.05),gold,x,y+.02,z).rotation.x=Math.PI/2;add(p,cyl(r*.04,r*.04,r*.6,6),gold,x,y+r*1.6,z);add(p,sph(r*.12,8,8),gold,x,y+r*1.92,z)};
const arch=(p,x,y,z,w=.3,h=.55,ry=0,m=warm)=>{const g=new THREE.Group();g.position.set(x,y,z);g.rotation.y=ry;add(g,bx(w,h,.08),m);add(g,new THREE.CylinderGeometry(w/2,w/2,.08,12,1,false,Math.PI/2,Math.PI),m,0,h/2).rotation.x=Math.PI/2;add(g,new THREE.TorusGeometry(w/2+.03,.025,5,12,Math.PI),gold,0,h/2,.045);add(g,bx(w+.1,.05,.1),gold,0,-h/2,.04);p.add(g)};
const cor=(p,w,d,y)=>add(p,bx(w+.2,.1,d+.2),ped,0,y,0);
const colm=(p,x,z,h)=>{add(p,cyl(.12,.14,h,10),cream,x,h/2,z);add(p,cyl(.19,.19,.08,10),gold,x,h,z);add(p,cyl(.19,.19,.08,10),gold,x,.04,z)};
const ivy=(p,x,y,z,n=5)=>{for(let i=0;i<n;i++)add(p,sph(.12+rnd()*.1,6,5),i%2?iv1:iv2,x+(rnd()-.5)*.6,y-rnd()*.9,z+rnd()*.1)};
const flag=(p,x,y,z)=>{add(p,cyl(.025,.025,.9,5),gold,x,y+.45,z);add(p,bx(.5,.26,.02),vio,x+.27,y+.75,z)};
Object.assign(mk,{
palat(g){add(g,bx(5.4,.25,2.8),ped,0,.12,.25);add(g,bx(4.6,1.9,1.9),cream,0,1.2,0);cor(g,4.6,1.9,2.17);
 add(g,cyl(1.35,1.45,3.2),cream,0,1.85,.1);add(g,tor(1.4,.07),gold,0,3,.1).rotation.x=Math.PI/2;onion(g,1.4,0,3.45,.1);flag(g,0,5.95,.1);
 for(const s of[-1,1]){add(g,cyl(.8,.85,2.8),cream,s*2.2,1.5,0);add(g,tor(.83,.05),gold,s*2.2,2.7,0).rotation.x=Math.PI/2;onion(g,.9,s*2.2,2.85);flag(g,s*2.2,4.5,0);arch(g,s*2.2,1.8,.86,.3,.6);arch(g,s*1.4,1.4,.96,.3,.55);add(g,bx(.34,1,.05),vio,s*1.15,1.4,.98);arch(g,s*.5,2.3,1.4,.28,.5,s*.37);colm(g,s*.75,1.6,1.5);ivy(g,s*1.6,1.7,1,6);ivy(g,s*2.2,1.9,.85,4)}
 arch(g,0,.9,1.55,.8,1.2);add(g,sph(.22,10,8),gemM,0,2,1.58);
 for(let i=0;i<3;i++)add(g,bx(2.2,.1,.45),stone,0,.05+i*.1,2.3-i*.4)},
obs(g){add(g,cyl(1.55,1.65,.3),ped,0,.15,0);add(g,cyl(1.3,1.4,1.7),cream,0,1.15,0);add(g,tor(1.35,.07),gold,0,2,0).rotation.x=Math.PI/2;add(g,new THREE.SphereGeometry(1.3,28,14,0,Math.PI*2,0,Math.PI/2),vio,0,2,0);
 add(g,bx(.5,1.1,.1),sky,0,2.65,1.15).rotation.x=-.5;
 for(let i=0;i<16;i++){const a=rnd()*6.28,b=.15+rnd()*1.1;add(g,sph(.04,5,4),warm,Math.sin(b)*Math.cos(a)*1.32,2+Math.cos(b)*1.32,Math.sin(b)*Math.sin(a)*1.32)}
 add(g,cyl(.18,.24,2.2,16),gold,.45,3,.7).rotation.set(-.9,0,-.45);
 add(g,bx(2.4,1.1,1.2),cream,0,.55,1.75);arch(g,0,.5,2.36,.6,.8);
 for(let i=0;i<5;i++)add(g,bx(.5,.08,.8),i%2?vio:cream,-1+i*.5,1.1,2.35).rotation.x=.45;
 for(const s of[-1,1])arch(g,s*.95,1.5,.97,.28,.5,s*.7);ivy(g,-1.3,1.7,.9,5)},
turn(g){add(g,cyl(1,1.1,.3),ped,0,.15,0);add(g,cyl(.8,.95,3.6),cream,0,2.1,0);for(const y of[1.5,2.9])add(g,tor(.99-y*.0417,.06),gold,0,y,0).rotation.x=Math.PI/2;add(g,cyl(1.05,1.05,.1),gold,0,3.9,0);onion(g,1,0,3.95);flag(g,0,5.8,0);
 arch(g,0,.85,.97,.5,.9,0,brown);add(g,bx(.5,1.1,.05),vio,0,1.95,.9);arch(g,0,3,.86,.26,.55);ivy(g,.5,2.2,.8,6)},
mag(g){add(g,bx(3,.2,2.4),ped,0,.1,0);add(g,bx(2.8,1.6,2.2),cream,0,1,0);cor(g,2.8,2.2,1.82);add(g,cyl(0,2.2,1.2,4),teal,0,2.4,0).rotation.y=Math.PI/4;add(g,sph(.12,8,8),gold,0,3.05,0);
 for(let i=0;i<6;i++)add(g,bx(.47,.08,1),i%2?vio:cream,-1.2+i*.48,1.55,1.55).rotation.x=.45;
 add(g,bx(1.7,.85,.1),warm,0,.85,1.12);add(g,bx(1.8,.06,.12),gold,0,1.3,1.12);add(g,bx(1.8,.06,.12),gold,0,.4,1.12);arch(g,1.12,.7,1.13,.3,.8,0,brown);
 add(g,cyl(.2,.15,.3,8),brown,-1.2,.15,1.7);add(g,sph(.3,8,6),green,-1.2,.5,1.7);add(g,sph(.1,6,5),M(0xff6fa8),-1.1,.75,1.75);add(g,bx(.4,.4,.4),brown,1.2,.2,1.7);ivy(g,-1.42,1.5,0,5)},
sera(g){add(g,cyl(1.8,1.9,.3),ped,0,.15,0);add(g,new THREE.SphereGeometry(1.65,28,14,0,Math.PI*2,0,Math.PI/2),glass,0,.3,0);
 for(let i=0;i<4;i++)add(g,new THREE.TorusGeometry(1.65,.035,6,24,Math.PI),gold,0,.3,0).rotation.y=i*Math.PI/4;
 add(g,tor(1.65,.045),gold,0,.3,0).rotation.x=Math.PI/2;add(g,tor(1.35,.035),gold,0,1.25,0).rotation.x=Math.PI/2;add(g,tor(.7,.035),gold,0,1.8,0).rotation.x=Math.PI/2;add(g,sph(.1,8,8),gold,0,1.98,0);add(g,sph(.28,10,8),warm,0,.75,0);
 for(let i=0;i<10;i++){const a=i*.63,r=.5+(i%3)*.4,x=Math.cos(a)*r,z=Math.sin(a)*r;add(g,sph(.28+(i%2)*.1,8,6),i%2?iv1:iv2,x,.55+(i%3)*.2,z);add(g,sph(.1,6,5),M(i%3?0xff6fa8:0xb07cff),x,.85+(i%3)*.2,z)}
 arch(g,0,.75,1.66,.5,.8,0,brown)}
});
for(let i=0;i<16;i++){const a=i*.4+rnd()*.3;add(isl,cyl(.025,.015,1+rnd()*1.6,4),iv1,Math.cos(a)*6.6,-.9-rnd()*.3,Math.sin(a)*6.6)}
for(let i=0;i<7;i++){const a=rnd()*6.28;add(isl,new THREE.IcosahedronGeometry(.4+rnd()*.4,0),M(0x8a7a8e,{flatShading:true}),Math.cos(a)*6.7,.15,Math.sin(a)*6.7)}
export const GB={},bg=[];
const lant=(p,x,z)=>{add(p,cyl(.06,.08,.8,8),gold,x,.4,z);add(p,sph(.15,8,8),warm,x,.9,z)};
export function applyLvl(g,id){if(g.ex)g.remove(g.ex);g.ex=new THREE.Group();g.add(g.ex);const L=S.b[id],P=[[-1.6,2.6],[1.6,2.6],[-2.9,1.2],[2.9,1.2]];for(let i=0;i<L-1;i++)lant(g.ex,P[i][0],P[i][1]);g.userData.base=1+.07*(L-1);g.scale.setScalar(g.userData.base)}
B.forEach(b=>{const g=new THREE.Group();g.position.set(b.x,0,b.z);g.userData={id:b.id,a:1};mk[b.id](g);isl.add(g);GB[b.id]=g;bg.push(g);applyLvl(g,b.id)});
// vegetation
const tree=(x,z,s,cy)=>{const g=new THREE.Group();g.position.set(x,0,z);add(g,cyl(.1*s,.15*s,1*s,6),brown,0,.5*s,0);if(cy)add(g,new THREE.ConeGeometry(.45*s,2.2*s,8),M(0x2f7a45),0,1.6*s,0);else{add(g,new THREE.IcosahedronGeometry(.7*s,1),M(0x4fae4a,{flatShading:true}),0,1.4*s,0);add(g,new THREE.IcosahedronGeometry(.5*s,1),M(0x66c458,{flatShading:true}),.3*s,1.9*s,.1*s)}isl.add(g)};
for(let i=0;i<20;i++){const a=rnd()*6.28,r=5.7+rnd()*.9,x=Math.cos(a)*r,z=Math.sin(a)*r;if(Math.abs(x)<2&&z>0)continue;if(Math.abs(Math.abs(x)-4.4)<1.2&&z>4.5)continue;tree(x,z,.8+rnd()*.5,i%4==0)}
const fc=[0xff6fa8,0xb07cff,0x7fa8ff,0xffffff];for(let i=0;i<70;i++){const a=rnd()*6.28,r=5.9+rnd()*.9,x=Math.cos(a)*r,z=Math.sin(a)*r;if(Math.abs(x)<1.5&&z>0)continue;add(isl,sph(.12,6,5),M(fc[i%4],{emissive:fc[i%4],emissiveIntensity:.15}),x,.12,z)}
[[-1.4,3.3],[1.4,3.3],[-1.4,6],[1.4,6]].forEach(p=>lant(isl,p[0],p[1]));
// waterfalls + drops
[[-4.4,5.2],[4.4,5.2]].forEach(w=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(1.1,4.5),new THREE.MeshBasicMaterial({color:0x9fe8ff,transparent:true,opacity:.5,side:2}));m.position.set(w[0]*1.03,-2.3,w[1]*1.03);m.rotation.y=Math.atan2(w[0],w[1]);isl.add(m)});
export const dp=[];for(let i=0;i<40;i++)dp.push({k:0,a:rnd()*6.28,p:rnd()});[[-4.4,5.2],[4.4,5.2]].forEach(w=>{for(let i=0;i<30;i++)dp.push({k:1,x:w[0]*1.05+(rnd()-.5)*.8,z:w[1]*1.05,p:rnd()})});
export const dg=new THREE.BufferGeometry();dg.setAttribute('position',new THREE.BufferAttribute(new Float32Array(dp.length*3),3));isl.add(new THREE.Points(dg,new THREE.PointsMaterial({size:.16,color:0xffffff,transparent:true,opacity:.85})));
// mascot
export const ms=new THREE.Group();isl.add(ms);const wh=M(0xfff6e8,{roughness:.5}),dk=M(0x2a1a3a);
const body=add(ms,sph(.7,24,16),wh,0,.75,0);body.scale.set(1,.95,.92);
for(const s of[-1,1]){add(ms,sph(.1,8,8),dk,s*.23,.82,.58);add(ms,sph(.03,6,6),M(0xffffff,{emissive:0xffffff}),s*.2,.86,.66);add(ms,sph(.1,8,8),M(0xff9fb5),s*.4,.68,.52).scale.set(1,.6,.4);add(ms,sph(.18,12,8),M(0x2bd4c8,{metalness:.5,roughness:.2}),s*.25,1.1,.5).scale.set(1,.8,.4);add(ms,tor(.18,.04),gold,s*.25,1.1,.52);add(ms,sph(.17,8,8),wh,s*.72,.6,.1);add(ms,sph(.2,8,8),wh,s*.3,.1,.1)}
export const mouth=add(ms,sph(.1,8,6),M(0xd8475a),0,.62,.64);mouth.scale.set(1,.5,.5);
add(ms,new THREE.TorusGeometry(.5,.11,8,24),vio,0,.45,0).rotation.x=Math.PI/2;add(ms,bx(.2,.5,.08),vio,.35,.25,.55).rotation.z=.3;
add(ms,bx(.6,.7,.3),brown,0,.7,-.62);add(ms,tor(.5,.03),gold,0,1.05,.05).rotation.x=Math.PI/2;
add(ms,new THREE.SphereGeometry(.76,20,10,0,Math.PI*2,0,Math.PI*.3),brown,0,.75,-.02);add(ms,tor(.615,.05),M(0xa8703a),0,1.2,-.02).rotation.x=Math.PI/2;for(const s of[-1,1])add(ms,sph(.2,8,6),brown,s*.62,.95,-.02).scale.set(.5,1,.8);
ms.position.set(0,0,5);
export const mas={t:new THREE.Vector3(0,0,5),j:0,ry:0}; // țintă, săritură, rotație
// selection ring
export const sr=new THREE.Mesh(new THREE.TorusGeometry(2.2,.07,8,48),M(0xffd86b,{emissive:0xffc040,emissiveIntensity:1}));sr.rotation.x=Math.PI/2;sr.visible=false;isl.add(sr);
// sparks
export const sp=[],sg=sph(.09,6,6),sm=M(0xffd86b,{emissive:0xffc040});
export function burst(x,z){for(let i=0;i<26;i++){const m=new THREE.Mesh(sg,sm);m.position.set(x,1.5,z);m.v=new THREE.Vector3((rnd()-.5)*5,2+rnd()*4,(rnd()-.5)*5);m.l=1;isl.add(m);sp.push(m)}}
// insule îndepărtate
export const far=[];[[-13,5,-16],[14,6,-14],[18,0,-24]].forEach(p=>{const g=new THREE.Group();add(g,new THREE.ConeGeometry(2,3,7),M(0x8a7a8e,{flatShading:true}),0,-1.5,0).rotation.x=Math.PI;add(g,cyl(2.1,2,.3),M(0x6fbf4a),0,.1,0);add(g,bx(1,.8,1),cream,0,.6,0);dome(g,.7,0,1,0);g.position.set(...p);sc.add(g);far.push(g)});
// ---- texturi pictate pe canvas, glow (bloom fals), nori sprite ----
export const clouds=[];
const rn=(a,b)=>a+Math.random()*(b-a);
const cvs=(w,h,f)=>{const c=document.createElement('canvas');c.width=w;c.height=h;f(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=4;return t};
const stoneTex=cvs(256,256,(x,w,h)=>{for(let r=0;r<8;r++)for(let c=-1;c<5;c++){const v=rn(232,255)|0;x.fillStyle='rgb('+v+','+(v-3)+','+(v-9)+')';x.fillRect(c*64+(r%2)*32,r*32,64,32)}x.strokeStyle='rgba(120,105,80,.6)';x.lineWidth=2;for(let r=0;r<=8;r++){x.beginPath();x.moveTo(0,r*32);x.lineTo(w,r*32);x.stroke()}for(let r=0;r<8;r++)for(let c=0;c<=4;c++){x.beginPath();x.moveTo(c*64+(r%2)*32,r*32);x.lineTo(c*64+(r%2)*32,r*32+32);x.stroke()}for(let i=0;i<500;i++){x.fillStyle='rgba(90,75,50,'+rn(.03,.1)+')';x.fillRect(rn(0,w),rn(0,h),rn(1,3),rn(1,3))}});
const roofTex=cvs(256,256,(x,w,h)=>{x.fillStyle='#cfe6e6';x.fillRect(0,0,w,h);for(let r=0;r<16;r++)for(let c=-1;c<9;c++){const cx=c*32+(r%2)*16,cy=r*16,g=x.createRadialGradient(cx,cy+4,2,cx,cy+4,24);g.addColorStop(0,'#ffffff');g.addColorStop(1,'#9fc4c4');x.fillStyle=g;x.beginPath();x.arc(cx,cy,16,0,Math.PI);x.fill();x.strokeStyle='rgba(20,70,80,.45)';x.lineWidth=1.5;x.stroke()}});
const grassTex=cvs(256,256,(x,w,h)=>{x.fillStyle='#f4f4f4';x.fillRect(0,0,w,h);for(let i=0;i<70;i++){x.fillStyle=i%2?'rgba(0,70,0,.07)':'rgba(255,255,255,.12)';x.beginPath();x.arc(rn(0,w),rn(0,h),rn(10,35),0,7);x.fill()}for(let i=0;i<900;i++){x.strokeStyle=i%3?'rgba(0,80,10,.18)':'rgba(255,255,255,.3)';x.lineWidth=1;const a=rn(0,w),b=rn(0,h);x.beginPath();x.moveTo(a,b);x.lineTo(a+rn(-2,2),b-rn(3,8));x.stroke()}});
const rockTex=cvs(256,256,(x,w,h)=>{x.fillStyle='#e6dfea';x.fillRect(0,0,w,h);for(let i=0;i<24;i++){x.fillStyle='rgba(60,45,80,'+rn(.04,.1)+')';x.fillRect(0,rn(0,h),w,rn(4,16))}for(let i=0;i<30;i++){x.strokeStyle='rgba(40,28,60,.4)';x.lineWidth=rn(1,2.5);let a=rn(0,w),b=rn(0,h);x.beginPath();x.moveTo(a,b);for(let k=0;k<4;k++){a+=rn(-18,18);b+=rn(6,24);x.lineTo(a,b)}x.stroke()}for(let i=0;i<700;i++){x.fillStyle='rgba(30,20,40,'+rn(.05,.15)+')';x.fillRect(rn(0,w),rn(0,h),rn(1,3),rn(1,3))}});
const cobTex=cvs(256,256,(x,w,h)=>{x.fillStyle='#8f8068';x.fillRect(0,0,w,h);for(let r=0;r<8;r++)for(let c=-1;c<5;c++){const v=rn(225,255)|0,px=c*64+(r%2)*32+3,py=r*32+3;x.fillStyle='rgb('+v+','+(v-6)+','+(v-18)+')';x.beginPath();x.moveTo(px+8,py);x.lineTo(px+50,py);x.quadraticCurveTo(px+58,py,px+58,py+8);x.lineTo(px+58,py+18);x.quadraticCurveTo(px+58,py+26,px+50,py+26);x.lineTo(px+8,py+26);x.quadraticCurveTo(px,py+26,px,py+18);x.lineTo(px,py+8);x.quadraticCurveTo(px,py,px+8,py);x.fill()}});
cream.map=ped.map=stoneTex;stoneTex.repeat.set(3,1.2);teal.map=roofTex;roofTex.repeat.set(3,1.5);stone.map=cobTex;cobTex.repeat.set(3,3);
isl.traverse(o=>{if(!o.isMesh||!o.material.color)return;const h=o.material.color.getHex();if(h==0x8a7a8e){o.material.map=rockTex;rockTex.repeat.set(6,2)}else if(h==0x6fbf4a){o.material.map=grassTex;grassTex.repeat.set(8,8)}});
const gtx=cvs(128,128,(x,w,h)=>{const g=x.createRadialGradient(64,64,0,64,64,64);g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(.25,'rgba(255,255,255,.45)');g.addColorStop(1,'rgba(255,255,255,0)');x.fillStyle=g;x.fillRect(0,0,128,128)});gtx.wrapS=gtx.wrapT=THREE.ClampToEdgeWrapping;
const gm={},glw=m=>{const k=m.emissive.getHex();return gm[k]||(gm[k]=new THREE.SpriteMaterial({map:gtx,color:m.emissive.clone().lerp(new THREE.Color(1,1,1),.35),blending:THREE.AdditiveBlending,depthWrite:false,depthTest:false,transparent:true,opacity:.55}))};
const gl2=[];isl.traverse(o=>{if(o.isMesh&&o.material.emissive&&o.material.emissiveIntensity>=.8){const h=o.material.emissive.getHex();if(h&&h!=0xffffff)gl2.push(o)}});
gl2.forEach(o=>{o.geometry.computeBoundingSphere();const r=o.geometry.boundingSphere.radius,s=new THREE.Sprite(glw(o.material));s.scale.setScalar(Math.min(Math.max(r*4,.4),1.6));s.raycast=()=>{};o.add(s)});
const ctx2=cvs(512,256,(x,w,h)=>{for(let i=0;i<14;i++){const cx=rn(90,420),cy=rn(90,170),r=rn(50,95),g=x.createRadialGradient(cx,cy,0,cx,cy,r);g.addColorStop(0,'rgba(255,255,255,.95)');g.addColorStop(.6,'rgba(240,246,255,.55)');g.addColorStop(1,'rgba(235,242,255,0)');x.fillStyle=g;x.fillRect(0,0,w,h)}});ctx2.wrapS=ctx2.wrapT=THREE.ClampToEdgeWrapping;
for(let i=0;i<24;i++){const s=new THREE.Sprite(new THREE.SpriteMaterial({map:ctx2,color:i%3?0xffffff:0xe4ecff,transparent:true,depthWrite:false,opacity:.5+rnd()*.4})),w=14+rnd()*14;s.scale.set(w,w*.5,1);if(i<15)s.position.set((rnd()-.5)*60,-9+rnd()*3.5,-8+rnd()*22);else s.position.set((rnd()-.5)*80,-3+rnd()*10,-22-rnd()*20);sc.add(s);clouds.push(s)}
[[-4.4,5.2],[4.4,5.2]].forEach(w=>{const s=new THREE.Sprite(new THREE.SpriteMaterial({map:ctx2,transparent:true,depthWrite:false,opacity:.7}));s.scale.set(3.2,1.6,1);s.position.set(w[0]*1.08,-4.6,w[1]*1.08);isl.add(s)});
// lumini calde locale (decay fizic 2 ⇒ intensitate mai mare decât în r128)
const pl=new THREE.PointLight(0xffb060,14,12);pl.position.set(0,2,-1.5);isl.add(pl);
const pl2=new THREE.PointLight(0x4fe8d8,8,7);pl2.position.set(0,2.3,.3);isl.add(pl2);

// ---- combinare statică (draw calls) ----
// Clădirile se combină fiecare separat (se scalează la upgrade); felinarele de nivel (g.ex) rămân libere.
bg.forEach((g) => mergeStatic(g, new Set([g.ex])));
mergeStatic(ms, new Set([mouth]));
far.forEach((f) => mergeStatic(f));
mergeStatic(isl, new Set([gem, sr, ms]));
