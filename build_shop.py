import pandas as pd, json, sys
df=pd.read_csv(sys.argv[1],encoding='latin-1'); df.columns=[c.strip() for c in df.columns]
for c in ['Product Name','Category Name','Department Name']: df[c]=df[c].astype(str).str.strip()
p=df.groupby('Product Card Id').agg(name=('Product Name','first'),cat=('Category Name','first'),dep=('Department Name','first'),price=('Product Price','first'),units=('Order Item Quantity','sum'),sales=('Sales','sum')).reset_index().sort_values('units',ascending=False)
p['rank']=range(1,len(p)+1)
print(p.head(8)[['name','dep','price','units']]); print(p.dep.value_counts()); print(len(p))
sm=df.drop_duplicates('Order Id').groupby('Shipping Mode').agg(real=('Days for shipping (real)','mean'),sch=('Days for shipment (scheduled)','mean'),p25=('Days for shipping (real)',lambda s:s.quantile(.25)),p75=('Days for shipping (real)',lambda s:s.quantile(.75)))
print(sm)
print(df['Order Country'].nunique(), df['Order Id'].max())
shop=dict(products=[[int(r['Product Card Id']),r['name'],r['cat'],r['dep'],round(float(r.price),2),int(r.units)] for _,r in p.iterrows()],
 ship={k:[round(v.real,1),int(v.sch),int(v.p25),int(v.p75)] for k,v in sm.iterrows()}, countries=int(df['Order Country'].nunique()), maxOrder=int(df['Order Id'].max()))
# orders for tracking
od=pd.to_datetime(df['order date (DateOrders)']); df['d']=od.dt.strftime('%Y-%m-%d')
o=df.groupby('Order Id').agg(d=('d','first'),st=('Order Status','first'),sm=('Shipping Mode','first'),ds=('Delivery Status','first'),real=('Days for shipping (real)','first'),sch=('Days for shipment (scheduled)','first'),n=('Order Item Quantity','sum'),tot=('Order Item Total','sum'),city=('Order City','first'),country=('Order Country','first'),pay=('Type','first'))
L={k:sorted(o[k].unique().tolist()) for k in ['st','sm','ds','pay']}
rows=[]
for i,r in o.iterrows(): rows.append(f"{i},{r.d},{L['st'].index(r.st)},{L['sm'].index(r.sm)},{L['ds'].index(r.ds)},{r.real},{r.sch},{r.n},{round(r.tot,2)},{L['pay'].index(r.pay)},{r.city.replace(',',' ').replace('|',' ')}|{r.country.replace(',',' ')}")
open('assets/shop.js','w').write('window.SHOP='+json.dumps(shop,separators=(',',':'))+';')
open('assets/orders.js','w').write('window.ORDERS={lk:'+json.dumps(L)+',rows:'+json.dumps('\n'.join(rows))+'};')
