const TABLEAU_URL = "https://public.tableau.com/views/DATACO-DASHBOARD_GROUP1_3DSA2redesigned/Overview";
const TABLEAU_W = 1247;
const TABLEAU_HEIGHTS = { "Overview": 1200, "Sales & Markets": 700, "Delivery Performance": 600, "Order Explorer": 600 };
const TABLEAU_EXTRA = 60;   

const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const money=v=>"$"+v.toFixed(2);
const nice=s=>s.replace(/_/g," ").toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());
const store={get(k,d){try{const v=localStorage.getItem(k);return v?JSON.parse(v):d;}catch(e){return d;}},set(k,v){try{localStorage.setItem(k,JSON.stringify(v));}catch(e){}}};
function toast(t){const el=$("toast");el.textContent=t;el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,1800);}

/* ================= STORE ================= */
const S=window.SHOP;
// Photo for a product
const IMG=id=>(window.PRODUCT_IMAGES||{})[id]||`assets/products/${id}.jpg`;
function imgFail(el,id){ const exts=["jpg","jpeg","JPG","JPEG","png","webp"]; const i=+(el.dataset.try||0)+1; if(el.src.includes(`assets/products/${id}.`) && i<exts.length){ el.dataset.try=i; el.src=`assets/products/${id}.${exts[i]}`; } else el.remove(); }
const DEP_COLORS={"Fan Shop":"#c9f7e4","Apparel":"#fcc8ec","Golf":"#fdf2c4","Footwear":"#ddf3d1","Outdoors":"#fdc9c9","Technology":"#fde3c3","Fitness":"#c6e8fb","Discs Shop":"#ebcdf5","Health and Beauty":"#e2f7c4","Pet Shop":"#fff0c2","Book Shop":"#d9e4ff"};
const DEAL_DEP="Fan Shop", DEAL=0.10;
const FIX={"Under Armour Girls' Toddler Spine Surge Runni":"Under Armour Girls' Toddler Spine Surge Running Shoe"};
const P=S.products.map(([id,name,cat,dep,price,units],i)=>({id,name:FIX[name]||name,cat,dep,price,units,rank:i+1,deal:dep===DEAL_DEP}));
const byId=new Map(P.map(p=>[p.id,p]));
const sale=p=>p.deal?Math.round(p.price*(1-DEAL)*100)/100:p.price;
const depCount={};P.forEach(p=>depCount[p.dep]=(depCount[p.dep]||0)+1);
const DEPS=["Fan Shop","Apparel","Golf","Footwear","Outdoors","Technology","Fitness","Discs Shop","Health and Beauty","Pet Shop","Book Shop"];
const SHIP_ORDER=["Standard Class","Second Class","First Class","Same Day"];
const PROMISE={"Standard Class":"4 days","Second Class":"2 days","First Class":"1 day","Same Day":"same day"};
function typical(m){const [avg,sch,p25,p75]=S.ship[m]; if(m==="Same Day") return "same or next day"; return p25===p75?`about ${p25} day${p25>1?"s":""}`:`about ${p25} to ${p75} days`;}

function card(p,showRank){
  return `<article class="prod"><div class="ph" style="background:${DEP_COLORS[p.dep]||"#eee"}">${IMG(p.id)?`<img class="pimg" src="${esc(IMG(p.id))}" alt="${esc(p.name)}" loading="lazy" onerror="imgFail(this,${p.id})">`:""}${showRank?`<span class="rank">#${p.rank}</span>`:""}${p.deal?`<span class="off">-10% OFF</span>`:""}<span class="cat">${esc(p.cat)}</span></div>
  <div class="info"><span class="dp">${esc(p.dep)}</span><span class="nm">${esc(p.name)}</span>
  <div class="row"><span class="price">${money(sale(p))}${p.deal?`<s>${money(p.price)}</s>`:""}</span><button class="add" type="button" data-add="${p.id}">Add</button></div></div></article>`;
}
/* Background pictures:*/
const slug=s=>s.toLowerCase().replace(/&/g,"and").replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"");
function loadBg(el,base){
  const exts=["jpg","jpeg","png","webp","JPG","JPEG","PNG"]; let i=0;
  const tryNext=()=>{ if(i>=exts.length) return; const src=`${base}.${exts[i++]}`; const im=new Image();
    im.onload=()=>{ el.style.backgroundImage=`linear-gradient(rgba(0,0,0,.45),rgba(0,0,0,.6)), url("${src}")`; el.classList.add("has-img"); };
    im.onerror=tryNext; im.src=src; };
  tryNext();
}
$("deps").innerHTML=DEPS.slice(0,8).map(d=>`<a class="dep" href="#shop" data-dep="${esc(d)}"><div class="t" data-bg="assets/departments/${slug(d)}" style="background-color:${DEP_COLORS[d]}">${esc(d)}</div><div class="n">${depCount[d]||0} products</div></a>`).join("");
document.querySelectorAll("#deps .t").forEach(el=>loadBg(el,el.dataset.bg));
loadBg(document.querySelector(".hero .r"),"assets/banners/hero");
$("best").innerHTML=P.slice(0,8).map(p=>card(p,true)).join("");
$("opts").innerHTML=SHIP_ORDER.map(m=>`<div class="opt"><b>${m}</b><div>Promised: ${PROMISE[m]}</div><div>Typically arrives: <strong>${typical(m)}</strong></div></div>`).join("");
$("perkShip").textContent=`5 markets, ${S.countries} countries`;

let shopFilter="All", query="";
function renderShop(){
  const chips=["All","Deals",...DEPS];
  $("chips").innerHTML=chips.map(c=>`<button type="button" class="chip ${c===shopFilter?"on":""}" data-chip="${esc(c)}">${esc(c)}</button>`).join("");
  const q=query.toLowerCase();
  const list=P.filter(p=>(shopFilter==="All"||(shopFilter==="Deals"?p.deal:p.dep===shopFilter)) && (!q||(p.name+" "+p.cat+" "+p.dep).toLowerCase().includes(q)));
  $("plist").innerHTML=list.map(p=>card(p,false)).join("")||`<div class="empty" style="grid-column:1/-1">No products match “${esc(query)}”. Try another word or pick All.</div>`;
}

/* cart */
let cart=store.get("dataco-cart",{});
let ship="Standard Class", pay="Debit card";
const PAYS=["Debit card","Bank transfer","Cash","Online payment"];
function saveCart(){store.set("dataco-cart",cart); const n=Object.values(cart).reduce((a,b)=>a+b,0); $("cartLabel").textContent=n?`Cart (${n})`:"Cart";}
function addToCart(id){cart[id]=(cart[id]||0)+1; saveCart(); toast("Added to cart");}
const cartItems=()=>Object.entries(cart).map(([id,q])=>({p:byId.get(+id),q})).filter(x=>x.p);
function renderCart(){
  const items=cartItems();
  if(!items.length){ $("cartOut").innerHTML=`<div class="box" style="max-width:760px"><p style="margin:4px 0 14px" class="small">Your cart is empty.</p><a class="b-dark" href="#shop" data-dep="All">Start shopping</a></div>`; return; }
  const sub=items.reduce((a,x)=>a+x.p.price*x.q,0), disc=items.reduce((a,x)=>a+(x.p.price-sale(x.p))*x.q,0), tot=sub-disc;
  $("cartOut").innerHTML=`<div class="cartgrid"><div style="display:grid;gap:16px;min-width:0">
    <div class="box">${items.map(({p,q})=>`<div class="line"><div class="thumb" style="background:${DEP_COLORS[p.dep]}">${IMG(p.id)?`<img class="pimg" src="${esc(IMG(p.id))}" alt="" onerror="imgFail(this,${p.id})">`:""}</div><div><div class="nm">${esc(p.name)}</div><div class="sub">${esc(p.dep)} · ${money(sale(p))} each</div></div>
      <div class="qty"><button type="button" data-q="${p.id}" data-d="-1" aria-label="Fewer">−</button><span>${q}</span><button type="button" data-q="${p.id}" data-d="1" aria-label="More">+</button></div><b>${money(sale(p)*q)}</b><button class="rm" type="button" data-rm="${p.id}">Remove</button></div>`).join("")}</div>
    <div class="box"><h3>Delivery</h3><div class="choices">${SHIP_ORDER.map(m=>`<button type="button" class="choice ${m===ship?"on":""}" data-ship="${m}"><b>${m}</b><span>Typically ${typical(m)}</span></button>`).join("")}</div>
      <h3 style="margin-top:16px">Payment</h3><div class="pays">${PAYS.map(x=>`<button type="button" class="chip ${x===pay?"on":""}" data-pay="${x}">${x}</button>`).join("")}</div></div></div>
    <div class="box"><h3>Order summary</h3><div class="sum"><div><span>Subtotal</span><span>${money(sub)}</span></div><div><span>Discount${disc?" (Fan Shop Week)":""}</span><span>−${money(disc)}</span></div><div><span>Shipping (${ship})</span><span>Free</span></div><div class="tot"><span>Total</span><span>${money(tot)}</span></div></div>
      <button class="place" type="button" id="placeBtn">Place order</button><p class="small" style="margin:8px 0 0">Paying by ${pay.toLowerCase()}</p></div></div>`;
}
let lastOrder=null, pendingTrack=null;
function placeOrder(){
  const items=cartItems(); if(!items.length) return;
  const mine=store.get("dataco-orders",[]);
  const id=S.maxOrder+1+mine.length;
  const total=items.reduce((a,x)=>a+sale(x.p)*x.q,0);
  mine.push({id,d:new Date().toISOString().slice(0,10),ship,pay,n:items.reduce((a,x)=>a+x.q,0),total:Math.round(total*100)/100});
  store.set("dataco-orders",mine); cart={}; saveCart(); lastOrder=id;
  $("thanks").textContent=`THANKS! Order #${id}`; $("thanksSub").textContent=`${ship}, typically ${typical(ship)}. Total ${money(total)}, paid by ${pay.toLowerCase()}.`;
  location.hash="placed";
}

document.addEventListener("click",e=>{
  const a=e.target.closest("[data-add]"); if(a){addToCart(+a.dataset.add); a.textContent="Added"; a.classList.add("added"); setTimeout(()=>{a.textContent="Add";a.classList.remove("added");},1200); return;}
  const c=e.target.closest("[data-chip]"); if(c){shopFilter=c.dataset.chip; renderShop(); return;}
  const d=e.target.closest("[data-dep]"); if(d){shopFilter=d.dataset.dep; query=""; $("q").value=""; if(location.hash==="#shop") renderShop(); return;}
  const q=e.target.closest("[data-q]"); if(q){const id=q.dataset.q; cart[id]=(cart[id]||0)+(+q.dataset.d); if(cart[id]<=0) delete cart[id]; saveCart(); renderCart(); return;}
  const r=e.target.closest("[data-rm]"); if(r){delete cart[r.dataset.rm]; saveCart(); renderCart(); return;}
  const s=e.target.closest("[data-ship]"); if(s){ship=s.dataset.ship; renderCart(); return;}
  const p=e.target.closest("[data-pay]"); if(p){pay=p.dataset.pay; renderCart(); return;}
  if(e.target.id==="placeBtn") placeOrder();
  if(e.target.id==="trackThis") pendingTrack=lastOrder;
});
$("q").addEventListener("input",e=>{query=e.target.value.trim(); shopFilter="All"; if(location.hash!=="#shop") location.hash="shop"; else renderShop();});

/* track */
let ORD=null;
function loadOrders(cb){ if(window.ORDERS) return cb(); const s=document.createElement("script"); s.src="assets/orders.js"; s.onload=cb; s.onerror=()=>{$("trackOut").innerHTML=`<div class="tcard">Order history could not load. Check that assets/orders.js was uploaded with the site.</div>`;}; document.head.appendChild(s); }
function findOrder(id){
  const mine=store.get("dataco-orders",[]).find(o=>String(o.id)===String(id)); if(mine) return {mine:true,...mine};
  if(!window.ORDERS) return null;
  if(!ORD){ ORD=new Map(); for(const line of window.ORDERS.rows.split("\n")){ ORD.set(line.slice(0,line.indexOf(",")),line); } }
  const line=ORD.get(String(id)); if(!line) return null;
  const [oid,d,st,sm,ds,real,sch,n,tot,pay,place]=line.split(","); const L=window.ORDERS.lk; const [city,country]=place.split("|");
  return {id:oid,d,st:L.st[st],ship:L.sm[sm],ds:L.ds[ds],real:+real,sch:+sch,n:+n,total:+tot,pay:L.pay[pay],city,country};
}
function track(id){
  id=String(id).replace(/\D/g,""); if(!id){$("trackOut").innerHTML=""; return;}
  $("ono").value=id; $("trackOut").innerHTML=`<div class="tcard small">Looking up order #${id}…</div>`;
  loadOrders(()=>{
    const o=findOrder(id);
    if(!o){ $("trackOut").innerHTML=`<div class="tcard"><b>We couldn't find order #${esc(id)}.</b><p class="small" style="margin:6px 0 0">Past order numbers run from 1 to ${S.maxOrder}. Check the number on your confirmation and try again.</p></div>`; return; }
    let step, status, pill;
    if(o.mine){ step=1; status="Placed"; pill=["good","Payment received"]; }
    else {
      const st=o.st;
      if(st==="CANCELED"||st==="SUSPECTED_FRAUD"){ step=0; status=st==="CANCELED"?"Canceled":"On hold for review"; pill=["bad","Shipping canceled"]; }
      else if(["PENDING","PENDING_PAYMENT","PAYMENT_REVIEW"].includes(st)){ step=1; status=nice(st); pill=["warn","Awaiting payment"]; }
      else if(["PROCESSING","ON_HOLD"].includes(st)){ step=2; status=nice(st); pill=o.ds==="Late delivery"?["warn","Running late"]:["good",o.ds]; }
      else { step=4; status="Delivered"; pill=o.ds==="Late delivery"?["bad","Late delivery"]:["good",o.ds]; }
    }
    const days=o.mine?typical(o.ship):`${o.real} day${o.real===1?"":"s"} (promised ${o.sch})`;
    const steps=[["Placed",o.mine?"Payment received":"Order received"],["Processing","Packing"],["Shipped",o.ship],["Delivered",step===4?`After ${o.real} day${o.real===1?"":"s"}`:`Typically ${typical(o.ship)}`]];
    $("trackOut").innerHTML=`<div class="tcard"><div class="top"><div><div class="ono">Order #${esc(o.id)} · placed ${esc(o.d)}</div><h3>Status: ${esc(status)}</h3></div><span class="pill ${pill[0]}">${esc(pill[1])}</span></div>
      <div class="steps">${steps.map((s,i)=>`<div class="step ${i<step?"done":"todo"}"><b>${s[0]}</b><span>${esc(s[1])}</span></div>`).join("")}</div>
      <div class="facts"><div><span>Shipping</span>${esc(o.ship)}</div><div><span>${o.mine?"Typical time":"Shipping time"}</span>${esc(days)}</div><div><span>Payment</span>${esc(nice(o.pay))}</div>
      <div><span>Items</span>${o.n}</div><div><span>Total</span>${money(o.total)}</div><div><span>Destination</span>${o.mine?"Your address":esc(o.city+", "+o.country)}</div></div></div>`;
  });
}
$("trackForm").addEventListener("submit",e=>{e.preventDefault(); track($("ono").value);});
$("tryLine").addEventListener("click",e=>{const b=e.target.closest("[data-o]"); if(b) track(b.dataset.o);});

/* ================= INSIGHTS (Tableau) ================= */
function showTableau(){
  const box=$("tableauBox");
  if(!TABLEAU_URL){ box.innerHTML=`<p class="note">Paste your Tableau Public link into TABLEAU_URL at the top of app.js to show the dashboard here.</p>`; return; }
  if(box.dataset.loaded) return;
  if(!document.getElementById("tableauApi")){ const s=document.createElement("script"); s.type="module"; s.id="tableauApi"; s.src="https://public.tableau.com/javascripts/api/tableau.embedding.3.latest.min.js"; document.head.appendChild(s); }
  const v=document.createElement("tableau-viz"); v.setAttribute("src",TABLEAU_URL.split("?")[0].replace(/\/app\/profile\/[^/]+\/viz\//,"/views/")); v.setAttribute("toolbar","bottom"); v.setAttribute("hide-tabs","false"); v.style.width=TABLEAU_W+"px"; v.style.display="block"; v.style.margin="0 auto";
  const fit=name=>{ const h=(TABLEAU_HEIGHTS[name]||TABLEAU_HEIGHTS["Overview"])+TABLEAU_EXTRA; v.style.height=h+"px"; v.setAttribute("height",h); v.setAttribute("width",TABLEAU_W); };
  fit("Overview");
  const current=()=>{ try{ return v.workbook.activeSheet.name; }catch(e){ return null; } };
  v.addEventListener("firstinteractive",()=>fit(current()));
  v.addEventListener("tabswitched",e=>{ const n=(e.detail&&e.detail.newSheetName)||current(); fit(n); });
  box.innerHTML=""; box.appendChild(v); box.dataset.loaded="1";
}

/* ================= ROUTER ================= */
const VIEWS=["home","shop","track","cart","placed","insights"];
function route(){
  const h=location.hash.slice(1)||"home";
  let v=h;
  if(h.startsWith("insights")) v="insights";
  if(h==="deals"){v="shop";shopFilter="Deals";}
  if(!VIEWS.includes(v)) v="home";
  if(v==="placed"&&!lastOrder) v="home";
  view=v;
  VIEWS.forEach(x=>$("v-"+x).hidden=x!==v);
  const navKey=v==="shop"?"deals":v;
  document.querySelectorAll("[data-nav]").forEach(a=>a.classList.toggle("on",a.dataset.nav===navKey));
  if(v==="shop") renderShop();
  if(v==="cart") renderCart();
  if(v==="track"&&pendingTrack){track(pendingTrack);pendingTrack=null;}
  document.body.classList.toggle("wide",v==="insights");
  if(v==="insights") showTableau();
  window.scrollTo(0,0);
}
addEventListener("hashchange",route);
let view="home";
saveCart(); route();
