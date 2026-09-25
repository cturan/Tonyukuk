local Y={}

Y.avx512_auto=os.getenv('YB_AVX512')=='1'
local E_DENETLE=os.getenv('YB_DENETLE')~=nil
local E_IZ=os.getenv('YB_IZ')

Y.saf={sabit=1,metin=1,genel_adres=1,yuva_adres=1,param=1,
  topla=1,cikar=1,carp=1,ve=1,veya=1,xor=1,sola=1,saga=1,
  carp_yuksek=1,carp_yuksek_s=1,tersle=1,bitnot=1,kiyas=1,sec=1,genislet=1,
  bit_say=1,ilk_bit=1,son_bit=1,bayt_ters=1,bit_ters=1,
  ftopla=1,fcikar=1,fcarp=1,fbol=1,fkiyas=1,fkarekok=1,
  f2f=1,f2i=1,i2f=1,fbit=1,fters=1}

Y.terminal={dal=1,kosul=1,don=1,tuzak=1}

function Y.islev(ad)
  return {ad=ad,d={},n=0,bloklar={},blok_no=0,yuva=0,yuvalar={},sabitler={}}
end

function Y.blok(f)
  f.blok_no=f.blok_no+1
  local b={no=f.blok_no,k={},oncul={},ardil={},muhurlu=false,bitti=false,
           tanim={},eksik={},eksik_sira={}}
  f.bloklar[#f.bloklar+1]=b
  return b
end

function Y.ek(f,b,t)
  f.n=f.n+1; t.id=f.n; t.blok=b; t.tur=t.tur or 'i'
  f.d[f.n]=t
  if b and not b.bitti then b.k[#b.k+1]=f.n end
  return f.n
end

function Y.ek_bas(f,b,t)
  f.n=f.n+1; t.id=f.n; t.blok=b; t.tur=t.tur or 'i'
  f.d[f.n]=t
  local i=1
  while b.k[i] and f.d[b.k[i]].op=='phi' do i=i+1 end
  table.insert(b.k,i,f.n)
  return f.n
end

function Y.sabit(f,v)
  local anahtar=tostring(v)
  local s=f.sabitler[anahtar]
  if s then return s end

  local g=f.bloklar[1]
  f.n=f.n+1
  local t={op='sabit',s=v,id=f.n,blok=g,tur='i'}
  f.d[f.n]=t
  table.insert(g.k,1,f.n)
  f.sabitler[anahtar]=f.n
  return f.n
end

function Y.bagla(o,a)
  o.ardil[#o.ardil+1]=a; a.oncul[#a.oncul+1]=o
end

function Y.bitir(f,b,t)
  if b.bitti then return end
  local id=Y.ek(f,b,t); b.bitti=true; b.son=id; return id
end

function Y.yaz(f,b,v,deger) b.tanim[v]=deger end

function Y.oku(f,b,v)
  local d=b.tanim[v]
  if d then return d end
  return Y.oku_ardisik(f,b,v)
end

function Y.oku_ardisik(f,b,v)
  local deger
  if not b.muhurlu then
    deger=Y.ek_bas(f,b,{op='phi',girdi={},degisken=v})
    b.eksik[v]=deger; b.eksik_sira[#b.eksik_sira+1]=v
  elseif #b.oncul==1 then
    deger=Y.oku(f,b.oncul[1],v)
    b.tanim[v]=deger
    return deger
  else
    deger=Y.ek_bas(f,b,{op='phi',girdi={},degisken=v})
    b.tanim[v]=deger
    deger=Y.phi_doldur(f,b,deger,v)
  end
  b.tanim[v]=deger
  return deger
end

function Y.phi_doldur(f,b,phi,v)
  local t=f.d[phi]
  for _,o in ipairs(b.oncul) do
    t.girdi[#t.girdi+1]={o,Y.oku(f,o,v)}
  end
  return Y.phi_sadelestir(f,phi)
end

function Y.phi_sadelestir(f,phi)
  local t=f.d[phi]; local ayni=nil
  for _,g in ipairs(t.girdi) do
    local o=g[2]
    if o~=phi and o~=ayni then
      if ayni~=nil then return phi end
      ayni=o
    end
  end
  if ayni==nil then return phi end
  t.op='kopya'; t.a=ayni; t.girdi=nil
  return phi
end

function Y.muhurle(f,b)
  if b.muhurlu then return end
  b.muhurlu=true

  local sira=b.eksik_sira
  b.eksik_sira={}
  for _,v in ipairs(sira) do
    local phi=b.eksik[v]
    if phi then Y.phi_doldur(f,b,phi,v) end
  end
  b.eksik={}
end

function Y.phi_temizle(f)
  local herhangi=false
  local degisti=true
  local tur=0
  while degisti and tur<50 do
    degisti=false; tur=tur+1
    for _,b in ipairs(f.bloklar) do
      for _,id in ipairs(b.k) do
        local t=f.d[id]
        if t.op=='phi' and t.girdi then
          local ayni,onemsiz=nil,true
          for _,g in ipairs(t.girdi) do
            local o=Y.coz(f,g[2])
            if o~=id and o~=ayni then
              if ayni~=nil then onemsiz=false; break end
              ayni=o
            end
          end
          if onemsiz and ayni then
            t.op='kopya'; t.a=ayni; t.girdi=nil; degisti=true; herhangi=true
          end
        end
      end
    end
  end
  return herhangi
end

function Y.coz(f,id)
  local g=0
  while id and f.d[id] and f.d[id].op=='kopya' do
    id=f.d[id].a; g=g+1
    if g>10000 then break end
  end
  return id
end

Y.blob={['kırp_i32_u8']=1,['kare_kırp_i16_u8']=1,['nokta_u8_i8']=1,
  ['vektör_topla_i8_i16']=1,['vektör_çıkar_i8_i16']=1,
  ['katla_u8_i8_i32']=1,['işlemci_özellikleri']=1,['kırp_i16_u8']=1,
  ['vektör_topla_i16']=1,['vektör_çıkar_i16']=1,['vektör_topla_i32']=1,
  ['vektör_topla_çıkar_i16']=1,['vektör_topla_çıkar_i32']=1,
  ['vektör_enbüyük_i16']=1,['vektör_topla_i16_i32']=1,['yoğun_i16']=1,['havuz_i16']=1,['taş_havuz_i16']=1,['taşlar_havuz_i16']=1,
  ['yoğun_blok_u8_i8_i32']=1,['karışım_i32']=1,['nokta8_i16']=1,
  ['nokta_u8_i8_i32']=1,['böl_ekle_i32_u8']=1,['karışım4_i32']=1,
  ['kaydır_kırp_i16_u8']=1,['ekle_relu512_i32_i16']=1,['çarp_kırp_i16_u8']=1,['kırp_çift_i32_u8']=1}

local ikili_op={['+']='topla',['-']='cikar',['*']='carp',['&']='ve',['|']='veya',
  ['^']='xor',['<<']='sola',['>>']='saga',['/']='bol',['%']='kalan'}
local fikili_op={['+']='ftopla',['-']='fcikar',['*']='fcarp',['/']='fbol'}
local kiyas_op={['==']=1,['!=']=1,['<']=1,['<=']=1,['>']=1,['>=']=1}

function Y.kurucu(C)
  local B={C=C}

  function B.normal(f,b,v,tur)
    local n=C.sayisal[tur]
    if not n or n.float or n[1]==64 then return v end
    return Y.ek(f,b,{op='genislet',a=v,bit=n[1],isaretli=n[2] and true or false})
  end

  function B.yuva(f,boy,hiza)
    hiza=hiza or 8
    f.yuva=(f.yuva+hiza-1)//hiza*hiza
    local o=f.yuva
    f.yuva=f.yuva+boy
    return o
  end

  function B.bag_yuvasi(f,bag)
    if not bag.yb_yuva then bag.yb_yuva=B.yuva(f,8) end
    return bag.yb_yuva
  end

  function B.yuva_adres(f,b,ofset)
    return Y.ek(f,b,{op='yuva_adres',ofset=ofset})
  end

  function B.guvenli(e,derinlik)
    derinlik=(derinlik or 0)+1
    if derinlik>6 then return false end
    local k=e[1]
    if k=='num' or k=='real' or k=='string' then return true end
    if k=='var' then return true end
    if k=='neg' or k=='bitnot' then return B.guvenli(e[2],derinlik) end
    if k=='call' then
      local n=e[2]
      if C.sayisal[n] then return B.guvenli(e[3][1],derinlik) end
      if n=='boyut' or n=='adres' or n=='adres_bitleri' or n=='bit_gör'
         or n=='gör' or n=='dizi_gör' then
        for _,a in ipairs(e[3]) do if not B.guvenli(a,derinlik) then return false end end
        return true
      end
      if n=='seç' or n=='adres_ekle' or n=='bit_say' or n=='ilk_bit' or n=='son_bit'
         or n=='bayt_ters' or n=='bit_ters' then
        for _,a in ipairs(e[3]) do if not B.guvenli(a,derinlik) then return false end end
        return true
      end
      return false
    end
    if k=='field' or k=='index' or k=='ref' then return false end
    if k=='&&' or k=='||' then return false end
    local p=C.oncelik[k]
    if p and k~='/' and k~='%' then
      return B.guvenli(e[2],derinlik) and B.guvenli(e[3],derinlik)
    end
    return false
  end

  function B.alan_adresi(f,st,e)
    local taban=B.ifade(f,st,e[2])
    if e.field.offset==0 then return taban end
    return Y.ek(f,st.b,{op='topla',a=taban,b=Y.sabit(f,e.field.offset)})
  end

  function B.indeks_adresi(f,st,e,genislik)
    local taban=B.ifade(f,st,e[2])
    local i=B.ifade(f,st,e[3])
    local o=i
    if genislik~=1 then
      o=Y.ek(f,st.b,{op='carp',a=i,b=Y.sabit(f,genislik)})
    end
    return Y.ek(f,st.b,{op='topla',a=taban,b=o})
  end

  function B.bellek_turu(t)
    if C.sayisal[t] then return C.sayisal[t][1],(C.sayisal[t][2] and true or false),
      (C.sayisal[t].float and t or nil) end
    return 64,false,nil
  end

  function B.yukle(f,st,adres,t,sinif)
    local bit,isaretli,kf=B.bellek_turu(t)
    return Y.ek(f,st.b,{op='yukle',a=adres,bit=bit,isaretli=isaretli,
                        sinif=sinif or 'yigin',tur='i'})
  end

  function B.sakla(f,st,adres,deger,t,sinif)
    local bit=B.bellek_turu(t)
    return Y.ek(f,st.b,{op='sakla',a=adres,b=deger,bit=bit,sinif=sinif or 'yigin'})
  end

  function B.ifade(f,st,e)
    local b=st.b
    local k=e[1]
    if k=='num' then
      if (C.sayisal[e.type] or {}).float then
        local paket=string.pack(e.type=='f32' and '<f' or '<d',e[2])
        return Y.sabit(f,string.unpack(e.type=='f32' and '<I4' or '<i8',paket))
      end
      return Y.sabit(f,e[2])
    elseif k=='real' then
      local paket=string.pack(e.type=='f32' and '<f' or '<d',e[2])
      return Y.sabit(f,string.unpack(e.type=='f32' and '<I4' or '<i8',paket))
    elseif k=='string' then
      return Y.ek(f,b,{op='metin',s=e[2]})
    elseif k=='var' then
      if e.global then
        if e.global.direct then return Y.ek(f,b,{op='genel_adres',g=e.global}) end
        local a=Y.ek(f,b,{op='genel_adres',g=e.global})
        return B.yukle(f,st,a,e.type,'genel:'..e.global.name)
      elseif e.constant~=nil then
        return Y.sabit(f,e.constant)
      else
        local bag=e.binding
        if bag.addressed then
          local a=B.yuva_adres(f,b,B.bag_yuvasi(f,bag))
          return B.yukle(f,st,a,e.type,'yigin')
        end
        return Y.oku(f,b,bag)
      end
    elseif k=='ref' then
      local l=e[2]
      if l[1]=='var' then
        if l.global then return Y.ek(f,b,{op='genel_adres',g=l.global}) end
        return B.yuva_adres(f,b,B.bag_yuvasi(f,l.binding))
      elseif l[1]=='field' then
        return B.alan_adresi(f,st,l)
      else
        local g=C.yapilar[l.type] and C.yapilar[l.type].size or C.sayisal[l.type][1]//8
        return B.indeks_adresi(f,st,l,g)
      end
    elseif k=='field' then
      if e.field.array then return B.alan_adresi(f,st,e) end
      return B.yukle(f,st,B.alan_adresi(f,st,e),e.type,'yigin')
    elseif k=='index' then
      if C.yapilar[e.element] then
        return B.indeks_adresi(f,st,e,C.yapilar[e.element].size)
      end
      local g=C.sayisal[e.element][1]//8
      return B.yukle(f,st,B.indeks_adresi(f,st,e,g),e.element,'yigin')
    elseif k=='neg' then
      local v=B.ifade(f,st,e[2])
      if (C.sayisal[e.type] or {}).float then
        return Y.ek(f,b,{op='fters',a=v,ft=e.type})
      end
      return B.normal(f,b,Y.ek(f,b,{op='tersle',a=v}),e.type)
    elseif k=='bitnot' then
      return B.normal(f,b,Y.ek(f,b,{op='bitnot',a=B.ifade(f,st,e[2])}),e.type)
    elseif k=='&&' or k=='||' then
      return B.kisa_devre(f,st,e)
    elseif k=='call' then
      return B.cagri(f,st,e)
    else
      return B.ikili(f,st,e)
    end
  end

  function B.ikili(f,st,e)
    local op=e[1]
    local iflo=(C.sayisal[e.operand] or {}).float
    local sol=B.ifade(f,st,e[2])
    local sag=B.ifade(f,st,e[3])
    local b=st.b
    if iflo then
      if fikili_op[op] then
        return Y.ek(f,b,{op=fikili_op[op],a=sol,b=sag,ft=e.operand})
      end
      return Y.ek(f,b,{op='fkiyas',a=sol,b=sag,iliski=op,ft=e.operand})
    end
    if kiyas_op[op] then
      local n=C.sayisal[e.operand]
      return Y.ek(f,b,{op='kiyas',a=sol,b=sag,iliski=op,
                       isaretsiz=(n and not n[2]) and true or false})
    end
    local n=C.sayisal[e.operand]
    local bit=n and n[1] or 64
    local isaretsiz=(n and not n[2]) and true or false
    if op=='>>' and bit<64 then
      sol=Y.ek(f,b,{op='genislet',a=sol,bit=bit,isaretli=not isaretsiz})
    end
    local d
    if op=='/' or op=='%' then
      d=Y.ek(f,b,{op=ikili_op[op],a=sol,b=sag,isaretsiz=isaretsiz})
    elseif op=='>>' then
      d=Y.ek(f,b,{op='saga',a=sol,b=sag,isaretsiz=isaretsiz})
    else
      d=Y.ek(f,b,{op=ikili_op[op],a=sol,b=sag})
    end
    return B.normal(f,b,d,e.type)
  end

  function B.kisa_devre(f,st,e)
    local b=st.b
    if B.guvenli(e[2]) and B.guvenli(e[3]) then
      local x=B.mantiksal(f,st,e[2])
      local y=B.mantiksal(f,st,e[3])
      if e[1]=='&&' then return Y.ek(f,st.b,{op='ve',a=x,b=y}) end
      return Y.ek(f,st.b,{op='veya',a=x,b=y})
    end
    local sonuc={}
    local ikinci,son=Y.blok(f),Y.blok(f)
    local x=B.ifade(f,st,e[2])
    local xb=st.b
    local sifir=Y.sabit(f,0)
    local kx=Y.ek(f,xb,{op='kiyas',a=x,b=sifir,iliski='!='})
    Y.yaz(f,xb,sonuc,kx)
    if e[1]=='&&' then
      Y.bitir(f,xb,{op='kosul',a=kx,dogru=ikinci,yanlis=son})
    else
      Y.bitir(f,xb,{op='kosul',a=kx,dogru=son,yanlis=ikinci})
    end
    Y.bagla(xb,ikinci); Y.bagla(xb,son)
    Y.muhurle(f,ikinci)
    st.b=ikinci
    local y=B.ifade(f,st,e[3])
    local yb=st.b
    local ky=Y.ek(f,yb,{op='kiyas',a=y,b=sifir,iliski='!='})
    Y.yaz(f,yb,sonuc,ky)
    Y.bitir(f,yb,{op='dal',hedef=son}); Y.bagla(yb,son)
    Y.muhurle(f,son)
    st.b=son
    return Y.oku(f,son,sonuc)
  end

  function B.mantiksal(f,st,e)
    local v=B.ifade(f,st,e)
    local t=f.d[v]
    if t.op=='kiyas' or t.op=='fkiyas' then return v end
    if t.op=='sabit' then return Y.sabit(f,t.s~=0 and 1 or 0) end
    return Y.ek(f,st.b,{op='kiyas',a=v,b=Y.sabit(f,0),iliski='!='})
  end

  local bellek_ilkel={bayt_oku={2,false,8,false},bayt_yaz={3,true,8,false},
    ['sayı_oku']={2,false,64,true},['sayı_yaz']={3,true,64,true}}

  function B.cagri(f,st,e)
    local n=e[2]
    local b=st.b

    if n=='seç' then return B.sec(f,st,e) end
    if n=='boyut' then return Y.sabit(f,e.size) end
    if n=='adres' or n=='adres_bitleri' then return B.ifade(f,st,e[3][1]) end
    if n=='gör' or n=='dizi_gör' then return B.ifade(f,st,e[3][2]) end
    if n=='bit_gör' then
      return B.normal(f,st.b,B.ifade(f,st,e[3][2]),e.type)
    end
    if n=='dizi' then
      local adet=e.count or e[3][1].constant or e[3][1][2]
      return B.yuva_adres(f,b,B.yuva(f,(adet+7)//8*8,16))
    end
    if n=='yerel' then return B.yuva_adres(f,b,B.yuva(f,(e.size+7)//8*8,16)) end
    if n=='yerel_dizi' then
      return B.yuva_adres(f,b,B.yuva(f,(e.size*e.count+7)//8*8,16))
    end
    if n=='yeni' then
      return B.dis_cagri(f,st,'bellek_ayır',{Y.sabit(f,e.size)})
    end
    if n=='yeni_dizi' then
      local uz=B.ifade(f,st,e[3][2])
      return B.t_cagri(f,st,'__t_array_alloc',{uz,Y.sabit(f,e.size)})
    end
    if n=='sil' then
      return B.dis_cagri(f,st,'bellek_bırak',{B.ifade(f,st,e[3][1])})
    end
    if n=='işlev_adresi' then
      return Y.ek(f,b,{op='islev_adres',ad=e[3][1][2]})
    end
    if n=='adres_ekle' then
      return Y.ek(f,b,{op='topla',a=B.ifade(f,st,e[3][1]),b=B.ifade(f,st,e[3][2])})
    end
    if n=='karekök' then
      return Y.ek(f,b,{op='fkarekok',a=B.ifade(f,st,e[3][1]),ft=e.type})
    end
    if C.sayisal[n] then return B.donusum(f,st,e) end

    local tek={bit_say='bit_say',ilk_bit='ilk_bit',son_bit='son_bit',
               bayt_ters='bayt_ters',bit_ters='bit_ters'}
    if tek[n] then
      return Y.ek(f,b,{op=tek[n],a=B.ifade(f,st,e[3][1])})
    end
    if n=='çarp_yüksek_u64' then
      return Y.ek(f,b,{op='carp_yuksek',a=B.ifade(f,st,e[3][1]),
                       b=B.ifade(f,st,e[3][2])})
    end
    if n=='işlemci_bekle' then
      Y.ek(f,b,{op='bekle'}); return Y.sabit(f,0)
    end
    if n=='öngetir' then
      Y.ek(f,b,{op='ongetir',a=B.ifade(f,st,e[3][1])}); return Y.sabit(f,0)
    end
    if n=='atomik_oku' or n=='atomik_yaz' or n=='atomik_ekle'
       or n=='atomik_kıyas_değiştir' then
      local a={}
      for i,x in ipairs(e[3]) do a[i]=B.ifade(f,st,x) end
      return Y.ek(f,b,{op='atomik',alt=n,a=a[1],b=a[2],c=a[3]})
    end

    local m=bellek_ilkel[n]
    local mtur,mislem=n:match('^([iuf]%d+)_(%a+)$')
    if n=='adres_oku' or n=='adres_yaz' then mtur='adres'; mislem=n:sub(7) end
    if m or ((C.sayisal[mtur] or mtur=='adres') and (mislem=='oku' or mislem=='yaz')) then
      local yazma,bit,olcek,isaretli,sinif
      if m then
        yazma=m[2]; bit=m[3]; olcek=m[4] and 8 or 1
        isaretli=false
      else
        yazma=(mislem=='yaz')
        if mtur=='adres' then bit=64; isaretli=false
        else bit=C.sayisal[mtur][1]; isaretli=C.sayisal[mtur][2] and true or false end
        olcek=bit//8
      end
      local taban=B.ifade(f,st,e[3][1])
      local i=B.ifade(f,st,e[3][2])
      local adres=taban
      local it=f.d[i]
      if it.op=='sabit' and it.s==0 then
        adres=taban
      else
        local o=i
        if olcek~=1 then o=Y.ek(f,st.b,{op='carp',a=i,b=Y.sabit(f,olcek)}) end
        adres=Y.ek(f,st.b,{op='topla',a=taban,b=o})
      end
      if yazma then
        local v=B.ifade(f,st,e[3][3])
        Y.ek(f,st.b,{op='sakla',a=adres,b=v,bit=bit,sinif='yigin'})
        return v
      end
      local fl=(C.sayisal[mtur] or {}).float
      return Y.ek(f,st.b,{op='yukle',a=adres,bit=bit,isaretli=isaretli,
                          sinif='yigin',kf=fl and mtur or nil})
    end

    if Y.blob[n] then return B.blob_cagri(f,st,e) end

    if n=='çağır' then
      local hedef=B.ifade(f,st,e[3][1])
      local a={}
      for i=2,#e[3] do a[#a+1]=B.ifade(f,st,e[3][i]) end
      return Y.ek(f,st.b,{op='cagri',dolayli=hedef,args=a,
                          sonuc=e.callback.result})
    end
    if C.yerlesik[n] then
      local a={}
      for i,x in ipairs(e[3]) do a[i]=B.ifade(f,st,x) end
      return B.dis_cagri(f,st,n,a)
    end
    if C.bildirim[n] then
      local a={}
      for i,x in ipairs(e[3]) do a[i]=B.ifade(f,st,x) end
      return B.t_cagri(f,st,n,a)
    end
    C.hata('YB: bilinmeyen cagri '..tostring(n))
  end

  function B.t_cagri(f,st,ad,args)
    local d=C.bildirim[ad]
    return Y.ek(f,st.b,{op='cagri',ad=ad,args=args,sonuc=d and d[5] or 'i64'})
  end

  function B.dis_cagri(f,st,ad,args,gercek)
    local y=C.yerlesik[gercek or ad]
    if not y then C.hata('YB: yerlesik yok '..tostring(gercek or ad)) end
    return Y.ek(f,st.b,{op='cagri',dis=gercek or ad,args=args,
                        sonuc=y[4],abi=y[5],indeks=y[1]})
  end

  function B.donusum(f,st,e)
    local hedef=e[2]
    local kaynak=e[3][1].type
    local kf=(C.sayisal[kaynak] or {}).float
    local hf=C.sayisal[hedef].float
    local v=B.ifade(f,st,e[3][1])
    local b=st.b
    if kf and hf then
      if kaynak~=hedef then v=Y.ek(f,b,{op='f2f',a=v,kf=kaynak,hf=hedef}) end
      return v
    elseif hf then
      return Y.ek(f,b,{op='i2f',a=v,hf=hedef,isaretsiz=(kaynak=='u64')})
    elseif kf then
      return Y.ek(f,b,{op='f2i',a=v,kf=kaynak,isaretsiz=(hedef=='u64')})
    end
    return B.normal(f,b,v,hedef)
  end

  function B.sec(f,st,e)
    local c,x,y=e[3][1],e[3][2],e[3][3]
    if B.guvenli(x) and B.guvenli(y) then
      local kv=B.mantiksal(f,st,c)
      local xv=B.ifade(f,st,x)
      local yv=B.ifade(f,st,y)
      return Y.ek(f,st.b,{op='sec',a=kv,b=xv,c=yv})
    end
    local sonuc={}
    local db,yb2,son=Y.blok(f),Y.blok(f),Y.blok(f)
    local kv=B.mantiksal(f,st,c)
    local cb=st.b
    Y.bitir(f,cb,{op='kosul',a=kv,dogru=db,yanlis=yb2})
    Y.bagla(cb,db); Y.bagla(cb,yb2)
    Y.muhurle(f,db); Y.muhurle(f,yb2)
    st.b=db
    local xv=B.ifade(f,st,x); Y.yaz(f,st.b,sonuc,xv)
    Y.bitir(f,st.b,{op='dal',hedef=son}); Y.bagla(st.b,son)
    st.b=yb2
    local yv=B.ifade(f,st,y); Y.yaz(f,st.b,sonuc,yv)
    Y.bitir(f,st.b,{op='dal',hedef=son}); Y.bagla(st.b,son)
    Y.muhurle(f,son)
    st.b=son
    return Y.oku(f,son,sonuc)
  end

  function B.blob_cagri(f,st,e)
    local a={}
    for i,x in ipairs(e[3]) do a[i]=B.ifade(f,st,x) end
    return Y.ek(f,st.b,{op='ic',ad=e[2],args=a,dugum=e})
  end

  function B.git(f,st,hedef)
    if st.b.bitti then return end
    Y.bitir(f,st.b,{op='dal',hedef=hedef}); Y.bagla(st.b,hedef)
  end

  function B.temizle(f,st,ilk)
    for i=#st.temizlik,ilk,-1 do
      local liste=st.temizlik[i]
      for j=#liste,1,-1 do B.govde(f,st,liste[j],true) end
    end
  end

  function B.govde(f,st,liste,ictemizlik)
    st.temizlik[#st.temizlik+1]={}
    for _,n in ipairs(liste) do
      if st.b.bitti then break end
      B.deyim(f,st,n)
    end
    if not st.b.bitti then B.temizle(f,st,#st.temizlik) end
    st.temizlik[#st.temizlik]=nil
  end

  function B.deyim(f,st,n)
    local k=n[1]
    if k=='scope' then B.govde(f,st,n[2])
    elseif k=='defer' then
      local liste=st.temizlik[#st.temizlik]; liste[#liste+1]=n[2]
    elseif k=='eval' then B.ifade(f,st,n[2])
    elseif k==':=' then
      local v=B.ifade(f,st,n[3])
      local bag=n.binding
      if bag.addressed then
        B.sakla(f,st,B.yuva_adres(f,st.b,B.bag_yuvasi(f,bag)),v,'i64')
      else
        Y.yaz(f,st.b,bag,v)
      end
    elseif k=='=' then
      local v=B.ifade(f,st,n[3])
      if n.global then
        local a=Y.ek(f,st.b,{op='genel_adres',g=n.global})
        Y.ek(f,st.b,{op='sakla',a=a,b=v,bit=B.bellek_turu(n.global.type),
                     sinif='genel:'..n.global.name})
      else
        local bag=n.binding
        if bag.addressed then
          B.sakla(f,st,B.yuva_adres(f,st.b,B.bag_yuvasi(f,bag)),v,'i64')
        else
          Y.yaz(f,st.b,bag,v)
        end
      end
    elseif k=='store' then
      local l=n[2]
      local adres,tur
      if l[1]=='field' then adres=B.alan_adresi(f,st,l); tur=l.type
      else
        local g=C.sayisal[l.element][1]//8
        adres=B.indeks_adresi(f,st,l,g); tur=l.element
      end
      local v=B.ifade(f,st,n[3])
      B.sakla(f,st,adres,v,tur)
    elseif k=='update' then
      B.guncelle(f,st,n)
    elseif k=='return' then
      local v=B.ifade(f,st,n[2])
      B.temizle(f,st,1)
      if not st.b.bitti then Y.bitir(f,st.b,{op='don',a=v}) end
    elseif k=='kır' then
      local d=st.dongu[#st.dongu]
      B.temizle(f,st,d.derinlik+1); B.git(f,st,d.son)
    elseif k=='sürdür' then
      local d=st.dongu[#st.dongu]
      B.temizle(f,st,d.derinlik+1); B.git(f,st,d.adim)
    elseif k=='if' then B.kosul_deyimi(f,st,n)
    elseif k=='while' then B.dongu(f,st,n)
    else C.hata('YB: bilinmeyen deyim '..tostring(k)) end
  end

  function B.guncelle(f,st,n)
    local l=n[2]; local t=n.type
    local op=ikili_op[n[4]]
    local sn=C.sayisal[t]
    local isaretsiz=(sn and not sn[2]) and true or false

    local fop=sn and sn.float and fikili_op[n[4]]
    if sn and sn.float and not fop then C.hata('YB: kayan noktali bilesik atama '..tostring(n[4])) end
    local function hesapla(eski,sag)
      if fop then return Y.ek(f,st.b,{op=fop,a=eski,b=sag,ft=t}) end
      if n[4]=='>>' and sn[1]<64 then
        eski=Y.ek(f,st.b,{op='genislet',a=eski,bit=sn[1],isaretli=not isaretsiz})
      end
      return B.normal(f,st.b,Y.ek(f,st.b,{op=op,a=eski,b=sag,isaretsiz=isaretsiz}),t)
    end
    if l[1]=='var' and not l.global and not l.binding.addressed then
      local eski=Y.oku(f,st.b,l.binding)
      local sag=B.ifade(f,st,n[3])
      Y.yaz(f,st.b,l.binding,hesapla(eski,sag))
      return
    end
    local adres,sinif
    if l[1]=='var' and l.global then
      adres=Y.ek(f,st.b,{op='genel_adres',g=l.global}); sinif='genel:'..l.global.name
    elseif l[1]=='var' then
      adres=B.yuva_adres(f,st.b,B.bag_yuvasi(f,l.binding)); sinif='yigin'
    elseif l[1]=='field' then
      adres=B.alan_adresi(f,st,l); sinif='yigin'
    else
      adres=B.indeks_adresi(f,st,l,C.sayisal[l.element][1]//8); sinif='yigin'
    end
    local bit=B.bellek_turu(t)
    local eski=Y.ek(f,st.b,{op='yukle',a=adres,bit=bit,
      isaretli=(sn and sn[2]) and true or false,sinif=sinif})
    local sag=B.ifade(f,st,n[3])
    Y.ek(f,st.b,{op='sakla',a=adres,b=hesapla(eski,sag),bit=bit,sinif=sinif})
  end

  function B.kosul_deyimi(f,st,n)
    local db,son=Y.blok(f),Y.blok(f)
    local yb=n[4] and Y.blok(f) or son
    local kv=B.mantiksal(f,st,n[2])
    Y.bitir(f,st.b,{op='kosul',a=kv,dogru=db,yanlis=yb})
    Y.bagla(st.b,db); Y.bagla(st.b,yb)
    Y.muhurle(f,db)
    st.b=db; B.govde(f,st,n[3]); B.git(f,st,son)
    if n[4] then
      Y.muhurle(f,yb)
      st.b=yb; B.govde(f,st,n[4]); B.git(f,st,son)
    end
    Y.muhurle(f,son)
    st.b=son
    if #son.oncul==0 then son.bitti=true end
  end

  function B.dongu(f,st,n)
    local kosul,govde,adim,son=Y.blok(f),Y.blok(f),Y.blok(f),Y.blok(f)
    B.git(f,st,kosul)
    st.b=kosul
    local kv=B.mantiksal(f,st,n[2])
    local kb=st.b
    Y.bitir(f,kb,{op='kosul',a=kv,dogru=govde,yanlis=son})
    Y.bagla(kb,govde); Y.bagla(kb,son)
    Y.muhurle(f,govde)
    st.dongu[#st.dongu+1]={adim=adim,son=son,derinlik=#st.temizlik}
    st.b=govde; B.govde(f,st,n[3]); B.git(f,st,adim)
    st.dongu[#st.dongu]=nil
    Y.muhurle(f,adim)
    st.b=adim
    if n.step then B.govde(f,st,n.step) end
    B.git(f,st,kosul)
    Y.muhurle(f,kosul)
    Y.muhurle(f,son)
    st.b=son
    if #son.oncul==0 then son.bitti=true end
  end

  function B.kur(fn)
    local f=Y.islev(fn[1])
    f.ast=fn
    local giris=Y.blok(f)
    giris.muhurlu=true
    local st={b=giris,dongu={},temizlik={}}
    f.param_sayisi=#fn[2]
    for i,ad in ipairs(fn[2]) do
      local bag=fn.params[i]
      local p=Y.ek(f,giris,{op='param',sira=i,tur='i'})
      if bag.addressed then
        B.sakla(f,st,B.yuva_adres(f,giris,B.bag_yuvasi(f,bag)),p,'i64')
      else
        Y.yaz(f,giris,bag,p)
      end
    end
    B.govde(f,st,fn[3])
    if not st.b.bitti then
      Y.bitir(f,st.b,{op='don',a=Y.sabit(f,0)})
    end
    for _,b in ipairs(f.bloklar) do
      if not b.muhurlu then Y.muhurle(f,b) end
      if not b.bitti then Y.bitir(f,b,{op='don',a=Y.sabit(f,0)}) end
    end
    return f
  end

  return B
end

function Y.yaz_deger(f,id)
  local t=f.d[id]
  if not t then return '?'..tostring(id) end
  local p={}
  local function e(x) p[#p+1]=x end
  if t.op=='sabit' then return string.format('%%%d = %d',id,t.s) end
  e(string.format('%%%d = %s',id,t.op))
  if t.op=='phi' then
    local g={}
    for _,x in ipairs(t.girdi or {}) do g[#g+1]=string.format('B%d:%%%d',x[1].no,x[2]) end
    e(' '..table.concat(g,' '))
  else
    if t.a then e(' %'..t.a) end
    if t.b then e(' %'..t.b) end
    if t.c then e(' %'..t.c) end
  end
  if t.iliski then e(' ['..t.iliski..(t.isaretsiz and ' u' or '')..']') end
  if t.bit then e(' :'..t.bit..(t.isaretli and 's' or 'u')) end
  if t.sinif then e(' @'..t.sinif) end
  if t.ofset then e(' +'..t.ofset) end
  if t.ad then e(' <'..t.ad..'>') end
  if t.dis then e(' dis<'..t.dis..'>') end
  if t.g then e(' g<'..t.g.name..'>') end
  if t.args then
    local g={}
    for _,x in ipairs(t.args) do g[#g+1]='%'..x end
    e('('..table.concat(g,',')..')')
  end
  if t.hedef then e(' -> B'..t.hedef.no) end
  if t.dogru then e(' ? B'..t.dogru.no..' : B'..t.yanlis.no) end
  return table.concat(p)
end

function Y.dokum(f)
  local s={string.format('islev %s  (%d deger, %d blok, %d bayt yuva)',
                         f.ad,f.n,#f.bloklar,f.yuva)}
  for _,b in ipairs(f.bloklar) do
    local o={}
    for _,x in ipairs(b.oncul) do o[#o+1]='B'..x.no end
    s[#s+1]=string.format('B%d:  <- %s',b.no,table.concat(o,' '))
    for _,id in ipairs(b.k) do s[#s+1]='    '..Y.yaz_deger(f,id) end
  end
  return table.concat(s,'\n')
end

function Y.istatistik(f)
  local say={}
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local o=f.d[id].op; say[o]=(say[o] or 0)+1
    end
  end
  return say
end

Y.anlik_ikili={topla=1,cikar=1,ve=1,veya=1,xor=1,sola=1,saga=1,kiyas=1}

function Y.kopyalari_coz(f)
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.a then t.a=Y.coz(f,t.a) end
      if t.b then t.b=Y.coz(f,t.b) end
      if t.c then t.c=Y.coz(f,t.c) end
      if t.args then for i,x in ipairs(t.args) do t.args[i]=Y.coz(f,x) end end
      if t.dolayli then t.dolayli=Y.coz(f,t.dolayli) end
      if t.girdi then for _,g in ipairs(t.girdi) do g[2]=Y.coz(f,g[2]) end end
    end
  end
  for _,b in ipairs(f.bloklar) do
    local y={}
    for _,id in ipairs(b.k) do if f.d[id].op~='kopya' then y[#y+1]=id end end
    b.k=y
  end
end

function Y.kullanim(f)
  local u={}
  for i=1,f.n do u[i]=0 end
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      local function s(x) if x then u[x]=(u[x] or 0)+1 end end
      if t.op=='phi' then for _,g in ipairs(t.girdi) do s(g[2]) end
      else s(t.a); s(t.b); s(t.c) end
      if t.args then for _,x in ipairs(t.args) do s(x) end end
      if t.dolayli then s(t.dolayli) end
    end
  end
  f.u=u
  return u
end

function Y.olu_ele(f)
  local degisti=true
  while degisti do
    degisti=false
    local u=Y.kullanim(f)
    for _,b in ipairs(f.bloklar) do
      local y={}
      for _,id in ipairs(b.k) do
        local t=f.d[id]
        if (Y.saf[t.op] or t.op=='phi') and u[id]==0 then degisti=true
        else y[#y+1]=id end
      end
      b.k=y
    end
  end
end

function Y.sirala(f,sicaklik)
  local gorulen,sira={},{}
  local function gez(b)
    if gorulen[b] then return end
    gorulen[b]=true
    local t=f.d[b.son]
    local ardil={}
    if t then
      if t.op=='dal' then ardil={t.hedef}
      elseif t.op=='kosul' then
        if sicaklik then
          local sd,sy=sicaklik(b,t.dogru),sicaklik(b,t.yanlis)
          if sy>sd then ardil={t.dogru,t.yanlis} else ardil={t.yanlis,t.dogru} end
        else ardil={t.yanlis,t.dogru} end
      end
    end
    for _,a in ipairs(ardil) do gez(a) end
    sira[#sira+1]=b
  end
  gez(f.bloklar[1])
  local n=#sira
  local d={}
  for i=n,1,-1 do d[#d+1]=sira[i] end
  for i,b in ipairs(d) do b.sira=i end
  f.duz=d

  local y={}
  for _,b in ipairs(f.bloklar) do if b.sira then y[#y+1]=b end end
  f.bloklar=y
  for _,b in ipairs(f.bloklar) do
    local o={}
    for _,x in ipairs(b.oncul) do if x.sira then o[#o+1]=x end end
    b.oncul=o
  end
  return d
end

Y.sonucsuz={sakla=1,dal=1,kosul=1,don=1,ongetir=1,bekle=1,tuzak=1}

function Y.sabit_maliyet(v)
  local sifir,bir=0,0
  for i=0,3 do
    local c=(v>>(i*16))&65535
    if c~=0 then sifir=sifir+1 end
    if c~=65535 then bir=bir+1 end
  end
  local n=math.min(sifir,bir)
  return n<1 and 1 or n
end

function Y.remat(f,id)
  local t=f.d[id]
  return t.op=='sabit' and not t.kayitli
end

function Y.sabit_kayitlari(f)
  local liste={}
  for id=1,f.n do
    local t=f.d[id]
    if t and t.op=='sabit' and f.ara[id] and Y.sabit_maliyet(t.s)>=2 then
      t.kayitli=true; liste[#liste+1]=id
    end
  end
  f.sabit_liste=liste
end

function Y.gruplar(f,H)
  local grup,n={},0
  local function bul(x) while grup[x] and grup[x]~=x do x=grup[x] end; return x end
  local function birlestir(a,b)
    a=bul(a); b=bul(b)
    if a~=b then grup[b]=a end
  end
  for _,b in ipairs(f.duz) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='phi' then
        grup[id]=grup[id] or id
        for _,g in ipairs(t.girdi) do
          if f.ara[g[2]] then grup[g[2]]=grup[g[2]] or g[2]; birlestir(id,g[2]) end
        end
      end
    end
  end
  f.grup_bul=bul

  local abi={}
  for _,b in ipairs(f.duz) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='cagri' and t.args then
        for i,x in ipairs(t.args) do
          if H.abi[i] and f.ara[x] then abi[bul(x)]=abi[bul(x)] or H.abi[i] end
        end
      elseif t.op=='param' and H.abi[t.sira] and f.ara[id] then
        abi[bul(id)]=abi[bul(id)] or H.abi[t.sira]
      end
    end
  end
  f.abi_tercih=abi
end

function Y.kiyas_cogalt(f,H)
  local sec_ok=not (H and H.sec_kaynastirma_yok)
  local u=Y.kullanim(f)
  local degisti=false
  for _,b in ipairs(f.bloklar) do
    local yeni={}
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if (t.op=='kosul' or (t.op=='sec' and sec_ok)) and t.a then
        local c=f.d[t.a]
        local onceki=yeni[#yeni] and f.d[yeni[#yeni]]
        if c and c.op=='kiyas' and t.op=='sec' and onceki and onceki.op=='sec'
           and onceki.cogul==t.a then

          local k=onceki.a
          f.d[k].kaynasik=true; onceki.kaynasik_kiyas=k
          u[t.a]=u[t.a]-1; t.cogul=t.a; t.a=k; t.kaynasik_kiyas=k; t.bayrak_yeniden=true
          degisti=true
        elseif c and c.op=='kiyas' and (u[t.a]>1 or c.blok~=b) and yeni[#yeni]~=t.a then
          f.n=f.n+1
          local k={}
          for anahtar,v in pairs(c) do k[anahtar]=v end
          k.id=f.n; k.blok=b; f.d[f.n]=k; yeni[#yeni+1]=f.n
          u[t.a]=u[t.a]-1; u[f.n]=1; t.cogul=t.a; t.a=f.n; degisti=true
        end
      end
      yeni[#yeni+1]=id
    end
    b.k=yeni
  end
  if degisti then Y.olu_ele(f) end
end

function Y.kaynastir(f,H)
  local u=Y.kullanim(f)
  local sec_ok=not (H and H.sec_kaynastirma_yok)
  for _,b in ipairs(f.bloklar) do
    for i,id in ipairs(b.k) do
      local t=f.d[id]
      if (t.op=='kosul' or (t.op=='sec' and sec_ok)) and t.a then
        local c=f.d[t.a]
        if c and (c.op=='kiyas' or c.op=='fkiyas') and u[t.a]==1
           and c.blok==b and b.k[i-1]==t.a then
          c.kaynasik=true; t.kaynasik_kiyas=t.a
        end
      end
    end
  end
end

function Y.yuk_kaynastir(f,H)
  if not H.yuk_katlama then return end
  local u=Y.kullanim(f)
  local uygun={topla=1,cikar=1,ve=1,veya=1,xor=1,kiyas=1}
  for _,b in ipairs(f.bloklar) do
    for i,id in ipairs(b.k) do
      local t=f.d[id]
      if uygun[t.op] and t.b and i>1 and b.k[i-1]==t.b then
        local y=f.d[t.b]
        if y.op=='yukle' and u[t.b]==1 and y.bit==64 and not y.kaynasik then
          y.kaynasik=true; t.kaynasik_yuk=t.b
        end
      end
    end
  end
end

function Y.tahsis(f,H)
  Y.gruplar(f,H)
  local bul=f.grup_bul
  local liste={}
  for id,it in pairs(f.ara) do
    local t=f.d[id]
    if t and t.blok and t.blok.sira and not Y.sonucsuz[t.op] and not t.kaynasik
       and not Y.remat(f,id) and #it.p>0 then
      it.id=id; liste[#liste+1]=it
    end
  end
  table.sort(liste,function(x,y)
    local a,b=Y.aralik_bas(x),Y.aralik_bas(y)
    if a~=b then return a<b end
    return x.id<y.id
  end)

  local kayit,dokum={},{}
  local aktif,pasif={},{}
  local kullanilan_kalici={}
  local grup_kayit={}
  local function yuva_ver(id)
    if not dokum[id] then
      f.yuva=(f.yuva+7)//8*8
      dokum[id]=f.yuva; f.yuva=f.yuva+8
    end
    return dokum[id]
  end

  for _,cur in ipairs(liste) do
    local pos=Y.aralik_bas(cur)
    local son=Y.aralik_son(cur)

    local ya={}
    for _,it in ipairs(aktif) do
      if Y.aralik_son(it)<pos then
      elseif not Y.kapsar(it,pos) then pasif[#pasif+1]=it
      else ya[#ya+1]=it end
    end
    aktif=ya
    local yp={}
    for _,it in ipairs(pasif) do
      if Y.aralik_son(it)<pos then
      elseif Y.kapsar(it,pos) then aktif[#aktif+1]=it
      else yp[#yp+1]=it end
    end
    pasif=yp

    local bos={}
    for _,r in ipairs(H.ucucu) do bos[r]=math.maxinteger end
    for _,r in ipairs(H.kalici) do bos[r]=math.maxinteger end
    for _,it in ipairs(aktif) do local r=kayit[it.id]; if r and bos[r] then bos[r]=0 end end
    for _,it in ipairs(pasif) do
      local r=kayit[it.id]
      if r and bos[r] then
        local x=Y.ilk_kesisme(it,cur)
        if x and x<bos[r] then bos[r]=x end
      end
    end
    for r,it in pairs(f.sabit_ara) do
      if bos[r] then
        local x=Y.ilk_kesisme(it,cur)
        if x and x<bos[r] then bos[r]=x end
      end
    end

    local g=bul(cur.id)
    local tercih=grup_kayit[g] or f.abi_tercih[g]
    local secilen
    if tercih and bos[tercih] and bos[tercih]>son then secilen=tercih end
    if not secilen then
      for _,r in ipairs(H.ucucu) do if bos[r]>son then secilen=r; break end end
    end
    if not secilen then
      for _,r in ipairs(H.kalici) do if bos[r]>son then secilen=r; break end end
    end

    if secilen then
      kayit[cur.id]=secilen
      if H.kalici_kume[secilen] then kullanilan_kalici[secilen]=true end
      if not grup_kayit[g] then grup_kayit[g]=secilen end
      aktif[#aktif+1]=cur
    else

      local kurban,kurban_k=nil,-1
      for _,it in ipairs(aktif) do
        local r=kayit[it.id]
        if r and bos[r]~=nil then
          local k=Y.sonraki_kullanim(it,pos)
          if k>kurban_k and Y.ilk_kesisme(it,cur) then kurban=it; kurban_k=k end
        end
      end
      local kendi=Y.sonraki_kullanim(cur,pos)
      local r=kurban and kayit[kurban.id]

      local uygun=false
      if r then
        local serbest=math.maxinteger
        for _,o in ipairs(aktif) do
          if o~=kurban and kayit[o.id]==r then serbest=0 end
        end
        for _,o in ipairs(pasif) do
          if kayit[o.id]==r then
            local x=Y.ilk_kesisme(o,cur)
            if x and x<serbest then serbest=x end
          end
        end
        local sab=f.sabit_ara[r]
        if sab then
          local x=Y.ilk_kesisme(sab,cur)
          if x and x<serbest then serbest=x end
        end
        uygun=serbest>son
      end
      if kurban and uygun and kurban_k>kendi then
        kayit[cur.id]=r; kayit[kurban.id]=nil
        if f.d[kurban.id].op=='sabit' then f.d[kurban.id].kayitli=nil
        else yuva_ver(kurban.id) end
        local ya2={}
        for _,it in ipairs(aktif) do if it~=kurban then ya2[#ya2+1]=it end end
        ya2[#ya2+1]=cur; aktif=ya2
        if H.kalici_kume[r] then kullanilan_kalici[r]=true end
      elseif f.d[cur.id].op=='sabit' then
        f.d[cur.id].kayitli=nil
      else
        yuva_ver(cur.id)
      end
    end
  end

  if E_DENETLE then
    local per={}
    for _,it in ipairs(liste) do
      local r=kayit[it.id]
      if r then per[r]=per[r] or {}; table.insert(per[r],it) end
    end
    for r,l in pairs(per) do
      for i=1,#l do for j=i+1,#l do
        local x=Y.ilk_kesisme(l[i],l[j])
        if x then
          error(string.format('YB TAHSIS HATASI %s: kayit %d, %%%d ile %%%d konum %d',
            f.ad,r,l[i].id,l[j].id,x),0)
        end
      end end
      local sab=f.sabit_ara[r]
      if sab then
        for i=1,#l do
          local x=Y.ilk_kesisme(l[i],sab)
          if x then
            error(string.format('YB TAHSIS HATASI %s: kayit %d sabit aralikla cakisti (%%%d, konum %d)',
              f.ad,r,l[i].id,x),0)
          end
        end
      end
    end
  end

  f.kayit=kayit; f.dokum=dokum
  local kl={}
  for r in pairs(kullanilan_kalici) do kl[#kl+1]=r end
  table.sort(kl)
  f.kalici_kayitlar=kl
  return f
end

local A={}
Y.ARM=A

A.kosul={['==']=0,['!=']=1,['<']=11,['>=']=10,['>']=12,['<=']=13}
A.kosul_u={['==']=0,['!=']=1,['<']=3,['>=']=2,['>']=8,['<=']=9}
A.ters={[0]=1,[1]=0,[2]=3,[3]=2,[8]=9,[9]=8,[10]=11,[11]=10,[12]=13,[13]=12}
A.ikili={topla=0x8b000000,cikar=0xcb000000,carp=0x9b007c00,
         ve=0x8a000000,veya=0xaa000000,xor=0xca000000,
         sola=0x9ac02000,saga=0x9ac02400}
A.mantik_anlik={ve=0x92000000,veya=0xb2000000,xor=0xd2000000}
A.yukle_imm={[8]=0x39400000,[16]=0x79400000,[32]=0xb9400000,[64]=0xf9400000}
A.yukle_imm_s={[8]=0x39800000,[16]=0x79800000,[32]=0xb9800000,[64]=0xf9400000}
A.sakla_imm={[8]=0x39000000,[16]=0x79000000,[32]=0xb9000000,[64]=0xf9000000}
A.yukle_reg={[8]=0x38606800,[16]=0x78607800,[32]=0xb8607800,[64]=0xf8607800}
A.yukle_reg_s={[8]=0x38a06800,[16]=0x78a07800,[32]=0xb8a07800,[64]=0xf8607800}
A.sakla_reg={[8]=0x38206800,[16]=0x78207800,[32]=0xb8207800,[64]=0xf8207800}

function A.yeni(f,E,H)
  local M={f=f,E=E,H=H}
  local u32,hex=E.u32,E.hex

  function M.kazi(i) return H.kazi[i] end

  function M.sabit_kayit(v,r) E.immediate(v,r); return r end

  function M.sabit_mi(id)
    local t=f.d[id]
    if t and t.op=='sabit' then return t.s end
  end

  function M.oku(id,kazi_no)
    local r=f.kayit[id]
    if r then return r end
    local k=H.kazi[kazi_no or 1]
    local s=M.sabit_mi(id)
    if s then E.immediate(s,k); return k end
    local d=f.dokum[id]
    if d then M.yuva_yukle(k,M.yuva_ofset(d)); return k end

    E.immediate(0,k); return k
  end

  function M.yuva_ofset(o) return f.yuva_taban+o end

  function M.yuva_yukle(r,ofset)
    if ofset//8<4096 then u32(0xf9400000|((ofset//8)<<10)|(29<<5)|r)
    else E.immediate(ofset,H.kazi[3]); u32(0xf8606800|(H.kazi[3]<<16)|(29<<5)|r) end
  end
  function M.yuva_sakla(r,ofset)
    if ofset//8<4096 then u32(0xf9000000|((ofset//8)<<10)|(29<<5)|r)
    else E.immediate(ofset,H.kazi[3]); u32(0xf8206800|(H.kazi[3]<<16)|(29<<5)|r) end
  end

  function M.hedef(id)
    local r=f.kayit[id]
    if r then return r end
    return H.kazi[1]
  end
  function M.hedef_bitir(id,r)
    local d=f.dokum[id]
    if d then M.yuva_sakla(r,M.yuva_ofset(d)) end
  end

  function M.tasi(d,s) if d~=s then u32(0xaa0003e0|(s<<16)|d) end end

  function M.anlik12(v) if v>=0 and v<4096 then return v end end

  function M.ikili_uret(t,d)
    local op=t.op
    local sa=M.sabit_mi(t.b)
    if op=='topla' or op=='cikar' then
      if sa then
        local v=(op=='cikar') and -sa or sa
        if v>=0 and v<4096 then u32(0x91000000|(v<<10)|(M.oku(t.a,1)<<5)|d); return
        elseif v<0 and v>-4096 then u32(0xd1000000|((-v)<<10)|(M.oku(t.a,1)<<5)|d); return
        elseif v>=4096 and v<16777216 and v%4096==0 then
          u32(0x91400000|((v>>12)<<10)|(M.oku(t.a,1)<<5)|d); return
        end
      end
    elseif op=='sola' or op=='saga' then
      if sa and sa>=0 and sa<64 then
        local rn=M.oku(t.a,1)
        if op=='sola' then u32(0xd3400000|(((64-sa)%64)<<16)|((63-sa)<<10)|(rn<<5)|d)
        elseif t.isaretsiz then u32(0xd340fc00|(sa<<16)|(rn<<5)|d)
        else u32(0x9340fc00|(sa<<16)|(rn<<5)|d) end
        return
      end
    elseif op=='carp' then
      if sa and sa>0 and (sa&(sa-1))==0 then
        local k=0; while (1<<k)~=sa do k=k+1 end
        local rn=M.oku(t.a,1)
        u32(0xd3400000|(((64-k)%64)<<16)|((63-k)<<10)|(rn<<5)|d); return
      elseif sa and sa>2 and ((sa-1)&(sa-2))==0 then
        local k=0; while (1<<k)~=(sa-1) do k=k+1 end
        local rn=M.oku(t.a,1)
        u32(0x8b000000|(rn<<16)|(k<<10)|(rn<<5)|d); return
      end
    elseif A.mantik_anlik[op] then
      if sa then
        local e=E.mantik_anlik(sa)
        if e then u32(A.mantik_anlik[op]|(e<<10)|(M.oku(t.a,1)<<5)|d); return end
      end
    end
    local rn=M.oku(t.a,1)
    local rm=M.oku(t.b,2)
    if op=='saga' and not t.isaretsiz then
      u32(0x9ac02800|(rm<<16)|(rn<<5)|d)
    else
      u32(A.ikili[op]|(rm<<16)|(rn<<5)|d)
    end
  end

  function M.kiyas_uret(t)
    local sa=M.sabit_mi(t.b)
    local rn=M.oku(t.a,1)
    if sa and sa>=0 and sa<4096 then u32(0xf100001f|(sa<<10)|(rn<<5))
    elseif sa and sa<0 and sa>-4096 then u32(0xb100001f|((-sa)<<10)|(rn<<5))
    else u32(0xeb00001f|(M.oku(t.b,2)<<16)|(rn<<5)) end
    local c=(t.isaretsiz and A.kosul_u or A.kosul)[t.iliski]
    return c
  end

  function M.genislet_uret(t,d)
    local rn=M.oku(t.a,1)
    if t.bit==64 then M.tasi(d,rn); return end
    u32((t.isaretli and 0x93400000 or 0xd3400000)|((t.bit-1)<<10)|(rn<<5)|d)
  end

  function M.adres_coz(aid)
    local t=f.d[aid]
    if t.op=='topla' and not f.kayit[aid] and not f.dokum[aid] then

    end
    return nil
  end

  function M.adres_kur(t,kazi_no)
    local genislik=t.bit//8
    local taban=t.a
    local ofset=t.ofset or 0
    local indeks=t.c
    local tt=f.d[taban]

    if tt.op=='yuva_adres' and not indeks and not f.kayit[taban] then
      local o=M.yuva_ofset(tt.ofset)+ofset
      if o>=0 and o%genislik==0 and o//genislik<4096 then return 29,o//genislik,nil end
    end
    local rn=M.oku(taban,kazi_no)
    if indeks then
      if ofset~=0 then

        local k=H.kazi[kazi_no]
        if ofset>0 and ofset<4096 then u32(0x91000000|(ofset<<10)|(rn<<5)|k)
        elseif ofset<0 and ofset>-4096 then u32(0xd1000000|((-ofset)<<10)|(rn<<5)|k)
        else
          local t2=H.kazi[kazi_no==1 and 2 or 1]
          E.immediate(ofset,t2); u32(0x8b000000|(t2<<16)|(rn<<5)|k)
        end
        rn=k
      end
      return rn,nil,M.oku(indeks,kazi_no==1 and 2 or 1)
    end
    if ofset>=0 and ofset%genislik==0 and ofset//genislik<4096 then
      return rn,ofset//genislik,nil
    end
    local k=H.kazi[kazi_no==1 and 2 or 1]
    E.immediate(ofset,k); u32(0x8b000000|(k<<16)|(rn<<5)|k)
    return k,0,nil
  end

  function M.yukle_uret(t,d)
    local rn,imm,ri=M.adres_kur(t,1)
    local bit=t.bit
    if ri then
      u32((t.isaretli and A.yukle_reg_s or A.yukle_reg)[bit]|(ri<<16)|(rn<<5)|d)
    else
      u32((t.isaretli and A.yukle_imm_s or A.yukle_imm)[bit]|(imm<<10)|(rn<<5)|d)
    end
  end

  function M.sakla_uret(t)
    local rn,imm,ri=M.adres_kur(t,1)
    local rv=M.oku(t.b,3)
    if ri then u32(A.sakla_reg[t.bit]|(ri<<16)|(rn<<5)|rv)
    else u32(A.sakla_imm[t.bit]|(imm<<10)|(rn<<5)|rv) end
  end

  function M.paralel(cift)

    local kalan={}
    for _,c in ipairs(cift) do
      if c[2]~=c[1] or c[3] then kalan[#kalan+1]=c end
    end
    local guvenli=true
    while #kalan>0 and guvenli do
      guvenli=false
      for i,c in ipairs(kalan) do
        local engel=false
        for j,o in ipairs(kalan) do
          if i~=j and o[2]==c[1] then engel=true end
        end
        if not engel then
          if c[3]~=nil then E.immediate(c[3],c[1])
          elseif c[4] then M.yuva_yukle(c[1],c[4])
          else M.tasi(c[1],c[2]) end
          table.remove(kalan,i); guvenli=true; break
        end
      end
      if not guvenli and #kalan>0 then

        local c=kalan[1]
        local k=H.kazi[3]
        M.tasi(k,c[2])
        for _,o in ipairs(kalan) do if o[2]==c[2] then o[2]=k end end
        guvenli=true
      end
    end
  end

  function M.phi_tasi(b,s)
    local cift={}
    for _,id in ipairs(s.k) do
      local t=f.d[id]
      if t.op~='phi' then break end
      local kaynak
      for _,g in ipairs(t.girdi) do if g[1]==b then kaynak=g[2] end end
      if kaynak then
        local hd=f.kayit[id]
        local sv=M.sabit_mi(kaynak)
        if hd then
          if sv then cift[#cift+1]={hd,nil,sv}
          elseif f.kayit[kaynak] then cift[#cift+1]={hd,f.kayit[kaynak]}
          else cift[#cift+1]={hd,nil,nil,M.yuva_ofset(f.dokum[kaynak])} end
        elseif f.dokum[id] then
          local r=M.oku(kaynak,1)
          M.yuva_sakla(r,M.yuva_ofset(f.dokum[id]))
        end
      end
    end
    M.paralel(cift)
  end

  local abi_reg={0,1,2,3,4,5,6,7}

  function M.cagri_uret(t,d)
    local n=#t.args
    local tasma=math.max(0,n-8)
    local golge=(tasma*8+15)//16*16
    if golge>0 then u32(0xd10003ff|(golge<<10)) end

    for i=9,n do
      local r=M.oku(t.args[i],1)
      u32(0xf90003e0|(((i-9)*8//8)<<10)|r)
    end

    local hedef_r
    if t.dolayli then hedef_r=H.kazi[2]; M.tasi(hedef_r,M.oku(t.dolayli,3)) end
    local cift={}
    for i=1,math.min(8,n) do
      local a=t.args[i]
      local sv=M.sabit_mi(a)
      if sv then cift[#cift+1]={abi_reg[i],nil,sv}
      elseif f.kayit[a] then cift[#cift+1]={abi_reg[i],f.kayit[a]}
      else cift[#cift+1]={abi_reg[i],nil,nil,M.yuva_ofset(f.dokum[a])} end
    end
    M.paralel(cift)
    if t.dis then
      local y=E.builtins[t.dis]
      if t.abi=='float64' then
        for i=1,math.min(8,n) do u32(0x9e670000|((i-1)<<5)|(i-1)) end
      end
      E.external(y[1])
      if t.abi=='float64' then u32(0x9e660000|(0<<5)|0)
      elseif t.abi=='int' then u32(0x93407c00)
      elseif t.abi=='void' then u32(0xd2800000) end
      E.normalize(y[4],0)
    elseif t.dolayli then
      u32(0xd63f0000|(hedef_r<<5))
    else
      E.jump(E.entries[t.ad],false,true)
    end
    if golge>0 then u32(0x910003ff|(golge<<10)) end
    M.tasi(d,0)
  end

  function M.ic_uret(t,d)
    local dugum=t.dugum
    local yeni={'call',dugum[2],{},type=dugum.type,yb_hazir=true}
    for k,v in pairs(dugum) do if type(k)=='string' then yeni[k]=v end end

    for i,a in ipairs(t.args) do
      local sv=M.sabit_mi(a)
      if sv then yeni[3][i]={'num',sv,type=dugum[3][i].type}
      else yeni[3][i]={'ybreg',i-1,type=dugum[3][i].type} end
    end
    local cift={}
    for i,a in ipairs(t.args) do
      local sv=M.sabit_mi(a)
      if sv then cift[#cift+1]={i-1,nil,sv}
      elseif f.kayit[a] then cift[#cift+1]={i-1,f.kayit[a]}
      else cift[#cift+1]={i-1,nil,nil,M.yuva_ofset(f.dokum[a])} end
    end
    M.paralel(cift)
    E.generate(yeni)
    M.tasi(d,0)
  end

  function M.atomik_uret(t,d)
    local rn=M.oku(t.a,1)
    local alt=t.alt
    if alt=='atomik_oku' then u32(0xc8dffc00|(rn<<5)|d); return end
    local rv=M.oku(t.b,2)
    if alt=='atomik_yaz' then u32(0xc89ffc00|(rn<<5)|rv); M.tasi(d,rv); return end
    local t1,t2,st=12,13,14
    if alt=='atomik_ekle' then
      local l=E.label(); E.mark(l)
      u32(0xc85ffc00|(rn<<5)|t1)
      u32(0x8b000000|(rv<<16)|(t1<<5)|t2)
      u32(0xc800fc00|(st<<16)|(rn<<5)|t2)
      E.cbnz(st,l)
      M.tasi(d,t1)
    else
      local rc=M.oku(t.c,3)
      local l,son=E.label(),E.label()
      E.mark(l)
      u32(0xc85ffc00|(rn<<5)|t1)
      u32(0xeb00001f|(rv<<16)|(t1<<5))
      E.kosul_dal(son,1)
      u32(0xc800fc00|(st<<16)|(rn<<5)|rc)
      E.cbnz(st,l)
      E.mark(son)
      u32(0xd5033f5f)
      M.tasi(d,t1)
    end
  end

  function M.float_uret(t,d)
    local ft=t.ft or 'f64'
    local ra=M.oku(t.a,1)
    u32((ft=='f32' and 0x1e270000 or 0x9e670000)|(ra<<5)|0)
    if t.op=='fkarekok' then
      u32(ft=='f32' and 0x1e21c000 or 0x1e61c000)
    elseif t.op=='fters' then
      u32(ft=='f32' and 0x1e214000 or 0x1e614000)
    else
      local rb=M.oku(t.b,2)
      u32((ft=='f32' and 0x1e270000 or 0x9e670000)|(rb<<5)|1)
      if t.op=='fkiyas' then
        u32(ft=='f32' and 0x1e212000 or 0x1e612000)
        local c=({['==']=0,['!=']=1,['<']=4,['<=']=9,['>']=12,['>=']=10})[t.iliski]
        u32(0x9a9f07e0|((c~1)<<12)|d); return
      end
      local ar=({ftopla=0x28,fcikar=0x38,fcarp=0x08,fbol=0x18})[t.op]
      u32((ft=='f32' and 0x1e210000 or 0x1e610000)|(ar<<8))
    end
    u32((ft=='f32' and 0x1e260000 or 0x9e660000)|(0<<5)|d)
  end

  function M.donusum_uret(t,d)
    local ra=M.oku(t.a,1)
    if t.op=='f2f' then
      u32((t.kf=='f32' and 0x1e270000 or 0x9e670000)|(ra<<5)|0)
      u32(t.hf=='f32' and 0x1e624000 or 0x1e22c000)
      u32((t.hf=='f32' and 0x1e260000 or 0x9e660000)|(0<<5)|d)
    elseif t.op=='i2f' then
      u32((t.hf=='f32' and 0x9e220000 or 0x9e620000)|(t.isaretsiz and 0x10000 or 0)|(ra<<5)|0)
      u32((t.hf=='f32' and 0x1e260000 or 0x9e660000)|(0<<5)|d)
    else
      u32((t.kf=='f32' and 0x1e270000 or 0x9e670000)|(ra<<5)|0)
      u32((t.kf=='f32' and 0x9e380000 or 0x9e780000)|(t.isaretsiz and 0x10000 or 0)|(0<<5)|d)
    end
  end

  function M.bol_uret(t,d)
    local rn=M.oku(t.a,1)
    local sv=M.sabit_mi(t.b)
    local rm
    if sv then
      if sv==0 then u32(0xd4200000); return end
      rm=H.kazi[2]; E.immediate(sv,rm)
    else
      rm=M.oku(t.b,2)
      local ok=E.label()
      u32(0xf100001f|(rm<<5))
      E.kosul_dal(ok,1)
      u32(0xd4200000)
      E.mark(ok)
    end
    local q=(t.op=='kalan') and H.kazi[3] or d
    u32((t.isaretsiz and 0x9ac00800 or 0x9ac00c00)|(rm<<16)|(rn<<5)|q)
    if t.op=='kalan' then u32(0x9b008000|(rm<<16)|(rn<<10)|(q<<5)|d) end
  end

  function M.komut(t,b)
    local op=t.op
    if op=='sabit' then

      if f.kayit[t.id] then E.immediate(t.s,f.kayit[t.id]) end
      return
    end
    if op=='phi' or op=='param' or t.kaynasik then return end
    local d=M.hedef(t.id)
    if op=='topla' or op=='cikar' or op=='carp' or op=='ve' or op=='veya'
       or op=='xor' or op=='sola' or op=='saga' then M.ikili_uret(t,d)
    elseif op=='bol' or op=='kalan' then M.bol_uret(t,d)
    elseif op=='kiyas' then
      local c=M.kiyas_uret(t)
      u32(0x9a9f07e0|((c~1)<<12)|d)
    elseif op=='sec' then
      local c
      if t.bayrak_yeniden then

        local k=f.d[t.kaynasik_kiyas]; c=(k.isaretsiz and A.kosul_u or A.kosul)[k.iliski]
      elseif t.kaynasik_kiyas then c=M.kiyas_uret(f.d[t.kaynasik_kiyas])
      else u32(0xf100001f|(M.oku(t.a,1)<<5)); c=1 end
      u32(0x9a800000|(M.oku(t.c,2)<<16)|(c<<12)|(M.oku(t.b,3)<<5)|d)
    elseif op=='genislet' then M.genislet_uret(t,d)
    elseif op=='tersle' then u32(0xcb0003e0|(M.oku(t.a,1)<<16)|d)
    elseif op=='bitnot' then u32(0xaa2003e0|(M.oku(t.a,1)<<16)|d)
    elseif op=='yukle' then M.yukle_uret(t,d)
    elseif op=='sakla' then M.sakla_uret(t); return
    elseif op=='yuva_adres' then
      local o=M.yuva_ofset(t.ofset)
      if o<4096 then u32(0x910003a0|(o<<10)|d)
      else u32(0x914003a0|((o//4096)<<10)|d)
        if o%4096~=0 then u32(0x91000000|((o%4096)<<10)|(d<<5)|d) end end
    elseif op=='genel_adres' then
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),t.g}
      u32(0x90000000|d); u32(0x91000000|(d<<5)|d)
    elseif op=='islev_adres' then
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),{text_label=E.entries[t.ad]}}
      u32(0x90000000|d); u32(0x91000000|(d<<5)|d)
    elseif op=='metin' then
      local l=E.label(); E.data[#E.data+1]={l,t.s..'\0'}
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),{text_label=l}}
      u32(0x90000000|d); u32(0x91000000|(d<<5)|d)
    elseif op=='cagri' then M.cagri_uret(t,d)
    elseif op=='ic' then M.ic_uret(t,d)
    elseif op=='atomik' then M.atomik_uret(t,d)
    elseif op=='bkopya' or op=='bsifir' then M.blok_bellek_uret(t,d)
    elseif op=='bit_say' then
      local rn=M.oku(t.a,1)
      u32(0x9e670000|(rn<<5)|0); u32(0x0e205800); u32(0x0e31b800)
      u32(0x9e660000|(0<<5)|d)
    elseif op=='ilk_bit' then
      local rn=M.oku(t.a,1); u32(0xdac00000|(rn<<5)|d); u32(0xdac01000|(d<<5)|d)
    elseif op=='son_bit' then
      local rn=M.oku(t.a,1); local k=H.kazi[2]
      u32(0xdac01000|(rn<<5)|d); E.immediate(63,k)
      u32(0xcb000000|(d<<16)|(k<<5)|d)
    elseif op=='bayt_ters' then u32(0xdac00c00|(M.oku(t.a,1)<<5)|d)
    elseif op=='bit_ters' then u32(0xdac00000|(M.oku(t.a,1)<<5)|d)
    elseif op=='carp_yuksek' then
      u32(0x9bc07c00|(M.oku(t.b,2)<<16)|(M.oku(t.a,1)<<5)|d)
    elseif op=='carp_yuksek_s' then
      u32(0x9b407c00|(M.oku(t.b,2)<<16)|(M.oku(t.a,1)<<5)|d)
    elseif op=='ongetir' then u32(0xf9800000|(M.oku(t.a,1)<<5)); return
    elseif op=='bekle' then u32(0xd503203f); return
    elseif op=='ftopla' or op=='fcikar' or op=='fcarp' or op=='fbol'
        or op=='fkiyas' or op=='fkarekok' or op=='fters' then M.float_uret(t,d)
    elseif op=='f2f' or op=='i2f' or op=='f2i' then M.donusum_uret(t,d)
    elseif op=='dal' or op=='kosul' or op=='don' or op=='tuzak' then return
    else E.hata('YB: uretilemeyen komut '..op) end
    M.hedef_bitir(t.id,d)
  end

  function M.blok_bellek_uret(t,d)
    local rd=M.oku(t.a,1)
    local rs=t.b and M.oku(t.b,2) or nil
    local n=t.boy
    local parca={}
    local o=0
    while n-o>=16 do parca[#parca+1]={o,16}; o=o+16 end
    while n-o>=8 do parca[#parca+1]={o,8}; o=o+8 end
    if t.op=='bsifir' then
      if n>=16 then u32(0x6e201c00) end
      for _,c in ipairs(parca) do
        if c[2]==16 then u32(0x3d800000|((c[1]//16)<<10)|(rd<<5)|0)
        else u32(0xf9000000|((c[1]//8)<<10)|(rd<<5)|31) end
      end
    elseif t.tasi then
      local v,x=0,0
      local kayitlar={}
      for i,c in ipairs(parca) do
        if c[2]==16 then
          u32(0x3dc00000|((c[1]//16)<<10)|(rs<<5)|v); kayitlar[i]={'v',v}; v=v+1
        else
          x=x+1; local r=H.kazi[x==1 and 3 or 2]
          u32(0xf9400000|((c[1]//8)<<10)|(rs<<5)|r); kayitlar[i]={'x',r}
        end
      end
      for i,c in ipairs(parca) do
        local k=kayitlar[i]
        if k[1]=='v' then u32(0x3d800000|((c[1]//16)<<10)|(rd<<5)|k[2])
        else u32(0xf9000000|((c[1]//8)<<10)|(rd<<5)|k[2]) end
      end
    else
      for _,c in ipairs(parca) do
        if c[2]==16 then
          u32(0x3dc00000|((c[1]//16)<<10)|(rs<<5)|0)
          u32(0x3d800000|((c[1]//16)<<10)|(rd<<5)|0)
        else
          local r=H.kazi[3]
          u32(0xf9400000|((c[1]//8)<<10)|(rs<<5)|r)
          u32(0xf9000000|((c[1]//8)<<10)|(rd<<5)|r)
        end
      end
    end
    M.tasi(d,rd)
  end

  function M.blok_uret(b,sonraki)
    Y.hiza_iste(f,E,b,H)
    E.mark(b.etiket)
    local n=#b.k
    for i=1,n do
      local t=f.d[b.k[i]]
      if not Y.terminal[t.op] then M.komut(t,b) end
    end
    local son=f.d[b.k[n]]
    if not son or not Y.terminal[son.op] then return end
    if son.op=='dal' then
      M.phi_tasi(b,son.hedef)
      if son.hedef~=sonraki then E.jump(son.hedef.etiket) end
    elseif son.op=='kosul' then
      local c
      if son.kaynasik_kiyas then c=M.kiyas_uret(f.d[son.kaynasik_kiyas])
      else u32(0xf100001f|(M.oku(son.a,1)<<5)); c=1 end
      if sonraki==son.yanlis then
        E.kosul_dal(son.dogru.etiket,c)
      elseif sonraki==son.dogru then
        E.kosul_dal(son.yanlis.etiket,A.ters[c])
      else
        E.kosul_dal(son.dogru.etiket,c); E.jump(son.yanlis.etiket)
      end
    elseif son.op=='don' then
      local sv=M.sabit_mi(son.a)
      if sv then E.immediate(sv,0) else M.tasi(0,M.oku(son.a,1)) end
      if sonraki~=nil or true then E.jump(f.bitis) end
    elseif son.op=='tuzak' then u32(0xd4200000) end
  end

  function M.giris_cikis(frame,kalici)
    return function(bas)
      if bas then
        u32(0xa9bf7bfd)

        if frame>65536 then
          u32(0x910003f0)
          E.immediate(frame//4096,17)
          local p=E.label(); E.mark(p)
          u32(0xd1400610); u32(0x3940021f)
          u32(0xf1000631); E.kosul_dal(p,1)
          if frame%4096~=0 then
            u32(0xd1000210|((frame%4096)<<10)); u32(0x3940021f)
          end
          u32(0xd14003ff|((frame//4096)<<10))
          if frame%4096~=0 then u32(0xd10003ff|((frame%4096)<<10)) end
        elseif frame>0 then
          if frame>=4096 then u32(0xd14003ff|((frame//4096)<<10)) end
          if frame%4096~=0 then u32(0xd10003ff|((frame%4096)<<10)) end
        end
        u32(0x910003fd)
        local i=1
        while i<=#kalici do
          local r=kalici[i]
          if kalici[i+1] then
            u32(0xa9000000|(((i-1)*8//8)<<15)|(kalici[i+1]<<10)|(29<<5)|r); i=i+2
          else
            u32(0xf9000000|(((i-1)*8//8)<<10)|(29<<5)|r); i=i+1
          end
        end
      else
        local i=1
        while i<=#kalici do
          local r=kalici[i]
          if kalici[i+1] then
            u32(0xa9400000|(((i-1)*8//8)<<15)|(kalici[i+1]<<10)|(29<<5)|r); i=i+2
          else
            u32(0xf9400000|(((i-1)*8//8)<<10)|(29<<5)|r); i=i+1
          end
        end

        if frame>=4096 then
          u32(0x914003ff|((frame//4096)<<10))
          if frame%4096~=0 then u32(0x910003ff|((frame%4096)<<10)) end
        elseif frame>0 then
          u32(0x910003ff|(frame<<10))
        end
        u32(0xa8c17bfd)
        u32(0xd65f03c0)
      end
    end
  end

  function M.uret()
    local kalici=f.kalici_kayitlar
    f.yuva_taban=(#kalici*8+15)//16*16
    local frame=(f.yuva_taban+f.yuva+15)//16*16
    if frame>16773120 then E.hata('YB: cerceve 16 MiB sinirini asti') end
    f.frame=frame
    for _,b in ipairs(f.duz) do b.etiket=E.label() end
    f.bitis=E.label()
    local kap=M.giris_cikis(frame,kalici)
    E.mark(f.giris_etiketi)
    kap(true)

    local cift={}
    for _,b in ipairs(f.duz) do
      for _,id in ipairs(b.k) do
        local t=f.d[id]
        if t.op=='param' then
          local hd=f.kayit[id]
          if t.sira<=8 then
            if hd then cift[#cift+1]={hd,t.sira-1}
            elseif f.dokum[id] then M.yuva_sakla(t.sira-1,M.yuva_ofset(f.dokum[id])) end
          else
            local o=frame+16+(t.sira-9)*8
            local r=hd or H.kazi[1]
            if o//8<4096 then u32(0xf9400000|((o//8)<<10)|(29<<5)|r)
            else E.immediate(o,H.kazi[3]); u32(0xf8606800|(H.kazi[3]<<16)|(29<<5)|r) end
            if not hd and f.dokum[id] then M.yuva_sakla(r,M.yuva_ofset(f.dokum[id])) end
          end
        end
      end
    end
    M.paralel(cift)
    for i,b in ipairs(f.duz) do M.blok_uret(b,f.duz[i+1]) end
    E.mark(f.bitis)
    kap(false)
  end

  return M
end

function Y.kenar_bol(f)
  local liste={}
  for _,b in ipairs(f.bloklar) do liste[#liste+1]=b end
  for _,b in ipairs(liste) do
    local t=f.d[b.son]
    if t and t.op=='kosul' then
      for _,alan in ipairs({'dogru','yanlis'}) do
        local s=t[alan]
        if #s.oncul>1 then
          local n=Y.blok(f); n.muhurlu=true
          Y.ek(f,n,{op='dal',hedef=s}); n.bitti=true; n.son=n.k[1]
          n.oncul={b}; n.ardil={s}
          for i,x in ipairs(b.ardil) do if x==s then b.ardil[i]=n end end
          for i,x in ipairs(s.oncul) do if x==b then s.oncul[i]=n end end
          for _,id in ipairs(s.k) do
            local p=f.d[id]
            if p.op~='phi' then break end
            for _,g in ipairs(p.girdi) do if g[1]==b then g[1]=n end end
          end
          t[alan]=n
        end
      end
    end
  end
end

function Y.dongu_derinligi(f)
  local derin={}
  for _,b in ipairs(f.duz) do derin[b.no]=0 end
  local bas,dongular={},Y.dongular(f)
  for _,dg in ipairs(dongular) do
    bas[dg.bas.no]=true
    for _,b in ipairs(dg.sira) do derin[b.no]=derin[b.no]+1 end
  end

  local ic={}
  for _,dg in ipairs(dongular) do
    local ickte=false
    for _,b in ipairs(dg.sira) do
      if bas[b.no] and b~=dg.bas then ickte=true end
    end
    if not ickte then ic[dg.bas.no]=true end
  end
  return derin,bas,ic
end

function Y.hiza_iste(f,E,b,H)
  if not H.x64 then return end
  if not (f.dongu_ic and f.dongu_ic[b.no]) then return end
  local n=tonumber(os.getenv('YB_HIZA_N') or '') or 16
  local ust=tonumber(os.getenv('YB_HIZA_UST') or '') or 8
  if n>1 and E.hiza then E.hiza(n,ust) end
end

function Y.yerlesim(f)
  if #f.duz<4 then return end
  local derin,dongu_bas,dongu_ic=Y.dongu_derinligi(f)
  local soguk={}
  for _,b in ipairs(f.duz) do
    local t=b.son and f.d[b.son]
    if t and t.op=='tuzak' then soguk[b.no]=true end
  end

  local function sicaklik(b,sc)
    if soguk[sc.no] then return 0 end
    if derin[sc.no]<derin[b.no] then return 1 end
    if Y.baskin_mi(f,sc,b) then return 3 end
    return 2
  end
  Y.sirala(f,sicaklik)
  f.dongu_derin=derin
  f.dongu_bas=dongu_bas
  f.dongu_ic=dongu_ic
end

function Y.cerceve_sec(f,H)
  f.rsp_cerceve=false
  if not H.x64 then return H end
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      if f.d[id].op=='ic' then return H end
    end
  end
  f.rsp_cerceve=true
  local H2={}
  for k,v in pairs(H) do H2[k]=v end
  H2.kalici={}
  for _,r in ipairs(H.kalici) do H2.kalici[#H2.kalici+1]=r end
  H2.kalici[#H2.kalici+1]=5
  H2.kalici_kume={}
  for _,r in ipairs(H2.kalici) do H2.kalici_kume[r]=true end
  return H2
end

function Y.derle(fn,E,H)
  local f=fn.ir
  Y.phi_temizle(f)
  Y.kopyalari_coz(f)
  Y.olu_ele(f)
  if (E.opt or 2)>0 then
    Y.sirala(f)
    Y.baskinlik(f)
    Y.bolme_indir(f); Y.kopyalari_coz(f)
    for tur=1,4 do
      Y.konumla(f)
      local d1=Y.katla(f); Y.kopyalari_coz(f)
      local d2=Y.gvn(f);   Y.kopyalari_coz(f)
      local d3=Y.genislet_ele(f); Y.kopyalari_coz(f)
      local d4=Y.yeniden_dagit(f); Y.kopyalari_coz(f)
      local d5=Y.yuk_ele(f); Y.kopyalari_coz(f)
      local d6=Y.phi_temizle(f); Y.kopyalari_coz(f)
      Y.olu_ele(f)
      if not (d1 or d2 or d3 or d4 or d5 or d6) then break end
    end
    if Y.kosul_donustur(f) then
      Y.kopyalari_coz(f); Y.olu_ele(f)
      Y.sirala(f); Y.baskinlik(f)
      for tur=1,2 do
        Y.konumla(f)
        local a1=Y.katla(f); Y.kopyalari_coz(f)
        local a2=Y.gvn(f); Y.kopyalari_coz(f)
        Y.olu_ele(f)
        if not (a1 or a2) then break end
      end
    end
    Y.bellek_indir(f,H)
    Y.adres_katla(f)
    Y.olu_ele(f)
    Y.licm(f)
    Y.olu_ele(f)

    Y.konumla(f)
    if Y.gvn(f) then Y.kopyalari_coz(f); Y.olu_ele(f) end
  end
  H=Y.cerceve_sec(f,H)
  Y.kenar_bol(f)
  Y.sirala(f)
  if (E.opt or 2)>0 then Y.baskinlik(f); Y.yerlesim(f); Y.baskinlik(f) end
  if (E.opt or 2)>0 then Y.kiyas_cogalt(f,H) end
  Y.kullanim(f)
  Y.kaynastir(f,H)
  Y.yuk_kaynastir(f,H)
  Y.konumla(f)
  Y.canlilik(f)
  Y.araliklar(f,H)

  for _,b in ipairs(f.duz) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='ic' then
        t.yuvalar={}
        for i=1,#t.args do
          f.yuva=(f.yuva+7)//8*8
          t.yuvalar[i]=f.yuva; f.yuva=f.yuva+8
        end
      end
    end
  end
  if (E.opt or 2)>0 then Y.sabit_kayitlari(f) end
  Y.kullanim(f)
  Y.tahsis(f,H)
  local M=(H.x64 and Y.X64 or Y.ARM).yeni(f,E,H)
  M.uret()
  return f
end

function Y.arm_hedef()
  local H={ucucu={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14},
           kalici={19,20,21,22,23,24,25,26,27,28},
           abi={0,1,2,3,4,5,6,7},
           kazi={15,16,17},kalici_kume={},
           bozan_kume={atomik={12,13,14}},bozan_kullanim={atomik=1},
           blok_bellek=true}
  for _,r in ipairs(H.kalici) do H.kalici_kume[r]=true end
  return H
end

function Y.baskinlik(f)
  local d=f.duz
  local idom={}
  idom[d[1].no]=d[1]
  local function kesis(a,b)
    while a~=b do
      while a.sira>b.sira do a=idom[a.no] end
      while b.sira>a.sira do b=idom[b.no] end
    end
    return a
  end
  local degisti=true
  while degisti do
    degisti=false
    for i=2,#d do
      local b=d[i]
      local yeni=nil
      for _,o in ipairs(b.oncul) do
        if idom[o.no] then
          yeni=yeni and kesis(yeni,o) or o
        end
      end
      if yeni and idom[b.no]~=yeni then idom[b.no]=yeni; degisti=true end
    end
  end
  f.idom=idom

  local derinlik={}
  derinlik[d[1].no]=0
  for i=2,#d do
    local b=d[i]; local k=0; local x=b
    while x and x~=d[1] do x=idom[x.no]; k=k+1; if k>#d then break end end
    derinlik[b.no]=k
  end
  f.dom_derinlik=derinlik
end

function Y.baskin_mi(f,a,b)
  if a==b then return true end
  local x=b
  local g=0
  while x and x~=f.duz[1] do
    x=f.idom[x.no]
    if x==a then return true end
    g=g+1; if g>#f.duz then return false end
  end
  return a==f.duz[1]
end

function Y.deger_baskin(f,tanim_id,kullanim_id)
  local a=f.d[tanim_id]; local b=f.d[kullanim_id]
  if a.blok==b.blok then return (a.konum or 0)<(b.konum or 0) end
  return Y.baskin_mi(f,a.blok,b.blok)
end

local function imza(t,f)
  local p={t.op}
  local function e(x) p[#p+1]=tostring(x) end
  e(t.a or '-'); e(t.b or '-'); e(t.c or '-')
  e(t.iliski or '-'); e(t.isaretsiz and 'u' or 's'); e(t.bit or '-')
  e(t.isaretli and 'i' or '-'); e(t.ad or t.dis or '-')
  e(t.g and t.g.name or '-'); e(t.ofset or '-'); e(t.sinif or '-')
  e(t.ft or '-'); e(t.kf or '-'); e(t.hf or '-'); e(t.s or '-'); e(t.sira or '-')
  return table.concat(p,'|')
end

function Y.mantiksal_mi(f,id,derin)
  local t=f.d[id]
  if not t or derin>6 then return false end
  if t.op=='kiyas' or t.op=='fkiyas' then return true end
  if t.op=='sabit' then return t.s==0 or t.s==1 end
  if t.op=='ve' then return Y.mantiksal_mi(f,t.a,derin+1) or Y.mantiksal_mi(f,t.b,derin+1) end
  if t.op=='veya' or t.op=='xor' or t.op=='sec' then
    local x,y=t.a,t.b
    if t.op=='sec' then x,y=t.b,t.c end
    return Y.mantiksal_mi(f,x,derin+1) and Y.mantiksal_mi(f,y,derin+1)
  end
  return false
end

function Y.katla(f)
  local degisti=false
  Y.kullanim(f)
  local function sb(id) local t=f.d[id]; if t and t.op=='sabit' then return t.s end end
  for _,b in ipairs(f.bloklar) do
    local anlik={}
    for i,id in ipairs(b.k) do anlik[i]=id end
    for _,id in ipairs(anlik) do
      local t=f.d[id]
      local op=t.op

      if (op=='topla' or op=='carp' or op=='ve' or op=='veya' or op=='xor')
         and t.a and t.b then
        local ta=f.d[t.a]
        if ta.op=='sabit' and f.d[t.b].op~='sabit' then t.a,t.b=t.b,t.a end
      end
      local x,y=t.a and sb(t.a),t.b and sb(t.b)
      local yeni
      if op=='topla' then
        if x and y then yeni=x+y
        elseif y==0 then yeni='kopya' end
        if x==0 and not y then t.a,t.b=t.b,t.a; yeni='kopya' end
      elseif op=='cikar' then
        if x and y then yeni=x-y elseif y==0 then yeni='kopya' end
      elseif op=='carp' then
        if x and y then yeni=x*y
        elseif y==1 then yeni='kopya'
        elseif y==0 then yeni=0
        elseif x==1 then t.a=t.b; yeni='kopya'
        elseif x==0 then yeni=0 end
      elseif op=='ve' then
        if x and y then yeni=x&y elseif y==0 then yeni=0 elseif y==-1 then yeni='kopya' end
      elseif op=='veya' then
        if x and y then yeni=x|y elseif y==0 then yeni='kopya' elseif y==-1 then yeni=-1 end
      elseif op=='xor' then
        if x and y then yeni=x~y elseif y==0 then yeni='kopya' end
      elseif op=='sola' then
        if x and y then yeni=x<<(y&63) elseif y==0 then yeni='kopya' end
      elseif op=='saga' then

        if x and y then
          local n=y&63
          if t.isaretsiz then yeni=x>>n
          elseif x<0 then yeni=~((~x)>>n)
          else yeni=x>>n end
        elseif y==0 then yeni='kopya' end
      elseif op=='tersle' then if x then yeni=-x end
      elseif op=='bitnot' then if x then yeni=~x end
      elseif op=='genislet' then
        if x then
          local m=(1<<t.bit)-1
          local v=x&m
          if t.isaretli and v>=(1<<(t.bit-1)) then v=v-(1<<t.bit) end
          yeni=v
        end
      elseif op=='kiyas' then
        if x and y and not t.isaretsiz then
          local r=({['==']=x==y,['!=']=x~=y,['<']=x<y,['<=']=x<=y,
                    ['>']=x>y,['>=']=x>=y})[t.iliski]
          yeni=r and 1 or 0
        end
      elseif op=='sec' then
        local c=t.a and sb(t.a)
        if c then t.a=(c~=0) and t.b or t.c; yeni='kopya' end
      end

      if yeni==nil and op=='kiyas' and t.iliski=='!=' and y==0 and not x
         and Y.mantiksal_mi(f,t.a,0) then yeni='kopya' end

      if yeni==nil and (op=='sola' or op=='carp') and t.a and t.b and y then
        local ic=f.d[t.a]
        local yc=ic.b and sb(ic.b)
        if yc and (ic.op=='sola' or ic.op=='carp') and f.u and f.u[t.a]==1 then
          local c1=(ic.op=='sola') and (1<<(yc&63)) or yc
          local c2=(op=='sola') and (1<<(y&63)) or y
          local carpim=c1*c2
          if c1~=0 and carpim//c1==c2 then
            t.op='carp'; t.a=ic.a; t.b=Y.sabit(f,carpim); degisti=true
          end
        end
      end
      if yeni=='kopya' then
        t.op='kopya'; degisti=true
      elseif yeni~=nil and math.type(yeni)=='integer' then
        t.op='kopya'; t.a=Y.sabit(f,yeni); t.b=nil; t.c=nil; degisti=true
      end
    end
  end
  return degisti
end

function Y.gvn(f)
  local tablo={}
  local degisti=false
  local sira={}
  local function gez(b)
    local yerel={}
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if Y.saf[t.op] and t.op~='sabit' and t.op~='phi' then
        local a=imza(t,f)
        local onceki=tablo[a]
        if onceki and f.d[onceki].op~='kopya' and Y.deger_baskin(f,onceki,id) then
          t.op='kopya'; t.a=onceki; t.b=nil; t.c=nil; degisti=true
        else
          tablo[a]=id; yerel[#yerel+1]=a
        end
      end
    end
    for _,c in ipairs(f.duz) do
      if f.idom[c.no]==b and c~=b then gez(c) end
    end
    for _,a in ipairs(yerel) do tablo[a]=nil end
  end
  gez(f.duz[1])
  return degisti
end

function Y.adres_katla(f)
  local u=Y.kullanim(f)
  local function sb(id) local t=f.d[id]; if t and t.op=='sabit' then return t.s end end
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='yukle' or t.op=='sakla' then
        local taban=t.a
        local ofset,indeks,olcek=0,nil,1
        local genislik=t.bit//8

        local devam=true
        local tur=0
        while devam and tur<8 do
          devam=false; tur=tur+1
          local tt=f.d[taban]

          local sabitli=tt.op=='topla' and (sb(tt.a) or sb(tt.b))
          if tt.op=='topla' and (u[taban]==1 or sabitli) then
            local sa,sb2=sb(tt.a),sb(tt.b)
            if sb2 then ofset=ofset+sb2; taban=tt.a; devam=true
            elseif sa then ofset=ofset+sa; taban=tt.b; devam=true
            elseif not indeks and u[taban]==1 then

              local ta,tb=f.d[tt.a],f.d[tt.b]
              if tb.op=='carp' and u[tt.b]==1 and sb(tb.b)==genislik and genislik>1 then
                indeks=tb.a; olcek=genislik; taban=tt.a; devam=true
              elseif ta.op=='carp' and u[tt.a]==1 and sb(ta.b)==genislik and genislik>1 then
                indeks=ta.a; olcek=genislik; taban=tt.b; devam=true
              elseif genislik==1 then
                indeks=tt.b; olcek=1; taban=tt.a; devam=true
              end
            end
          end
        end
        t.a=taban; t.ofset=ofset; t.c=indeks; t.olcek=olcek
      end
    end
  end
end

function Y.genislet_ele(f)
  local degisti=false
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='genislet' then
        local a=f.d[t.a]
        if a.op=='genislet' and a.bit==t.bit and a.isaretli==t.isaretli then
          t.op='kopya'; degisti=true
        elseif a.op=='yukle' and a.bit==t.bit and (a.isaretli==t.isaretli) then
          t.op='kopya'; degisti=true
        elseif a.op=='yukle' and a.bit<t.bit and not a.isaretli then
          t.op='kopya'; degisti=true
        elseif t.bit==64 then
          t.op='kopya'; degisti=true
        elseif a.op=='sabit' then
          local m=(1<<t.bit)-1; local v=a.s&m
          if t.isaretli and v>=(1<<(t.bit-1)) then v=v-(1<<t.bit) end
          if v==a.s then t.op='kopya'; degisti=true end
        end
      end
    end
  end
  return degisti
end

local function usuz_kucuk(a,b) return (a~math.mininteger)<(b~math.mininteger) end
local function usuz_bol(a,b)
  if b<0 then return usuz_kucuk(a,b) and 0 or 1,usuz_kucuk(a,b) and a or a-b end
  if a>=0 then return a//b,a%b end
  local q=((a>>1)//b)<<1
  local r=a-q*b
  if not usuz_kucuk(r,b) then q=q+1; r=r-b end
  return q,r
end

function Y.sihir_isaretli(d)
  local iki63=math.mininteger
  local ad=d<0 and -d or d
  local t=iki63+((d>>63)&1)
  local _,m=usuz_bol(t,ad)
  local anc=t-1-m
  local p=63
  local q1,r1=usuz_bol(iki63,anc)
  local q2,r2=usuz_bol(iki63,ad)
  local delta
  repeat
    p=p+1
    q1=q1*2; r1=r1*2
    if not usuz_kucuk(r1,anc) then q1=q1+1; r1=r1-anc end
    q2=q2*2; r2=r2*2
    if not usuz_kucuk(r2,ad) then q2=q2+1; r2=r2-ad end
    delta=ad-r2
  until not (usuz_kucuk(q1,delta) or (q1==delta and r1==0))
  local M=q2+1
  if d<0 then M=-M end
  return M,p-64
end

function Y.sihir_isaretsiz(d)
  local iki63=math.mininteger
  local hepsi=-1
  local _,m=usuz_bol(hepsi-d+1-1,d)

  local _,m2=usuz_bol(hepsi-d,d)
  local nc=hepsi-m2-d+d
  nc=hepsi-((function() local _,r=usuz_bol(hepsi-d,d); return r end)())
  local p=63
  local ekle=false
  local q1,r1=usuz_bol(iki63,nc)
  local q2,r2=usuz_bol(iki63-1,d)
  local delta
  repeat
    p=p+1
    if not usuz_kucuk(r1,nc-r1) then q1=q1*2+1; r1=r1*2-nc
    else q1=q1*2; r1=r1*2 end
    if not usuz_kucuk(r2+1,d-r2) then
      if not usuz_kucuk(q2,iki63-1) then ekle=true end
      q2=q2*2+1; r2=r2*2+1-d
    else
      if not usuz_kucuk(q2,iki63) then ekle=true end
      q2=q2*2; r2=r2*2+1
    end
    delta=d-1-r2
  until not (p<128 and (usuz_kucuk(q1,delta) or (q1==delta and r1==0)))
  return q2+1,p-64,ekle
end

function Y.bit_siniri(f,id,derin)
  local t=f.d[id]
  if not t or derin>10 then return nil end
  local function bs(x) return Y.bit_siniri(f,x,derin+1) end
  local function sabit(x) local c=f.d[x]; if c and c.op=='sabit' then return c.s end end
  local op=t.op
  if op=='sabit' then
    if t.s<0 then return nil end
    local n,v=0,t.s; while v>0 do n=n+1; v=v>>1 end; return n
  elseif op=='yukle' then
    if t.bit<64 and not t.isaretli then return t.bit end
  elseif op=='kiyas' or op=='fkiyas' then return 1
  elseif op=='kopya' then return bs(t.a)
  elseif op=='ve' then
    local x,y=bs(t.a),bs(t.b)
    if x and y then return math.min(x,y) end
    return x or y
  elseif op=='veya' or op=='xor' then
    local x,y=bs(t.a),bs(t.b)
    if x and y then return math.max(x,y) end
  elseif op=='saga' then
    local c=sabit(t.b)
    if c and c>0 and c<64 then
      local x=bs(t.a)
      if x then return math.max(0,x-c) end
      if t.isaretsiz then return 64-c end
    end
  elseif op=='sola' then
    local c=sabit(t.b); local x=bs(t.a)
    if c and c>=0 and x and x+c<=62 then return x+c end
  elseif op=='topla' then
    local x,y=bs(t.a),bs(t.b)
    if x and y and math.max(x,y)+1<=62 then return math.max(x,y)+1 end
  elseif op=='carp' then
    local x,y=bs(t.a),bs(t.b)
    if x and y and x+y<=62 then return x+y end
  elseif op=='sec' then
    local x,y=bs(t.b),bs(t.c)
    if x and y then return math.max(x,y) end
  elseif op=='genislet' then
    local x=bs(t.a)
    if x and x<t.bit then return x end
    if not t.isaretli then return x and math.min(x,t.bit) or t.bit end
  end
  return nil
end

function Y.bolme_indir(f)
  local degisti=false
  for _,b in ipairs(f.bloklar) do
    local anlik={}
    for i,id in ipairs(b.k) do anlik[i]=id end
    for _,id in ipairs(anlik) do
      local t=f.d[id]
      if (t.op=='bol' or t.op=='kalan') and t.b then
        local bt=f.d[t.b]
        if bt.op=='sabit' and bt.s~=0 then
          local d=bt.s
          local kalan=(t.op=='kalan')
          local x=t.a
          local yeni={}
          local function ekle(o)
            local nid=Y.ek(f,nil,o)
            f.d[nid].blok=b
            yeni[#yeni+1]=nid
            return nid
          end
          local q
          local us=nil
          if d>0 and (d&(d-1))==0 then us=0; while (1<<us)~=d do us=us+1 end end

          local isaretsiz=t.isaretsiz or (d>0 and Y.bit_siniri(f,x,0)~=nil and Y.bit_siniri(f,x,0)<=63)
          if isaretsiz and us and kalan and us>0 then
            q=ekle({op='ve',a=x,b=Y.sabit(f,d-1)}); kalan=false
          elseif d==1 then q=x
          elseif not t.isaretsiz and d==-1 then
            q=ekle({op='tersle',a=x})
          elseif isaretsiz and us then
            q=(us==0) and x or ekle({op='saga',a=x,b=Y.sabit(f,us),isaretsiz=true})
          elseif not t.isaretsiz and us then
            if us==0 then q=x else
              local s=ekle({op='saga',a=x,b=Y.sabit(f,63),isaretsiz=false})
              local m=ekle({op='saga',a=s,b=Y.sabit(f,64-us),isaretsiz=true})
              local a2=ekle({op='topla',a=x,b=m})
              q=ekle({op='saga',a=a2,b=Y.sabit(f,us),isaretsiz=false})
            end
          elseif isaretsiz then
            local M,sh,ekle_bayrak=Y.sihir_isaretsiz(d)
            local h=ekle({op='carp_yuksek',a=x,b=Y.sabit(f,M)})
            if ekle_bayrak then
              local c=ekle({op='cikar',a=x,b=h})
              local c1=ekle({op='saga',a=c,b=Y.sabit(f,1),isaretsiz=true})
              local c2=ekle({op='topla',a=c1,b=h})
              q=ekle({op='saga',a=c2,b=Y.sabit(f,sh-1),isaretsiz=true})
            else
              q=(sh==0) and h or ekle({op='saga',a=h,b=Y.sabit(f,sh),isaretsiz=true})
            end
          else
            local M,sh=Y.sihir_isaretli(d)
            local h=ekle({op='carp_yuksek_s',a=x,b=Y.sabit(f,M)})
            if d>0 and M<0 then h=ekle({op='topla',a=h,b=x})
            elseif d<0 and M>0 then h=ekle({op='cikar',a=h,b=x}) end
            if sh>0 then h=ekle({op='saga',a=h,b=Y.sabit(f,sh),isaretsiz=false}) end
            local u=ekle({op='saga',a=h,b=Y.sabit(f,63),isaretsiz=true})
            q=ekle({op='topla',a=h,b=u})
          end
          if kalan then
            local mm=ekle({op='carp',a=q,b=Y.sabit(f,d)})
            q=ekle({op='cikar',a=x,b=mm})
          end
          t.op='kopya'; t.a=q; t.b=nil; t.c=nil

          local konum
          for i,q2 in ipairs(b.k) do if q2==id then konum=i end end
          for i=#yeni,1,-1 do table.insert(b.k,konum,yeni[i]) end
          degisti=true
        end
      end
    end
  end
  return degisti
end

function Y.maliyet(f)
  local n=0
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op~='sabit' and t.op~='phi' and t.op~='kopya' then n=n+1 end
      if t.op=='cagri' or t.op=='ic' then n=n+6 end
    end
  end
  return n,#f.bloklar
end

local function kopyala(hedef,kaynak,arg)
  local dh,bh={},{}
  for _,b in ipairs(kaynak.bloklar) do
    local n=Y.blok(hedef)
    n.muhurlu=true
    bh[b]=n
  end
  local function d(id)
    if id==nil then return nil end
    return dh[id] or id
  end

  for _,b in ipairs(kaynak.bloklar) do
    local n=bh[b]
    for _,id in ipairs(b.k) do
      local t=kaynak.d[id]
      local y={}
      for k,v in pairs(t) do y[k]=v end
      y.id=nil; y.blok=n; y.konum=nil
      hedef.n=hedef.n+1
      y.id=hedef.n; hedef.d[hedef.n]=y
      dh[id]=hedef.n
      n.k[#n.k+1]=hedef.n
    end
  end

  for _,b in ipairs(kaynak.bloklar) do
    local n=bh[b]
    for _,id in ipairs(n.k) do
      local y=hedef.d[id]
      y.a=d(y.a); y.b=d(y.b); y.c=d(y.c)
      if y.args then
        local a2={}
        for i,x in ipairs(y.args) do a2[i]=d(x) end
        y.args=a2
      end
      if y.dolayli then y.dolayli=d(y.dolayli) end
      if y.girdi then
        local g2={}
        for i,g in ipairs(y.girdi) do g2[i]={bh[g[1]],d(g[2])} end
        y.girdi=g2
      end
      if y.hedef then y.hedef=bh[y.hedef] end
      if y.dogru then y.dogru=bh[y.dogru]; y.yanlis=bh[y.yanlis] end
      if y.ofset and (y.op=='yuva_adres') then y.ofset=y.ofset+hedef.yuva_kaydirma end
    end
  end

  for _,b in ipairs(kaynak.bloklar) do
    local n=bh[b]
    n.oncul={}; n.ardil={}
  end
  for _,b in ipairs(kaynak.bloklar) do
    local n=bh[b]
    local t=hedef.d[n.k[#n.k]]
    if t then
      if t.op=='dal' then Y.bagla(n,t.hedef)
      elseif t.op=='kosul' then Y.bagla(n,t.dogru); Y.bagla(n,t.yanlis) end
    end
    n.bitti=true; n.son=n.k[#n.k]
  end

  for _,b in ipairs(kaynak.bloklar) do
    for _,id in ipairs(bh[b].k) do
      local y=hedef.d[id]
      if y.op=='param' then y.op='kopya'; y.a=arg[y.sira] or Y.sabit(hedef,0) end
    end
  end
  return bh[kaynak.bloklar[1]],bh
end

function Y.inline(f,ir_tablo,siniri)
  local degisti=false
  local blok_listesi={}
  for _,b in ipairs(f.bloklar) do blok_listesi[#blok_listesi+1]=b end
  for _,b in ipairs(blok_listesi) do
    local i=1
    while i<=#b.k do
      local id=b.k[i]
      local t=f.d[id]
      if t.op=='cagri' and t.ad and ir_tablo[t.ad] and ir_tablo[t.ad]~=f
         and ir_tablo[t.ad].inline_uygun then
        local c=ir_tablo[t.ad]

        local sonra=Y.blok(f); sonra.muhurlu=true
        for j=i+1,#b.k do sonra.k[#sonra.k+1]=b.k[j]; f.d[b.k[j]].blok=sonra end
        for j=#b.k,i,-1 do b.k[j]=nil end
        sonra.ardil=b.ardil; sonra.bitti=b.bitti; sonra.son=b.son
        for _,x in ipairs(sonra.ardil) do
          for k,y in ipairs(x.oncul) do if y==b then x.oncul[k]=sonra end end
          for _,pid in ipairs(x.k) do
            local pt=f.d[pid]
            if pt.op~='phi' then break end
            for _,g in ipairs(pt.girdi) do if g[1]==b then g[1]=sonra end end
          end
        end
        b.ardil={}; b.bitti=false; b.son=nil
        f.yuva_kaydirma=f.yuva
        f.yuva=f.yuva+c.yuva
        local giris,bh=kopyala(f,c,t.args)
        Y.ek(f,b,{op='dal',hedef=giris}); b.bitti=true; b.son=b.k[#b.k]
        Y.bagla(b,giris)

        local donusler={}
        for _,eski in ipairs(c.bloklar) do
          local n=bh[eski]
          local son=f.d[n.son]
          if son and son.op=='don' then
            donusler[#donusler+1]={n,son.a}
            son.op='dal'; son.hedef=sonra; son.a=nil
            n.ardil={}
            Y.bagla(n,sonra)
          end
        end

        local sonuc
        if #donusler==1 then sonuc=donusler[1][2]
        else
          local phi=Y.ek_bas(f,sonra,{op='phi',girdi={}})
          for _,r in ipairs(donusler) do
            f.d[phi].girdi[#f.d[phi].girdi+1]={r[1],r[2]}
          end
          sonuc=phi
        end

        t.op='kopya'; t.a=sonuc; t.args=nil; t.ad=nil
        degisti=true
        b=sonra; i=1
      else
        i=i+1
      end
    end
  end
  return degisti
end

function Y.yeniden_dagit(f)
  local u=Y.kullanim(f)
  local degisti=false
  local function sb(id) local t=f.d[id]; if t and t.op=='sabit' then return t.s end end
  for _,b in ipairs(f.bloklar) do
    local anlik={}
    for i,id in ipairs(b.k) do anlik[i]=id end
    for _,id in ipairs(anlik) do
      local t=f.d[id]
      if t.op=='carp' and t.b and sb(t.b) then
        local w=sb(t.b)
        local ic=f.d[t.a]
        if ic.op=='topla' and u[t.a]==1 and ic.b and sb(ic.b) then
          local c=sb(ic.b)
          if math.abs(c)<0x4000000 and math.abs(w)<0x4000000 then
            local yeni=Y.ek(f,nil,{op='carp',a=ic.a,b=t.b})
            f.d[yeni].blok=b
            t.op='topla'; t.a=yeni; t.b=Y.sabit(f,c*w)
            local konum
            for i,q in ipairs(b.k) do if q==id then konum=i end end
            table.insert(b.k,konum,yeni)
            degisti=true
          end
        end
      end
    end
  end
  return degisti
end

function Y.dongular(f)
  local geri={}
  for _,b in ipairs(f.duz) do
    for _,s in ipairs(b.ardil) do
      if Y.baskin_mi(f,s,b) then geri[#geri+1]={b,s} end
    end
  end
  local dongular={}
  for _,e in ipairs(geri) do
    local kuyruk,bas=e[1],e[2]
    local govde={[bas]=true}
    local yigin={kuyruk}
    if kuyruk~=bas then govde[kuyruk]=true end
    while #yigin>0 do
      local x=table.remove(yigin)
      for _,o in ipairs(x.oncul) do
        if not govde[o] then govde[o]=true; yigin[#yigin+1]=o end
      end
    end
    local var=false
    for _,d in ipairs(dongular) do if d.bas==bas then
      for k in pairs(govde) do d.govde[k]=true end; var=true
    end end
    if not var then dongular[#dongular+1]={bas=bas,govde=govde} end
  end

  for _,d in ipairs(dongular) do
    local sira={}
    for b in pairs(d.govde) do sira[#sira+1]=b end
    table.sort(sira,function(x,y) return x.sira<y.sira end)
    d.sira=sira
  end

  table.sort(dongular,function(a,b)
    if #a.sira~=#b.sira then return #a.sira<#b.sira end
    return a.bas.sira<b.bas.sira
  end)
  return dongular
end

function Y.on_blok(f,d)
  local bas=d.bas
  local disardan={}
  for _,o in ipairs(bas.oncul) do
    if not d.govde[o] then disardan[#disardan+1]=o end
  end
  if #disardan==1 then
    local o=disardan[1]
    if #o.ardil==1 then return o end
  end
  return nil
end

function Y.licm(f)
  local degisti=false
  local dongular=Y.dongular(f)
  for _,d in ipairs(dongular) do
    local on=Y.on_blok(f,d)

    local yuk_ok=true
    for _,b in ipairs(d.sira) do
      for _,id in ipairs(b.k) do
        local o=f.d[id].op
        if o=='sakla' or o=='cagri' or o=='ic' or o=='atomik'
           or o=='bkopya' or o=='bsifir' then yuk_ok=false end
      end
    end
    if on then
      local tanim_ici={}
      for _,b in ipairs(d.sira) do
        for _,id in ipairs(b.k) do tanim_ici[id]=true end
      end
      local ilerleme=true
      while ilerleme do
        ilerleme=false
        for _,b in ipairs(d.sira) do
          local i=1
          while i<=#b.k do
            local id=b.k[i]
            local t=f.d[id]
            local tasinabilir=(Y.saf[t.op] or (yuk_ok and t.op=='yukle'))
                              and t.op~='phi' and t.op~='param'
            if tasinabilir then
              local function disarida(x) return x==nil or not tanim_ici[x] end
              if disarida(t.a) and disarida(t.b) and disarida(t.c) then
                table.remove(b.k,i)
                table.insert(on.k,#on.k,id)
                t.blok=on; tanim_ici[id]=nil
                degisti=true; ilerleme=true
              else i=i+1 end
            else i=i+1 end
          end
        end
      end
    end
  end
  return degisti
end

local X={}
Y.X64=X

X.kosul={['==']=0x4,['!=']=0x5,['<']=0xc,['>=']=0xd,['>']=0xf,['<=']=0xe}
X.kosul_u={['==']=0x4,['!=']=0x5,['<']=0x2,['>=']=0x3,['>']=0x7,['<=']=0x6}
X.ters={[0x4]=0x5,[0x5]=0x4,[0x2]=0x3,[0x3]=0x2,[0x6]=0x7,[0x7]=0x6,
        [0xc]=0xd,[0xd]=0xc,[0xe]=0xf,[0xf]=0xe}

X.ikili={topla=0x01,cikar=0x29,ve=0x21,veya=0x09,xor=0x31}
X.ikili_imm={topla=0,veya=1,ve=4,cikar=5,xor=6}
X.kaydir_digit={sola=4,saga_u=5,saga_s=7}

function X.yeni(f,E,H)
  local M={f=f,E=E,H=H}
  local bytes,hex,u32=E.bytes,E.hex,E.u32
  local function b1(v) bytes(string.char(v&0xff)) end
  local function i32(v) bytes(string.pack('<i4',v)) end

  function M.rr(w,opcode,reg,rm)
    local rex=0x40|(w and 8 or 0)|(((reg>>3)&1)<<2)|((rm>>3)&1)
    if rex~=0x40 then b1(rex) end
    if opcode>0xff then b1(opcode>>8) end
    b1(opcode)
    b1(0xc0|((reg&7)<<3)|(rm&7))
  end

  function M.mr(w,opcode,reg,taban,indeks,olcek,yer,zorla_rex)
    local x=indeks or 0
    if taban==nil then

      local rex=0x40|(w and 8 or 0)|(((reg>>3)&1)<<2)|(((x>>3)&1)<<1)
      if rex~=0x40 or zorla_rex then b1(rex) end
      if opcode>0xff then b1(opcode>>8) end
      b1(opcode)
      b1((0<<6)|((reg&7)<<3)|4)
      local o=({[1]=0,[2]=1,[4]=2,[8]=3})[olcek or 1]
      b1((o<<6)|((x&7)<<3)|5)
      i32(yer or 0)
      return
    end
    local rex=0x40|(w and 8 or 0)|(((reg>>3)&1)<<2)|(((x>>3)&1)<<1)|((taban>>3)&1)
    if rex~=0x40 or zorla_rex then b1(rex) end
    if opcode>0xff then b1(opcode>>8) end
    b1(opcode)
    local sib=indeks~=nil or (taban&7)==4
    local mod
    if yer==0 and (taban&7)~=5 then mod=0
    elseif yer>=-128 and yer<=127 then mod=1
    else mod=2 end
    if sib then
      b1((mod<<6)|((reg&7)<<3)|4)
      local o=({[1]=0,[2]=1,[4]=2,[8]=3})[olcek or 1]
      b1((o<<6)|(((indeks or 4)&7)<<3)|(taban&7))
    else
      b1((mod<<6)|((reg&7)<<3)|(taban&7))
    end
    if mod==1 then b1(yer) elseif mod==2 then i32(yer) end
  end

  function M.tasi(d,s) if d~=s then M.rr(true,0x89,s,d) end end

  function M.anlik(v,r)
    if v==0 then M.rr(false,0x31,r,r)
    elseif v>0 and v<=0xffffffff then
      local rex=0x40|((r>>3)&1); if rex~=0x40 then b1(rex) end
      b1(0xb8|(r&7)); u32(v)
    elseif v>=-2147483648 and v<0 then
      b1(0x48|((r>=8) and 1 or 0)); b1(0xc7); b1(0xc0|(r&7)); i32(v)
    else
      b1(0x48|((r>=8) and 1 or 0)); b1(0xb8|(r&7)); bytes(string.pack('<i8',v))
    end
  end

  function M.sabit_mi(id)
    local t=f.d[id]
    if t and t.op=='sabit' then return t.s end
  end

  local TB=f.rsp_cerceve and 4 or 5
  function M.yuva_ofset(o) return f.yuva_taban+o end
  function M.yuva_yukle(r,ofset) M.mr(true,0x8b,r,TB,nil,1,ofset) end
  function M.yuva_sakla(r,ofset) M.mr(true,0x89,r,TB,nil,1,ofset) end

  function M.oku(id,kazi_no)
    local r=f.kayit[id]
    if r then return r end
    local k=H.kazi[kazi_no or 1]
    local s=M.sabit_mi(id)
    if s then M.anlik(s,k); return k end
    local d=f.dokum[id]
    if d then M.yuva_yukle(k,M.yuva_ofset(d)); return k end
    M.anlik(0,k); return k
  end

  function M.hedef(id) return f.kayit[id] or H.kazi[1] end
  function M.hedef_bitir(id,r)
    local d=f.dokum[id]
    if d then M.yuva_sakla(r,M.yuva_ofset(d)) end
  end

  function M.paralel(cift)
    local kalan={}
    for _,c in ipairs(cift) do
      if c[2]~=c[1] or c[3] or c[4] then kalan[#kalan+1]=c end
    end
    local ilerledi=true
    while #kalan>0 and ilerledi do
      ilerledi=false
      for i,c in ipairs(kalan) do
        local engel=false
        for j,o in ipairs(kalan) do if i~=j and o[2]==c[1] then engel=true end end
        if not engel then
          if c[3]~=nil then M.anlik(c[3],c[1])
          elseif c[4] then M.yuva_yukle(c[1],c[4])
          else M.tasi(c[1],c[2]) end
          table.remove(kalan,i); ilerledi=true; break
        end
      end
      if not ilerledi and #kalan>0 then

        local c=kalan[1]; local k=H.kazi[1]
        M.tasi(k,c[2])
        for _,o in ipairs(kalan) do if o[2]==c[2] then o[2]=k end end
        ilerledi=true
      end
    end
  end

  function M.phi_tasi(b,s)
    local cift={}
    for _,id in ipairs(s.k) do
      local t=f.d[id]
      if t.op~='phi' then break end
      local kaynak
      for _,g in ipairs(t.girdi) do if g[1]==b then kaynak=g[2] end end
      if kaynak then
        local hd=f.kayit[id]
        local sv=M.sabit_mi(kaynak)
        if hd then
          if sv then cift[#cift+1]={hd,nil,sv}
          elseif f.kayit[kaynak] then cift[#cift+1]={hd,f.kayit[kaynak]}
          else cift[#cift+1]={hd,nil,nil,M.yuva_ofset(f.dokum[kaynak])} end
        elseif f.dokum[id] then
          M.yuva_sakla(M.oku(kaynak,1),M.yuva_ofset(f.dokum[id]))
        end
      end
    end
    M.paralel(cift)
  end

  local degismeli={topla=true,ve=true,veya=true,xor=true,carp=true}

  function M.grup_imm(digit,r,v)
    if v>=-128 and v<=127 then
      M.rr(true,0x83,digit,r); b1(v)
    else
      M.rr(true,0x81,digit,r); i32(v)
    end
  end

  X.ikili_rm={topla=0x03,cikar=0x2b,ve=0x23,veya=0x0b,xor=0x33}

  function M.katlanmis_yuk(t)
    local y=t.kaynasik_yuk
    if not y then return nil end
    return f.d[y]
  end

  function M.ikili_uret(t,d)
    local op=t.op
    local yuk=M.katlanmis_yuk(t)
    if yuk and X.ikili_rm[op] then
      local ra=M.oku(t.a,1)
      local rn,ri,olcek,yer=M.adres_kur(yuk,3,2)
      if d~=rn and d~=ri then
        M.tasi(d,ra)
        M.mr(true,X.ikili_rm[op],d,rn,ri,olcek,yer)
      else

        local k=H.kazi[2]
        if k==rn or k==ri then k=H.kazi[3] end
        M.mr(true,0x8b,k,rn,ri,olcek,yer)
        M.tasi(d,ra)
        M.rr(true,X.ikili[op],k,d)
      end
      return
    end
    local sv=M.sabit_mi(t.b)

    if op=='topla' and not yuk then
      if sv and sv>=-2147483648 and sv<=2147483647 and sv~=0 then
        M.mr(true,0x8d,d,M.oku(t.a,1),nil,1,sv); return
      elseif not sv then
        local ra=M.oku(t.a,1); local rb=M.oku(t.b,2)
        if d~=ra and d~=rb then M.mr(true,0x8d,d,ra,rb,1,0); return end
      end
    end

    if op=='carp' and sv then
      local tabanli={[2]=1,[3]=2,[5]=4,[9]=8}
      local tabansiz={[4]=4,[8]=8}
      if tabanli[sv] then
        local ra=M.oku(t.a,1)
        M.mr(true,0x8d,d,ra,ra,tabanli[sv],0); return
      elseif tabansiz[sv] then
        local ra=M.oku(t.a,1)
        M.mr(true,0x8d,d,nil,ra,tabansiz[sv],0); return
      end
    end
    if op=='sola' and sv and sv>=1 and sv<=3 then
      local ra=M.oku(t.a,1)
      if d~=ra then M.mr(true,0x8d,d,nil,ra,1<<sv,0); return end
    end
    if op=='sola' or op=='saga' then
      local digit=(op=='sola') and 4 or (t.isaretsiz and 5 or 7)
      if sv then
        M.tasi(d,M.oku(t.a,1)); M.rr(true,0xc1,digit,d); b1(sv&63)
      else
        local rb=M.oku(t.b,2); M.tasi(1,rb)
        M.tasi(d,M.oku(t.a,1)); M.rr(true,0xd3,digit,d)
      end
      return
    end
    if op=='carp' then
      if sv and sv>=-2147483648 and sv<=2147483647 then
        M.rr(true,0x69,d,M.oku(t.a,1)); i32(sv); return
      end
      local ra=M.oku(t.a,1); local rb=M.oku(t.b,2)
      if d==rb then M.rr(true,0x0faf,d,ra)
      else M.tasi(d,ra); M.rr(true,0x0faf,d,rb) end
      return
    end
    if sv and sv>=-2147483648 and sv<=2147483647 and X.ikili_imm[op] then
      M.tasi(d,M.oku(t.a,1)); M.grup_imm(X.ikili_imm[op],d,sv); return
    end
    local ra=M.oku(t.a,1)
    local rb=M.oku(t.b,2)
    if d==ra then M.rr(true,X.ikili[op],rb,d)
    elseif d==rb and degismeli[op] then M.rr(true,X.ikili[op],ra,d)
    elseif d==rb then
      local k=H.kazi[3]; M.tasi(k,ra); M.rr(true,X.ikili[op],rb,k); M.tasi(d,k)
    else M.tasi(d,ra); M.rr(true,X.ikili[op],rb,d) end
  end

  function M.kiyas_uret(t)
    local yuk=M.katlanmis_yuk(t)
    if yuk then
      local ra=M.oku(t.a,1)
      local rn,ri,olcek,yer=M.adres_kur(yuk,3,2)
      M.mr(true,0x3b,ra,rn,ri,olcek,yer)
      return (t.isaretsiz and X.kosul_u or X.kosul)[t.iliski]
    end
    local sv=M.sabit_mi(t.b)
    local ra=M.oku(t.a,1)
    if sv and sv>=-2147483648 and sv<=2147483647 then
      if sv==0 then M.rr(true,0x85,ra,ra) else M.grup_imm(7,ra,sv) end
    else
      M.rr(true,0x39,M.oku(t.b,2),ra)
    end
    return (t.isaretsiz and X.kosul_u or X.kosul)[t.iliski]
  end

  function M.setcc(c,d)
    local rex=0x40|((d>>3)&1)
    b1(rex); b1(0x0f); b1(0x90|c); b1(0xc0|(d&7))
    M.rr(true,0x0fb6,d,d)
  end

  function M.genislet_uret(t,d)
    local ra=M.oku(t.a,1)
    if t.bit==64 then M.tasi(d,ra); return end
    if t.bit==32 then
      if t.isaretli then M.rr(true,0x63,d,ra) else M.rr(false,0x89,ra,d) end
    elseif t.bit==16 then M.rr(true,t.isaretli and 0x0fbf or 0x0fb7,d,ra)
    else
      if not t.isaretli and ra<4 then M.rr(true,0x0fb6,d,ra)
      else
        local rex=0x48|(((d>>3)&1)<<2)|((ra>>3)&1)
        b1(rex); b1(0x0f); b1(t.isaretli and 0xbe or 0xb6); b1(0xc0|((d&7)<<3)|(ra&7))
      end
    end
  end

  function M.adres_kur(t,kb,ki)
    kb=kb or 1; ki=ki or 2
    local taban=t.a
    local ofset=t.ofset or 0
    local indeks=t.c
    local tt=f.d[taban]
    if tt.op=='yuva_adres' and not f.kayit[taban] and not f.dokum[taban] then
      return TB,(indeks and M.oku(indeks,ki) or nil),
             t.olcek or 1,M.yuva_ofset(tt.ofset)+ofset
    end
    local rn=M.oku(taban,kb)
    local ri=indeks and M.oku(indeks,ki) or nil
    return rn,ri,t.olcek or 1,ofset
  end

  function M.yukle_uret(t,d)
    local rn,ri,olcek,yer=M.adres_kur(t,1,2)
    local bit=t.bit
    if bit==64 then M.mr(true,0x8b,d,rn,ri,olcek,yer)
    elseif bit==32 then
      if t.isaretli then M.mr(true,0x63,d,rn,ri,olcek,yer)
      else M.mr(false,0x8b,d,rn,ri,olcek,yer) end
    elseif bit==16 then M.mr(true,t.isaretli and 0x0fbf or 0x0fb7,d,rn,ri,olcek,yer)
    else M.mr(true,t.isaretli and 0x0fbe or 0x0fb6,d,rn,ri,olcek,yer) end
  end

  function M.sakla_uret(t)
    local rn,ri,olcek,yer=M.adres_kur(t,1,2)
    local rv=M.oku(t.b,3)
    local bit=t.bit
    if bit==64 then M.mr(true,0x89,rv,rn,ri,olcek,yer)
    elseif bit==32 then M.mr(false,0x89,rv,rn,ri,olcek,yer)
    elseif bit==16 then b1(0x66); M.mr(false,0x89,rv,rn,ri,olcek,yer)
    else

      M.mr(false,0x88,rv,rn,ri,olcek,yer,rv>=4 and rv<8)
    end
  end

  function M.bol_uret(t,d)
    local isaretsiz=t.isaretsiz
    local ra=M.oku(t.a,1)
    local k=H.kazi[2]
    M.tasi(k,M.oku(t.b,2))
    M.tasi(0,ra)
    local son=E.label()
    if not isaretsiz then
      local normal=E.label()
      M.grup_imm(7,k,-1)
      E.kosul_dal64(normal,X.kosul['!='])
      if t.op=='bol' then M.rr(true,0xf7,3,0)
      else M.rr(false,0x31,0,0) end
      if t.op=='kalan' then M.tasi(2,0) end
      E.jump(son); E.mark(normal)
      b1(0x48); b1(0x99)
      M.rr(true,0xf7,7,k)
    else
      M.rr(false,0x31,2,2)
      M.rr(true,0xf7,6,k)
    end
    E.mark(son)
    M.tasi(d,(t.op=='bol') and 0 or 2)
  end

  function M.carp_yuksek_uret(t,d,isaretli)
    local rb=M.oku(t.b,2)
    local k=rb
    if rb==0 or rb==2 then k=H.kazi[2]; M.tasi(k,rb) end
    M.tasi(0,M.oku(t.a,1))
    M.rr(true,0xf7,isaretli and 5 or 4,k)
    M.tasi(d,2)
  end

  function M.atomik_uret(t,d)
    local rn=M.oku(t.a,1)
    local alt=t.alt
    if alt=='atomik_oku' then M.mr(true,0x8b,d,rn,nil,1,0); return end
    local rv=M.oku(t.b,2)
    local k=H.kazi[3]
    if alt=='atomik_yaz' then

      M.mr(true,0x89,rv,rn,nil,1,0); M.tasi(d,rv); return
    end
    if alt=='atomik_ekle' then
      M.tasi(k,rv); b1(0xf0); M.mr(true,0x0fc1,k,rn,nil,1,0); M.tasi(d,k); return
    end
    local rc=M.oku(t.c,3)
    if rc==0 then M.tasi(H.kazi[3],0); rc=H.kazi[3] end
    M.tasi(0,rv)
    b1(0xf0); M.mr(true,0x0fb1,rc,rn,nil,1,0)
    M.tasi(d,0)
  end

  function M.float_uret(t,d)
    local ft=t.ft or 'f64'
    local ra=M.oku(t.a,1)

    b1(0x66); b1(0x48|(((ra>>3)&1))); b1(0x0f); b1(0x6e); b1(0xc0|(0<<3)|(ra&7))
    if t.op=='fkarekok' then
      hex(ft=='f32' and 'f3 0f 51 c0' or 'f2 0f 51 c0')
    elseif t.op=='fters' then
      hex('48 0f ba f8'); b1(ft=='f32' and 31 or 63)
      b1(0x66); b1(0x48|(((d>>3)&1)<<2)); b1(0x0f); b1(0x7e); b1(0xc0|(0<<3)|(d&7))
      return
    else
      local rb=M.oku(t.b,2)
      b1(0x66); b1(0x48|(((rb>>3)&1))); b1(0x0f); b1(0x6e); b1(0xc0|(1<<3)|(rb&7))
      if t.op=='fkiyas' then
        hex(ft=='f32' and '0f 2e c1' or '66 0f 2e c1')
        local c=({['==']=0x94,['!=']=0x95,['<']=0x92,['<=']=0x96,['>']=0x97,['>=']=0x93})[t.iliski]
        b1(0x0f); b1(c); b1(0xc0)
        if t.iliski=='!=' then hex('0f 9a c2 08 d0')
        elseif t.iliski=='==' or t.iliski=='<' or t.iliski=='<=' then hex('0f 9b c2 20 d0') end
        hex('48 0f b6 c0'); M.tasi(d,0); return
      end
      hex(ft=='f32' and 'f3 0f' or 'f2 0f')
      b1(({ftopla=0x58,fcikar=0x5c,fcarp=0x59,fbol=0x5e})[t.op]); b1(0xc1)
    end
    b1(0x66); b1(0x48|(((d>>3)&1)<<2)); b1(0x0f); b1(0x7e); b1(0xc0|(0<<3)|(d&7))
  end

  function M.donusum_uret(t,d)
    local ra=M.oku(t.a,1)
    b1(0x66); b1(0x48|(((ra>>3)&1))); b1(0x0f); b1(0x6e); b1(0xc0|(0<<3)|(ra&7))
    if t.op=='f2f' then
      hex(t.hf=='f32' and 'f2 0f 5a c0' or 'f3 0f 5a c0')
      b1(0x66); b1(0x48|(((d>>3)&1)<<2)); b1(0x0f); b1(0x7e); b1(0xc0|(d&7))
    elseif t.op=='i2f' then
      local normal,son=E.label(),E.label()
      if t.isaretsiz then
        M.rr(true,0x85,ra,ra)
        E.kosul_dal64(normal,X.kosul['>='])
        M.tasi(1,ra); M.grup_imm(4,1,1)
        M.tasi(0,ra); M.rr(true,0xd1,5,0)
        M.rr(true,0x09,1,0)
        hex(t.hf=='f32' and 'f3 48 0f 2a c0 f3 0f 58 c0' or 'f2 48 0f 2a c0 f2 0f 58 c0')
        E.jump(son); E.mark(normal)
        hex(t.hf=='f32' and 'f3 48 0f 2a c0' or 'f2 48 0f 2a c0')
        E.mark(son)
      else
        local rex=0x48|((ra>>3)&1)
        b1(t.hf=='f32' and 0xf3 or 0xf2); b1(rex); b1(0x0f); b1(0x2a); b1(0xc0|(ra&7))
      end
      b1(0x66); b1(0x48|(((d>>3)&1)<<2)); b1(0x0f); b1(0x7e); b1(0xc0|(d&7))
    else
      hex(t.kf=='f32' and 'f3 48 0f 2c c0' or 'f2 48 0f 2c c0')
      M.tasi(d,0)
    end
  end

  function M.cagri_uret(t,d)
    local n=#t.args
    local reg=H.abi
    local kayitli=math.min(#reg,n)
    local tasma=math.max(0,n-#reg)

    local golge=0
    if not f.rsp_cerceve then golge=((H.golge or 0)+tasma*8+15)//16*16 end
    local hedef_r
    if t.dolayli then hedef_r=H.kazi[2]; M.tasi(hedef_r,M.oku(t.dolayli,3)) end
    if golge>0 then M.grup_imm(5,4,golge) end
    for i=#reg+1,n do
      local r=M.oku(t.args[i],1)
      M.mr(true,0x89,r,4,nil,1,(H.golge or 0)+(i-#reg-1)*8)
    end
    local cift={}
    for i=1,kayitli do
      local a=t.args[i]
      local sv=M.sabit_mi(a)
      if sv then cift[#cift+1]={reg[i],nil,sv}
      elseif f.kayit[a] then cift[#cift+1]={reg[i],f.kayit[a]}
      else cift[#cift+1]={reg[i],nil,nil,M.yuva_ofset(f.dokum[a])} end
    end
    M.paralel(cift)
    if t.dis then
      local y=E.builtins[t.dis]
      if t.abi=='float64' then
        for i=1,kayitli do
          local r=reg[i]
          b1(0x66); b1(0x48|(((r>>3)&1))); b1(0x0f); b1(0x6e); b1(0xc0|((i-1)<<3)|(r&7))
        end
      end
      E.external(y[1])
      if t.abi=='float64' then hex('66 48 0f 7e c0')
      elseif t.abi=='int' then hex('48 98')
      elseif t.abi=='void' then hex('31 c0') end
      E.normalize(y[4],0)
    elseif t.dolayli then
      M.rr(false,0xff,2,hedef_r)
    else
      E.jump(E.entries[t.ad],false,true)
    end
    if golge>0 then M.grup_imm(0,4,golge) end
    M.tasi(d,0)
  end

  function M.ic_uret(t,d)
    local dugum=t.dugum
    local yeni={'call',dugum[2],{},type=dugum.type}
    for k,v in pairs(dugum) do if type(k)=='string' then yeni[k]=v end end
    for i,a in ipairs(t.args) do
      local r=M.oku(a,1)
      M.yuva_sakla(r,M.yuva_ofset(t.yuvalar[i]))
      yeni[3][i]={'ybyuva',M.yuva_ofset(t.yuvalar[i]),type=dugum[3][i].type}
    end
    E.generate(yeni)
    M.tasi(d,0)
  end

  function M.swar(d,ra,sabitler)
    M.tasi(d,ra)
    local k1,k2=H.kazi[2],H.kazi[3]

    M.tasi(k1,d); M.rr(true,0xc1,5,k1); b1(1)
    M.anlik(sabitler[1],k2); M.rr(true,0x21,k2,k1); M.rr(true,0x29,k1,d)
    M.tasi(k1,d); M.rr(true,0xc1,5,k1); b1(2)
    M.anlik(sabitler[2],k2); M.rr(true,0x21,k2,d); M.rr(true,0x21,k2,k1)
    M.rr(true,0x01,k1,d)
    M.tasi(k1,d); M.rr(true,0xc1,5,k1); b1(4); M.rr(true,0x01,k1,d)
    M.anlik(sabitler[3],k2); M.rr(true,0x21,k2,d)
    M.anlik(sabitler[4],k2); M.rr(true,0x0faf,d,k2)
    M.rr(true,0xc1,5,d); b1(56)
  end

  function M.bit_ters_uret(d,ra)
    M.tasi(d,ra)
    local k1,k2=H.kazi[2],H.kazi[3]
    for _,v in ipairs({{1,0x5555555555555555},{2,0x3333333333333333},{4,0x0f0f0f0f0f0f0f0f}}) do
      M.tasi(k1,d); M.rr(true,0xc1,5,k1); b1(v[1])
      M.anlik(v[2],k2)
      M.rr(true,0x21,k2,k1); M.rr(true,0x21,k2,d)
      M.rr(true,0xc1,4,d); b1(v[1])
      M.rr(true,0x09,k1,d)
    end
    local rex=0x48|((d>=8) and 1 or 0); b1(rex); b1(0x0f); b1(0xc8|(d&7))
  end

  function M.komut(t,b)
    local op=t.op
    if op=='sabit' then
      if f.kayit[t.id] then M.anlik(t.s,f.kayit[t.id]) end
      return
    end
    if op=='phi' or op=='param' or t.kaynasik then return end
    local d=M.hedef(t.id)
    if X.ikili[op] or op=='carp' or op=='sola' or op=='saga' then M.ikili_uret(t,d)
    elseif op=='bol' or op=='kalan' then M.bol_uret(t,d)
    elseif op=='kiyas' then M.setcc(M.kiyas_uret(t),d)
    elseif op=='sec' then

      local rc=M.oku(t.a,1)
      local ry=M.oku(t.c,2)
      local rx=M.oku(t.b,3)
      M.rr(true,0x85,rc,rc)
      if d==rx and d~=ry then
        M.rr(true,0x0f40|X.kosul['=='],d,ry)
      else
        M.tasi(d,ry)
        if d~=rx then M.rr(true,0x0f40|X.kosul['!='],d,rx) end
      end
    elseif op=='genislet' then M.genislet_uret(t,d)
    elseif op=='tersle' then M.tasi(d,M.oku(t.a,1)); M.rr(true,0xf7,3,d)
    elseif op=='bitnot' then M.tasi(d,M.oku(t.a,1)); M.rr(true,0xf7,2,d)
    elseif op=='yukle' then M.yukle_uret(t,d)
    elseif op=='sakla' then M.sakla_uret(t); return
    elseif op=='yuva_adres' then M.mr(true,0x8d,d,TB,nil,1,M.yuva_ofset(t.ofset))
    elseif op=='genel_adres' then
      b1(0x48|(((d>>3)&1)<<2)); b1(0x8d); b1((0<<6)|((d&7)<<3)|5)
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),t.g}; u32(0)
    elseif op=='islev_adres' then
      b1(0x48|(((d>>3)&1)<<2)); b1(0x8d); b1((0<<6)|((d&7)<<3)|5)
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),{text_label=E.entries[t.ad]}}; u32(0)
    elseif op=='metin' then
      local l=E.label(); E.data[#E.data+1]={l,t.s..'\0'}
      b1(0x48|(((d>>3)&1)<<2)); b1(0x8d); b1((0<<6)|((d&7)<<3)|5)
      E.global_relocations[#E.global_relocations+1]={E.kod_boy(),{text_label=l}}; u32(0)
    elseif op=='cagri' then M.cagri_uret(t,d)
    elseif op=='ic' then M.ic_uret(t,d)
    elseif op=='atomik' then M.atomik_uret(t,d)
    elseif op=='bkopya' or op=='bsifir' then M.blok_bellek_uret(t,d)
    elseif op=='carp_yuksek' then M.carp_yuksek_uret(t,d,false)
    elseif op=='carp_yuksek_s' then M.carp_yuksek_uret(t,d,true)
    elseif op=='bit_say' then
      M.swar(d,M.oku(t.a,1),{0x5555555555555555,0x3333333333333333,
                             0x0f0f0f0f0f0f0f0f,0x0101010101010101})
    elseif op=='ilk_bit' then
      local k=H.kazi[2]
      M.rr(true,0x0fbc,k,M.oku(t.a,1)); M.anlik(64,d); M.rr(true,0x0f45,d,k)
    elseif op=='son_bit' then
      local k=H.kazi[2]
      M.rr(true,0x0fbd,k,M.oku(t.a,1)); M.anlik(-1,d); M.rr(true,0x0f45,d,k)
    elseif op=='bayt_ters' then
      M.tasi(d,M.oku(t.a,1))
      b1(0x48|((d>=8) and 1 or 0)); b1(0x0f); b1(0xc8|(d&7))
    elseif op=='bit_ters' then M.bit_ters_uret(d,M.oku(t.a,1))
    elseif op=='ongetir' then M.mr(false,0x0f18,1,M.oku(t.a,1),nil,1,0); return
    elseif op=='bekle' then hex('f3 90'); return
    elseif op=='ftopla' or op=='fcikar' or op=='fcarp' or op=='fbol'
        or op=='fkiyas' or op=='fkarekok' or op=='fters' then M.float_uret(t,d)
    elseif op=='f2f' or op=='i2f' or op=='f2i' then M.donusum_uret(t,d)
    elseif op=='dal' or op=='kosul' or op=='don' or op=='tuzak' then return
    else E.hata('YB/x64: uretilemeyen komut '..op) end
    M.hedef_bitir(t.id,d)
  end

  function M.blok_bellek_uret(t,d)
    local rd=M.oku(t.a,1)
    local rs=t.b and M.oku(t.b,2) or nil
    local n=t.boy
    local parca={}
    local o=0
    while n-o>=16 do parca[#parca+1]={o,16}; o=o+16 end
    while n-o>=8 do parca[#parca+1]={o,8}; o=o+8 end
    local function vyukle(vt,rn,off) b1(0xf3); M.mr(false,0x0f6f,vt,rn,nil,1,off) end
    local function vsakla(vt,rn,off) b1(0xf3); M.mr(false,0x0f7f,vt,rn,nil,1,off) end
    if t.op=='bsifir' then
      if n>=16 then hex('66 0f ef c0') end
      local k=H.kazi[3]
      if n%16~=0 then M.anlik(0,k) end
      for _,c in ipairs(parca) do
        if c[2]==16 then vsakla(0,rd,c[1])
        else M.mr(true,0x89,k,rd,nil,1,c[1]) end
      end
    elseif t.tasi then
      local v,x=0,0
      local kayitlar={}
      for i,c in ipairs(parca) do
        if c[2]==16 then vyukle(v,rs,c[1]); kayitlar[i]={'v',v}; v=v+1
        else x=x+1; local r=H.kazi[x==1 and 3 or 2]
          M.mr(true,0x8b,r,rs,nil,1,c[1]); kayitlar[i]={'x',r} end
      end
      for i,c in ipairs(parca) do
        local k=kayitlar[i]
        if k[1]=='v' then vsakla(k[2],rd,c[1])
        else M.mr(true,0x89,k[2],rd,nil,1,c[1]) end
      end
    else
      for _,c in ipairs(parca) do
        if c[2]==16 then vyukle(0,rs,c[1]); vsakla(0,rd,c[1])
        else
          local r=H.kazi[3]
          M.mr(true,0x8b,r,rs,nil,1,c[1]); M.mr(true,0x89,r,rd,nil,1,c[1])
        end
      end
    end
    M.tasi(d,rd)
  end

  function M.blok_uret(b,sonraki)
    Y.hiza_iste(f,E,b,H)
    E.mark(b.etiket)
    local n=#b.k
    for i=1,n do
      local t=f.d[b.k[i]]
      if not Y.terminal[t.op] then M.komut(t,b) end
    end
    local son=f.d[b.k[n]]
    if not son or not Y.terminal[son.op] then return end
    if son.op=='dal' then
      M.phi_tasi(b,son.hedef)
      if son.hedef~=sonraki then E.jump(son.hedef.etiket) end
    elseif son.op=='kosul' then
      local c
      if son.kaynasik_kiyas then c=M.kiyas_uret(f.d[son.kaynasik_kiyas])
      else local r=M.oku(son.a,1); M.rr(true,0x85,r,r); c=X.kosul['!='] end
      if sonraki==son.yanlis then E.kosul_dal64(son.dogru.etiket,c)
      elseif sonraki==son.dogru then E.kosul_dal64(son.yanlis.etiket,X.ters[c])
      else E.kosul_dal64(son.dogru.etiket,c); E.jump(son.yanlis.etiket) end
    elseif son.op=='don' then
      local sv=M.sabit_mi(son.a)
      if sv then M.anlik(sv,0) else M.tasi(0,M.oku(son.a,1)) end
      E.jump(f.bitis)
    elseif son.op=='tuzak' then hex('0f 0b') end
  end

  function M.uret()
    local kalici=f.kalici_kayitlar

    local cikis,cagri_var=0,false
    for _,b in ipairs(f.duz) do
      for _,id in ipairs(b.k) do
        local t=f.d[id]
        if t.op=='cagri' then
          cagri_var=true
          local c=(H.golge or 0)+math.max(0,#t.args-#H.abi)*8
          if c>cikis then cikis=c end
        end
      end
    end
    cikis=f.rsp_cerceve and (cikis+15)//16*16 or 0
    f.cikis=cikis
    f.yuva_taban=cikis+(#kalici*8+15)//16*16
    local frame=(f.yuva_taban+f.yuva+15)//16*16
    if frame>16773120 then E.hata('YB/x64: cerceve 16 MiB sinirini asti') end
    f.frame=frame

    local toplam=frame
    if f.rsp_cerceve and cagri_var then toplam=frame+8 end
    for _,b in ipairs(f.duz) do b.etiket=E.label() end
    f.bitis=E.label()
    E.mark(f.giris_etiketi)
    local uw_bas=E.kod_boy()
    local uw_alloc,uw_cerceve
    if not f.rsp_cerceve then b1(0x55) end

    local yoklama_siniri=H.windows and 4096 or 65536
    if toplam>yoklama_siniri then
      hex('49 89 e3'); b1(0xb8); u32(toplam)
      local p,son=E.label(),E.label(); E.mark(p)
      hex('48 3d 00 10 00 00'); E.kosul_dal64(son,X.kosul_u['<'])
      hex('49 81 eb 00 10 00 00 41 f6 03 00 48 2d 00 10 00 00'); E.jump(p)
      E.mark(son); hex('49 29 c3 41 f6 03 00')
    end
    if toplam>0 then M.grup_imm(5,4,toplam) end
    uw_alloc=E.kod_boy()-uw_bas
    if not f.rsp_cerceve then hex('48 89 e5') end
    uw_cerceve=E.kod_boy()-uw_bas
    local uw_kayitlar={}
    for i,r in ipairs(kalici) do
      M.mr(true,0x89,r,TB,nil,1,cikis+(i-1)*8)
      uw_kayitlar[#uw_kayitlar+1]={r,cikis+(i-1)*8,E.kod_boy()-uw_bas}
    end
    local uw_prolog=E.kod_boy()-uw_bas
    local cift={}
    for _,b in ipairs(f.duz) do
      for _,id in ipairs(b.k) do
        local t=f.d[id]
        if t.op=='param' then
          local hd=f.kayit[id]
          if t.sira<=#H.abi then
            if hd then cift[#cift+1]={hd,H.abi[t.sira]}
            elseif f.dokum[id] then M.yuva_sakla(H.abi[t.sira],M.yuva_ofset(f.dokum[id])) end
          else
            local o=(f.rsp_cerceve and toplam+8 or frame+16)
                    +(H.golge or 0)+(t.sira-#H.abi-1)*8

            if hd then cift[#cift+1]={hd,nil,nil,o}
            elseif f.dokum[id] then
              local r=H.kazi[1]
              M.mr(true,0x8b,r,TB,nil,1,o)
              M.yuva_sakla(r,M.yuva_ofset(f.dokum[id]))
            end
          end
        end
      end
    end
    M.paralel(cift)
    for i,b in ipairs(f.duz) do M.blok_uret(b,f.duz[i+1]) end
    E.mark(f.bitis)
    for i,r in ipairs(kalici) do M.mr(true,0x8b,r,TB,nil,1,cikis+(i-1)*8) end
    if f.rsp_cerceve then
      if toplam>0 then M.grup_imm(0,4,toplam) end
      b1(0xc3)
    else
      M.mr(true,0x8d,4,5,nil,1,frame)
      b1(0x5d); b1(0xc3)
    end
    if H.windows and E.unwind then
      E.unwind[#E.unwind+1]={uw_bas,E.kod_boy(),toplam,uw_kayitlar,uw_prolog,
                             uw_alloc,uw_cerceve,rsp=f.rsp_cerceve}
    end
  end

  return M
end

function Y.x64_hedef(windows)
  local H={}
  if windows then
    H.ucucu={0,2,8,9}
    H.kalici={3,6,7,12,13,14,15}
    H.abi={1,2,8,9}
    H.golge=32
  else
    H.ucucu={0,2,6,7,8,9}
    H.kalici={3,12,13,14,15}
    H.abi={7,6,2,1,8,9}
    H.golge=0
  end
  H.kazi={11,10,1}
  H.kalici_kume={}
  for _,r in ipairs(H.kalici) do H.kalici_kume[r]=true end

  H.bozan_kume={bol={0,2},kalan={0,2},carp_yuksek={0,2},carp_yuksek_s={0,2},
                atomik={0}}
  H.bozan_kullanim={atomik=1}
  H.windows=windows
  H.blok_bellek=true
  H.sec_kaynastirma_yok=true
  H.yuk_katlama=true
  H.x64=true
  return H
end

local function ara_yeni() return {p={},u={}} end

local function ekle_aralik(it,a,b)
  if b<a then b=a end
  local p=it.p
  if #p==0 then p[1]=a; p[2]=b; return end
  if b<p[1]-1 then table.insert(p,1,b); table.insert(p,1,a); return end
  if a<p[1] then p[1]=a end
  if b>p[2] then p[2]=b end
end

local function aralik_bas(it) return it.p[1] end
local function aralik_son(it) return it.p[#it.p] end

local function kapsar(it,pos)
  local p=it.p
  for i=1,#p,2 do
    if pos<p[i] then return false end
    if pos<=p[i+1] then return true end
  end
  return false
end

local function ilk_kesisme(a,b)
  local pa,pb=a.p,b.p
  local i,j=1,1
  while i<=#pa and j<=#pb do
    local a1,a2=pa[i],pa[i+1]
    local b1,b2=pb[j],pb[j+1]
    local lo=a1>b1 and a1 or b1
    local hi=a2<b2 and a2 or b2
    if lo<=hi then return lo end
    if a2<b2 then i=i+2 else j=j+2 end
  end
  return nil
end

local function sonraki_kullanim(it,pos)
  for _,q in ipairs(it.u) do if q>=pos then return q end end
  return math.maxinteger
end

Y.ara_yeni=ara_yeni; Y.ekle_aralik=ekle_aralik; Y.kapsar=kapsar
Y.ilk_kesisme=ilk_kesisme; Y.sonraki_kullanim=sonraki_kullanim
Y.aralik_bas=aralik_bas; Y.aralik_son=aralik_son

function Y.konumla(f)
  local p=0
  for _,b in ipairs(f.duz) do
    b.bas=p
    for _,id in ipairs(b.k) do p=p+4; f.d[id].konum=p end
    p=p+4
    b.bit=p

    p=p+4
  end
  f.son_konum=p+4
end

function Y.canlilik(f)
  local giris,cikis={},{}
  for _,b in ipairs(f.duz) do giris[b.no]={}; cikis[b.no]={} end
  local degisti=true
  local tur=0
  while degisti and tur<500 do
    degisti=false; tur=tur+1
    for i=#f.duz,1,-1 do
      local b=f.duz[i]
      local c={}
      for _,s in ipairs(b.ardil) do
        for v in pairs(giris[s.no]) do c[v]=true end
        for _,id in ipairs(s.k) do
          local t=f.d[id]
          if t.op~='phi' then break end
          for _,g in ipairs(t.girdi) do if g[1]==b then c[g[2]]=true end end
        end
      end
      local g={}
      for v in pairs(c) do g[v]=true end
      for j=#b.k,1,-1 do
        local id=b.k[j]; local t=f.d[id]
        g[id]=nil
        if t.op~='phi' then
          local function s(x) if x then g[x]=true end end
          s(t.a); s(t.b); s(t.c)
          if t.args then for _,x in ipairs(t.args) do g[x]=true end end
          if t.dolayli then g[t.dolayli]=true end
        end
      end
      local ec,eg=cikis[b.no],giris[b.no]
      local fark=false
      for v in pairs(c) do if not ec[v] then fark=true end end
      for v in pairs(g) do if not eg[v] then fark=true end end
      if fark then degisti=true end
      cikis[b.no]=c; giris[b.no]=g
    end
  end
  f.canli_giris=giris; f.canli_cikis=cikis
end

function Y.araliklar(f,H)
  local ara={}
  local sabit={}
  local function al(id)
    local it=ara[id]
    if not it then it=ara_yeni(); ara[id]=it end
    return it
  end
  local function sabit_al(r)
    local it=sabit[r]
    if not it then it=ara_yeni(); sabit[r]=it end
    return it
  end
  for i=#f.duz,1,-1 do
    local b=f.duz[i]

    for v in pairs(f.canli_cikis[b.no]) do ekle_aralik(al(v),b.bas,b.bit) end
    for j=#b.k,1,-1 do
      local id=b.k[j]
      local t=f.d[id]
      local pos=t.konum
      if not Y.sonucsuz[t.op] then
        local it=al(id)
        if #it.p==0 then ekle_aralik(it,pos+2,pos+2) else it.p[1]=pos+2 end
      end

      local bozan=H.bozan_kume and H.bozan_kume[t.op]
      if t.op=='cagri' or t.op=='ic' then bozan=H.ucucu end
      if bozan then

        local bas=(H.bozan_kullanim and H.bozan_kullanim[t.op]) and pos or pos+1
        for _,r in ipairs(bozan) do ekle_aralik(sabit_al(r),bas,pos+1) end
      end
      if t.op~='phi' then
        local function kullan(x)
          if not x then return end
          local it=al(x); ekle_aralik(it,b.bas,pos); it.u[#it.u+1]=pos
        end
        kullan(t.a); kullan(t.b); kullan(t.c)
        if t.kaynasik_yuk then
          local y=f.d[t.kaynasik_yuk]
          kullan(y.a); kullan(y.c)
        end
        if t.args then for _,x in ipairs(t.args) do kullan(x) end end
        if t.dolayli then kullan(t.dolayli) end
      end
    end

    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op~='phi' then break end
      local it=al(id)
      if #it.p>0 then it.p[1]=t.konum+2 end
    end

    for _,s in ipairs(b.ardil) do
      for _,id in ipairs(s.k) do
        local t=f.d[id]
        if t.op~='phi' then break end
        for _,g in ipairs(t.girdi) do
          if g[1]==b then

            local tg=f.d[g[2]]
            local bas=(tg and tg.blok==b and tg.op~='phi' and tg.konum) and tg.konum+2 or b.bas
            local it=al(g[2]); ekle_aralik(it,bas,b.bit); it.u[#it.u+1]=b.bit
          end
        end
      end
    end
  end
  for _,it in pairs(ara) do table.sort(it.u) end
  f.ara=ara; f.sabit_ara=sabit
end

Y.bellek_siniri={['bellek_kopyala']=256,['bellek_taşı']=64,['__t_memset']=256}

function Y.bellek_indir(f,H)
  if not H.blok_bellek then return false end
  local degisti=false
  local function sb(id) local t=f.d[id]; if t and t.op=='sabit' then return t.s end end
  for _,b in ipairs(f.bloklar) do
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='cagri' and t.dis and Y.bellek_siniri[t.dis] and t.args then
        local n=sb(t.args[3])
        local sinir=Y.bellek_siniri[t.dis]
        if n and n>0 and n<=sinir and n%8==0 then
          if t.dis=='__t_memset' then
            if sb(t.args[2])==0 then
              t.op='bsifir'; t.a=t.args[1]; t.boy=n
              t.args=nil; t.dis=nil; t.abi=nil; degisti=true
            end
          else
            t.op='bkopya'; t.a=t.args[1]; t.b=t.args[2]; t.boy=n
            t.tasi=(t.dis=='bellek_taşı'); t.args=nil; t.dis=nil; t.abi=nil
            degisti=true
          end
        end
      end
    end
  end
  return degisti
end

function Y.yuk_ele(f)
  local degisti=false
  for _,b in ipairs(f.bloklar) do
    local gorulen={}
    for _,id in ipairs(b.k) do
      local t=f.d[id]
      if t.op=='yukle' then
        local a=table.concat({tostring(t.a),tostring(t.c),tostring(t.ofset or 0),
                              tostring(t.bit),tostring(t.isaretli),tostring(t.olcek or 1)},'|')
        local onceki=gorulen[a]
        if onceki and f.d[onceki].op=='yukle' then
          t.op='kopya'; t.a=onceki; t.b=nil; t.c=nil; degisti=true
        else
          gorulen[a]=id
        end
      elseif t.op=='sakla' or t.op=='cagri' or t.op=='ic' or t.op=='atomik'
          or t.op=='bkopya' or t.op=='bsifir' then
        gorulen={}
      end
    end
  end
  return degisti
end

local function bos_blok(f,b)
  if #b.k~=1 then return false end
  local t=f.d[b.k[1]]
  return t.op=='dal' and t.hedef or false
end

function Y.kosul_donustur(f)
  local degisti=false
  local liste={}
  for _,b in ipairs(f.duz) do liste[#liste+1]=b end
  for _,b in ipairs(liste) do
    local son=b.son and f.d[b.son]
    if son and son.op=='kosul' and b.sira then
      local T,F=son.dogru,son.yanlis
      local jt=T and bos_blok(f,T)
      local jf=F and bos_blok(f,F)
      local J,vt_blok,vf_blok
      if jt and jf and jt==jf and #T.oncul==1 and #F.oncul==1 then
        J=jt; vt_blok=T; vf_blok=F
      elseif jt==F and #T.oncul==1 then
        J=F; vt_blok=T; vf_blok=b
      elseif jf==T and #F.oncul==1 then
        J=T; vt_blok=b; vf_blok=F
      end
      if J and J~=b then

        local sayi=0
        for _,o in ipairs(J.oncul) do
          if o==vt_blok or o==vf_blok then sayi=sayi+1 end
        end
        if sayi==#J.oncul then
          local c=son.a
          local yeni_phi={}
          local uygun=true
          for _,id in ipairs(J.k) do
            local t=f.d[id]
            if t.op~='phi' then break end
            local a,bv
            for _,g in ipairs(t.girdi) do
              if g[1]==vt_blok then a=g[2] elseif g[1]==vf_blok then bv=g[2] end
            end
            if not a or not bv then uygun=false end
            yeni_phi[#yeni_phi+1]={id,a,bv}
          end
          if uygun then
            for _,x in ipairs(yeni_phi) do
              local t=f.d[x[1]]
              if x[2]==x[3] then t.op='kopya'; t.a=x[2]; t.girdi=nil
              else t.op='sec'; t.a=c; t.b=x[2]; t.c=x[3]; t.girdi=nil end
            end

            son.op='dal'; son.hedef=J; son.a=nil; son.dogru=nil; son.yanlis=nil
            b.ardil={J}
            local yo={}
            for _,o in ipairs(J.oncul) do
              if o~=vt_blok and o~=vf_blok then yo[#yo+1]=o end
            end
            yo[#yo+1]=b; J.oncul=yo
            if vt_blok~=b then vt_blok.sira=nil end
            if vf_blok~=b then vf_blok.sira=nil end
            degisti=true
          end
        end
      end
    end
  end
  if degisti then
    local y={}
    for _,b in ipairs(f.bloklar) do if b.sira then y[#y+1]=b end end
    f.bloklar=y
  end
  return degisti
end

local function main()

local path=arg[1];local location=1;local locations={}
local function fail(s)
  local at=locations[location] or {path or 'T',location}
  error(s:match(':%d+: ') and s or (at[1]..':'..at[2]..': '..s),0)
end
if path=='--help' or path=='-h' then
  print('T 0.7: lua derleyici/t.lua kaynak.t --arch macos|windows|linux --cpu arm64|x86_64 --instruction auto|scalar|neon|sse2|avx|avx2|avx512|avx512bw --arka yeni|eski --avx512 evet|hayır --opt 0|2 --gom dosya --output dosya')
  return
end
local optimization=2;local symbol_map;local arka='yeni';local dokum;local yb_inline=28
Y.gom={}
local target,platform,instruction,output='arm64','macos',nil,nil
local modern=arg[2] and arg[2]:sub(1,1)=='-'
local emit=modern and 'exe' or 'obj';local explicit_cpu=false
if modern then
  local i=2
  while i<=#arg do
    local flag,value=arg[i],arg[i+1]
    if not value then fail('seçenek değeri eksik: '..flag) end
    if flag=='--opt' then optimization=tonumber(value);if optimization~=0 and optimization~=2 then fail('--opt 0 veya 2 olmalı') end
    elseif flag=='--arch' then platform=value
    elseif flag=='--cpu' then target=value;explicit_cpu=true
    elseif flag=='--emit' then emit=value
    elseif flag=='--instruction' then instruction=value
    elseif flag=='--output' or flag=='-o' then output=value
    elseif flag=='--harita' then symbol_map=value
    elseif flag=='--arka' then arka=value
    elseif flag=='--avx512' then Y.avx512_auto=(value=='evet' or value=='1')
    elseif flag=='--dokum' then dokum=value
    elseif flag=='--inline' then yb_inline=tonumber(value)
    elseif flag=='--gom' then
      local n,f=value:match('^([^=]+)=(.+)$')
      if n then Y.gom[n]=f else Y.gom_dosya=value end
    else fail('bilinmeyen seçenek: '..flag) end
    i=i+2
  end
  if platform=='windows' then
    if explicit_cpu and target~='x86_64' then fail('Windows hedefi şu an yalnızca x86_64') end
    target='x86_64'
  end
else
  if #arg>3 then fail('fazla konumsal argüman') end
  target=arg[2] or target;output=arg[3]
end
if platform~='macos' and platform~='windows' and platform~='linux' then fail('--arch macos, windows veya linux olmalı') end
if target~='arm64' and target~='x86_64' then fail('--cpu arm64 veya x86_64 olmalı') end
local windows=platform=='windows'
local linux=platform=='linux'
if emit~='obj' and emit~='exe' then fail('--emit obj veya exe olmalı') end
if windows and not modern then emit='exe' end
if (windows or linux) and emit~='exe' then fail('Windows/Linux çıktısı doğrudan çalıştırılabilir; --emit exe kullanın') end
instruction=instruction or (target=='arm64' and 'neon' or 'auto')
if target=='arm64' and instruction=='auto' then instruction='neon' end
if instruction=='sse' then instruction='sse2' end
if instruction=='avx-512' then instruction='avx512' end
if instruction=='avx-512bw' then instruction='avx512bw' end
local levels={auto=1,scalar=0,sse2=1,avx=2,avx2=3,avx512=4,avx512bw=4,neon=1}
if not levels[instruction] then fail('bilinmeyen komut kümesi: '..instruction) end
if (target=='arm64' and instruction~='neon' and instruction~='scalar') or
   (target=='x86_64' and instruction=='neon') then fail('CPU ve komut kümesi uyuşmuyor') end
output=output or (windows and 'program.exe' or (emit=='exe' and 'program' or 'program.o'))
if not path then fail('kullanım: lua derleyici/t.lua kaynak.t --arch macos|windows|linux --cpu arm64|x86_64 --instruction neon|sse|avx|avx2|avx512 --output çıktı') end
local f=assert(io.open(path,'rb')); local source=f:read('a'); f:close()

local runtime_common=[[
işlev hata_kodu():i64 { dön i64(i32_oku(__t_errno(),0)); }
işlev hata_sıfırla():i64 { i32_yaz(__t_errno(),0,i32(0));dön 0; }

işlev __t_hat(kare:i64,dolu:u64,maske:u64):u64 {
    taş:=u64(1)<<u64(kare);o:=dolu&maske;
    dön ((o-(taş<<u64(1))) ^ bit_ters(bit_ters(o)-(bit_ters(taş)<<u64(1)))) & maske;
}
işlev satranç_kale(kare:i64,dolu:u64):u64 {
    eğer kare<0 || kare>63 { dön u64(0); }
    sıra:=u64(255)<<u64(kare&56);dikey:=u64(0x0101010101010101)<<u64(kare&7);
    dön __t_hat(kare,dolu,sıra) | __t_hat(kare,dolu,dikey);
}
işlev satranç_fil(kare:i64,dolu:u64):u64 {
    eğer kare<0 || kare>63 { dön u64(0); }
    d:=(kare/8)-(kare&7);a:=(kare/8)+(kare&7)-7;
    çapraz:=u64(0x8040201008040201);ters:=u64(0x0102040810204080);
    eğer d>=0 { çapraz=çapraz<<u64(d*8); } yoksa { çapraz=çapraz>>u64(-d*8); }
    eğer a>=0 { ters=ters<<u64(a*8); } yoksa { ters=ters>>u64(-a*8); }
    dön __t_hat(kare,dolu,çapraz) | __t_hat(kare,dolu,ters);
}
işlev satranç_at(kare:i64):u64 {
    eğer kare<0 || kare>63 { dön u64(0); }
    b:=u64(1)<<u64(kare);a:=u64(0xfefefefefefefefe);h:=u64(0x7f7f7f7f7f7f7f7f);
    ab:=u64(0xfcfcfcfcfcfcfcfc);gh:=u64(0x3f3f3f3f3f3f3f3f);
    dön ((b<<u64(17))&a)|((b<<u64(15))&h)|((b<<u64(10))&ab)|((b<<u64(6))&gh)
       |((b>>u64(15))&a)|((b>>u64(17))&h)|((b>>u64(6))&ab)|((b>>u64(10))&gh);
}
işlev satranç_şah(kare:i64):u64 {
    eğer kare<0 || kare>63 { dön u64(0); }
    b:=u64(1)<<u64(kare);a:=u64(0xfefefefefefefefe);h:=u64(0x7f7f7f7f7f7f7f7f);
    yatay:=((b<<u64(1))&a)|((b>>u64(1))&h);geniş:=yatay|b;
    dön yatay|(geniş<<u64(8))|(geniş>>u64(8));
}
işlev satranç_piyon(kare:i64,renk:i64):u64 {
    eğer kare<0 || kare>63 { dön u64(0); }
    b:=u64(1)<<u64(kare);a:=u64(0xfefefefefefefefe);h:=u64(0x7f7f7f7f7f7f7f7f);
    eğer renk==0 { dön ((b<<u64(9))&a)|((b<<u64(7))&h); }
    dön ((b>>u64(7))&a)|((b>>u64(9))&h);
}
işlev enaz(a:i64,b:i64):i64 { eğer a<b { dön a; } dön b; }
işlev ençok(a:i64,b:i64):i64 { eğer a>b { dön a; } dön b; }
işlev sınırla(x:i64,a:i64,b:i64):i64 { dön ençok(a,enaz(x,b)); }

işlev kaydır_kırp_i16_u8(dst:adres,src:adres,n:i64,k:i64,üst:i64):i64 {
    eğer n<0 || k<0 || k>15 || üst<0 || üst>255 { dön -1; }
    için(i:=0;i<n;i+=1) {
        v:=i64(i16_oku(src,i)); eğer v<0 { v=0; }
        v=v>>k; eğer v>üst { v=üst; } bayt_yaz(dst,i,v);
    }
    dön 0;
}

işlev böl_ekle_i32_u8(dst:adres,src:adres,n:i64,bölen:i64,ek:i64):i64 {
    eğer n<0 || bölen<1 || bölen>2147483647 { dön -1; }
    için(i:=0;i<n;i+=1) { bayt_yaz(dst,i,i64(i32_oku(src,i))/bölen+ek); }
    dön 0;
}
işlev karışım4_i32(dst:adres,a:adres,b:adres,c:adres,d:adres,n:i64,w0:i64,w1:i64,w2:i64,w3:i64):i64 {
    eğer n<0 { dön -1; }
    için(i:=0;i<n;i+=1) {
        v:=i64(i32_oku(a,i))*w0+i64(i32_oku(b,i))*w1+i64(i32_oku(c,i))*w2+i64(i32_oku(d,i))*w3;
        i32_yaz(dst,i,i32(v));
    }
    dön 0;
}

işlev __t_array_alloc(n:i64, genişlik:i64):adres {
    eğer n < 0 || u64(n) > u64(9223372036854775807) / u64(genişlik) { dön 0; }
    dön bellek_ayır(n * genişlik);
}
işlev bellek_sıfırla(p:adres, n:i64):adres { dön __t_memset(p, 0, n); }
işlev metin_eşit(a:adres, b:adres):i64 { dön __t_strcmp(a,b)==0; }
işlev metin_başlar(a:adres, önek:adres):i64 { dön __t_strncmp(a,önek,metin_uzunluğu(önek))==0; }
işlev sayı_metin(tampon:adres, değer:i64):i64 {
    geçici:=dizi(32); n:=0; x:=u64(değer); negatif:=değer<0;
    eğer negatif { x=u64(0)-x; }
    iken 1 {
        bayt_yaz(geçici,n,i64(x%u64(10))+48);n=n+1;x=x/u64(10);
        eğer x==u64(0) { kır; }
    }
    boy:=n+negatif;i:=0;
    eğer negatif { bayt_yaz(tampon,0,45);i=1; }
    iken n>0 { n=n-1;bayt_yaz(tampon,i,bayt_oku(geçici,n));i=i+1; }
    bayt_yaz(tampon,boy,0);dön boy;
}
işlev sayı_yazdır(n:i64):i64 { b:=dizi(32);sayı_metin(b,n);dön satır_yaz(b); }
işlev uci_satır_oku(p:adres, kapasite:i64):i64 {
    eğer kapasite<1 { dön -1; }
    n:=0;taştı:=0;c:=karakter_oku();
    iken c != -1 && c != 10 {
        eğer c!=13 {
            eğer n<kapasite-1 { bayt_yaz(p,n,c);n=n+1; } yoksa { taştı=1; }
        }
        c=karakter_oku();
    }
    bayt_yaz(p,n,0);
    eğer taştı { bayt_yaz(p,0,0);dön -1; }
    eğer c == -1 && n == 0 { dön 0; }
    dön 1;
}
işlev döndür_sola(x:u64, n:i64):u64 {
    s:=u64(n&63);dön (x<<s) | (x>>((u64(64)-s)&u64(63)));
}
işlev rastgele64(durum:adres):u64 {
    x:=u64_oku(durum,0)+u64(0x9e3779b97f4a7c15);u64_yaz(durum,0,x);
    x=(x^(x>>u64(30)))*u64(0xbf58476d1ce4e5b9);
    x=(x^(x>>u64(27)))*u64(0x94d049bb133111eb);
    dön x^(x>>u64(31));
}
işlev kilit_al(p:adres):i64 {
    iken atomik_kıyas_değiştir(p,0,1)!=0 {
        iken atomik_oku(p)!=0 { işlemci_bekle(); }
    }
    dön 0;
}
işlev kilit_bırak(p:adres):i64 { dön atomik_yaz(p,0); }
işlev nokta_i16(a:adres,b:adres,n:i64):i64 {
    toplam:=0;i:=0;
    iken n-i>=8 { toplam=toplam+nokta8_i16(adres_ekle(a,i*2),adres_ekle(b,i*2));i=i+8; }
    iken i<n { toplam=toplam+i64(i16_oku(a,i))*i64(i16_oku(b,i));i=i+1; }
    dön toplam;
}

işlev dosya_oku(p:adres, n:i64, f:dosya):i64 { dön __t_fread(p, 1, n, f); }
işlev dosya_yaz(p:adres, n:i64, f:dosya):i64 { dön __t_fwrite(p, 1, n, f); }

işlev standart_çıktı_aç():dosya {
    fd:=__t_dup(1);eğer fd<0 { dön 0; }
    f:=__t_fdopen(fd,"wb");eğer f==0 { __t_close(fd); } dön f;
}
]]
local runtime_mac=[[
işlev mutex_kur(p:adres):i64 { dön __t_mutex_init(p,0); }
işlev mutex_al(p:adres):i64 { dön __t_mutex_lock(p); }
işlev mutex_bırak(p:adres):i64 { dön __t_mutex_unlock(p); }
işlev mutex_sil(p:adres):i64 { dön __t_mutex_destroy(p); }
işlev koşul_kur(p:adres):i64 { dön __t_cond_init(p,0); }
işlev koşul_bekle(p:adres,kilit:adres):i64 { dön __t_cond_wait(p,kilit); }
işlev koşul_uyandır(p:adres):i64 { dön __t_cond_signal(p); }
işlev koşul_hepsini_uyandır(p:adres):i64 { dön __t_cond_broadcast(p); }
işlev koşul_sil(p:adres):i64 { dön __t_cond_destroy(p); }

işlev dosya_eşle(f:dosya, n:i64):adres {
    eğer n<=0 { dön 0; }
    p:=__t_mmap(0,n,1,2,__t_fileno(f),0);
    eğer adres_bitleri(p)==u64(-1) { dön 0; }
    dön p;
}
işlev dosya_eşlemeyi_bırak(p:adres,n:i64):i64 { dön __t_munmap(p,n); }

işlev hizalı_ayır(n:i64,hiza:i64):adres {
    eğer n<0 || hiza<8 || (hiza&(hiza-1))!=0 { dön 0; }
    sonuç:=dizi(8);adres_yaz(sonuç,0,0);
    eğer __t_posix_memalign(sonuç,hiza,n)!=0 { dön 0; }
    dön adres_oku(sonuç,0);
}
işlev hizalı_bırak(p:adres):i64 { dön bellek_bırak(p); }
işlev uyu_ns(n:i64):i64 {
    eğer n<0 { dön -1; }
    t:=dizi(16);sayı_yaz(t,0,n/1000000000);sayı_yaz(t,1,n%1000000000);
    iken __t_nanosleep(t,t)!=0 { eğer i32_oku(__t_errno(),0)!=i32(4) { dön -1; } }
    dön 0;
}

işlev iş_başlat(kayıt:adres, giriş:işçi, veri:adres):i64 {
    dön __t_pthread_create(kayıt, 0, giriş, veri);
}
işlev iş_bekle(kayıt:adres):i64 {
    dön __t_pthread_join(sayı_oku(kayıt, 0), 0);
}
]]
runtime_mac=runtime_mac..[[
işlev zaman_ns():i64 {
    t:=dizi(16);
    eğer __t_clock_gettime(]]..(linux and '1' or '6')..[[,t)!=0 { dön -1; }
    dön sayı_oku(t,0)*1000000000+sayı_oku(t,1);
}
]]..(linux and [[
işlev işlemci_sayısı():i64 { dön __t_get_nprocs(); }
]] or [[
işlev işlemci_sayısı():i64 {
    n:=dizi(8);boy:=dizi(8);sayı_yaz(boy,0,4);
    eğer __t_sysctlbyname("hw.logicalcpu",n,boy,0,0)!=0 { dön -1; }
    dön i64(i32_oku(n,0));
}
]])
local runtime_windows=[[
işlev dosya_konumu(f:dosya):i64 {
    p:=dizi(8);eğer __t_fgetpos(f,p)!=0 { dön -1; } dön sayı_oku(p,0);
}
işlev mutex_kur(p:adres):i64 { dön __t_srw_init(p); }
işlev mutex_al(p:adres):i64 { dön __t_srw_lock(p); }
işlev mutex_bırak(p:adres):i64 { dön __t_srw_unlock(p); }
işlev mutex_sil(p:adres):i64 { dön 0; }
işlev koşul_kur(p:adres):i64 { dön __t_cv_init(p); }
işlev koşul_bekle(p:adres,kilit:adres):i64 {
    eğer __t_cv_wait(p,kilit,4294967295,0)==0 { dön -1; } dön 0;
}
işlev koşul_uyandır(p:adres):i64 { dön __t_cv_wake(p); }
işlev koşul_hepsini_uyandır(p:adres):i64 { dön __t_cv_wake_all(p); }
işlev koşul_sil(p:adres):i64 { dön 0; }

işlev dosya_eşle(f:dosya, n:i64):adres {
    eğer n<=0 { dön 0; }
    h:=__t_create_mapping(__t_oshandle(__t_fileno(f)),0,2,0,0,0);
    eğer h==0 { dön 0; }
    p:=__t_map_view(h,4,0,0,n);__t_close(h);dön p;
}
işlev dosya_eşlemeyi_bırak(p:adres,n:i64):i64 {
    eğer __t_unmap_view(p)==0 { dön -1; } dön 0;
}

işlev hizalı_ayır(n:i64,hiza:i64):adres {
    eğer n<0 || hiza<8 || (hiza&(hiza-1))!=0 { dön 0; }
    dön __t_aligned_malloc(n,hiza);
}
işlev hizalı_bırak(p:adres):i64 { dön __t_aligned_free(p); }
işlev uyu_ns(n:i64):i64 {
    eğer n<0 || n>4294967294000000 { dön -1; }
    __t_sleep(n/1000000 + i64(n%1000000!=0));dön 0;
}
işlev zaman_ns():i64 {
    c:=dizi(8);f:=dizi(8);
    eğer __t_qpc(c)==0 || __t_qpf(f)==0 { dön -1; }
    x:=sayı_oku(c,0);hz:=sayı_oku(f,0);
    eğer hz<=0 || hz>1000000000 { dön -1; }
    dön (x/hz)*1000000000 + ((x%hz)*1000000000)/hz;
}
işlev işlemci_sayısı():i64 { dön __t_cpu_count(65535); }

işlev iş_başlat(kayıt:adres, giriş:işçi, veri:adres):i64 {
    h := __t_beginthreadex(0, 0, giriş, veri, 0, 0);
    eğer h == 0 { dön -1; }
    sayı_yaz(kayıt, 0, h);
    dön 0;
}
işlev iş_bekle(kayıt:adres):i64 {
    h := sayı_oku(kayıt, 0);
    r := __t_wait(h, 4294967295);
    eğer r != 0 { dön i64(r); }
    eğer __t_close(h) == 0 { dön -1; }
    dön 0;
}
işlev __t_giriş():i64 { __t_exit(ana()); dön 0; }
]]
runtime_common=runtime_common..[[

işlev nokta_u8_i8_i32(a:adres,b:adres,n:i64):i32 { dön i32(nokta_u8_i8(a,b,n)); }
işlev yoğun_u8_i8_i32(çıktı:adres,girdi:adres,ağırlık:adres,sapma:adres,giriş:i64,çıkış:i64):i64 {
    eğer giriş<0 || çıkış<0 || (çıkış!=0 && giriş>9223372036854775807/çıkış) || çıkış>2305843009213693951 { dön -1; }
    için (o:=0;o<çıkış;o+=1) {
        b:=seç(sapma==0,i32(0),i32_oku(sapma,o));
        i32_yaz(çıktı,o,i32(i64(b)+i64(nokta_u8_i8_i32(girdi,adres_ekle(ağırlık,o*giriş),giriş))));
    } dön 0;
}

işlev __t_yoğun_blok_düz(çıktı:adres,girdi:adres,ağırlık:adres,sapma:adres,giriş:i64,çıkış:i64):i64 {
    eğer giriş<0 || giriş%8!=0 || çıkış<=0 || çıkış%16!=0 { dön -1; }
    grup:=giriş/4;
    için (ob:=0;ob<çıkış/16;ob+=1) {
        için (o:=0;o<16;o+=1) {
            top:=i64(i32_oku(sapma,ob*16+o));
            için (g:=0;g<grup;g+=1) {
                w:=adres_ekle(ağırlık,((ob*grup+g)*16+o)*4);
                için (j:=0;j<4;j+=1) { top+=(bayt_oku(girdi,g*4+j)-128)*i64(i8_oku(w,j)); }
            }
            i32_yaz(çıktı,ob*16+o,i32(top));
        }
    } dön 0;
}

işlev __t_karışım_düz(dst:adres,kaynak:adres,adım:i64,n:i64,ağırlık:adres,m:i64):i64 {
    eğer n<0 || n%16!=0 || m<=0 { dön -1; }
    için (i:=0;i<n;i+=1) {
        v:=0;
        için (k:=0;k<m;k+=1) { v+=i64(i32_oku(adres_ekle(kaynak,k*adım),i))*sayı_oku(ağırlık,k); }
        i32_yaz(dst,i,i32(v));
    } dön 0;
}

işlev __t_topla_çıkar_i16_düz(dst:adres,src:adres,ekle:adres,çıkar:adres,n:i64):i64 {
    eğer n<0 { dön -1; }
    için (i:=0;i<n;i+=1) { i16_yaz(dst,i,i16(i64(i16_oku(src,i))+i64(i16_oku(ekle,i))-i64(i16_oku(çıkar,i)))); } dön 0;
}
işlev __t_taşlar_havuz_i16_düz(satırlar:adres,sayılar:adres,adet:i64,toplam:adres,enb:adres):i64 {
    için (i:=0;i<32;i+=1) { i32_yaz(toplam,i,i32(0)); i16_yaz(enb,i,i16(0)); }
    satır:=0;
    için (t:=0;t<adet;t+=1) {
        n:=bayt_oku(sayılar,t);
        için (i:=0;i<32;i+=1) { v:=0; için (r:=0;r<n;r+=1) { v=v+i64(i16_oku(adres_oku(satırlar,satır+r),i)); } eğer v<0 { v=0; } i32_yaz(toplam,i,i32(i64(i32_oku(toplam,i))+v)); eğer v>i64(i16_oku(enb,i)) { i16_yaz(enb,i,i16(v)); } }
        satır+=n;
    }
    dön 0;
}
işlev __t_taş_havuz_i16_düz(satırlar:adres,adet:i64,toplam:adres,enb:adres):i64 {
    için (i:=0;i<32;i+=1) { v:=0; için (j:=0;j<adet;j+=1) { v=v+i64(i16_oku(adres_oku(satırlar,j),i)); } eğer v<0 { v=0; } i32_yaz(toplam,i,i32(i64(i32_oku(toplam,i))+v)); eğer v>i64(i16_oku(enb,i)) { i16_yaz(enb,i,i16(v)); } } dön 0;
}
işlev __t_havuz_i16_düz(h:adres,toplam:adres,enb:adres,n:i64):i64 {
    için (i:=0;i<n;i+=1) { v:=i64(i16_oku(h,i)); eğer v<0 { v=0; } i16_yaz(h,i,i16(v)); i32_yaz(toplam,i,i32(i64(i32_oku(toplam,i))+v)); eğer v>i64(i16_oku(enb,i)) { i16_yaz(enb,i,i16(v)); } } dön 0;
}
işlev __t_yoğun_i16_düz(y:adres,x:adres,w:adres,giriş:i64,çıkış:i64):i64 {
    için (o:=0;o<çıkış;o+=1) { t:=0; için (i:=0;i<giriş;i+=1) { t=t+i64(i16_oku(x,i))*i64(i16_oku(w,o*giriş+i)); } i32_yaz(y,o,i32(t)); } dön 0;
}
işlev __t_ekle_relu512_i32_i16_düz(dst:adres,src:adres,sapma:adres,n:i64):i64 {
    eğer n<0 || n%8!=0 { dön -1; }
    için (i:=0;i<n;i+=1) { v:=i64(i32_oku(src,i))+i64(i32_oku(sapma,i)); i16_yaz(dst,i,i16(seç(v<0,0,v/512))); }
    dön 0;
}
işlev __t_topla_çıkar_i32_düz(dst:adres,src:adres,ekle:adres,çıkar:adres,n:i64):i64 {
    eğer n<0 { dön -1; }
    için (i:=0;i<n;i+=1) { i32_yaz(dst,i,i32(i64(i32_oku(src,i))+i64(i32_oku(ekle,i))-i64(i32_oku(çıkar,i)))); } dön 0;
}
işlev seyrek_indis_u8(girdi:adres,n:i64,indis:adres,kapasite:i64):i64 {
    eğer n<0 || n>4294967295 || kapasite<0 { dön -1; } k:=0;
    için (i:=0;i<n;i+=1) {
        eğer u8_oku(girdi,i)!=u8(0) {
            eğer k>=kapasite { dön -1; } u32_yaz(indis,k,u32(i));k+=1;
        }
    } dön k;
}
işlev seyrek_u8_i8_i32(çıktı:adres,girdi:adres,ağırlık:adres,sapma:adres,giriş:i64,çıkış:i64):i64 {
    eğer giriş<0 || çıkış<0 || (çıkış!=0 && giriş>9223372036854775807/çıkış) || çıkış>2305843009213693951 { dön -1; }
    eğer çıkış==0 { dön 0; }
    eğer sapma==0 { bellek_sıfırla(çıktı,çıkış*4); } yoksa { bellek_taşı(çıktı,sapma,çıkış*4); }
    için (i:=0;i<giriş;i+=1) {
        x:=i64(u8_oku(girdi,i));eğer x!=0 { katla_u8_i8_i32(çıktı,adres_ekle(ağırlık,i*çıkış),çıkış,x); }
    } dön 0;
}
işlev seyrek_indis_u8_i8_i32(çıktı:adres,girdi:adres,ağırlık:adres,sapma:adres,giriş:i64,çıkış:i64,indis:adres,adet:i64):i64 {
    eğer giriş<0 || giriş>4294967295 || çıkış<0 || adet<0 || adet>giriş || (çıkış!=0 && giriş>9223372036854775807/çıkış) || çıkış>2305843009213693951 { dön -1; }
    için (j:=0;j<adet;j+=1) { eğer i64(u32_oku(indis,j))>=giriş { dön -1; } }
    eğer çıkış==0 { dön 0; }
    eğer sapma==0 { bellek_sıfırla(çıktı,çıkış*4); } yoksa { bellek_taşı(çıktı,sapma,çıkış*4); }
    için (j:=0;j<adet;j+=1) {
        i:=i64(u32_oku(indis,j));x:=i64(u8_oku(girdi,i));
        eğer x!=0 { katla_u8_i8_i32(çıktı,adres_ekle(ağırlık,i*çıkış),çıkış,x); }
    } dön 0;
}
]]

runtime_common=runtime_common..[[
genel __t_argc:i64=0;
genel __t_argv:adres=0;
işlev argüman_sayısı():i64 { dön __t_argc; }
]]
if windows then runtime_windows=runtime_windows..[[
işlev dosya_aç_utf8(yol:adres,kip:adres,tampon:adres,kapasite:i64):dosya {
    n:=__t_utf8_wide(65001,8,yol,-1,0,0);m:=__t_utf8_wide(65001,8,kip,-1,0,0);
    eğer n<=0 || m<=0 || kapasite<(n+m)*2 { dön 0; }
    son:=adres_ekle(tampon,n*2);
    eğer __t_utf8_wide(65001,8,yol,-1,tampon,n)!=n || __t_utf8_wide(65001,8,kip,-1,son,m)!=m { dön 0; }
    dön __t_wfopen(tampon,son);
}
işlev __t_args_init():i64 {
    env:adres:=0;info:i32:=i32(0);n:i32:=i32(0);
    r:=__t_wgetmainargs(&n,&__t_argv,&env,0,&info);
    eğer r!=0 { dön -1; } __t_argc=i64(n);dön 0;
}
işlev argüman_boyu(i:i64):i64 {
    eğer i<0 || i>=__t_argc { dön -1; }
    n:=__t_wide_utf8(65001,128,adres_oku(__t_argv,i),-1,0,0,0,0);
    eğer n<=0 { dön -1; } dön n-1;
}
işlev argüman_oku(i:i64,p:adres,kapasite:i64):i64 {
    n:=argüman_boyu(i);eğer n<0 || kapasite<=n || kapasite>2147483647 { dön -1; }
    r:=__t_wide_utf8(65001,128,adres_oku(__t_argv,i),-1,p,kapasite,0,0);
    eğer r<=0 { dön -1; } dön r-1;
}
işlev iş_başlat_boy(kayıt:adres,giriş:işçi,veri:adres,boy:i64):i64 {
    eğer boy<=0 || boy>4294967295 { dön -1; }
    h:=__t_beginthreadex(0,boy,giriş,veri,65536,0);eğer h==0 { dön -1; }
    sayı_yaz(kayıt,0,h);dön 0;
}
işlev iş_bağla(grup:i64,maske:u64):i64 {
    eğer grup<0 || grup>65535 || maske==u64(0) { dön -1; }
    a:=dizi(16);bellek_sıfırla(a,16);u64_yaz(a,0,maske);u16_yaz(a,4,u16(grup));
    eğer __t_affinity(-2,a,0)==0 { dön -1; } dön 0;
}
işlev iş_maskesi(grup:i64):u64 {
    a:=dizi(16);eğer __t_get_affinity(-2,a)==0 { dön u64(0); }
    eğer i64(u16_oku(a,4))!=grup { dön u64(0); } dön u64_oku(a,0);
}
işlev bölge_ayır(n:i64):adres { eğer n<=0 { dön 0; } dön __t_virtual_alloc(0,n,12288,4); }
işlev bölge_bırak(p:adres,n:i64):i64 { eğer p==0 || n<=0 { dön -1; } eğer __t_virtual_free(p,0,32768)==0 { dön -1; } dön 0; }
işlev numa_ayır(n:i64,düğüm:i64):adres {
    eğer n<=0 || düğüm<0 || düğüm>65535 { dön 0; }
    dön __t_numa_alloc(-1,0,n,12288,4,düğüm);
}
işlev büyük_sayfa_ayır(n:i64,üs:i64):adres {
    eğer üs<12 || üs>30 || n<=0 { dön 0; }
    boy:=1<<üs;eğer n%boy!=0 || __t_large_min()!=boy { dön 0; }
    dön __t_virtual_alloc(0,n,536883200,4);
}
işlev sistem_hata():i64 { dön i64(__t_last_error()); }
]] else
runtime_mac=runtime_mac..[[
işlev dosya_aç_utf8(yol:adres,kip:adres,tampon:adres,kapasite:i64):dosya { dön dosya_aç(yol,kip); }
işlev __t_main(n:i64,v:adres):i64 { __t_argc=n;__t_argv=v;dön ana(); }
işlev argüman_boyu(i:i64):i64 { eğer i<0 || i>=__t_argc { dön -1; } dön metin_uzunluğu(adres_oku(__t_argv,i)); }
işlev argüman_oku(i:i64,p:adres,kapasite:i64):i64 {
    n:=argüman_boyu(i);eğer n<0 || kapasite<=n { dön -1; }
    bellek_kopyala(p,adres_oku(__t_argv,i),n+1);dön n;
}
işlev iş_başlat_boy(kayıt:adres,giriş:işçi,veri:adres,boy:i64):i64 {
    eğer boy<=0 { dön -1; } a:=dizi(64);r:=__t_attr_init(a);eğer r!=0 { dön r; }
    ertele { __t_attr_destroy(a); }
    r=__t_attr_stack(a,boy);eğer r!=0 { dön r; }
    dön __t_pthread_create(kayıt,a,giriş,veri);
}
işlev bölge_bırak(p:adres,n:i64):i64 { eğer p==0 || n<=0 { dön -1; } dön __t_munmap(p,n); }
işlev sistem_hata():i64 { dön hata_kodu(); }
]]..(linux and [[
işlev bölge_ayır(n:i64):adres {
    eğer n<=0 { dön 0; } p:=__t_mmap(0,n,3,34,-1,0);eğer adres_bitleri(p)==u64(-1) { dön 0; } dön p;
}
işlev iş_bağla(grup:i64,maske:u64):i64 {
    eğer grup<0 || grup>=1024 || maske==u64(0) { dön -1; }
    a:=dizi(8192);bellek_sıfırla(a,8192);u64_yaz(a,grup,maske);dön __t_set_affinity(0,8192,a);
}
işlev iş_maskesi(grup:i64):u64 {
    eğer grup<0 || grup>=1024 { dön u64(0); }
    a:=dizi(8192);bellek_sıfırla(a,8192);eğer __t_get_affinity(0,8192,a)!=0 { dön u64(0); } dön u64_oku(a,grup);
}
işlev numa_ayır(n:i64,düğüm:i64):adres {
    eğer n<=0 || düğüm<0 || düğüm>=65536 { dön 0; }
    a:=dizi(8192);bellek_sıfırla(a,8192);u64_yaz(a,düğüm/64,u64(1)<<u64(düğüm%64));
    p:=bölge_ayır(n);eğer p==0 { dön 0; }
    eğer __t_syscall(]]..(target=='arm64' and '235' or '237')..[[,p,n,1,a,düğüm+1,0)!=0 { hata:=hata_kodu();bölge_bırak(p,n);i32_yaz(__t_errno(),0,i32(hata));dön 0; }
    dön p;
}
işlev büyük_sayfa_ayır(n:i64,üs:i64):adres {
    eğer üs<12 || üs>30 || n<=0 { dön 0; } boy:=1<<üs;eğer n%boy!=0 { dön 0; }
    p:=__t_mmap(0,n,3,34|262144|(üs<<26),-1,0);eğer adres_bitleri(p)==u64(-1) { dön 0; } dön p;
}
]] or [[
işlev bölge_ayır(n:i64):adres {
    eğer n<=0 { dön 0; } p:=__t_mmap(0,n,3,4098,-1,0);eğer adres_bitleri(p)==u64(-1) { dön 0; } dön p;
}

işlev iş_bağla(grup:i64,maske:u64):i64 { i32_yaz(__t_errno(),0,i32(45));dön -1; }
işlev iş_maskesi(grup:i64):u64 { i32_yaz(__t_errno(),0,i32(45));dön u64(0); }
işlev numa_ayır(n:i64,düğüm:i64):adres { i32_yaz(__t_errno(),0,i32(45));dön 0; }
işlev büyük_sayfa_ayır(n:i64,üs:i64):adres {
    eğer üs!=21 || n<=0 || n%2097152!=0 { dön 0; }
    p:=__t_mmap(0,n,3,4098,131072,0);eğer adres_bitleri(p)==u64(-1) { dön 0; } dön p;
}
]])
end

if target=='arm64' then
  if linux then
    runtime_common=runtime_common..[[
işlev __t_arm_features():u64 {
    dön u64(32)|seç((__t_getauxval(u64(16))&u64(1048576))!=u64(0),u64(64),u64(0));
}
]]
  else
    runtime_common=runtime_common..[[
işlev __t_arm_features():u64 {
    değer:i32:=i32(0); boy:u64:=u64(4);
    eğer __t_sysctlbyname("hw.optional.arm.FEAT_DotProd",&değer,&boy,0,0)==0 && değer!=i32(0) { dön u64(96); }
    dön u64(32);
}
]]
  end
end
local required_features=({auto=1,scalar=0,sse2=1,avx=3,avx2=7,avx512=15,avx512bw=31,neon=32})[instruction]
runtime_common=runtime_common..'\nişlev komut_kümesi_uygun():i64 { dön (işlemci_özellikleri() & u64('..required_features..')) == u64('..required_features..'); }\n'
if instruction=='auto' or instruction=='avx512' or instruction=='avx512bw' or (target=='arm64' and instruction=='neon') then runtime_common=runtime_common..'\ngenel __t_cpu_cache:u64=0;\n' end
local tokens={}
do
local function lex(source,file,internal)
local tokens={};local pos,line=1,1;local lines={}
local function at(n)
  if not lines[n] then locations[#locations+1]={file,n};lines[n]=#locations end
  return lines[n]
end
while pos<=#source do
  location=at(line)
  local c=source:sub(pos,pos)
  if c:match('%s') then if c=='\n' then line=line+1 end; pos=pos+1
  elseif source:sub(pos,pos+1)=='/*' then
    local depth=1;pos=pos+2
    while depth>0 do
      if pos>#source then fail('kapanmamış blok yorumu') end
      local pair=source:sub(pos,pos+1)
      if pair=='/*' then depth=depth+1;pos=pos+2
      elseif pair=='*/' then depth=depth-1;pos=pos+2
      else if source:sub(pos,pos)=='\n' then line=line+1 end;pos=pos+1 end
    end
  elseif source:sub(pos,pos+1)=='//' then pos=source:find('\n',pos,true) or (#source+1)
  elseif c=='"' then
    local start=line;local value={};pos=pos+1
    while pos<=#source and source:sub(pos,pos)~='"' do
      local ch=source:sub(pos,pos)
      if ch=='\\' then
        pos=pos+1;ch=source:sub(pos,pos)
        ch=({n='\n',r='\r',t='\t',['\\']='\\',['"']='"'})[ch]
        if not ch then fail('geçersiz metin kaçışı') end
      elseif ch=='\n' then line=line+1 end
      value[#value+1]=ch;pos=pos+1
    end
    if pos>#source then fail('kapanmamış metin') end
    pos=pos+1;tokens[#tokens+1]={'<metin>',at(start),table.concat(value)}
  else
    local s=source:match('^0[xX]%x+',pos) or source:match('^%d+%.%d+[eE][+-]?%d+',pos) or source:match('^%d+%.%d+',pos) or source:match('^%d+[eE][+-]?%d+',pos) or source:match('^%d+',pos) or source:match('^[%a_\128-\255][%w_\128-\255]*',pos)
    if not s then
      local two=source:sub(pos,pos+1)
      s=({['+=']=true,['-=']=true,['*=']=true,['/=']=true,['%=']=true,['&=']=true,['|=']=true,['^=']=true,['::']=true,[':=']=true,['==']=true,['!=']=true,['<=']=true,['>=']=true,['<<']=true,['>>']=true,['&&']=true,['||']=true})[two] and two or c
      if not s:match('^[%w_\128-\255]+$') and not ({['+=']=1,['-=']=1,['*=']=1,['/=']=1,['%=']=1,['&=']=1,['|=']=1,['^=']=1,['::']=1,[':=']=1,['==']=1,['!=']=1,['<=']=1,['>=']=1,['+']=1,['-']=1,['*']=1,['<']=1,['>']=1,['=']=1,['(']=1,[')']=1,['{']=1,['}']=1,[';']=1,[':']=1,[',']=1,['&']=1,['|']=1,['^']=1,['~']=1,['<<']=1,['>>']=1,['&&']=1,['||']=1,['!']=1,['/']=1,['%']=1,['.']=1,['[']=1,[']']=1})[s] then fail('geçersiz karakter '..s) end
    end
    if not internal and s:sub(1,4)=='__t_' then fail('__t_ öneki derleyiciye ayrılmıştır') end
    tokens[#tokens+1]={s,at(line)};pos=pos+#s
  end
end
return tokens,at(line)
end
local function normal(p)
  p=p:gsub('\\','/');local root=p:match('^%a:/') or (p:sub(1,1)=='/' and '/' or '')
  local parts={}
  for part in p:sub(#root+1):gmatch('[^/]+') do
    if part=='..' and #parts>0 and parts[#parts]~='..' then parts[#parts]=nil
    elseif part~='.' and part~='' and (part~='..' or root=='') then parts[#parts+1]=part end
  end
  return root..table.concat(parts,'/')
end
local included,active={},{}
local function include(file,contents,depth)
  file=normal(file)
  if active[file] then fail('döngüsel ekle: '..file) end
  if included[file] then return end
  if depth>64 then fail('ekle derinliği 64 sınırını aştı') end
  if not contents then
    local f,err=io.open(file,'rb');if not f then fail('ekle dosyası açılamadı: '..file..' ('..err..')') end
    contents=f:read('a');f:close()
  end
  included[file]=true;active[file]=true
  local list,last=lex(contents,file,false);local i,nesting=1,0
  while i<=#list do
    local t=list[i];location=t[2]
    if t[1]=='ekle' and list[i+1] and list[i+1][1]=='<metin>' then
      if nesting~=0 then fail('ekle yalnızca dosyanın üst düzeyinde kullanılabilir') end
      local name,ending=list[i+1],list[i+2]
      if not name or name[1]~='<metin>' or not ending or ending[1]~=';' then fail('ekle "dosya.tt"; bekleniyordu') end
      local relative=name[3]:gsub('\\','/')
      if relative=='' or relative:find('%z') then fail('geçersiz ekle yolu') end
      local resolved=(relative:sub(1,1)=='/' or relative:match('^%a:/')) and relative or ((file:match('^(.*[/])') or '')..relative)
      include(resolved,nil,depth+1);i=i+3
    else
      if t[1]=='{' then nesting=nesting+1 elseif t[1]=='}' then nesting=nesting-1 end
      tokens[#tokens+1]=t;i=i+1
    end
  end
  active[file]=nil;location=last
end
include(path,source,1)
local runtime,last=lex(runtime_common..(windows and runtime_windows or runtime_mac),'<T çalışma zamanı>',true)
for _,t in ipairs(runtime) do tokens[#tokens+1]=t end
tokens[#tokens+1]={'<son>',last}
end
local ti=1
local function peek() return tokens[ti] and tokens[ti][1] or '<son>' end
local function take(s)
  local t=tokens[ti]
  if not t then fail('beklenmeyen dosya sonu') end
  location=t[2]
  if s and t[1]~=s then fail(s..' bekleniyordu, bulunan '..t[1]) end
  ti=ti+1;return t[1]
end
local precedence={['||']=-1,['&&']=0,['/']=9,['%']=9,['|']=1,['^']=2,['&']=3,['<<']=7,['>>']=7,['==']=5,['!=']=5,['<']=6,['>']=6,['<=']=6,['>=']=6,['+']=8,['-']=8,['*']=9}
local expr,parse_type
local atom
local function primary()
  if peek()=='<metin>' then local v=tokens[ti][3];take();return {'string',v} end
  if peek()=='(' then take();local e=expr(-1);take(')');return e end
  if peek()=='-' then take();if peek()=='9223372036854775808' then take();return {'num',math.mininteger} end;return {'neg',atom()} end
  if peek()=='!' then take();return {'==',atom(),{'num',0}} end
  if peek()=='&' then take();return {'ref',atom()} end
  if peek()=='~' then take();return {'bitnot',atom()} end
  local t=take()
  if t:match('^%d') and not t:match('^0[xX]') and (t:find('.',1,true) or t:find('[eE]')) then return {'real',assert(tonumber(t))} end
  if t:match('^%d+$') or t:match('^0[xX]%x+$') then
    if t:match('^0[xX]') and #t>18 then fail('64 bit hex sabiti taşması') end
    local n=tonumber(t);if not math.type(n) or math.type(n)~='integer' then fail('i64 sabiti taşması: '..t) end
    return {'num',n}
  end
  if not t:match('^[%a_\128-\255][%w_\128-\255]*$') then fail('ifade bekleniyordu: '..t) end
  local types
  if peek()=='::' then
    take();take('[');types={parse_type()}
    while peek()==',' do take();types[#types+1]=parse_type() end
    take(']')
  end
  if peek()=='(' then
    take();local args={}
    if peek()~=')' then repeat args[#args+1]=expr(-1);if peek()~=',' then break end;take(',') until false end
    take(')');return {'call',t,args,typeargs=types}
  end
  if types then return {'generic',t,types} end
  return {'var',t}
end
atom=function()
  local at=tokens[ti][2];local value=primary()
  while peek()=='.' or peek()=='[' do
    if peek()=='.' then take();value={'field',value,take()}
    else take();local i=expr(-1);take(']');value={'index',value,i} end
  end
  value.line=at;return value
end
parse_type=function()
  local t=take()
  if peek()=='[' then take();take(']');t=t..'[]' end
  return t
end
expr=function(min)
  local a=atom()
  while precedence[peek()] and precedence[peek()]>=min do
    local op=take();a={op,a,expr(precedence[op]+1),line=a.line}
  end
  return a
end
local block,statement
local function assignment(terminator)
  local lhs=atom();local n
  if peek()==terminator then n={'eval',lhs}
  else
    local annotation;if peek()==':' then take();annotation=parse_type() end
    local op=take();local compound=op:match('^([+%-%*/%%&|^])=$')
    if compound then
      if annotation then fail('bileşik atamada tür belirtilmez') end
      n={'update',lhs,expr(-1),compound}
    elseif op==':=' or op=='=' then
      if lhs[1]=='var' then n={op,lhs[2],expr(-1),annotation}
      else
        if op~='=' or annotation or (lhs[1]~='field' and lhs[1]~='index') then fail('alan/dizi ataması = ister') end
        n={'store',lhs,expr(-1)}
      end
    else fail('atama bekleniyordu') end
  end
  if terminator==';' then take(';') end
  return n
end
statement=function()
  local at=tokens[ti][2];local k=peek();local n
  if k=='{' then return {'scope',block()} end
  take()
  if k=='kır' or k=='sürdür' then n={k};take(';')
  elseif k=='dön' then n={'return',expr(-1)};take(';')
  elseif k=='ertele' then n={'defer',block()}
  elseif k=='eğer' then
    n={'if',expr(-1),block()}
    if peek()=='yoksa' then take();n[4]=peek()=='eğer' and {statement()} or block() end
  elseif k=='iken' then n={'while',expr(-1),block()}
  elseif k=='yinele' or k=='için' then
    take('(');local init=assignment(';');local condition=expr(-1);take(';');local step=assignment(')');take(')')
    n={'scope',{init,{'while',condition,block(),step={step}}}}
  else ti=ti-1;n=assignment(';') end
  n.line=at;return n
end
block=function()
  take('{');local b={}
  while peek()~='}' do b[#b+1]=statement() end
  take('}');return b
end
local functions={};local signatures={};local structures={};local constants={};local globals={};local global_order={};local callbacks={};local templates={}
while peek()~='<son>' do
  local declaration_at=tokens[ti][2]
  if peek()=='imza' then
    take();local n=take();if callbacks[n] then fail('yinelenen imza: '..n) end
    take('(');local args={}
    if peek()~=')' then repeat args[#args+1]=parse_type();if peek()~=',' then break end;take() until false end
    take(')');take(':');local result=parse_type();take(';')
    callbacks[n]={args=args,result=result,line=declaration_at}
  elseif peek()=='genel' or peek()=='tablo' then
    local readonly=take()=='tablo';local n=take();take(':');local t=take();local count
    if peek()=='[' then take();if peek()~=']' then count=expr(-1) else t=t..'[]' end;take(']') end
    if globals[n] then fail('yinelenen genel: '..n) end
    local init
    if peek()=='=' then
      take()
      if peek()=='{' then
        take();init={}
        if peek()~='}' then repeat init[#init+1]=expr(-1);if peek()~=',' then break end;take();if peek()=='}' then break end until false end
        take('}')
      else init=expr(-1) end
    end
    take(';');globals[n]={name=n,element=t,count=count,init=init,readonly=readonly,line=declaration_at};global_order[#global_order+1]=globals[n]
  elseif peek()=='sabit' then
    take();local n=take();if constants[n] then fail('yinelenen sabit: '..n) end
    local annotation;if peek()==':' then take();annotation=parse_type() end
    take('=');constants[n]={expr=expr(-1),annotation=annotation,line=declaration_at};take(';')
  elseif peek()=='yapı' then
    take();local n=take();if structures[n] then fail('yinelenen yapı: '..n) end
    take('{');local fields={}
    while peek()~='}' do
      local field=take();take(':');local t=take();local count
      if peek()=='[' then
        take();if peek()==']' then take();t=t..'[]'
        else count=expr(-1);take(']') end
      end
      take(';');fields[#fields+1]={field,t,count}
    end
    take('}');structures[n]={raw=fields,line=declaration_at}
  else
  take('işlev');local n=take();local generics
  if peek()=='[' then
    take();generics={take()};while peek()==',' do take();generics[#generics+1]=take() end;take(']')
    local seen={};for _,t in ipairs(generics) do
      if not t:match('^[%a_\128-\255][%w_\128-\255]*$') or seen[t] then fail('geçersiz/yinelenen şablon türü: '..t) end;seen[t]=true
    end
    if n=='ana' then fail('ana şablon olamaz') end
  end
  take('(');local params={};local types={}
  if peek()~=')' then repeat
    local v=take();if not v:match('^[%a_\128-\255][%w_\128-\255]*$') then fail('parametre adı bekleniyordu') end
    params[#params+1]=v;types[#params]='i64'
    if peek()==':' then take();types[#params]=parse_type() end
    if peek()~=',' then break end;take(',')
  until false end
  take(')');local result='i64';if peek()==':' then take();result=parse_type() end
  if signatures[n] then fail('yinelenen işlev: '..n) end
  if #params>32 then fail('en fazla 32 parametre desteklenir') end
  signatures[n]=#params;local fn={n,params,block(),types,result,line=declaration_at}
  if generics then fn.generics=generics;templates[n]=fn else functions[#functions+1]=fn end
  end
end
if signatures.ana~=0 then fail('parametresiz ana işlevi gerekli') end

local numeric={i8={8,true},u8={8,false},i16={16,true},u16={16,false},i32={32,true},u32={32,false},i64={64,true},u64={64,false}}
numeric.f32={32,true,float=true};numeric.f64={64,true,float=true}
local valid_type={adres=true,dosya=true,['işçi']=true}
for k in pairs(numeric) do valid_type[k]=true end
local pointer_type={adres=true};local infer,constant_eval,resolve_constant
for n in pairs(callbacks) do if valid_type[n] or structures[n] or signatures[n] then fail('imza adı çakışması: '..n) end;valid_type[n]=true end
for n in pairs(numeric) do valid_type[n..'[]']=true;pointer_type[n..'[]']=true end
for n in pairs(structures) do
  if valid_type[n] or signatures[n] then fail('yapı adı çakışması: '..n) end
  valid_type[n]=true;pointer_type[n]=true
  valid_type[n..'[]']=true;pointer_type[n..'[]']=true
end
local function clone(n)
  if type(n)~='table' then return n end
  local r={};for k,v in pairs(n) do r[k]=clone(v) end;return r
end

local instances={};local instance_count=0
local type_arguments={boyut=true,yerel=true,yeni=true,yerel_dizi=true,yeni_dizi=true,['gör']=true,['dizi_gör']=true,['bit_gör']=true}
local function specialize(name,args)
  local template=templates[name]
  if not template then fail('şablon işlev bulunamadı: '..name) end
  if #args~=#template.generics then fail('şablon tür sayısı uyuşmuyor: '..name) end
  for _,t in ipairs(args) do if not valid_type[t] then fail('bilinmeyen şablon türü: '..t) end end
  local key=name..'['..table.concat(args,',')..']'
  if instances[key] then return instances[key] end
  instance_count=instance_count+1;if instance_count>1024 then fail('1024 şablon özelleştirmesi sınırı aşıldı') end
  local map={};for i,t in ipairs(template.generics) do map[t]=args[i] end
  local function replace(t)
    if map[t] then return map[t] end
    local base=t:match('^(.-)%[%]$');return base and map[base] and map[base]..'[]' or t
  end
  local function substitute(n)
    if type(n)~='table' then return end
    if n[1]==':=' and n[4] then n[4]=replace(n[4]) end
    if n[1]=='call' then
      if type_arguments[n[2]] and n[3][1] and n[3][1][1]=='var' then n[3][1][2]=replace(n[3][1][2]) end
      n[2]=replace(n[2])
    end
    local types=n.typeargs or (n[1]=='generic' and n[3])
    if types then for i,t in ipairs(types) do types[i]=replace(t) end end
    for _,v in ipairs(n) do if type(v)=='table' then substitute(v) end end
    if n.step then substitute(n.step) end
  end
  local fn=clone(template);fn[1]='__t_örnek_'..instance_count;fn.generics=nil;fn.specialization=key
  for i,t in ipairs(fn[4]) do fn[4][i]=replace(t) end;fn[5]=replace(fn[5]);substitute(fn[3])
  instances[key]=fn[1];functions[#functions+1]=fn;signatures[fn[1]]=#fn[2];return fn[1]
end
local function expand_templates(n)
  if type(n)~='table' then return end
  location=n.line or location
  if n[1]=='call' and n.typeargs then n[2]=specialize(n[2],n.typeargs);n.typeargs=nil
  elseif n[1]=='generic' then n[2]=specialize(n[2],n[3]);n[1]='var';n[3]=nil
  elseif n[1]=='call' and templates[n[2]] then fail('şablon çağrısı açık tür ister: '..n[2]..'::[Tür](...)') end
  for _,v in ipairs(n) do if type(v)=='table' then expand_templates(v) end end
  if n.step then expand_templates(n.step) end
end
for name,fn in pairs(templates) do
  location=fn.line or location
  for _,t in ipairs(fn.generics) do if valid_type[t] or signatures[t] then fail('şablon tür adı çakışması: '..t) end end
  if valid_type[name] then fail('şablon adı çakışması: '..name) end
end
local function layout_structure(name)
  local st=structures[name];location=st.line or location;if st.size then return st.size end
  if st.busy then fail('döngüsel yapı boyutu: '..name) end;st.busy=true
  local offset,alignment=0,1;st.fields={}
  for _,field in ipairs(st.raw) do
    local n,t,count=field[1],field[2],field[3]
    if count then infer(count,'i64');count=constant_eval(count);if count<1 or count>1048576 then fail('alan dizisi 1..1048576 öğe ister') end end
    if st.fields[n] then fail('yinelenen alan: '..n) end
    if not valid_type[t] then fail('bilinmeyen alan türü: '..t) end
    if count and not numeric[t] then fail('sabit alan dizisi sayısal tür ister') end
    local size=numeric[t] and numeric[t][1]//8 or 8
    offset=(offset+size-1)//size*size;alignment=math.max(alignment,size)
    st.fields[n]={offset=offset,type=count and t..'[]' or t,array=count~=nil}
    offset=offset+size*(count or 1)
  end
  st.size=(offset+alignment-1)//alignment*alignment;st.busy=nil
  if st.size==0 then fail('boş yapı desteklenmiyor: '..name) end
  return st.size
end
for _,g in ipairs(global_order) do
  location=g.line or location
  if valid_type[g.name] or signatures[g.name] or constants[g.name] then fail('genel adı çakışması: '..g.name) end
  if not valid_type[g.element] or (g.count and not numeric[g.element] and not structures[g.element]) then fail('geçersiz genel türü: '..g.element) end
  g.type=g.count and g.element..'[]' or g.element
  g.direct=g.count~=nil or structures[g.element]~=nil
end
local externs,builtins={},{}
local function builtin(n,args,result,mac,win,abi)
  externs[#externs+1]=windows and (win or mac) or mac
  builtins[n]={#externs,#args,args,result,abi or 'word'}
end
local math_symbols={log=true,exp=true,pow=true,floor=true,ceil=true}
for _,d in ipairs({{'logaritma','log',1},{'üstel','exp',1},{'üs','pow',2},{'aşağı_yuvarla','floor',1},{'yukarı_yuvarla','ceil',1}}) do
  local args={'f64'};if d[3]==2 then args[2]='f64' end;builtin(d[1],args,'f64',d[2],nil,'float64')
end
builtin('karakter_oku',{},'i64','getchar',nil,'int')
builtin('karakter_yaz',{'i64'},'i64','putchar',nil,'int')
builtin('satır_yaz',{'adres'},'i64','puts',nil,'int')
builtin('çıktıyı_boşalt',{'adres'},'i64','fflush',nil,'int')
builtin('dosya_boşalt',{'dosya'},'i64','fflush',nil,'int')
builtin('__t_dup',{'i64'},'i64','dup','_dup','int')
builtin('__t_fdopen',{'i64','adres'},'dosya','fdopen','_fdopen')
builtin('__t_close',{'i64'},'i64','close','_close','int')
builtin('bellek_ayır',{'i64'},'adres','malloc')
builtin('bellek_yenile',{'adres','i64'},'adres','realloc')
builtin('bellek_bırak',{'adres'},'i64','free',nil,'void')
builtin('dosya_aç',{'adres','adres'},'dosya','fopen')
builtin('__t_fread',{'adres','i64','i64','dosya'},'i64','fread')
builtin('__t_fwrite',{'adres','i64','i64','dosya'},'i64','fwrite')
builtin('dosya_kapat',{'dosya'},'i64','fclose',nil,'int')
builtin('dosya_konumla',{'dosya','i64','i64'},'i64','fseeko','_fseeki64','int')

if windows then builtin('__t_fgetpos',{'dosya','adres'},'i64','fgetpos',nil,'int')
else builtin('dosya_konumu',{'dosya'},'i64','ftello') end
builtin('dosya_hata',{'dosya'},'i64','ferror',nil,'int')
builtin('dosya_sonu',{'dosya'},'i64','feof',nil,'int')
local kernel32={WaitForSingleObject=true,CloseHandle=true,Sleep=true,QueryPerformanceCounter=true,QueryPerformanceFrequency=true,GetActiveProcessorCount=true,CreateFileMappingA=true,MapViewOfFile=true,UnmapViewOfFile=true}
if windows then
  local defs={
    {'__t_srw_init','InitializeSRWLock'},{'__t_srw_lock','AcquireSRWLockExclusive'},{'__t_srw_unlock','ReleaseSRWLockExclusive'},
    {'__t_cv_init','InitializeConditionVariable'},{'__t_cv_wake','WakeConditionVariable'},{'__t_cv_wake_all','WakeAllConditionVariable'},
  }
  for _,d in ipairs(defs) do builtin(d[1],{'adres'},'i64',d[2],nil,'void');kernel32[d[2]]=true end
  builtin('__t_cv_wait',{'adres','adres','i64','i64'},'i64','SleepConditionVariableSRW',nil,'int');kernel32.SleepConditionVariableSRW=true
else
  for _,d in ipairs({{'mutex_init',2},{'mutex_lock',1},{'mutex_unlock',1},{'mutex_destroy',1},{'cond_init',2},{'cond_wait',2},{'cond_signal',1},{'cond_broadcast',1},{'cond_destroy',1}}) do
    local args=d[2]==2 and {'adres','adres'} or {'adres'}
    builtin('__t_'..d[1],args,'i64','pthread_'..d[1],nil,'int')
  end
end
builtin('__t_fileno',{'dosya'},'i64','fileno','_fileno','int')
if windows then
  builtin('__t_oshandle',{'i64'},'i64','_get_osfhandle')
  builtin('__t_create_mapping',{'i64','adres','i64','i64','i64','adres'},'i64','CreateFileMappingA')
  builtin('__t_map_view',{'i64','i64','i64','i64','i64'},'adres','MapViewOfFile')
  builtin('__t_unmap_view',{'adres'},'i64','UnmapViewOfFile',nil,'int')
else
  builtin('__t_mmap',{'adres','i64','i64','i64','i64','i64'},'adres','mmap')
  builtin('__t_munmap',{'adres','i64'},'i64','munmap',nil,'int')
end
builtin('bellek_kopyala',{'adres','adres','i64'},'adres','memcpy')
builtin('bellek_taşı',{'adres','adres','i64'},'adres','memmove')
builtin('bellek_karşılaştır',{'adres','adres','i64'},'i64','memcmp',nil,'int')
builtin('__t_memset',{'adres','i64','i64'},'adres','memset')
builtin('metin_uzunluğu',{'adres'},'i64','strlen')
builtin('__t_strcmp',{'adres','adres'},'i64','strcmp',nil,'int')
builtin('__t_strncmp',{'adres','adres','i64'},'i64','strncmp',nil,'int')
builtin('metin_tamsayı',{'adres','adres','i64'},'i64','strtoll','_strtoi64')
if windows then
  builtin('__t_errno',{},'adres','_errno')
  builtin('__t_aligned_malloc',{'i64','i64'},'adres','_aligned_malloc')
  builtin('__t_aligned_free',{'adres'},'i64','_aligned_free',nil,'void')
  builtin('__t_sleep',{'i64'},'i64','Sleep',nil,'void')
  builtin('__t_qpc',{'adres'},'i64','QueryPerformanceCounter',nil,'int')
  builtin('__t_qpf',{'adres'},'i64','QueryPerformanceFrequency',nil,'int')
  builtin('__t_cpu_count',{'i64'},'i64','GetActiveProcessorCount',nil,'int')
else
  builtin('__t_posix_memalign',{'adres','i64','i64'},'i64','posix_memalign',nil,'int')
  builtin('__t_clock_gettime',{'i64','adres'},'i64','clock_gettime',nil,'int')
  builtin('__t_nanosleep',{'adres','adres'},'i64','nanosleep',nil,'int')
  builtin('__t_errno',{},'adres',linux and '__errno_location' or '__error')
  if linux then builtin('__t_get_nprocs',{},'i64','get_nprocs',nil,'int')
  else builtin('__t_sysctlbyname',{'adres','adres','adres','adres','i64'},'i64','sysctlbyname',nil,'int') end
end
if windows then
  builtin('__t_beginthreadex',{'adres','i64','işçi','adres','i64','adres'},'i64','_beginthreadex')
  builtin('__t_wait',{'i64','i64'},'u32','WaitForSingleObject')
  builtin('__t_close',{'i64'},'i64','CloseHandle',nil,'int')
  builtin('__t_exit',{'i64'},'i64','exit',nil,'void')
else
  builtin('__t_pthread_create',{'adres','adres','işçi','adres'},'i64','pthread_create',nil,'int')
  builtin('__t_pthread_join',{'i64','adres'},'i64','pthread_join',nil,'int')
end
if windows then
  builtin('__t_wfopen',{'adres','adres'},'dosya','_wfopen')
  builtin('__t_wgetmainargs',{'adres','adres','adres','i64','adres'},'i64','__wgetmainargs',nil,'int')
  for _,d in ipairs({
    {'__t_utf8_wide','MultiByteToWideChar',{'i64','i64','adres','i64','adres','i64'},'i64','int'},
    {'__t_wide_utf8','WideCharToMultiByte',{'i64','i64','adres','i64','adres','i64','adres','adres'},'i64','int'},
    {'__t_affinity','SetThreadGroupAffinity',{'i64','adres','adres'},'i64','int'},
    {'__t_get_affinity','GetThreadGroupAffinity',{'i64','adres'},'i64','int'},
    {'__t_virtual_alloc','VirtualAlloc',{'adres','i64','i64','i64'},'adres'},
    {'__t_virtual_free','VirtualFree',{'adres','i64','i64'},'i64','int'},
    {'__t_numa_alloc','VirtualAllocExNuma',{'i64','adres','i64','i64','i64','i64'},'adres'},
    {'__t_large_min','GetLargePageMinimum',{},'i64'}, {'__t_last_error','GetLastError',{},'u32'},
  }) do builtin(d[1],d[3],d[4],d[2],nil,d[5]);kernel32[d[2]]=true end
else
  builtin('__t_attr_init',{'adres'},'i64','pthread_attr_init',nil,'int')
  builtin('__t_attr_destroy',{'adres'},'i64','pthread_attr_destroy',nil,'int')
  builtin('__t_attr_stack',{'adres','i64'},'i64','pthread_attr_setstacksize',nil,'int')
  if linux then
    builtin('__t_set_affinity',{'i64','i64','adres'},'i64','sched_setaffinity',nil,'int')
    builtin('__t_get_affinity',{'i64','i64','adres'},'i64','sched_getaffinity',nil,'int')
    builtin('__t_syscall',{'i64','adres','i64','i64','adres','i64','i64'},'i64','syscall')
  end
end
if linux then builtin('__t_libc_start',{},'i64','__libc_start_main');if target=='arm64' then builtin('__t_getauxval',{'u64'},'u64','getauxval') end end
local primitives={
 ['çarp_kırp_i16_u8']={{'adres','adres','adres','i64'},'i64'},
 ['kırp_çift_i32_u8']={{'adres','adres','i64','i64'},'i64'},
 ['kırp_i32_u8']={{'adres','adres','i64','i64','i64'},'i64'},
 ['kare_kırp_i16_u8']={{'adres','adres','i64','i64','i64'},'i64'},
 ['nokta_u8_i8']={{'adres','adres','i64'},'i64'},
 ['katla_u8_i8_i32']={{'adres','adres','i64','i64'},'i64'},
 ['işlemci_özellikleri']={{},'u64'},
 ['kırp_i16_u8']={{'adres','adres','i64','i64'},'i64'},['çarp_yüksek_u64']={{'u64','u64'},'u64'},
 ['vektör_topla_i16']={{'adres','adres','adres','i64'},'i64'},['vektör_çıkar_i16']={{'adres','adres','adres','i64'},'i64'},
 adres_bitleri={{'adres'},'u64'},['işlemci_bekle']={{},'i64'},['öngetir']={{'adres'},'i64'},son_bit={{'u64'},'i64'},bayt_ters={{'u64'},'u64'},bit_ters={{'u64'},'u64'},

 dizi={{'i64'},'adres'},bayt_oku={{'adres','i64'},'i64'},bayt_yaz={{'adres','i64','i64'},'i64'},
 ['sayı_oku']={{'adres','i64'},'i64'},['sayı_yaz']={{'adres','i64','i64'},'i64'},
 bit_say={{'i64'},'i64'},ilk_bit={{'i64'},'i64'},nokta8_i16={{'adres','adres'},'i64'},
 ['adres_ekle']={{'adres','i64'},'adres'},
 ['vektör_topla_i32']={{'adres','adres','adres','i64'},'i64'},
 ['vektör_topla_i8_i16']={{'adres','adres','adres','i64'},'i64'},
 ['vektör_çıkar_i8_i16']={{'adres','adres','adres','i64'},'i64'},
 ['yoğun_blok_u8_i8_i32']={{'adres','adres','adres','adres','i64','i64'},'i64'},
 ['karışım_i32']={{'adres','adres','i64','i64','adres','i64'},'i64'},
 ['vektör_topla_çıkar_i16']={{'adres','adres','adres','adres','i64'},'i64'},['vektör_topla_çıkar_i32']={{'adres','adres','adres','adres','i64'},'i64'},
 ['vektör_enbüyük_i16']={{'adres','adres','adres','i64'},'i64'},['vektör_topla_i16_i32']={{'adres','adres','adres','i64'},'i64'},
 ['yoğun_i16']={{'adres','adres','adres','i64','i64'},'i64'},['ekle_relu512_i32_i16']={{'adres','adres','adres','i64'},'i64'},['havuz_i16']={{'adres','adres','adres','i64'},'i64'},['taş_havuz_i16']={{'adres','i64','adres','adres'},'i64'},['taşlar_havuz_i16']={{'adres','adres','i64','adres','adres'},'i64'},
 atomik_oku={{'adres'},'i64'},atomik_yaz={{'adres','i64'},'i64'},atomik_ekle={{'adres','i64'},'i64'},
 ['atomik_kıyas_değiştir']={{'adres','i64','i64'},'i64'},
}
primitives.adres_oku={{'adres','i64'},'adres'}
primitives.adres_yaz={{'adres','i64','adres'},'adres'}
for n in pairs(numeric) do
  primitives[n..'_oku']={{'adres','i64'},n}
  primitives[n..'_yaz']={{'adres','i64',n},n}
end
local declarations={}
local function check_function_name(n)
  if builtins[n] or primitives[n] or valid_type[n] or ({['seç']=true,['karekök']=true,['bit_gör']=true,['çağır']=true,['işlev_adresi']=true,yerel=true,yeni=true,["gör"]=true,["dizi_gör"]=true,yerel_dizi=true,yeni_dizi=true,boyut=true,adres=true,sil=true})[n] then fail('ayrılmış ilkel adı: '..n) end
end
for n,fn in pairs(templates) do location=fn.line or location;check_function_name(n) end
for _,c in pairs(constants) do expand_templates(c.expr) end
for _,g in ipairs(global_order) do expand_templates(g.init);expand_templates(g.count) end
for _,st in pairs(structures) do for _,f in ipairs(st.raw) do expand_templates(f[3]) end end
for _,fn in ipairs(functions) do expand_templates(fn[3]) end

for _,fn in ipairs(functions) do
  location=fn.line or location;check_function_name(fn[1])
  declarations[fn[1]]=fn
  if not valid_type[fn[5]] then fail('bilinmeyen dönüş türü: '..fn[5]) end
  for _,t in ipairs(fn[4]) do if not valid_type[t] then fail('bilinmeyen parametre türü: '..t) end end
end
if declarations.ana[5]~='i64' then fail('ana dönüş türü i64 olmalı') end
local type_scopes={}
local function variable_type(n)
  for i=#type_scopes,1,-1 do if type_scopes[i][n] then return type_scopes[i][n] end end
  if constants[n] then local c=resolve_constant(n);return c.type,c.value end
  if globals[n] then return globals[n].type,nil,globals[n] end
  fail('tanımsız değişken: '..n)
end
local function type_error(expected,actual) fail('tür uyuşmazlığı: '..expected..' bekleniyordu, bulunan '..actual) end
infer=function(e,expected)
  location=e.line or location
  local op=e[1];local t
  if op=='num' then
    t='i64'
    if expected and numeric[expected] then
      local spec=numeric[expected]
      if spec[1]<64 and not spec.float then
        local hi=(1<<(spec[1]-(spec[2] and 1 or 0)))-1
        local lo=spec[2] and -(1<<(spec[1]-1)) or 0
        if e[2]>hi or e[2]<lo then fail('sabit hedef türe sığmıyor: '..expected) end
      end
      t=expected
    elseif expected and e[2]==0 then t=expected end
  elseif op=='ref' then
    local lhs=e[2];infer(lhs)
    if (lhs[1]~='var' and lhs[1]~='field' and lhs[1]~='index') or lhs.constant~=nil then fail('& saklama alanı olan bir değer ister') end
    t='adres'
  elseif op=='real' then
    t=expected and numeric[expected] and numeric[expected].float and expected or 'f64'
  elseif op=='neg' or op=='bitnot' then
    if op=='neg' and e[2][1]=='num' and expected and numeric[expected] then t=infer({'num',-e[2][2]},expected);e[2].type=t
    else t=infer(e[2],expected) end
    if not numeric[t] or (op=='bitnot' and numeric[t].float) then fail('geçersiz tekli sayısal işlem') end
  elseif op=='string' then t='adres'
  elseif op=='var' then t,e.constant,e.global=variable_type(e[2])
  elseif op=='field' then
    local base=infer(e[2]);local st=structures[base];if st then layout_structure(base) end
    if not st or not st.fields[e[3]] then fail('bilinmeyen yapı alanı: '..base..'.'..e[3]) end
    e.field=st.fields[e[3]];t=e.field.type
  elseif op=='index' then
    local base=infer(e[2]);local element=base:match('^(.-)%[%]$')
    if not element or (not numeric[element] and not structures[element]) then fail('indeksleme türlenmiş dizi ister') end
    infer(e[3],'i64');e.element=element;t=element
  elseif op=='call' then
    local n=e[2]
    if n=='seç' then
      if #e[3]~=3 then fail('seç koşul ve iki değer ister') end
      local ct=infer(e[3][1]);if not numeric[ct] or numeric[ct].float then fail('seç koşulu tamsayı/karşılaştırma olmalı') end
      local a,b=e[3][2],e[3][3]
      if not expected and (a[1]=='num' or a[1]=='real') and b[1]~='num' and b[1]~='real' then t=infer(b);infer(a,t)
      else t=infer(a,expected);infer(b,t) end
    elseif n=='dizi' then
      if #e[3]~=1 then fail('dizi sabit bayt boyutu ister') end
      infer(e[3][1],'i64');local ok,v=pcall(constant_eval,e[3][1]);if not ok or v<1 or v>16777216 then fail('dizi 1..16777216 sabit bayt boyutu ister') end
      e.count=v;t='adres'
    elseif n=='bit_gör' then
      if #e[3]~=2 or e[3][1][1]~='var' then fail('bit_gör hedef tür ve değer ister') end
      t=e[3][1][2];local from=infer(e[3][2]);if not numeric[t] or not numeric[from] or numeric[t][1]~=numeric[from][1] then fail('bit_gör eşit genişlikte sayısal türler ister') end
    elseif n=='karekök' then
      if #e[3]~=1 then fail('karekök tek sayı ister') end;t=infer(e[3][1]);if not numeric[t] or not numeric[t].float then fail('karekök f32/f64 ister') end
    elseif n=='dizi_gör' then
      if #e[3]~=2 or e[3][1][1]~='var' or (not structures[e[3][1][2]] and not numeric[e[3][1][2]]) then fail('dizi_gör eleman türü ve adres ister') end
      infer(e[3][2],'adres');t=e[3][1][2]..'[]'
    elseif n=='gör' then
      if #e[3]~=2 or e[3][1][1]~='var' or not structures[e[3][1][2]] then fail('gör yapı türü ve adres ister') end
      infer(e[3][2],'adres');t=e[3][1][2]
    elseif n=='yerel' or n=='yeni' or n=='boyut' then
      if #e[3]~=1 or e[3][1][1]~='var' then fail(n..' tür adı ister') end
      local name=e[3][1][2];local size=structures[name] and layout_structure(name) or (numeric[name] and numeric[name][1]//8) or (pointer_type[name] and 8)
      if not size or (n~='boyut' and not structures[name]) then fail('bilinmeyen yapı/tür: '..name) end
      e.size=size;t=n=='boyut' and 'i64' or name
    elseif n=='yerel_dizi' or n=='yeni_dizi' then
      if #e[3]~=2 or e[3][1][1]~='var' or (not numeric[e[3][1][2]] and not structures[e[3][1][2]]) then fail(n..' eleman türü ve uzunluk ister') end
      local name=e[3][1][2];e.size=structures[name] and layout_structure(name) or numeric[name][1]//8;infer(e[3][2],'i64');t=name..'[]'
      if n=='yerel_dizi' then
        local ok,v=pcall(constant_eval,e[3][2]);if not ok or v<1 or v>16777216//e.size then fail('yerel_dizi pozitif sabit uzunluk ve en fazla 16777216 bayt ister') end;e.count=v
      end
    elseif n=='adres' or n=='sil' then
      if #e[3]~=1 or not pointer_type[infer(e[3][1])] then fail(n..' veri adresi ister') end
      t=n=='adres' and 'adres' or 'i64'
    elseif n=='çağır' then
      if #e[3]<1 then fail('çağır işlev işaretçisi ister') end
      local cb=callbacks[infer(e[3][1])]
      if not cb then fail('çağır adlandırılmış imza türü ister') end
      if #e[3]~=#cb.args+1 then fail('dolaylı çağrı parametre sayısı uyuşmuyor') end
      for i,a in ipairs(cb.args) do infer(e[3][i+1],a) end
      e.callback=cb;t=cb.result
    elseif n=='işlev_adresi' then
      if #e[3]~=1 or e[3][1][1]~='var' then fail('işlev_adresi işlev adı ister') end
      local fn=declarations[e[3][1][2]]
      if expected and callbacks[expected] then
        local cb=callbacks[expected]
        if not fn or #fn[2]~=#cb.args or fn[5]~=cb.result then fail('işlev adresi imzası uyuşmuyor') end
        for i,a in ipairs(cb.args) do if fn[4][i]~=a then fail('işlev adresi parametre türü uyuşmuyor') end end
        t=expected
      else
        if not fn or #fn[2]~=1 or fn[4][1]~='adres' or fn[5]~='i64' then fail('işlev_adresi için imza türü belirtin; işçi imzası (adres):i64 olmalı') end
        t='işçi'
      end
    elseif numeric[n] then
      if #e[3]~=1 or not numeric[infer(e[3][1])] then fail('sayısal dönüşüm sayısal değer ister') end
      t=n
    else
      local p,b,fn=primitives[n],builtins[n],declarations[n]
      if not p and not b and not fn then fail('tanımsız işlev: '..n) end
      local args=p and p[1] or (b and b[3] or fn[4])
      t=p and p[2] or (b and b[4] or fn[5])
      if #args~=#e[3] then fail('parametre sayısı uyuşmuyor: '..n) end
      for i,a in ipairs(e[3]) do
        local wanted=args[i]

        if (n=='bit_say' or n=='ilk_bit') then
          local actual=infer(a);if actual~='i64' and actual~='u64' then type_error('i64/u64',actual) end
        else infer(a,wanted) end
      end
    end
  elseif op=='&&' or op=='||' then
    if (numeric[infer(e[2])] or {}).float or (numeric[infer(e[3])] or {}).float then fail('mantıksal koşul için float karşılaştırması kullanın') end
    if not numeric[infer(e[2])] or not numeric[infer(e[3])] then fail('mantıksal işlem sayısal koşul ister') end
    t='i64'
  else
    local left,right
    if (e[2][1]=='num' or e[2][1]=='real') and e[3][1]~='num' and e[3][1]~='real' then right=infer(e[3]);left=infer(e[2],right)
    else left=infer(e[2]);right=infer(e[3],left) end
    if left~=right then type_error(left,right) end
    local comparison=op=='==' or op=='!=' or op=='<' or op=='>' or op=='<=' or op=='>='
    if not numeric[left] and not (op=='==' or op=='!=') then fail('adresler üzerinde yalnızca ==/!=; adres aritmetiği için adres_ekle') end
    if numeric[left] and numeric[left].float and not comparison and op~='+' and op~='-' and op~='*' and op~='/' then fail('float için geçersiz işlem: '..op) end
    e.operand=left;t=comparison and 'i64' or left
  end
  if expected and t~=expected then type_error(expected,t) end
  e.type=t;return t
end
local function unsigned_less(a,b) return (a~math.mininteger)<(b~math.mininteger) end
local function unsigned_div(a,b)
  local q,r=0,0
  for i=63,0,-1 do
    local carry=r<0;r=(r<<1)|((a>>i)&1)
    if carry or not unsigned_less(r,b) then r=r-b;q=q|(1<<i) end
  end
  return q,r
end
local function integer_f32(v,unsigned)
  local sign=0;if v<0 and not unsigned then sign=0x80000000;v=-v end
  if v==0 then return 0.0 end
  local high=63;while ((v>>high)&1)==0 do high=high-1 end
  local q
  if high<=23 then q=v<<(23-high)
  else
    local shift=high-23;q=v>>shift;local remainder=v&((1<<shift)-1);local half=1<<(shift-1)
    if remainder>half or (remainder==half and (q&1)~=0) then q=q+1 end
    if q==(1<<24) then high=high+1;q=q>>1 end
  end
  return string.unpack('<f',string.pack('<I4',sign|((high+127)<<23)|(q&0x7fffff)))
end
local function normalize_constant(v,t)
  local n=numeric[t];if n and n.float then
    if t=='f32' and math.type(v)=='integer' then return integer_f32(v,false) end
    return t=='f32' and string.unpack('<f',string.pack('<f',v)) or (v+0.0)
  end
  if not n or n[1]==64 then return v end
  local mask=(1<<n[1])-1;v=v&mask
  if n[2] and v>=(1<<(n[1]-1)) then v=v-(1<<n[1]) end
  return v
end
constant_eval=function(e)
  local k=e[1];local v
  if k=='num' or k=='real' then v=e[2]
  elseif k=='neg' then v=-constant_eval(e[2])
  elseif k=='bitnot' then v=~constant_eval(e[2])
  elseif k=='var' then v=resolve_constant(e[2]).value
  elseif k=='call' and e[2]=='boyut' then v=e.size
  elseif k=='call' and e[2]=='seç' then v=constant_eval(e[3][constant_eval(e[3][1])~=0 and 2 or 3])
  elseif k=='call' and numeric[e[2]] then
    local x=constant_eval(e[3][1])
    if (numeric[e[3][1].type] or {}).float and not numeric[e[2]].float then
      local unsigned=e[2]=='u64';local lower=unsigned and 0.0 or -9223372036854775808.0;local upper=unsigned and 18446744073709551616.0 or 9223372036854775808.0
      if x~=x or x<lower or x>=upper then fail('sabit float dönüşümü aralık dışında') end
      local integer
      if unsigned and x>=9223372036854775808.0 then integer=assert(math.tointeger(math.floor(x-9223372036854775808.0)))|math.mininteger
      else integer=assert(math.tointeger(x<0 and math.ceil(x) or math.floor(x))) end
      return normalize_constant(integer,e[2])
    end
    if e[2]=='f32' and not numeric[e[3][1].type].float then return integer_f32(x,e[3][1].type=='u64') end
    if numeric[e[2]].float and e[3][1].type=='u64' and x<0 then x=((x>>1)|(x&1))*2.0 end
    v=normalize_constant(x,e[2])
  elseif k=='&&' then v=constant_eval(e[2])~=0 and (constant_eval(e[3])~=0 and 1 or 0) or 0
  elseif k=='||' then v=constant_eval(e[2])~=0 and 1 or (constant_eval(e[3])~=0 and 1 or 0)
  elseif precedence[k] then
    local a,b=constant_eval(e[2]),constant_eval(e[3]);local unsigned=numeric[e.operand] and not numeric[e.operand][2]
    if k=='+' then v=a+b elseif k=='-' then v=a-b elseif k=='*' then v=a*b
    elseif k=='&' then v=a&b elseif k=='|' then v=a|b elseif k=='^' then v=a~b
    elseif k=='<<' then v=a<<(b&63)
    elseif k=='>>' then
      local n=numeric[e.operand];if n and n[1]<64 then a=a&((1<<n[1])-1) end
      v=a>>(b&63)
    elseif k=='/' and (numeric[e.operand] or {}).float then v=a/b
    elseif k=='/' or k=='%' then
      if b==0 then fail('sabit ifadede sıfıra bölme') end
      local q,r
      if unsigned then q,r=unsigned_div(a,b)
      elseif b==-1 then q,r=-a,0
      else q=a//b;if a%b~=0 and ((a<0)~=(b<0)) then q=q+1 end;r=a-q*b end
      v=k=='/' and q or r
    else
      local less=unsigned and unsigned_less(a,b) or (not unsigned and a<b)
      local equal=a==b
      local truth=(k=='==' and equal) or (k=='!=' and not equal) or (k=='<' and less) or (k=='<=' and (less or equal)) or (k=='>' and not less and not equal) or (k=='>=' and not less)
      if (numeric[e.operand] or {}).float then truth=(k=='==' and a==b) or (k=='!=' and a~=b) or (k=='<' and a<b) or (k=='<=' and a<=b) or (k=='>' and a>b) or (k=='>=' and a>=b) end
      v=truth and 1 or 0
    end
  else fail('sabit ifade yalnızca tamsayılar, sabitler ve sayısal dönüşümler içerebilir') end
  return normalize_constant(v,e.type)
end
resolve_constant=function(name)
  local c=constants[name];if not c then fail('tanımsız sabit: '..name) end
  if c.ready then return c end
  if c.busy then fail('döngüsel sabit: '..name) end
  if signatures[name] or valid_type[name] or builtins[name] or primitives[name] then fail('sabit adı çakışması: '..name) end
  if c.annotation and not numeric[c.annotation] then fail('sabit sayısal tür ister') end
  c.busy=true;c.type=infer(c.expr,c.annotation);c.value=constant_eval(c.expr);c.ready=true;c.busy=nil;return c
end
for _,cb in pairs(callbacks) do
  if #cb.args>32 or not valid_type[cb.result] then fail('geçersiz imza dönüşü/parametre sayısı') end
  for _,t in ipairs(cb.args) do if not valid_type[t] then fail('geçersiz imza parametre türü: '..t) end end
end
for name in pairs(structures) do layout_structure(name) end
for name in pairs(constants) do resolve_constant(name) end
if Y.gom_dosya then
  local ad
  for _,g in ipairs(global_order) do
    if g.readonly and not g.init then
      if ad then fail('--gom birden fazla boş tablo var; tablo=dosya yazın') end
      ad=g.name
    end
  end
  if not ad then fail('--gom için boş tablo yok') end
  if Y.gom[ad] then fail('--gom '..ad..' iki kez verildi') end
  Y.gom[ad]=Y.gom_dosya
end
local global_bytes={};local global_size=0;local readonly_size=0

for _,g in ipairs(global_order) do
  local count=1

  if g.count then
    infer(g.count,'i64');count=constant_eval(g.count)
    local limit=g.readonly and 268435456 or 16777216
    if count<1 or count>limit then fail('genel dizi boyutu 1..'..limit..' olmalı') end
  end
  local width=structures[g.element] and structures[g.element].size or (numeric[g.element] and numeric[g.element][1]//8 or 8)
  if width>268435456//count then fail('statik veri 256 MiB sınırını aşıyor') end
  local values={}
  if g.init then
    if structures[g.element] then fail('genel yapılar sıfır başlatılır; alanları başlangıçta atayın') end
    local list=g.count and g.init or {g.init}
    if g.count and #list>0 and type(list[1])~='table' then fail('genel dizi başlatıcısı {...} ister') end
    if #list>count then fail('genel dizi başlatıcısı fazla öğe içeriyor') end
    for _,e in ipairs(list) do
      infer(e,g.element)
      local v=constant_eval(e);values[#values+1]=numeric[g.element] and numeric[g.element].float and string.pack(g.element=='f32' and '<f' or '<d',v) or string.pack('<i'..width,normalize_constant(v,'i'..(width*8)))
    end
  end
  if Y.gom[g.name] then

    if not g.readonly then fail('--gom yalnız tablo için: '..g.name) end
    if g.init then fail('--gom tablosunun başlatıcısı olamaz: '..g.name) end
    local fh=io.open(Y.gom[g.name],'rb');if not fh then fail('--gom dosyası açılamadı: '..Y.gom[g.name]) end
    local bytes=fh:read('a');fh:close()
    if #bytes~=width*count then fail(string.format('--gom %s: tablo %d bayt, dosya %d bayt',g.name,width*count,#bytes)) end
    values={bytes};Y.gom[g.name]=nil
  else
    values[#values+1]=string.rep('\0',width*count-#values*width)
  end
  g.bytes=table.concat(values);g.zero=g.bytes:find('[^%z]')==nil
end
for n in pairs(Y.gom) do fail('--gom tablosu tanımlı değil: '..n) end
local layout_order={}
for _,g in ipairs(global_order) do if g.readonly then layout_order[#layout_order+1]=g end end
local readonly_count=#layout_order
for _,g in ipairs(global_order) do if not g.readonly and not g.zero then layout_order[#layout_order+1]=g end end
Y.initialized_count=#layout_order
for _,g in ipairs(global_order) do if not g.readonly and g.zero then layout_order[#layout_order+1]=g end end
Y.file_globals=0
for gi,g in ipairs(layout_order) do
  if global_size+#g.bytes+64>268435456 then fail('statik veri 256 MiB sınırını aşıyor') end
  local padding=(-global_size)%64;global_bytes[#global_bytes+1]=string.rep('\0',padding);global_size=global_size+padding;g.offset=global_size
  global_bytes[#global_bytes+1]=g.bytes;global_size=global_size+#g.bytes;g.bytes=nil
  if global_size>268435456 then fail('statik veri 256 MiB sınırını aşıyor') end
  if gi==readonly_count then
    local page=linux and target=='arm64' and 65536 or 4096
    local pad=(-global_size)%page;global_bytes[#global_bytes+1]=string.rep('\0',pad);global_size=global_size+pad;readonly_size=global_size
  end
  if gi==Y.initialized_count then Y.file_globals=global_size end
end
if Y.initialized_count==0 then Y.file_globals=global_size end
Y.file_globals=math.max(Y.file_globals,readonly_size)
global_bytes=table.concat(global_bytes)
assert(not global_bytes:find('[^%z]',Y.file_globals+1),'bss bölgesinde sıfır olmayan bayt')
local check_block
check_block=function(b,result,depth,cleanup)
  depth=depth or 0
  type_scopes[#type_scopes+1]={};local scope=type_scopes[#type_scopes]
  for _,n in ipairs(b) do
    location=n.line or location
    if n[1]=='scope' then check_block(n[2],result,depth,cleanup)
    elseif n[1]=='defer' then
      if cleanup then fail('ertele içinde ertele kullanılamaz') end
      check_block(n[2],result,0,true)
    elseif n[1]=='update' then
      local lhs=n[2];if lhs[1]~='var' and lhs[1]~='field' and lhs[1]~='index' then fail('bileşik atama değişken/alan/indeks ister') end
      local t=infer(lhs);if not numeric[t] then fail('bileşik atama sayısal hedef ister') end
      local root=lhs;while root[1]=='field' or root[1]=='index' do root=root[2] end
      if lhs.constant~=nil or (root.global and root.global.readonly) then fail('sabit/tablo değiştirilemez') end
      infer(n[3],t);infer({n[4],lhs,n[3]});n.type=t
    elseif n[1]=='kır' or n[1]=='sürdür' then
      if depth==0 then fail('döngü dışında '..n[1]) end
    elseif n[1]=='store' then
      local wanted=infer(n[2]);if (n[2].field and n[2].field.array) or (n[2][1]=='index' and structures[wanted]) then fail('dizi/yapı değeri topluca atanamaz; alanları veya bellek_kopyala kullanın') end
      local root=n[2];while root[1]=='field' or root[1]=='index' do root=root[2] end
      if root.global and root.global.readonly then fail('tablo değiştirilemez') end
      infer(n[3],wanted)
    elseif n[1]==':=' then
      if scope[n[2]] then fail('yinelenen değişken: '..n[2]) end
      if n[4] and not valid_type[n[4]] then fail('bilinmeyen tür: '..n[4]) end
      scope[n[2]]=infer(n[3],n[4])
    elseif n[1]=='=' then
      local _,constant,g=variable_type(n[2]);n.global=g;if g and (g.readonly or g.direct) then fail('genel yapı/dizi/tablo topluca atanamaz') end;if constant~=nil then fail('sabit değiştirilemez: '..n[2]) end
      if n[4] then fail('atamada tür yeniden bildirilemez') end
      infer(n[3],variable_type(n[2]))
    elseif n[1]=='eval' then infer(n[2])
    elseif n[1]=='return' then
      if cleanup then fail('ertele bloğundan dön kullanılamaz') end;infer(n[2],result)
    else
      local ct=infer(n[2]);if not numeric[ct] or numeric[ct].float then fail('koşul tamsayı veya karşılaştırma olmalı') end
      check_block(n[3],result,depth+(n[1]=='while' and 1 or 0),cleanup);if n[4] then check_block(n[4],result,depth,cleanup) end
      if n.step then check_block(n.step,result,depth+1,cleanup) end
    end
  end
  type_scopes[#type_scopes]=nil
end
if required_features>0 then table.insert(declarations.ana[3],1,{'if',{'==',{'call','komut_kümesi_uygun',{}},{'num',0}},{{'return',{'num',78}}}}) end
if instruction=='auto' or instruction=='avx512' or instruction=='avx512bw' or (target=='arm64' and instruction=='neon') then table.insert(declarations.ana[3],1,{'=','__t_cpu_cache',{'call','işlemci_özellikleri',{}}}) end
for _,fn in ipairs(functions) do
  type_scopes={{}}
  for i,n in ipairs(fn[2]) do
    if type_scopes[1][n] then fail('yinelenen parametre: '..n) end
    type_scopes[1][n]=fn[4][i]
  end
  check_block(fn[3],fn[5])
end

local function pure_constant(e)
  if (numeric[e.type] or {}).float or (numeric[e.operand] or {}).float then return false end
  if e[1]=='num' or e.constant~=nil then return true end
  if e[1]=='neg' or e[1]=='bitnot' then return pure_constant(e[2]) end
  if e[1]=='call' then
    if e[2]=='seç' then return pure_constant(e[3][1]) and pure_constant(e[3][2]) and pure_constant(e[3][3]) end
    return e[2]=='boyut' or (numeric[e[2]] and pure_constant(e[3][1]))
  end
  return precedence[e[1]]~=nil and pure_constant(e[2]) and pure_constant(e[3])
end
local leaf_inline={}
local pure_bit_call={bit_ters=true,bayt_ters=true,bit_say=true,ilk_bit=true,son_bit=true,adres_ekle=true}
local function safe_inline_argument(e)
  if e[1]=='num' or e[1]=='real' then return true end
  if e[1]=='var' then return not e.global or e.constant~=nil or e.global.direct end
  if e[1]=='neg' then return safe_inline_argument(e[2]) end
  if e[1]=='call' and numeric[e[2]] and not ((numeric[e[3][1].type] or {}).float and not numeric[e[2]].float) then return safe_inline_argument(e[3][1]) end
  if e[1]=='bitnot' then return safe_inline_argument(e[2]) end
  if precedence[e[1]] and e[1]~='/' and e[1]~='%' then return safe_inline_argument(e[2]) and safe_inline_argument(e[3]) end
  if e[1]=='call' and pure_bit_call[e[2]] then
    for _,a in ipairs(e[3]) do if not safe_inline_argument(a) then return false end end;return true
  end
  return false
end
local function leaf_size(e,params)
  if e[1]=='num' or e.constant~=nil or (e[1]=='var' and params[e[2]]) then return 1 end
  if e[1]=='neg' or e[1]=='bitnot' then return 1+leaf_size(e[2],params) end
  if e[1]=='call' and numeric[e[2]] then return leaf_size(e[3][1],params)+1 end
  if e[1]=='call' and e[2]=='seç' then return 1+leaf_size(e[3][1],params)+leaf_size(e[3][2],params)+leaf_size(e[3][3],params) end
  if e[1]=='call' and pure_bit_call[e[2]] then local n=1;for _,a in ipairs(e[3]) do n=n+leaf_size(a,params) end;return n end
  if e[1]=='field' then return 1+leaf_size(e[2],params) end
  if e[1]=='index' then return 1+leaf_size(e[2],params)+leaf_size(e[3],params) end
  if precedence[e[1]] then return 1+leaf_size(e[2],params)+leaf_size(e[3],params) end
  return 1000
end
if optimization>0 then
  for _,fn in ipairs(functions) do
    local params={};for i,n in ipairs(fn[2]) do params[n]=i end

    local defs={};local body=fn[3];local eligible=#body>=1 and #body<=5
    local function expand(e)
      if e[1]=='var' and e.constant==nil and not e.global and defs[e[2]] then return clone(defs[e[2]]) end
      local r=clone(e);for i,v in ipairs(e) do if type(v)=='table' then r[i]=expand(v) end end;return r
    end
    for i=1,#body-1 do
      local n=body[i]
      if n[1]~=':=' or not safe_inline_argument(n[3]) then eligible=false;break end
      defs[n[2]]=expand(n[3])
    end
    if eligible and body[#body][1]=='return' then
      local expr=expand(body[#body][2])
      if leaf_size(expr,params)<=64 then leaf_inline[fn[1]]={expr=expr,params=params} end
    end
  end
end
local function optimize(n)
  if type(n)~='table' then return n end
  for i,v in ipairs(n) do if type(v)=='table' then n[i]=optimize(v) end end
  if n.step then n.step=optimize(n.step) end
  if n[1]=='call' and n[2]=='seç' and pure_constant(n[3][1]) then
    local ok,value=pcall(constant_eval,n[3][1])
    if ok then return n[3][value~=0 and 2 or 3] end
  end
  if n[1]=='call' and leaf_inline[n[2]] then
    local fn=leaf_inline[n[2]];local safe=true
    for _,a in ipairs(n[3]) do if not safe_inline_argument(a) then safe=false end end
    if safe then
      local function substitute(e)
        if e[1]=='var' and e.constant==nil and fn.params[e[2]] then return clone(n[3][fn.params[e[2]]]) end
        local r=clone(e);for i,v in ipairs(e) do if type(v)=='table' then r[i]=substitute(v) end end;return r
      end
      n=substitute(fn.expr)
    end
  end
  if n.type and pure_constant(n) then

    local ok,value=pcall(constant_eval,n)
    if ok then return {'num',value,type=n.type} end
  end
  return n
end
if optimization>0 then for _,fn in ipairs(functions) do fn[3]=optimize(fn[3]) end end

local function allocate_registers(fn)
  local env={{}};local bindings={}
  local function binding(n)
    for i=#env,1,-1 do if env[i][n] then return env[i][n] end end
  end
  local function create(n)
    local b={score=0,id=#bindings+1};bindings[#bindings+1]=b;env[#env][n]=b;return b
  end
  fn.params={};for i,n in ipairs(fn[2]) do fn.params[i]=create(n) end
  local function expression(e,weight)
    if e[1]=='var' and e.constant==nil then e.binding=binding(e[2]);if e.binding then e.binding.score=e.binding.score+weight end end
    for _,v in ipairs(e) do if type(v)=='table' then expression(v,weight) end end
    if target=='x86_64' and e[1]=='call' and e[2]=='işlemci_özellikleri' then fn.needs_rbx=true end
    if e[1]=='ref' and e[2].binding then e[2].binding.addressed=true end
  end
  local walk
  walk=function(block,weight)
    env[#env+1]={}
    for _,n in ipairs(block) do
      local k=n[1]
      if k=='scope' or k=='defer' then walk(n[2],weight)
      elseif k==':=' then expression(n[3],weight);n.binding=create(n[2]);n.binding.score=weight
      elseif k=='=' then expression(n[3],weight);n.binding=binding(n[2]);if n.binding then n.binding.score=n.binding.score+weight end
      elseif k=='if' or k=='while' then
        local w=k=='while' and math.min(weight*10,10000) or weight
        expression(n[2],w);walk(n[3],w);if n[4] then walk(n[4],w) end;if n.step then walk(n.step,w) end
      else for _,v in ipairs(n) do if type(v)=='table' then expression(v,weight) end end end
    end
    env[#env]=nil
  end
  walk(fn[3],1)
  table.sort(bindings,function(a,b) return a.score==b.score and a.id<b.id or a.score>b.score end)
  local regs=target=='arm64' and {19,20,21,22,23,24,25,26,27,28} or {12,13,14,15,3}
  fn.saved={}
  if target=='arm64' and optimization>0 and fn.leaf then

    regs={8,7,6,5,4,3};local taken={}
    for i,b in ipairs(fn.params) do if i>=4 and i<=8 and not b.addressed then b.reg=i-1;taken[i-1]=true end end
    local free={};for _,r in ipairs(regs) do if not taken[r] then free[#free+1]=r end end
    local used=0
    for _,b in ipairs(bindings) do
      if not b.reg and not b.addressed and used<#free then used=used+1;b.reg=free[used] end
    end
  elseif optimization>0 then for _,b in ipairs(bindings) do
    if not b.addressed and #fn.saved<#regs then local r=regs[#fn.saved+1];b.reg=r;fn.saved[#fn.saved+1]=r end
  end end
  if fn.needs_rbx then local found=false;for _,r in ipairs(fn.saved) do if r==3 then found=true end end;if not found then fn.saved[#fn.saved+1]=3 end end
end

local leaf_safe_call={['seç']=true,['adres_ekle']=true,['gör']=true,['dizi_gör']=true,['bit_gör']=true,['boyut']=true,['adres']=true,['adres_bitleri']=true,['bayt_oku']=true,['bayt_yaz']=true,['sayı_oku']=true,['sayı_yaz']=true,['çarp_yüksek_u64']=true,['işlev_adresi']=true,['dizi']=true,['yerel']=true,['yerel_dizi']=true,['bit_say']=true,['ilk_bit']=true,['son_bit']=true,['bayt_ters']=true,['bit_ters']=true,['öngetir']=true,['işlemci_bekle']=true,['karekök']=true}
local function leaf_body(n)
  if type(n)~='table' then return true end
  if n[1]=='call' then
    local c=n[2]
    if not (leaf_safe_call[c] or numeric[c] or c:match('^[iuf]%d+_oku$') or c:match('^[iuf]%d+_yaz$') or c=='adres_oku' or c=='adres_yaz') then return false end
  end
  for _,v in ipairs(n) do if not leaf_body(v) then return false end end
  if n.step and not leaf_body(n.step) then return false end
  return true
end
for _,fn in ipairs(functions) do fn.leaf=leaf_body(fn[3]);allocate_registers(fn) end

local reachable={}
local visit_function
local function visit_node(n)
  if type(n)~='table' then return end
  if n[1]=='call' then
    if n[2]=='işlemci_özellikleri' and target=='arm64' then visit_function('__t_arm_features')
    elseif n[2]=='yoğun_blok_u8_i8_i32' then visit_function('__t_yoğun_blok_düz')
    elseif n[2]=='karışım_i32' then visit_function('__t_karışım_düz')
    elseif n[2]=='vektör_topla_çıkar_i16' then visit_function('__t_topla_çıkar_i16_düz')
    elseif n[2]=='vektör_topla_çıkar_i32' then visit_function('__t_topla_çıkar_i32_düz')
    elseif n[2]=='yoğun_i16' then visit_function('__t_yoğun_i16_düz')
    elseif n[2]=='ekle_relu512_i32_i16' then visit_function('__t_ekle_relu512_i32_i16_düz')
    elseif n[2]=='havuz_i16' then visit_function('__t_havuz_i16_düz')
    elseif n[2]=='taş_havuz_i16' then visit_function('__t_taş_havuz_i16_düz')
    elseif n[2]=='taşlar_havuz_i16' then visit_function('__t_taşlar_havuz_i16_düz')
    elseif n[2]=='işlev_adresi' then visit_function(n[3][1][2])
    elseif n[2]=='yeni_dizi' then visit_function('__t_array_alloc')
    elseif declarations[n[2]] then visit_function(n[2]) end
  end
  for _,v in ipairs(n) do if type(v)=='table' then visit_node(v) end end
  if n.step then visit_node(n.step) end
end
visit_function=function(name)
  if reachable[name] then return end;reachable[name]=true
  if declarations[name] then visit_node(declarations[name][3]) end
end
visit_function('ana');if windows then visit_function('__t_giriş') end
local main_entry='ana'
if reachable['argüman_sayısı'] or reachable['argüman_boyu'] or reachable['argüman_oku'] then
  if windows then
    table.insert(declarations['__t_giriş'][3],1,{'eval',{'call','__t_args_init',{},type='i64'}})
    visit_function('__t_args_init')
  else main_entry='__t_main';visit_function(main_entry) end
end
local selected={};for _,fn in ipairs(functions) do if reachable[fn[1]] then selected[#selected+1]=fn end end
functions=selected

local YBC,YBK
if arka=='yeni' or dokum then
  YBC={hata=fail,sayisal=numeric,yapilar=structures,genel=globals,ilkel=primitives,
       yerlesik=builtins,bildirim=declarations,geri=callbacks,sabit=constants,
       oncelik=precedence,isaretci=pointer_type,hedef=target,komut=instruction,
       opt=optimization}
  YBK=Y.kurucu(YBC)
  for _,fn in ipairs(functions) do
    location=fn.line or location
    fn.ir=YBK.kur(fn)
  end
  if arka=='yeni' and optimization>0 then

    local ir_tablo={}
    for _,fn in ipairs(functions) do ir_tablo[fn[1]]=fn.ir end
    for _,fn in ipairs(functions) do
      local f=fn.ir
      Y.kopyalari_coz(f); Y.olu_ele(f)
      local maliyet,bloklar=Y.maliyet(f)
      local ozyineli=false
      for _,b in ipairs(f.bloklar) do
        for _,id in ipairs(b.k) do
          local t=f.d[id]
          if t.op=='cagri' and t.ad==fn[1] then ozyineli=true end
          if t.op=='ic' then ozyineli=true end
        end
      end
      f.inline_uygun=(not ozyineli) and maliyet<=yb_inline and bloklar<=12
                     and fn[1]~='ana' and fn[1]~='__t_main'
    end
    for _,fn in ipairs(functions) do
      if Y.inline(fn.ir,ir_tablo) then Y.kopyalari_coz(fn.ir); Y.olu_ele(fn.ir) end
    end
  end
  if dokum then
    local h=assert(io.open(dokum,'w'))
    local toplam,en={},{}
    for _,fn in ipairs(functions) do
      h:write(Y.dokum(fn.ir),'\n\n')
      for o,c in pairs(Y.istatistik(fn.ir)) do toplam[o]=(toplam[o] or 0)+c end
      en[#en+1]={fn.ir.n,fn[1],#fn.ir.bloklar,fn.ir.yuva}
    end
    table.sort(en,function(a,b) return a[1]>b[1] end)
    h:write('=== komut sayilari ===\n')
    local liste={}
    for o,c in pairs(toplam) do liste[#liste+1]={c,o} end
    table.sort(liste,function(a,b) return a[1]>b[1] end)
    for _,x in ipairs(liste) do h:write(string.format('%8d %s\n',x[1],x[2])) end
    h:write('=== en buyuk islevler ===\n')
    for i=1,math.min(20,#en) do
      h:write(string.format('%8d deger %4d blok %8d yuva  %s\n',en[i][1],en[i][3],en[i][4],en[i][2]))
    end
    h:close()
    print('dokum: '..dokum)
  end
end

local code={};local labels={};local patches={};local serial=0
local function bytes(s) for i=1,#s do code[#code+1]=s:byte(i) end end
local function u32(n) bytes(string.pack('<I4',n & 0xffffffff)) end
local function hex(s) for b in s:gmatch('%x%x') do code[#code+1]=tonumber(b,16) end end
local function label() serial=serial+1;return serial end
local dead_after=-1;local x0_alias;local pending_marks={};local pending_at=-1
local function mark(l)
  if pending_at~=#code then pending_marks={};pending_at=#code end

  local p=patches[#patches]
  if p and p[3]=='b' and p[2]==l and p[1]==#code-4 then
    patches[#patches]=nil;for i=1,4 do code[#code]=nil end
    for _,m in ipairs(pending_marks) do labels[m]=#code end;pending_at=#code
  end
  labels[l]=#code;pending_marks[#pending_marks+1]=l;dead_after=-1;x0_alias=nil
end
local arm=target=='arm64'
local function jump(l,zero,call)
  if arm and not zero and not call and dead_after==#code then return end
  if arm then patches[#patches+1]={#code,l,zero and 'cbz' or (call and 'bl' or 'b')};u32(zero and 0xb4000000 or (call and 0x94000000 or 0x14000000))
    if not zero and not call then dead_after=#code end
  else
    if zero then hex('48 85 c0 0f 84') else hex(call and 'e8' or 'e9') end

    local bicim
    if not call then bicim=zero and 'jcc' or 'jmp' end
    patches[#patches+1]={#code,l,'rel32',bicim};u32(0)
  end
end
local slots=0;local scopes={};local function lookup(name)
  for i=#scopes,1,-1 do if scopes[i][name] then return scopes[i][name] end end
  fail('tanımsız değişken: '..name)
end
local function load(slot)
  if arm then u32(0xf94003e0 | ((slot-1)<<10)) else hex('48 8b 85');u32(windows and (slot-1)*8 or -slot*8) end
end
local function save(slot)
  if arm then u32(0xf90003e0 | ((slot-1)<<10)) else hex('48 89 85');u32(windows and (slot-1)*8 or -slot*8) end
end

local function move_register(dst,src)
  if dst==src then return end
  if arm then u32(0xaa0003e0 | (src<<16) | dst)
  else bytes(string.char(0x48 | (src>=8 and 4 or 0) | (dst>=8 and 1 or 0),0x89,0xc0 | ((src&7)<<3) | (dst&7))) end
end
local function frame_address(offset,reg)
  reg=reg or 0
  if offset<4096 then u32(0x910003a0 | (offset<<10) | reg)
  else
    u32(0x914003a0 | ((offset//4096)<<10) | reg)
    if offset%4096~=0 then u32(0x91000000 | ((offset%4096)<<10) | (reg<<5) | reg) end
  end
end
local function frame_memory(offset,reg,write)
  local base=29
  if offset>=32768 then frame_address(offset,16);base=16;offset=0 end
  u32((write and 0xf9000000 or 0xf9400000) | ((offset//8)<<10) | (base<<5) | reg)
end
local function local_load(s)
  if type(s)=='table' then if s.reg then move_register(0,s.reg);return end;s=s.slot end
  if arm then frame_memory((s-1)*8,0,false) else load(s) end
end
local function local_save(s)
  if type(s)=='table' then if s.reg then move_register(s.reg,0);x0_alias={b=s,at=#code};return end;s=s.slot end
  if arm then frame_memory((s-1)*8,0,true) else save(s) end
end
local entries={};for _,fn in ipairs(functions) do entries[fn[1]]=label() end
local data={}
Y.hizalar={}
local relocations={};local global_relocations={}
local function global_address(g)
  if arm then global_relocations[#global_relocations+1]={#code,g};u32(0x90000000);u32(0x91000000)
  else hex('48 8d 05');global_relocations[#global_relocations+1]={#code,g};u32(0) end
end
local function external(index)
  if arm and linux then
    relocations[#relocations+1]={#code,index};u32(0x90000010);u32(0xf9400210);u32(0xd63f0200)
  elseif arm then relocations[#relocations+1]={#code,index};u32(0x94000000)
  else
    hex((windows or linux) and 'ff 15' or 'e8');relocations[#relocations+1]={#code,index};u32(0)
  end
end
local function push()
  if arm then u32(0xf81f0fe0) else hex('48 83 ec 10 48 89 04 24') end
end
local function pop(reg)
  if arm then u32(0xf84107e0 | reg)
  else

    if reg>=8 then hex('4c') else hex('48') end
    bytes(string.char(0x8b,0x04 | ((reg&7)<<3),0x24));hex('48 83 c4 10')
  end
end
local function address(l)
  if arm then global_relocations[#global_relocations+1]={#code,{text_label=l}};u32(0x90000000);u32(0x91000000)
  else hex('48 8d 05');patches[#patches+1]={#code,l,'rel32'};u32(0) end
end
local function normalize(t,reg)
  local n=numeric[t or 'i64'];if not n or n.float or n[1]==64 then return end
  reg=reg or 0
  if arm then
    u32((n[2] and 0x93400000 or 0xd3400000) | ((n[1]-1)<<10) | (reg<<5) | reg)
  else
    local mod=0xc0|((reg&7)<<3)|(reg&7)
    if t=='u32' then if reg>=8 then bytes('\69') end;bytes(string.char(0x89,mod))
    else
      bytes(string.char(0x48|(reg>=8 and 5 or 0)))
      if t=='i32' then bytes(string.char(0x63,mod))
      else bytes(string.char(0x0f,assert(({i8=0xbe,u8=0xb6,i16=0xbf,u16=0xb7})[t]),mod)) end
    end
  end
end
local function field_address(e)
  return {'call','adres_ekle',{e[2],{'num',e.field.offset}}}
end
local function memory_node(lhs,value)
  local address,index,t
  if lhs[1]=='field' then address=field_address(lhs);index={'num',0};t=lhs.type
  else address=lhs[2];index=lhs[3];t=lhs.element end
  local stem=numeric[t] and t or 'adres'
  return {'call',stem..(value and '_yaz' or '_oku'),value and {address,index,value} or {address,index},type=t}
end
local generate
local function fp_in(t,reg,source)
  if arm then u32((t=='f32' and 0x1e270000 or 0x9e670000) | (source<<5) | reg)
  else hex(t=='f32' and '66 0f 6e' or '66 48 0f 6e');bytes(string.char(0xc0 | (reg<<3) | source)) end
end
local function fp_out(t)
  if arm then u32(t=='f32' and 0x1e260000 or 0x9e660000) else hex(t=='f32' and '66 0f 7e c0' or '66 48 0f 7e c0') end
end
local function fp_compare(t) if arm then u32(t=='f32' and 0x1e212000 or 0x1e612000) else hex(t=='f32' and '0f 2e c1' or '66 0f 2e c1') end end
local function condition_branch(l,ac,xc)
  if arm then patches[#patches+1]={#code,l,'cond'..ac};u32(0x54000000|ac)
  else hex('0f');bytes(string.char(xc));patches[#patches+1]={#code,l,'rel32','jcc'};u32(0) end
end
local function scalar_leaf(e)
  if e[1]=='call' and numeric[e[2]] and numeric[e[2]][1]==64 and not numeric[e[2]].float and (numeric[e[3][1].type] or {})[1]==64 and not numeric[e[3][1].type].float then return scalar_leaf(e[3][1]) end

  if e[1]=='call' and (e[2]=='adres' or e[2]=='adres_bitleri') then return scalar_leaf(e[3][1]) end
  if e[1]=='call' and (e[2]=='gör' or e[2]=='dizi_gör') then return scalar_leaf(e[3][2]) end
  return e
end
local temp_depth=0
local temp_registers=arm and {9,10,11,12,13,14,15} or {10,11,8,9}
local function scratch_safe(e)
  if (numeric[e.type] or {}).float or (numeric[e.operand] or {}).float then return false end
  if e[1]=='num' or e[1]=='var' then return not e.global end
  if e[1]=='neg' or e[1]=='bitnot' then return scratch_safe(e[2]) end
  if e[1]=='call' and numeric[e[2]] and not numeric[e[2]].float then return scratch_safe(e[3][1]) end
  return precedence[e[1]]~=nil and scratch_safe(e[2]) and scratch_safe(e[3])
end
local function simple(e)
  e=scalar_leaf(e)
  return not (numeric[e.type] or {}).float and (e[1]=='num' or (e[1]=='var' and (e.constant~=nil or e.binding)))
end
local function immediate(value,reg)
  if arm then
    local chunks,z,n={},0,0
    for i=0,3 do chunks[i]=(value>>(i*16))&65535;if chunks[i]~=0 then z=z+1 end;if chunks[i]~=65535 then n=n+1 end end
    local invert=n<z;local fill=invert and 65535 or 0;local first=true
    for i=0,3 do
      if chunks[i]~=fill then
        if first then u32((invert and 0x92800000 or 0xd2800000) | (i<<21) | ((invert and (~chunks[i]&65535) or chunks[i])<<5) | reg);first=false
        else u32(0xf2800000 | (i<<21) | (chunks[i]<<5) | reg) end
      end
    end
    if first then u32((invert and 0x92800000 or 0xd2800000) | reg) end
  elseif value==0 then
    if reg>=8 then bytes('\69') end;bytes(string.char(0x31,0xc0|((reg&7)<<3)|(reg&7)))
  elseif value>0 and value<=0xffffffff then
    if reg>=8 then bytes('\65') end;bytes(string.char(0xb8|(reg&7)));u32(value)
  elseif value>=-2147483648 and value<0 then
    bytes(string.char(0x48|(reg>=8 and 1 or 0),0xc7,0xc0|(reg&7)));u32(value)
  else bytes(string.char(0x48|(reg>=8 and 1 or 0),0xb8|(reg&7)));bytes(string.pack('<i8',value)) end
end
local function generate_leaf(e,reg)
  e=scalar_leaf(e)
  if e[1]=='var' and e.constant==nil then
    local b=e.binding
    if b.reg then move_register(reg,b.reg)
    elseif arm then frame_memory((b.slot-1)*8,reg,false);normalize(e.type,reg)
    else bytes(string.char(0x48 | (reg>=8 and 4 or 0),0x8b,0x85 | ((reg&7)<<3)));u32(windows and (b.slot-1)*8 or -b.slot*8)
      normalize(e.type,reg)
    end
  else immediate(e.constant or e[2],reg) end
end
local H={}

local function global_address_reg(g,r)
  global_relocations[#global_relocations+1]={#code,g};u32(0x90000000|r);u32(0x91000000|(r<<5)|r)
end
local function yb_cpu_dal(bit,l)
  global_address_reg(globals.__t_cpu_cache,16)
  u32(0xf9400000|(16<<5)|16)
  u32(0x92000000|(H.encode_logical(bit)<<10)|(16<<5)|16)
  patches[#patches+1]={#code,l,'cbz'};u32(0xb4000000|16)
end

function H.x64_cpu_dal(bit,l)
  hex('f6 05');global_relocations[#global_relocations+1]={#code,globals.__t_cpu_cache,bias=1};u32(0)
  bytes(string.char(bit&255));condition_branch(l,0,0x84)
end
local function memory_arguments(args,write)

  if optimization>0 and simple(args[2]) and (not write or simple(args[3])) then
    generate(args[1]);generate_leaf(args[2],1);if write then generate_leaf(args[3],2) end
  elseif arm and optimization>0 and not write and scratch_safe(args[2]) then

    local base=args[1];local inner,c=H.split_base(base)
    local rb=H.leaf_register(base)
    if rb then generate(args[2]);move_register(1,0);move_register(0,rb)
    elseif c>=0 and c<16777216 and H.leaf_register(inner) then generate(args[2]);move_register(1,0);generate(base)
    elseif temp_depth<#temp_registers then
      temp_depth=temp_depth+1;local t=temp_registers[temp_depth];generate(base);move_register(t,0);generate(args[2]);move_register(1,0);move_register(0,t);temp_depth=temp_depth-1
    else generate(base);push();generate(args[2]);move_register(1,0);pop(0) end
  else
    for _,a in ipairs(args) do generate(a);push() end
    if write then pop(2) end;pop(1);pop(0)
  end
end

H.arm_ops={['+']=0x8b000000,['-']=0xcb000000,['*']=0x9b007c00,['&']=0x8a000000,['|']=0xaa000000,['^']=0xca000000,['<<']=0x9ac02000,['>>']=0x9ac02400}
H.arm_logical={['&']=0x92000000,['|']=0xb2000000,['^']=0xd2000000}
H.signed_cond={['==']=0,['!=']=1,['<']=11,['>=']=10,['>']=12,['<=']=13}
H.unsigned_cond={['==']=0,['!=']=1,['<']=3,['>=']=2,['>']=8,['<=']=9}
H.mirrored={['<']='>',['>']='<',['<=']='>=',['>=']='<=',['==']='==',['!=']='!=',['+']='+',['*']='*',['&']='&',['|']='|',['^']='^'}
function H.is_float(e) return (numeric[e.type] or {}).float or (numeric[e.operand] or {}).float end
function H.leaf_register(e)
  e=scalar_leaf(e)
  if e[1]=='var' and e.constant==nil and not e.global and e.binding and e.binding.reg then return e.binding.reg end
end
function H.leaf_constant(e)
  e=scalar_leaf(e)
  if e[1]=='num' and math.type(e[2])=='integer' then return e[2] end
  if e[1]=='var' and e.constant~=nil and math.type(e.constant)=='integer' then return e.constant end
end

function H.encode_logical(v)
  if v==0 or v==-1 then return nil end
  local size=64
  while size>2 do
    local half=size//2;local mask=(1<<half)-1
    if (v & mask)~=((v>>half) & mask) then break end
    size=half
  end
  local full=size==64 and -1 or ((1<<size)-1)
  local elem=v & full;local ones=0
  for i=0,size-1 do if ((elem>>i)&1)==1 then ones=ones+1 end end
  if ones==0 or ones==size then return nil end
  local run=(1<<ones)-1
  for r=0,size-1 do
    local rot=r==0 and run or (((run>>r) | (run<<(size-r))) & full)
    if rot==elem then return ((size==64 and 1 or 0)<<12) | (r<<6) | (((~(2*size-1)) & 0x3f) | (ones-1)) end
  end
end
function H.arm_immediate(op,v)
  if op=='+' or op=='-' or H.signed_cond[op] then
    if v>=0 and v<4096 then return {'arith',v} elseif v<0 and v>-4096 then return {'arith_neg',-v} end
  elseif op=='<<' or op=='>>' then if v>=0 and v<64 then return {'shift',v} end
  elseif op=='*' then if v>0 and (v&(v-1))==0 then for i=0,62 do if v==(1<<i) then return {'shift',i} end end end
  elseif H.arm_logical[op] then local enc=H.encode_logical(v);if enc then return {'logical',enc} end end
end

function H.arm_operands(e)
  local op,l,r=e[1],e[2],e[3]
  if H.mirrored[op] and H.leaf_constant(l) and not H.leaf_constant(r) then op=H.mirrored[op];l,r=r,l end
  local c=H.leaf_constant(r);local imm=c and H.arm_immediate(op,c)
  local rl=H.leaf_register(l)
  if rl then
    if imm then return op,rl,nil,imm end
    local rr=H.leaf_register(r);if rr then return op,rl,rr end
    if simple(r) then generate_leaf(r,0);return op,rl,0 end
    generate(r);return op,rl,0
  end
  if simple(l) then
    if imm then generate_leaf(l,0);return op,0,nil,imm end
    local rr=H.leaf_register(r);if rr then generate_leaf(l,0);return op,0,rr end
    if simple(r) then generate_leaf(l,1);generate_leaf(r,0);return op,1,0 end
  end
  generate(l)
  if imm then return op,0,nil,imm end
  local rr=H.leaf_register(r);if rr then return op,0,rr end
  if simple(r) then generate_leaf(r,1);return op,0,1 end
  if temp_depth<#temp_registers and (scratch_safe(r) or H.pure(r)) then
    temp_depth=temp_depth+1;local t=temp_registers[temp_depth];move_register(t,0);generate(r);temp_depth=temp_depth-1;return op,t,0
  end
  push();generate(r);pop(1);return op,1,0
end
function H.arm_compare(e)
  local op,rn,rm,imm=H.arm_operands(e)
  if imm then u32((imm[1]=='arith' and 0xf100001f or 0xb100001f) | (imm[2]<<10) | (rn<<5))
  else u32(0xeb00001f | (rm<<16) | (rn<<5)) end
  local conds=(e.operand and numeric[e.operand] and not numeric[e.operand][2]) and H.unsigned_cond or H.signed_cond
  return conds[op]
end
function H.emit_arm_binary(e,dst)
  if H.signed_cond[e[1]] then u32(0x9a9f07e0 | ((H.arm_compare(e)~1)<<12) | dst);return end
  local op,rn,rm,imm=H.arm_operands(e)
  local bits=e.operand and numeric[e.operand] and numeric[e.operand][1] or 64
  if op=='>>' and bits<64 then u32(0xd3400002 | ((bits-1)<<10) | (rn<<5));rn=2 end
  if imm then
    if imm[1]=='arith' or imm[1]=='arith_neg' then
      local add=(op=='+')==(imm[1]=='arith')
      u32((add and 0x91000000 or 0xd1000000) | (imm[2]<<10) | (rn<<5) | dst)
    elseif imm[1]=='shift' then
      local sh=imm[2]
      if op=='>>' then u32(0xd340fc00 | (sh<<16) | (rn<<5) | dst)
      else u32(0xd3400000 | (((64-sh)%64)<<16) | ((63-sh)<<10) | (rn<<5) | dst) end
    else u32(H.arm_logical[op] | (imm[2]<<10) | (rn<<5) | dst) end
  else u32(H.arm_ops[op] | (rm<<16) | (rn<<5) | dst) end
  normalize(e.type,dst)
end
function H.arm_branchable(e) return arm and optimization>0 and (e[1]=='&&' or e[1]=='||' or (H.signed_cond[e[1]] and not H.is_float(e))) end

function H.x64_branch(e,l,truth)
  if arm or optimization==0 then return false end
  local op=e[1]
  if op=='&&' or op=='||' then
    if (op=='&&')~=truth then
      if truth then H.branch_true(e[2],l);H.branch_true(e[3],l)
      else H.branch_false(e[2],l);H.branch_false(e[3],l) end
    else
      local skip=label()
      if truth then H.branch_false(e[2],skip);H.branch_true(e[3],l)
      else H.branch_true(e[2],skip);H.branch_false(e[3],l) end
      mark(skip)
    end
    return true
  end
  if not H.signed_cond[op] or H.is_float(e) then return false end
  local c=H.leaf_constant(e[3]);generate(e[2])
  if c and c>=-2147483648 and c<=2147483647 then
    if c==0 then hex('48 85 c0')
    elseif c>=-128 and c<=127 then hex('48 83 f8');bytes(string.char(c&255))
    else hex('48 3d');u32(c&0xffffffff) end
  else
    if simple(e[3]) then generate_leaf(e[3],1)
    else push();generate(e[3]);move_register(1,0);pop(0) end
    hex('48 39 c8')
  end
  local unsigned=e.operand and numeric[e.operand] and not numeric[e.operand][2]
  local cc=({['==']=0x84,['!=']=0x85,['<']=unsigned and 0x82 or 0x8c,
    ['<=']=unsigned and 0x86 or 0x8e,['>']=unsigned and 0x87 or 0x8f,
    ['>=']=unsigned and 0x83 or 0x8d})[op]
  condition_branch(l,0,truth and cc or (cc~1));return true
end
H.branch_false=function(e,l)
  if H.x64_branch(e,l,false) then return end
  local op=e[1]
  if H.arm_branchable(e) then
    if op=='&&' then H.branch_false(e[2],l);H.branch_false(e[3],l);return end
    if op=='||' then local t=label();H.branch_true(e[2],t);H.branch_false(e[3],l);mark(t);return end
    if (op=='==' or op=='!=') and H.leaf_constant(e[3])==0 and not H.leaf_constant(e[2]) then
      local r=H.leaf_register(e[2]);if not r then generate(e[2]);r=0 end
      patches[#patches+1]={#code,l,op=='==' and 'cbnz' or 'cbz'};u32((op=='==' and 0xb5000000 or 0xb4000000) | r);return
    end
    condition_branch(l,H.arm_compare(e)~1,0);return
  end
  generate(e);jump(l,true)
end
H.branch_true=function(e,l)
  if H.x64_branch(e,l,true) then return end
  local op=e[1]
  if H.arm_branchable(e) then
    if op=='||' then H.branch_true(e[2],l);H.branch_true(e[3],l);return end
    if op=='&&' then local f=label();H.branch_false(e[2],f);H.branch_true(e[3],l);mark(f);return end
    if (op=='==' or op=='!=') and H.leaf_constant(e[3])==0 and not H.leaf_constant(e[2]) then
      local r=H.leaf_register(e[2]);if not r then generate(e[2]);r=0 end
      patches[#patches+1]={#code,l,op=='!=' and 'cbnz' or 'cbz'};u32((op=='!=' and 0xb5000000 or 0xb4000000) | r);return
    end
    condition_branch(l,H.arm_compare(e),0);return
  end
  generate(e)
  if arm then patches[#patches+1]={#code,l,'cbnz'};u32(0xb5000000)
  else hex('48 85 c0');condition_branch(l,0,0x85) end
end

H.pure_call={['seç']=true,['adres_ekle']=true,['gör']=true,['dizi_gör']=true,['bit_gör']=true,['boyut']=true,['adres']=true,['adres_bitleri']=true,['bayt_oku']=true,['sayı_oku']=true,['adres_oku']=true,['çarp_yüksek_u64']=true,['işlev_adresi']=true}
for k in pairs(pure_bit_call) do H.pure_call[k]=true end
function H.pure(e)
  local op=e[1]
  if H.is_float(e) then return false end
  if op=='num' or op=='string' or op=='global_address' or op=='var' then return true end
  if op=='neg' or op=='bitnot' or op=='field' then return H.pure(e[2]) end
  if op=='index' then return H.pure(e[2]) and H.pure(e[3]) end
  if op=='ref' then return e[2][1]=='var' or H.pure(e[2]) end
  if op=='call' then
    local n=e[2]
    if numeric[n] then return H.pure(e[3][1]) end
    if H.pure_call[n] or n:match('^[iu]%d+_oku$') then
      for _,a in ipairs(e[3]) do if not H.pure(a) then return false end end;return true
    end
    return false
  end
  if precedence[op] then return H.pure(e[2]) and H.pure(e[3]) end
  return false
end

H.arm_load_imm={u8=0x39400000,i8=0x39800000,u16=0x79400000,i16=0x79800000,u32=0xb9400000,i32=0xb9800000,f32=0xb9400000,u64=0xf9400000,i64=0xf9400000,f64=0xf9400000,adres=0xf9400000}
H.arm_store_imm={[8]=0x39000000,[16]=0x79000000,[32]=0xb9000000,[64]=0xf9000000}

H.arm_load_reg={u8=0x38606800,i8=0x38a06800,u16=0x78607800,i16=0x78a07800,u32=0xb8607800,i32=0xb8a07800,f32=0xb8607800,u64=0xf8607800,i64=0xf8607800,f64=0xf8607800,adres=0xf8607800}
H.arm_store_reg={[8]=0x38206800,[16]=0x78207800,[32]=0xb8207800,[64]=0xf8207800}

function H.split_base(base)
  local off=0
  while true do
    if base[1]=='field' and base.field and base.field.array then off=off+base.field.offset;base=base[2]
    elseif base[1]=='call' and base[2]=='adres_ekle' and H.leaf_constant(base[3][2]) then off=off+H.leaf_constant(base[3][2]);base=base[3][1]
    else return base,off end
  end
end

function H.arm_indexed_access(args,write,memtype,dest)
  dest=dest or 0
  local base,idx=args[1],args[2]
  local inner,off=H.split_base(base)
  local rb=H.leaf_register(inner)
  if not rb or off<0 or off>=16777216 then return false end
  local discard=H.discard;H.discard=false
  local width=memtype=='adres' and 64 or numeric[memtype][1]
  local ri=H.leaf_register(idx);local rv
  if write then
    local v=args[3];rv=H.leaf_register(v) or (H.leaf_constant(v)==0 and 31 or nil)
    local simple_idx=ri or simple(idx);local simple_v=rv or simple(v)
    if not simple_idx and not simple_v then return false end
    if not simple_v then generate(v);rv=0
    elseif not simple_idx then generate(idx);move_register(1,0);ri=1 end
    if not ri then generate_leaf(idx,1);ri=1 end
    if not rv then generate_leaf(v,2);rv=2 end
  else
    if not ri then
      if simple(idx) then generate_leaf(idx,1);ri=1
      elseif scratch_safe(idx) or H.pure(idx) then generate(idx);ri=0
      else return false end
    end
  end
  if off>0 then
    local rt=0;while rt==ri or rt==rv do rt=rt+1 end
    if off<4096 then u32(0x91000000 | (off<<10) | (rb<<5) | rt)
    else u32(0x91400000 | ((off>>12)<<10) | (rb<<5) | rt);if off%4096~=0 then u32(0x91000000 | ((off%4096)<<10) | (rt<<5) | rt) end end
    rb=rt
  end
  if write then
    u32(H.arm_store_reg[width] | (ri<<16) | (rb<<5) | rv);if not discard then move_register(0,rv) end
  else u32(H.arm_load_reg[memtype] | (ri<<16) | (rb<<5) | dest) end
  return true
end
function H.arm_memory_access(args,write,memtype,dest)
  dest=dest or 0
  local width=memtype=='adres' and 8 or numeric[memtype][1]//8
  local idx=H.leaf_constant(args[2]);if not idx then return false end
  local base,off=H.split_base(args[1])
  off=off+idx*width
  if off<0 or off%width~=0 or off>=16777216 then return false end
  local discard=H.discard;H.discard=false
  local rb=H.leaf_register(base)

  local g=(base[1]=='global_address' and base[2]) or (base[1]=='var' and base.global and base.global.direct and base.global)
  if g and emit=='exe' and not g.text_label then
    local rv
    if write then
      local v=args[3]
      if H.leaf_constant(v)==0 then rv=31 elseif H.leaf_register(v) then rv=H.leaf_register(v)
      elseif simple(v) then generate_leaf(v,2);rv=2 else generate(v);rv=0 end
    end
    local ra=write and 1 or dest
    local opcode=(write and H.arm_store_imm[width*8] or H.arm_load_imm[memtype]) | (ra<<5) | (write and rv or dest)
    global_relocations[#global_relocations+1]={#code,g,opcode=opcode,width=width,extra=off}
    u32(0x90000000 | ra);u32(opcode)
    if write and not discard then move_register(0,rv) end
    return true
  end

  local hi=0;if off//width>=4096 then hi=(off>>12)<<12;off=off-hi;if off//width>=4096 then return false end end
  local function base_into(rt)
    if hi>0 then u32(0x91400000 | ((hi>>12)<<10) | ((rb or 0)<<5) | rt);return rt end
    return rb or 0
  end
  if write then
    local v=args[3];local rv
    if H.leaf_constant(v)==0 then if not rb then generate(base) end;rv=31
    elseif H.leaf_register(v) then if not rb then generate(base) end;rv=H.leaf_register(v)
    elseif simple(v) then if not rb then generate(base) end;generate_leaf(v,2);rv=2
    elseif rb then generate(v);rv=0
    else generate(base);push();generate(v);move_register(2,0);pop(0);rv=2 end
    local rn=base_into(rv==1 and 2 or 1)
    u32(H.arm_store_imm[width*8] | ((off//width)<<10) | (rn<<5) | rv);if not discard then move_register(0,rv) end
  else
    if not rb then generate(base) end
    local rn=base_into(0)
    u32(H.arm_load_imm[memtype] | ((off//width)<<10) | (rn<<5) | dest)
  end
  return true
end

function H.arm_update(addr,rhs,op,t)
  local inner,off=H.split_base(addr)
  local rb=H.leaf_register(inner);local ri
  if not rb then
    if addr[1]=='call' and addr[2]=='adres_ekle' and addr[3][2][1]=='*' and H.leaf_constant(addr[3][2][3])==numeric[t][1]//8 then
      ri=H.leaf_register(addr[3][2][2]);rb=H.leaf_register(addr[3][1]);off=0
    end
    if not rb or not ri then return false end
  end
  local width=numeric[t][1]//8
  if off<0 or off%width~=0 or off//width>=4096 then return false end
  local c=H.leaf_constant(rhs);local imm=c and H.arm_immediate(op,c);local rr
  if imm then rr=nil elseif H.leaf_register(rhs) then rr=H.leaf_register(rhs) else generate(rhs);rr=0 end
  if ri then u32(H.arm_load_reg[t] | (ri<<16) | (rb<<5) | 1) else u32(H.arm_load_imm[t] | ((off//width)<<10) | (rb<<5) | 1) end
  local bits=numeric[t][1]
  local rn=1
  if op=='>>' and bits<64 then u32(0xd3400002 | ((bits-1)<<10) | (1<<5));rn=2 end
  if imm then
    if imm[1]=='arith' or imm[1]=='arith_neg' then
      local add=(op=='+')==(imm[1]=='arith');u32((add and 0x91000000 or 0xd1000000) | (imm[2]<<10) | (rn<<5))
    elseif imm[1]=='shift' then
      local sh=imm[2]
      if op=='>>' then u32(0xd340fc00 | (sh<<16) | (rn<<5)) else u32(0xd3400000 | (((64-sh)%64)<<16) | ((63-sh)<<10) | (rn<<5)) end
    else u32(H.arm_logical[op] | (imm[2]<<10) | (rn<<5)) end
  else u32(H.arm_ops[op] | (rr<<16) | (rn<<5)) end
  normalize(t,0)
  if ri then u32(H.arm_store_reg[bits] | (ri<<16) | (rb<<5)) else u32(H.arm_store_imm[bits] | ((off//width)<<10) | (rb<<5)) end
  return true
end

function H.load_into(e,dest)
  if e[1]=='field' and (not e.field or e.field.array) then return false end
  if e[1]=='index' and structures[e.element] then return false end
  if e[1]~='field' and e[1]~='index' then return false end
  local m=memory_node(e);local memtype=numeric[m.type] and m.type or 'adres'
  if (numeric[memtype] or {}).float then return false end
  return H.arm_memory_access(m[3],false,memtype,dest) or H.arm_indexed_access(m[3],false,memtype,dest)
end
 generate=function(e)
  local op=e[1]
  if op=='ybyuva' then

    if arm then frame_memory(e[2],0,false) else hex('48 8b 85');u32(e[2]) end
    return
  end
  if op=='ybreg' then

    if arm then move_register(0,e[2]) else move_register(0,e[2]) end
    return
  end
  if op=='real' or (op=='num' and (numeric[e.type] or {}).float) then
    local packed=string.pack(e.type=='f32' and '<f' or '<d',e[2])
    generate({'num',string.unpack(e.type=='f32' and '<I4' or '<i8',packed)});return
  elseif op=='bitnot' then
    generate(e[2]);if arm then u32(0xaa2003e0) else hex('48 f7 d0') end;normalize(e.type);return
  elseif op=='neg' then
    generate(e[2])
    if (numeric[e.type] or {}).float then
      if arm then u32(e.type=='f32' and 0xd2610000 or 0xd2410000)
      else hex('48 0f ba f8');bytes(string.char(e.type=='f32' and 31 or 63)) end
    elseif arm then u32(0xcb0003e0) else hex('48 f7 d8') end
    normalize(e.type);return
  elseif op=='num' then
    immediate(e[2],0)
  elseif op=='string' then
    if e[2]:find('\0',1,true) then fail('metin içinde NUL desteklenmiyor') end
    local l=label();data[#data+1]={l,e[2]..'\0'}
    address(l)
  elseif op=='ref' then
    local lhs=e[2]
    if lhs[1]=='var' then
      if lhs.global then global_address(lhs.global)
      else local b=lhs.binding;assert(b and b.slot and not b.reg,'adres alınan değişken yığında olmalı')
        if arm then frame_address((b.slot-1)*8) else hex('48 8d 85');u32(windows and (b.slot-1)*8 or -b.slot*8) end
      end
    elseif lhs[1]=='field' then generate(field_address(lhs))
    else generate({'call','adres_ekle',{lhs[2],{'*',lhs[3],{'num',structures[lhs.type] and structures[lhs.type].size or numeric[lhs.type][1]//8}}}}) end
    return
  elseif op=='global_address' then global_address(e[2])
  elseif op=='var' then
    if e.global then
      if e.global.direct then global_address(e.global)
      else generate({'call',(numeric[e.type] and e.type or 'adres')..'_oku',{{'global_address',e.global},{'num',0}},type=e.type}) end
    elseif e.constant~=nil then generate({'num',e.constant,type=e.type})
    else

      local b=e.binding or lookup(e[2])
      if x0_alias and x0_alias.b==b and x0_alias.at==#code then return end
      local_load(b)
      if not (type(b)=='table' and b.reg) then normalize(e.type) end
    end
    return
  elseif op=='field' then
    if e.field.array then generate(field_address(e)) else generate(memory_node(e)) end
    return
  elseif op=='index' then
    if structures[e.element] then generate({'call','adres_ekle',{e[2],{'*',e[3],{'num',structures[e.element].size}}}})
    else generate(memory_node(e)) end
    return
  elseif op=='call' then
    local special=e[2]
    if arm and instruction=='neon' and (special=='karışım4_i32' or special=='kaydır_kırp_i16_u8') then
      local mix=special=='karışım4_i32'
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        for r=#e[3]-1,0,-1 do pop(r) end
      end
      local loop,tail,done,bad,exit=label(),label(),label(),label(),label()
      local nreg=mix and 5 or 2
      u32(0xf100001f | (nreg<<5));condition_branch(bad,11,0)
      if not mix then
        u32(0xf1003c7f);condition_branch(bad,8,0)
        u32(0xf103fc9f);condition_branch(bad,8,0)
      end
      local snippets={
        mix_init='c4 0c 04 4e e5 0c 04 4e 06 0d 04 4e 27 0d 04 4e',
        mix_body='20 04 c1 3c 41 04 c1 3c 62 04 c1 3c 83 04 c1 3c 00 9c a4 4e 20 94 a5 4e 40 94 a6 4e 60 94 a7 4e 00 04 81 3c a5 10 00 d1',
        mix_tail='2a 44 40 b8 4b 44 40 b8 6c 44 40 b8 8d 44 40 b8 4a 7d 06 1b 6a 29 07 1b 8a 29 08 1b aa 29 09 1b 0a 44 00 b8 a5 04 00 d1',
        clip16_init='e5 03 03 4b a3 0c 02 4e 01 84 00 4f 82 0c 02 4e',
        clip16_body='20 04 c1 3c 00 44 63 4e 00 64 61 4e 00 6c 62 4e 00 28 21 2e 00 84 00 fc 42 20 00 d1',
        clip16_tail='25 24 80 78 a5 28 c3 9a bf 00 00 f1 e5 b3 85 9a bf 00 04 eb 85 c0 85 9a 05 14 00 38 42 04 00 d1'}
      local key=mix and 'mix' or 'clip16';hex(snippets[key..'_init'])
      if not mix then

        local big=label();mark(big);u32(0xf100001f | (nreg<<5) | (32<<10));condition_branch(loop,11,0)
        hex('24 20 df 4c 84 44 63 4e a5 44 63 4e c6 44 63 4e e7 44 63 4e 84 64 61 4e a5 64 61 4e c6 64 61 4e e7 64 61 4e 84 6c 62 4e a5 6c 62 4e c6 6c 62 4e e7 6c 62 4e 84 28 21 0e a4 28 21 4e c6 28 21 0e e6 28 21 4e 04 18 81 ac 42 80 00 d1');jump(big)
      end
      mark(loop);u32(0xf100001f | (nreg<<5) | ((mix and 4 or 8)<<10));condition_branch(tail,11,0)
      hex(snippets[key..'_body']);jump(loop)
      mark(tail);u32(0xf100001f | (nreg<<5));condition_branch(done,13,0)
      hex(snippets[key..'_tail']);jump(tail)
      mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if special=='seç' then
      local c,a,b=e[3][1],e[3][2],e[3][3]
      if arm and optimization>0 and simple(a) and simple(b) and not H.is_float(c) then
        local cond
        if H.signed_cond[c[1]] then cond=H.arm_compare(c) else generate(c);u32(0xf100001f);cond=1 end
        local ra=H.leaf_register(a);if not ra then generate_leaf(a,1);ra=1 end
        local rb=H.leaf_register(b);if not rb then generate_leaf(b,2);rb=2 end
        u32(0x9a800000 | (rb<<16) | (cond<<12) | (ra<<5));return
      end
      local no,done=label(),label();H.branch_false(c,no)
      generate(a);jump(done);mark(no);generate(b);mark(done);return
    end

    local block_kernel=({['yoğun_blok_u8_i8_i32']='dense',['karışım_i32']='mix',
      ['vektör_topla_çıkar_i16']='fused16',['vektör_topla_çıkar_i32']='fused32'})[special]
    if not arm and block_kernel and instruction~='scalar' then
      local vnni_done
      if block_kernel=='dense' and (instruction=='avx512' or instruction=='avx512bw' or (instruction=='auto' and Y.avx512_auto)) then

        local fallback=label();vnni_done=label()
        H.x64_cpu_dal(128,fallback)
        for _,a in ipairs(e[3]) do generate(a);push() end
        local dense_vnni='48 8b 44 24 50 4c 8b 44 24 20 4c 8b 14 24 4c 8b 4c 24 10 4d 85 c9 0f 88 d7 00 00 00 49 f7 c1 07 00 00 00 0f 85 ca 00 00 00 4d 85 d2 0f 8e c1 00 00 00 49 f7 c2 0f 00 00 00 0f 85 b4 00 00 00 41 bb 80 80 80 80 62 c2 7d 48 7c c3 48 8b 4c 24 40 48 8b 54 24 30 4c 8b 4c 24 10 62 f1 7d 48 ef c0 62 f1 75 48 ef c9 62 f1 6d 48 ef d2 62 f1 65 48 ef db 4d 85 c9 74 43 62 f2 7d 48 58 21 62 f1 fe 48 6f 2a 62 f2 5d 48 50 c5 62 f2 7d 40 50 d5 62 f2 7d 48 58 61 01 62 f1 fe 48 6f 6a 01 62 f2 5d 48 50 cd 62 f2 7d 40 50 dd 48 83 c1 08 48 81 c2 80 00 00 00 49 83 e9 08 75 bd 62 f1 7d 48 fe c1 62 f1 6d 48 fe d3 62 f1 7d 48 fa c2 62 d1 7d 48 fe 00 62 f1 fe 48 7f 00 48 89 54 24 30 48 83 c0 40 49 83 c0 40 49 83 ea 10 0f 85 5c ff ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 60'
        hex(dense_vnni);jump(vnni_done);mark(fallback)
      end
      if instruction=='auto' then
        local done=label()
        for _,choice in ipairs({{7,'avx2'},{3,'avx'}}) do
          local next_label=label()
          generate({'==',{'&',{'var','__t_cpu_cache',global=globals.__t_cpu_cache,type='u64'},{'num',choice[1],type='u64'},type='u64',operand='u64'},{'num',choice[1],type='u64'},type='i64',operand='u64'})
          jump(next_label,true);instruction=choice[2];generate(e);instruction='auto';jump(done);mark(next_label)
        end
        instruction='sse2';generate(e);instruction='auto';mark(done);if vnni_done then mark(vnni_done) end;return
      end
      local profile=(instruction=='avx512' or instruction=='avx512bw') and 'avx2' or instruction
      local snippets={
        fused16_sse2='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 c7 00 00 00 49 83 f9 20 0f 8c 89 00 00 00 f3 0f 6f 01 f3 0f 6f 22 66 0f fd c4 f3 41 0f 6f 20 66 0f f9 c4 f3 0f 6f 49 10 f3 0f 6f 62 10 66 0f fd cc f3 41 0f 6f 60 10 66 0f f9 cc f3 0f 6f 51 20 f3 0f 6f 62 20 66 0f fd d4 f3 41 0f 6f 60 20 66 0f f9 d4 f3 0f 6f 59 30 f3 0f 6f 62 30 66 0f fd dc f3 41 0f 6f 60 30 66 0f f9 dc f3 0f 7f 00 f3 0f 7f 48 10 f3 0f 7f 50 20 f3 0f 7f 58 30 48 83 c0 40 48 83 c1 40 48 83 c2 40 49 83 c0 40 49 83 e9 20 e9 6d ff ff ff 4d 85 c9 74 2b 44 0f bf 11 44 0f bf 1a 45 01 da 45 0f bf 18 45 29 da 66 44 89 10 48 83 c0 02 48 83 c1 02 48 83 c2 02 49 83 c0 02 49 ff c9 eb d0 31 c0 eb 07 48 c7 c0 ff ff ff ff 48 83 c4 50',
        fused32_sse2='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 bd 00 00 00 49 83 f9 10 0f 8c 89 00 00 00 f3 0f 6f 01 f3 0f 6f 22 66 0f fe c4 f3 41 0f 6f 20 66 0f fa c4 f3 0f 6f 49 10 f3 0f 6f 62 10 66 0f fe cc f3 41 0f 6f 60 10 66 0f fa cc f3 0f 6f 51 20 f3 0f 6f 62 20 66 0f fe d4 f3 41 0f 6f 60 20 66 0f fa d4 f3 0f 6f 59 30 f3 0f 6f 62 30 66 0f fe dc f3 41 0f 6f 60 30 66 0f fa dc f3 0f 7f 00 f3 0f 7f 48 10 f3 0f 7f 50 20 f3 0f 7f 58 30 48 83 c0 40 48 83 c1 40 48 83 c2 40 49 83 c0 40 49 83 e9 10 e9 6d ff ff ff 4d 85 c9 74 21 44 8b 11 44 03 12 45 2b 10 44 89 10 48 83 c0 04 48 83 c1 04 48 83 c2 04 49 83 c0 04 49 ff c9 eb da 31 c0 eb 07 48 c7 c0 ff ff ff ff 48 83 c4 50',
        mix_sse2='48 8b 44 24 50 4c 8b 4c 24 20 4d 85 c9 0f 88 bd 00 00 00 49 f7 c1 0f 00 00 00 0f 85 b0 00 00 00 48 83 3c 24 00 0f 8e a5 00 00 00 4d 85 c9 0f 84 98 00 00 00 66 0f ef c0 66 0f ef c9 48 8b 4c 24 40 48 8b 54 24 10 4c 8b 14 24 66 0f 6e 22 66 0f 70 e4 00 f3 0f 6f 11 66 0f 6f da 66 0f f4 d4 66 0f 73 d3 20 66 0f f4 dc 66 0f 70 d2 88 66 0f 70 db 88 66 0f 62 d3 66 0f fe c2 f3 0f 6f 51 10 66 0f 6f da 66 0f f4 d4 66 0f 73 d3 20 66 0f f4 dc 66 0f 70 d2 88 66 0f 70 db 88 66 0f 62 d3 66 0f fe ca 48 03 4c 24 30 48 83 c2 08 49 ff ca 75 9a f3 0f 7f 00 f3 0f 7f 48 10 48 83 c0 20 48 83 44 24 40 20 49 83 e9 08 e9 5f ff ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff 48 83 c4 60',
        dense_sse2='48 8b 44 24 50 4c 8b 44 24 20 4c 8b 14 24 4c 8b 4c 24 10 4d 85 c9 0f 88 77 01 00 00 49 f7 c1 07 00 00 00 0f 85 6a 01 00 00 4d 85 d2 0f 8e 61 01 00 00 49 f7 c2 0f 00 00 00 0f 85 54 01 00 00 48 8b 4c 24 40 48 8b 54 24 30 4c 8b 4c 24 10 66 0f ef c0 66 0f ef c9 66 0f ef d2 66 0f ef db 4d 85 c9 0f 84 86 00 00 00 44 8b 19 41 81 f3 80 80 80 80 66 41 0f 6e e3 66 0f 60 e4 66 0f 71 e4 08 66 0f 70 e4 44 f3 0f 7e 2a 66 0f 60 ed 66 0f 71 e5 08 66 0f f5 ec 66 0f fe c5 f3 0f 7e 6a 08 66 0f 60 ed 66 0f 71 e5 08 66 0f f5 ec 66 0f fe cd f3 0f 7e 6a 10 66 0f 60 ed 66 0f 71 e5 08 66 0f f5 ec 66 0f fe d5 f3 0f 7e 6a 18 66 0f 60 ed 66 0f 71 e5 08 66 0f f5 ec 66 0f fe dd 48 83 c1 04 48 83 c2 40 49 83 e9 04 0f 85 7a ff ff ff 66 0f 70 e0 b1 66 0f fe c4 66 0f 70 c0 88 f3 41 0f 7e 20 66 0f fe c4 66 0f d6 00 66 0f 70 e1 b1 66 0f fe cc 66 0f 70 c9 88 f3 41 0f 7e 60 08 66 0f fe cc 66 0f d6 48 08 66 0f 70 e2 b1 66 0f fe d4 66 0f 70 d2 88 f3 41 0f 7e 60 10 66 0f fe d4 66 0f d6 50 10 66 0f 70 e3 b1 66 0f fe dc 66 0f 70 db 88 f3 41 0f 7e 60 18 66 0f fe dc 66 0f d6 58 18 48 83 c0 20 49 83 c0 20 49 83 ea 08 74 22 49 f7 c2 08 00 00 00 74 0b 48 83 44 24 30 20 e9 be fe ff ff 48 83 ea 20 48 89 54 24 30 e9 b0 fe ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff 48 83 c4 60',
        fused16_avx='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 c7 00 00 00 49 83 f9 20 0f 8c 89 00 00 00 c5 fa 6f 01 c5 fa 6f 22 c5 f9 fd c4 c4 c1 7a 6f 20 c5 f9 f9 c4 c5 fa 6f 49 10 c5 fa 6f 62 10 c5 f1 fd cc c4 c1 7a 6f 60 10 c5 f1 f9 cc c5 fa 6f 51 20 c5 fa 6f 62 20 c5 e9 fd d4 c4 c1 7a 6f 60 20 c5 e9 f9 d4 c5 fa 6f 59 30 c5 fa 6f 62 30 c5 e1 fd dc c4 c1 7a 6f 60 30 c5 e1 f9 dc c5 fa 7f 00 c5 fa 7f 48 10 c5 fa 7f 50 20 c5 fa 7f 58 30 48 83 c0 40 48 83 c1 40 48 83 c2 40 49 83 c0 40 49 83 e9 20 e9 6d ff ff ff 4d 85 c9 74 2b 44 0f bf 11 44 0f bf 1a 45 01 da 45 0f bf 18 45 29 da 66 44 89 10 48 83 c0 02 48 83 c1 02 48 83 c2 02 49 83 c0 02 49 ff c9 eb d0 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 50',
        fused32_avx='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 bd 00 00 00 49 83 f9 10 0f 8c 89 00 00 00 c5 fa 6f 01 c5 fa 6f 22 c5 f9 fe c4 c4 c1 7a 6f 20 c5 f9 fa c4 c5 fa 6f 49 10 c5 fa 6f 62 10 c5 f1 fe cc c4 c1 7a 6f 60 10 c5 f1 fa cc c5 fa 6f 51 20 c5 fa 6f 62 20 c5 e9 fe d4 c4 c1 7a 6f 60 20 c5 e9 fa d4 c5 fa 6f 59 30 c5 fa 6f 62 30 c5 e1 fe dc c4 c1 7a 6f 60 30 c5 e1 fa dc c5 fa 7f 00 c5 fa 7f 48 10 c5 fa 7f 50 20 c5 fa 7f 58 30 48 83 c0 40 48 83 c1 40 48 83 c2 40 49 83 c0 40 49 83 e9 10 e9 6d ff ff ff 4d 85 c9 74 21 44 8b 11 44 03 12 45 2b 10 44 89 10 48 83 c0 04 48 83 c1 04 48 83 c2 04 49 83 c0 04 49 ff c9 eb da 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 50',
        mix_avx='48 8b 44 24 50 4c 8b 4c 24 20 4d 85 c9 0f 88 b5 00 00 00 49 f7 c1 0f 00 00 00 0f 85 a8 00 00 00 48 83 3c 24 00 0f 8e 9d 00 00 00 4d 85 c9 0f 84 90 00 00 00 c5 f9 ef c0 c5 f1 ef c9 48 8b 4c 24 40 48 8b 54 24 10 4c 8b 14 24 c5 f9 6e 22 c5 f9 70 e4 00 c5 fa 6f 11 c5 e1 73 d2 20 c5 e9 f4 d4 c5 e1 f4 dc c5 f9 70 d2 88 c5 f9 70 db 88 c5 e9 62 d3 c5 f9 fe c2 c5 fa 6f 51 10 c5 e1 73 d2 20 c5 e9 f4 d4 c5 e1 f4 dc c5 f9 70 d2 88 c5 f9 70 db 88 c5 e9 62 d3 c5 f1 fe ca 48 03 4c 24 30 48 83 c2 08 49 ff ca 75 a2 c5 fa 7f 00 c5 fa 7f 48 10 48 83 c0 20 48 83 44 24 40 20 49 83 e9 08 e9 67 ff ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 60',
        dense_avx='48 8b 44 24 50 4c 8b 44 24 20 4c 8b 14 24 4c 8b 4c 24 10 4d 85 c9 0f 88 77 01 00 00 49 f7 c1 07 00 00 00 0f 85 6a 01 00 00 4d 85 d2 0f 8e 61 01 00 00 49 f7 c2 0f 00 00 00 0f 85 54 01 00 00 48 8b 4c 24 40 48 8b 54 24 30 4c 8b 4c 24 10 c5 f9 ef c0 c5 f1 ef c9 c5 e9 ef d2 c5 e1 ef db 4d 85 c9 0f 84 86 00 00 00 44 8b 19 41 81 f3 80 80 80 80 c4 c1 79 6e e3 c5 d9 60 e4 c5 d9 71 e4 08 c5 f9 70 e4 44 c5 fa 7e 2a c5 d1 60 ed c5 d1 71 e5 08 c5 d1 f5 ec c5 f9 fe c5 c5 fa 7e 6a 08 c5 d1 60 ed c5 d1 71 e5 08 c5 d1 f5 ec c5 f1 fe cd c5 fa 7e 6a 10 c5 d1 60 ed c5 d1 71 e5 08 c5 d1 f5 ec c5 e9 fe d5 c5 fa 7e 6a 18 c5 d1 60 ed c5 d1 71 e5 08 c5 d1 f5 ec c5 e1 fe dd 48 83 c1 04 48 83 c2 40 49 83 e9 04 0f 85 7a ff ff ff c5 f9 70 e0 b1 c5 f9 fe c4 c5 f9 70 c0 88 c4 c1 7a 7e 20 c5 f9 fe c4 c5 f9 d6 00 c5 f9 70 e1 b1 c5 f1 fe cc c5 f9 70 c9 88 c4 c1 7a 7e 60 08 c5 f1 fe cc c5 f9 d6 48 08 c5 f9 70 e2 b1 c5 e9 fe d4 c5 f9 70 d2 88 c4 c1 7a 7e 60 10 c5 e9 fe d4 c5 f9 d6 50 10 c5 f9 70 e3 b1 c5 e1 fe dc c5 f9 70 db 88 c4 c1 7a 7e 60 18 c5 e1 fe dc c5 f9 d6 58 18 48 83 c0 20 49 83 c0 20 49 83 ea 08 74 22 49 f7 c2 08 00 00 00 74 0b 48 83 44 24 30 20 e9 be fe ff ff 48 83 ea 20 48 89 54 24 30 e9 b0 fe ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 60',
        fused16_avx2='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 d2 00 00 00 49 83 f9 40 0f 8c 94 00 00 00 c5 fe 6f 01 c5 fe 6f 22 c5 fd fd c4 c4 c1 7e 6f 20 c5 fd f9 c4 c5 fe 6f 49 20 c5 fe 6f 62 20 c5 f5 fd cc c4 c1 7e 6f 60 20 c5 f5 f9 cc c5 fe 6f 51 40 c5 fe 6f 62 40 c5 ed fd d4 c4 c1 7e 6f 60 40 c5 ed f9 d4 c5 fe 6f 59 60 c5 fe 6f 62 60 c5 e5 fd dc c4 c1 7e 6f 60 60 c5 e5 f9 dc c5 fe 7f 00 c5 fe 7f 48 20 c5 fe 7f 50 40 c5 fe 7f 58 60 48 05 80 00 00 00 48 81 c1 80 00 00 00 48 81 c2 80 00 00 00 49 81 c0 80 00 00 00 49 83 e9 40 e9 62 ff ff ff 4d 85 c9 74 2b 44 0f bf 11 44 0f bf 1a 45 01 da 45 0f bf 18 45 29 da 66 44 89 10 48 83 c0 02 48 83 c1 02 48 83 c2 02 49 83 c0 02 49 ff c9 eb d0 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 50',
        fused32_avx2='48 8b 44 24 40 48 8b 4c 24 30 48 8b 54 24 20 4c 8b 44 24 10 4c 8b 0c 24 4d 85 c9 0f 88 c8 00 00 00 49 83 f9 20 0f 8c 94 00 00 00 c5 fe 6f 01 c5 fe 6f 22 c5 fd fe c4 c4 c1 7e 6f 20 c5 fd fa c4 c5 fe 6f 49 20 c5 fe 6f 62 20 c5 f5 fe cc c4 c1 7e 6f 60 20 c5 f5 fa cc c5 fe 6f 51 40 c5 fe 6f 62 40 c5 ed fe d4 c4 c1 7e 6f 60 40 c5 ed fa d4 c5 fe 6f 59 60 c5 fe 6f 62 60 c5 e5 fe dc c4 c1 7e 6f 60 60 c5 e5 fa dc c5 fe 7f 00 c5 fe 7f 48 20 c5 fe 7f 50 40 c5 fe 7f 58 60 48 05 80 00 00 00 48 81 c1 80 00 00 00 48 81 c2 80 00 00 00 49 81 c0 80 00 00 00 49 83 e9 20 e9 62 ff ff ff 4d 85 c9 74 21 44 8b 11 44 03 12 45 2b 10 44 89 10 48 83 c0 04 48 83 c1 04 48 83 c2 04 49 83 c0 04 49 ff c9 eb da 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 50',
        mix_avx2='48 8b 44 24 50 4c 8b 4c 24 20 4d 85 c9 78 6e 49 f7 c1 0f 00 00 00 75 65 48 83 3c 24 00 7e 5e 4d 85 c9 74 55 c5 fd ef c0 c5 f5 ef c9 48 8b 4c 24 40 48 8b 54 24 10 4c 8b 14 24 c4 e2 7d 58 22 c4 e2 5d 40 11 c5 fd fe c2 c4 e2 5d 40 51 20 c5 f5 fe ca 48 03 4c 24 30 48 83 c2 08 49 ff ca 75 da c5 fe 7f 00 c5 fe 7f 48 20 48 83 c0 40 48 83 44 24 40 40 49 83 e9 10 eb a6 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 60',
        dense_avx2='48 8b 44 24 50 4c 8b 44 24 20 4c 8b 14 24 4c 8b 4c 24 10 4d 85 c9 0f 88 26 01 00 00 49 f7 c1 07 00 00 00 0f 85 19 01 00 00 4d 85 d2 0f 8e 10 01 00 00 49 f7 c2 0f 00 00 00 0f 85 03 01 00 00 48 8b 4c 24 40 48 8b 54 24 30 4c 8b 4c 24 10 c5 fd ef c0 c5 f5 ef c9 c5 ed ef d2 c5 e5 ef db 4d 85 c9 74 5e 44 8b 19 41 81 f3 80 80 80 80 c4 c1 79 6e e3 c4 e2 79 20 e4 c4 e2 7d 59 e4 c4 e2 7d 20 2a c5 d5 f5 ec c5 fd fe c5 c4 e2 7d 20 6a 10 c5 d5 f5 ec c5 f5 fe cd c4 e2 7d 20 6a 20 c5 d5 f5 ec c5 ed fe d5 c4 e2 7d 20 6a 30 c5 d5 f5 ec c5 e5 fe dd 48 83 c1 04 48 83 c2 40 49 83 e9 04 75 a2 c4 e2 7d 02 c0 c4 e3 7d 39 c4 01 c5 f9 6c c4 c4 c1 79 fe 00 c5 fa 7f 00 c4 e2 75 02 c9 c4 e3 7d 39 cc 01 c5 f1 6c cc c4 c1 71 fe 48 10 c5 fa 7f 48 10 c4 e2 6d 02 d2 c4 e3 7d 39 d4 01 c5 e9 6c d4 c4 c1 69 fe 50 20 c5 fa 7f 50 20 c4 e2 65 02 db c4 e3 7d 39 dc 01 c5 e1 6c dc c4 c1 61 fe 58 30 c5 fa 7f 58 30 48 89 54 24 30 48 83 c0 40 49 83 c0 40 49 83 ea 10 0f 85 01 ff ff ff 31 c0 eb 07 48 c7 c0 ff ff ff ff c5 f8 77 48 83 c4 60',
      }
      for _,a in ipairs(e[3]) do generate(a);push() end
      hex(assert(snippets[block_kernel..'_'..profile]));if vnni_done then mark(vnni_done) end;return
    end
    if special=='yoğun_blok_u8_i8_i32' then

      if arm and instruction=='neon' then
        local fallback,done=label(),label()
        if e.yb_hazir then yb_cpu_dal(64,fallback) else
        generate({'!=',{'&',{'var','__t_cpu_cache',global=globals.__t_cpu_cache,type='u64'},{'num',64,type='u64'},type='u64',operand='u64'},{'num',0,type='u64'},type='i64',operand='u64'})
        jump(fallback,true)
        end
        if not e.yb_hazir then
          for _,a in ipairs(e[3]) do generate(a);push() end
          for r=#e[3]-1,0,-1 do pop(r) end
        end
        hex('04 05 f8 b7 9f 08 40 f2 c1 04 00 54 bf 00 00 f1 8d 04 00 54 bf 0c 40 f2 41 04 00 54 01 e4 04 4f e8 03 05 aa 70 28 df 4c 14 04 00 4f 15 04 00 4f 16 04 00 4f 17 04 00 4f e6 03 01 aa e7 03 04 aa e7 01 00 b4 c0 84 40 fc 00 1c 21 2e 58 20 df 4c 5c 20 df 4c 10 e3 80 4f 31 e3 80 4f 52 e3 80 4f 73 e3 80 4f 94 e3 a0 4f b5 e3 a0 4f d6 e3 a0 4f f7 e3 a0 4f e7 20 00 f1 61 fe ff 54 10 86 b4 4e 31 86 b5 4e 52 86 b6 4e 73 86 b7 4e 10 28 9f 4c 08 41 00 f1 81 fc ff 54 00 00 80 d2 02 00 00 14 00 00 80 92')
        jump(done);mark(fallback)
        generate({'call','__t_yoğun_blok_düz',e[3],type='i64'})
        mark(done);return
      end
      generate({'call','__t_yoğun_blok_düz',e[3],type='i64'});return
    end
    if special=='karışım_i32' then

      if arm and instruction=='neon' then
        if not e.yb_hazir then
          for _,a in ipairs(e[3]) do generate(a);push() end
          for r=#e[3]-1,0,-1 do pop(r) end
        end
        hex('a3 03 f8 b7 7f 0c 40 f2 61 03 00 54 bf 00 00 f1 2d 03 00 54 c3 02 00 b4 00 04 00 4f 01 04 00 4f 02 04 00 4f 03 04 00 4f e6 03 01 aa e7 03 04 aa e8 03 05 aa e9 84 40 f8 24 0d 04 4e d0 28 40 4c c6 00 02 8b 00 96 a4 4e 21 96 a4 4e 42 96 a4 4e 63 96 a4 4e 08 05 00 f1 e1 fe ff 54 00 28 9f 4c 21 00 01 91 63 40 00 d1 eb ff ff 17 00 00 80 d2 02 00 00 14 00 00 80 92');return
      end
      generate({'call','__t_karışım_düz',e[3],type='i64'});return
    end
    if special=='vektör_topla_çıkar_i16' or special=='vektör_topla_çıkar_i32' then

      local word=special=='vektör_topla_çıkar_i16'
      if arm and instruction=='neon' then
        if not e.yb_hazir then
          for _,a in ipairs(e[3]) do generate(a);push() end
          for r=#e[3]-1,0,-1 do pop(r) end
        end
        hex(word and '84 03 f8 b7 9f 80 00 f1 eb 01 00 54 20 20 df 4c 44 20 df 4c 70 20 df 4c 00 84 64 4e 21 84 65 4e 42 84 66 4e 63 84 67 4e 00 84 70 6e 21 84 71 6e 42 84 72 6e 63 84 73 6e 00 20 9f 4c 84 80 00 d1 f1 ff ff 17 24 01 00 b4 25 24 c0 78 46 24 c0 78 67 24 c0 78 a5 00 06 0b a5 00 07 4b 05 24 00 78 84 04 00 d1 f8 ff ff 17 00 00 80 d2 02 00 00 14 00 00 80 92' or '84 03 f8 b7 9f 40 00 f1 eb 01 00 54 20 20 df 4c 44 20 df 4c 70 20 df 4c 00 84 a4 4e 21 84 a5 4e 42 84 a6 4e 63 84 a7 4e 00 84 b0 6e 21 84 b1 6e 42 84 b2 6e 63 84 b3 6e 00 20 9f 4c 84 40 00 d1 f1 ff ff 17 24 01 00 b4 25 44 40 b8 46 44 40 b8 67 44 40 b8 a5 00 06 0b a5 00 07 4b 05 44 00 b8 84 04 00 d1 f8 ff ff 17 00 00 80 d2 02 00 00 14 00 00 80 92');return
      end
      generate({'call',word and '__t_topla_çıkar_i16_düz' or '__t_topla_çıkar_i32_düz',e[3],type='i64'});return
    end
    if instruction=='auto' and (special=='vektör_topla_i8_i16' or special=='vektör_çıkar_i8_i16' or special=='böl_ekle_i32_u8' or special=='nokta_u8_i8_i32' or special=='karışım4_i32' or special=='kaydır_kırp_i16_u8' or special=='vektör_topla_i32' or special=='vektör_topla_i16' or special=='vektör_çıkar_i16' or special=='vektör_enbüyük_i16' or special=='vektör_topla_i16_i32' or special=='yoğun_i16' or special=='ekle_relu512_i32_i16' or special=='havuz_i16' or special=='taş_havuz_i16' or special=='taşlar_havuz_i16' or special=='nokta8_i16' or special=='nokta_u8_i8' or special=='katla_u8_i8_i32' or special=='kırp_i32_u8' or special=='kare_kırp_i16_u8') then

      local done=label();local choices=Y.avx512_auto and ((special=='böl_ekle_i32_u8' and {{15,'avx512'},{7,'avx2'}}) or (special=='nokta_u8_i8_i32' and {{31,'avx512bw'},{7,'avx2'}}) or (special=='karışım4_i32' and {{15,'avx512'},{7,'avx2'}}) or (special=='kaydır_kırp_i16_u8' and {{31,'avx512bw'},{7,'avx2'}}) or (special=='kırp_i32_u8' and {{15,'avx512'},{7,'avx2'}}) or (special=='kare_kırp_i16_u8' and {{31,'avx512bw'},{7,'avx2'}}) or (special=='nokta_u8_i8' and {{31,'avx512bw'},{7,'avx2'}}) or (special=='katla_u8_i8_i32' and {{15,'avx512'},{7,'avx2'}}) or special=='vektör_topla_i32' and {{15,'avx512'},{7,'avx2'}} or (special=='nokta8_i16' and {{7,'avx2'}} or {{31,'avx512bw'},{7,'avx2'}})) or {{7,'avx2'}}
      for _,choice in ipairs(choices) do
        local next_label=label()

        H.x64_cpu_dal(({[7]=4,[15]=8,[31]=16})[choice[1]] or choice[1],next_label)
        instruction=choice[2];generate(e);instruction='auto';jump(done);mark(next_label)
      end
      instruction='sse2';generate(e);instruction='auto';mark(done);return
    end
    if special=='böl_ekle_i32_u8' and instruction~='scalar' then
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 4 or 9);pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local profile=instruction=='avx512bw' and 'avx512' or instruction
      local bad,loop,tail,scalar,done,exit=label(),label(),label(),label(),label(),label()

      local snippets={
        init_neon='05 00 b0 d2 a5 08 c3 9a a4 0c 04 4e 65 0c 04 4e 86 0c 04 4e',
        body_neon='20 00 c0 3d 01 04 21 4f 00 1c 21 6e 00 84 a1 6e 02 c0 a4 2e 03 c0 a4 6e 42 04 61 6f 63 04 61 6f 42 28 a1 0e 62 28 a1 4e 40 94 a5 6e 00 3c a5 4e 42 84 a0 6e 42 1c 21 6e 42 84 a1 6e 42 84 a6 4e 40 28 61 0e 00 28 21 0e 00 00 00 bd',
        tail_neon='26 44 80 b8 c6 0c c3 9a c6 00 04 8b 06 14 00 38 42 04 00 d1',
        prepare_x64='66 48 0f 6e ea 49 89 c3 b8 00 00 00 80 31 d2 49 f7 f0 41 89 c2 66 48 0f 7e ea 4c 89 d8 41 bb ff 00 00 00',
        tail_x64='66 48 0f 6e c0 66 48 0f 6e ca 48 63 01 48 99 49 f7 f8 4c 01 c8 41 89 c2 66 48 0f 7e c0 66 48 0f 7e ca 44 88 10',
        init_sse2='f2 49 0f 2a e8 66 0f c6 ed 00 66 41 0f 6e e1 66 0f 70 e4 00 41 bb ff 00 00 00 66 41 0f 6e db 66 0f 70 db 00',
        body_sse2='f3 0f e6 01 f3 0f e6 49 08 66 0f 5e c5 66 0f 5e cd 66 0f e6 c0 66 0f e6 c9 66 0f 6c c1 66 0f fe c4 66 0f db c3 66 0f 6b c0 66 0f 67 c0 66 0f 7e 00',
        init_avx='c4 c1 d3 2a e8 c5 d1 c6 ed 00 c4 c1 79 6e e1 c5 f9 70 e4 00 41 bb ff 00 00 00 c4 c1 79 6e db c5 f9 70 db 00',
        body_avx='c5 fa e6 01 c5 fa e6 49 08 c5 f9 5e c5 c5 f1 5e cd c5 f9 e6 c0 c5 f9 e6 c9 c5 f9 6c c1 c5 f9 fe c4 c5 f9 db c3 c5 f9 6b c0 c5 f9 67 c0 c5 f9 7e 00',
        init_avx2='c4 c1 d3 2a e8 c4 e2 7d 19 ed c4 c1 79 6e e1 c5 f9 70 e4 00 41 bb ff 00 00 00 c4 c1 79 6e db c5 f9 70 db 00',
        body_avx2='c5 fe e6 01 c5 fd 5e c5 c5 fd e6 c0 c5 f9 fe c4 c5 f9 db c3 c5 f9 6b c0 c5 f9 67 c0 c5 f9 7e 00',
        init_avx512='41 ff c8 c4 c1 79 6e e8 62 f2 7d 48 58 ed 41 ff c0 c4 c1 79 6e e2 62 f2 7d 48 58 e4',
        body_avx512='62 f1 7e 48 6f 01 62 f1 75 48 72 e0 1f 62 f1 7d 48 ef c1 62 f1 7d 48 fa c1 62 f1 e5 48 73 d0 20 62 f1 fd 48 f4 d4 62 f1 e5 48 f4 dc 62 f1 ed 48 73 d2 1f 62 f1 e5 48 73 d3 1f 62 f1 7d 48 70 d2 88 62 f1 7d 48 70 db 88 62 f1 6d 48 62 d3 62 f2 6d 48 40 dd 62 f1 65 48 fe da 62 f1 7d 48 fa c3 62 f3 7d 48 1f cd 06 62 f1 7d 48 fa c0 62 f3 7d c9 25 c0 ff 62 f1 6d 48 fa d0 62 f1 6d 48 ef d1 62 f1 6d 48 fa d1 c4 c1 79 6e c1 62 f2 7d 48 58 c0 62 f1 6d 48 fe d0 62 f2 7e 48 31 10',
      }
      if arm then
        u32(0xf100005f);condition_branch(bad,11,0);u32(0xf100047f);condition_branch(bad,11,0)
        immediate(2147483647,5);u32(0xeb05007f);condition_branch(bad,12,0)
      else
        hex('48 85 d2');condition_branch(bad,0,0x88);hex('49 83 f8 01');condition_branch(bad,0,0x8c)
        hex('49 81 f8 ff ff ff 7f');condition_branch(bad,0,0x8f);if profile=='avx512' then hex(snippets.prepare_x64) end
      end
      hex(snippets['init_'..profile]);local width=profile=='avx512' and 16 or 4
      mark(loop)
      if arm then u32(0xf100005f | (width<<10));condition_branch(tail,11,0)
      else hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c) end
      hex(snippets['body_'..profile])
      if arm then u32(0x91000000 | (width<<10));u32(0x91000021 | ((width*4)<<10));u32(0xd1000042 | (width<<10))
      else hex('48 83 c0');bytes(string.char(width));hex('48 83 c1');bytes(string.char(width*4));hex('48 83 ea');bytes(string.char(width)) end
      jump(loop);mark(tail);if not arm and profile~='sse2' then hex('c5 f8 77') end
      mark(scalar)
      if arm then u32(0xf100005f);condition_branch(done,13,0)
      else hex('48 85 d2');condition_branch(done,0,0x8e) end
      hex(snippets['tail_'..(arm and 'neon' or 'x64')])
      if not arm then hex('48 ff c0 48 83 c1 04 48 ff ca') end
      jump(scalar);mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if arm and instruction=='neon' and special=='nokta_u8_i8_i32' then
      local fallback,done=label(),label()
      if e.yb_hazir then yb_cpu_dal(64,fallback) else
      generate({'!=',{'&',{'var','__t_cpu_cache',global=globals.__t_cpu_cache,type='u64'},{'num',64,type='u64'},type='u64',operand='u64'},{'num',0,type='u64'},type='i64',operand='u64'})
      jump(fallback,true)
      end;instruction='dotprod';generate(e);instruction='neon';jump(done);mark(fallback)
      instruction='neon-base';generate(e);instruction='neon';mark(done);return
    end

    if special=='nokta_u8_i8_i32' and instruction~='scalar' then
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end;pop(2);pop(1);pop(0)
      end
      local profile=instruction=='avx512' and 'avx2' or (instruction=='neon-base' and 'neon' or instruction)
      local loop,tail,scalar,done,zero,exit=label(),label(),label(),label(),label(),label()
      local snippets={
        init_dotprod='06 04 00 4f 07 04 00 4f 22 e4 00 4f 03 e4 04 4f',
        body_dotprod='00 00 c0 3d 21 00 c0 3d 00 1c 23 6e 06 94 81 4e 47 94 81 4e',
        sum_dotprod='e7 54 27 4f c6 84 a7 4e c6 b8 b1 4e c3 2c 04 4e',
        init_neon='06 04 00 4f',
        body_neon='00 00 c0 3d 21 00 c0 3d 02 a4 08 2f 03 a4 08 6f 24 a4 08 0f 25 a4 08 4f 40 c0 64 0e 40 80 64 4e 60 80 65 0e 60 80 65 4e c6 84 a0 4e',
        sum_neon='c6 b8 b1 4e c3 2c 04 4e',
        init_sse2='66 0f ef ed',
        body_sse2='f3 41 0f 6f 02 f3 41 0f 6f 0b 66 0f ef d2 66 0f 6f d8 66 0f 60 c2 66 0f 68 da 66 0f 64 d1 66 0f 6f e1 66 0f 60 ca 66 0f 68 e2 66 0f f5 c1 66 0f f5 dc 66 0f fe c3 66 0f fe e8',
        sum_sse2='66 0f 6f c5 66 0f 73 d8 08 66 0f fe e8 66 0f 6f c5 66 0f 73 d8 04 66 0f fe e8 66 41 0f 7e e8',
        init_avx='c5 d1 ef ed',
        body_avx='c4 c1 7a 6f 02 c4 c1 7a 6f 0b c5 e9 ef d2 c5 f9 68 da c5 f9 60 c2 c5 e9 64 d1 c5 f1 68 e2 c5 f1 60 ca c5 f9 f5 c1 c5 e1 f5 dc c5 f9 fe c3 c5 d1 fe e8',
        sum_avx='c5 f9 73 dd 08 c5 d1 fe e8 c5 f9 73 dd 04 c5 d1 fe e8 c4 c1 79 7e e8',
        init_avx2='c5 d1 ef ed',
        body_avx2='c4 c2 7d 30 02 c4 c2 7d 20 0b c5 fd f5 c1 c4 e3 7d 39 c1 01 c5 f9 fe c1 c5 d1 fe e8',
        sum_avx2='c5 f9 73 dd 08 c5 d1 fe e8 c5 f9 73 dd 04 c5 d1 fe e8 c4 c1 79 7e e8',
        init_avx512bw='62 f1 55 48 ef ed',
        body_avx512bw='62 d2 7d 48 30 02 62 d2 7d 48 20 0b 62 f1 7d 48 f5 c1 62 f1 55 48 fe e8',
        sum_avx512bw='62 f3 fd 48 3b e8 01 c5 d5 fe e8 c4 e3 7d 39 e8 01 c5 d1 fe e8 c5 f9 73 dd 08 c5 d1 fe e8 c5 f9 73 dd 04 c5 d1 fe e8 c4 c1 79 7e e8',
      }
      if arm then u32(0xf100005f);condition_branch(zero,13,0)
      else hex('48 85 d2');condition_branch(zero,0,0x8e);hex('49 89 c2 49 89 cb') end
      hex(snippets['init_'..profile]);local width=profile=='avx512bw' and 32 or 16
      mark(loop)
      if arm then u32(0xf100005f | (width<<10));condition_branch(tail,11,0)
      else hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c) end
      hex(snippets['body_'..profile])
      if arm then u32(0x91000000 | (width<<10));u32(0x91000021 | (width<<10));u32(0xd1000042 | (width<<10))
      else hex('49 83 c2');bytes(string.char(width));hex('49 83 c3');bytes(string.char(width));hex('48 83 ea');bytes(string.char(width)) end
      jump(loop);mark(tail);hex(snippets['sum_'..profile]);if not arm and profile~='sse2' then hex('c5 f8 77') end
      mark(scalar)
      if arm then
        u32(0xf100005f);condition_branch(done,13,0);u32(0x39400004);u32(0x39800025);u32(0x9b050c83)
        u32(0x91000400);u32(0x91000421);u32(0xd1000442)
      else
        hex('48 85 d2');condition_branch(done,0,0x8e)
        hex('41 0f b6 02 41 0f be 0b 0f af c1 41 01 c0 49 ff c2 49 ff c3 48 ff ca')
      end
      jump(scalar);mark(done);if arm then move_register(0,3) else move_register(0,8) end
      jump(exit);mark(zero);generate({'num',0});mark(exit);normalize('i32');return
    end
    if not arm and instruction~='scalar' and (special=='karışım4_i32' or special=='kaydır_kırp_i16_u8') then

      local mix=special=='karışım4_i32';local profile=instruction
      if mix and profile=='avx512bw' then profile='avx512'
      elseif not mix and profile=='avx512' then profile='avx2' end
      local snippets={
        mix_args='48 8b 84 24 90 00 00 00 48 8b 8c 24 80 00 00 00 48 8b 54 24 70 4c 8b 44 24 60 4c 8b 4c 24 50 4c 8b 54 24 40',
        mix_tail='44 8b 19 44 0f af 5c 24 30 44 8b 12 44 0f af 54 24 20 45 01 d3 45 8b 10 44 0f af 54 24 10 45 01 d3 45 8b 11 44 0f af 14 24 45 01 d3 44 89 18',
        mix_init_sse2='',
        mix_body_sse2='66 0f 6e 5c 24 30 66 0f 70 db 00 f3 0f 6f 09 66 0f 6f d1 66 0f f4 cb 66 0f 73 d2 20 66 0f f4 d3 66 0f 70 c9 88 66 0f 70 d2 88 66 0f 62 ca 66 0f 6f c1 66 0f 6e 5c 24 20 66 0f 70 db 00 f3 0f 6f 0a 66 0f 6f d1 66 0f f4 cb 66 0f 73 d2 20 66 0f f4 d3 66 0f 70 c9 88 66 0f 70 d2 88 66 0f 62 ca 66 0f fe c1 66 0f 6e 5c 24 10 66 0f 70 db 00 f3 41 0f 6f 08 66 0f 6f d1 66 0f f4 cb 66 0f 73 d2 20 66 0f f4 d3 66 0f 70 c9 88 66 0f 70 d2 88 66 0f 62 ca 66 0f fe c1 66 0f 6e 1c 24 66 0f 70 db 00 f3 41 0f 6f 09 66 0f 6f d1 66 0f f4 cb 66 0f 73 d2 20 66 0f f4 d3 66 0f 70 c9 88 66 0f 70 d2 88 66 0f 62 ca 66 0f fe c1 f3 0f 7f 00',
        mix_init_avx='',
        mix_body_avx='c5 f9 6e 5c 24 30 c5 f9 70 db 00 c5 fa 6f 09 c5 e9 73 d1 20 c5 f1 f4 cb c5 e9 f4 d3 c5 f9 70 c9 88 c5 f9 70 d2 88 c5 f1 62 ca c5 f9 6f c1 c5 f9 6e 5c 24 20 c5 f9 70 db 00 c5 fa 6f 0a c5 e9 73 d1 20 c5 f1 f4 cb c5 e9 f4 d3 c5 f9 70 c9 88 c5 f9 70 d2 88 c5 f1 62 ca c5 f9 fe c1 c5 f9 6e 5c 24 10 c5 f9 70 db 00 c4 c1 7a 6f 08 c5 e9 73 d1 20 c5 f1 f4 cb c5 e9 f4 d3 c5 f9 70 c9 88 c5 f9 70 d2 88 c5 f1 62 ca c5 f9 fe c1 c5 f9 6e 1c 24 c5 f9 70 db 00 c4 c1 7a 6f 09 c5 e9 73 d1 20 c5 f1 f4 cb c5 e9 f4 d3 c5 f9 70 c9 88 c5 f9 70 d2 88 c5 f1 62 ca c5 f9 fe c1 c5 fa 7f 00',
        mix_init_avx2='c4 e2 7d 58 54 24 30 c4 e2 7d 58 5c 24 20 c4 e2 7d 58 64 24 10 c4 e2 7d 58 2c 24',
        mix_body_avx2='c4 e2 6d 40 01 c4 e2 65 40 0a c5 fd fe c1 c4 c2 5d 40 08 c5 fd fe c1 c4 c2 55 40 09 c5 fd fe c1 c5 fe 7f 00',
        mix_init_avx512='62 f2 7d 48 58 54 24 0c 62 f2 7d 48 58 5c 24 08 62 f2 7d 48 58 64 24 04 62 f2 7d 48 58 2c 24',
        mix_body_avx512='62 f2 6d 48 40 01 62 f2 65 48 40 0a 62 f1 7d 48 fe c1 62 d2 5d 48 40 08 62 f1 7d 48 fe c1 62 d2 55 48 40 09 62 f1 7d 48 fe c1 62 f1 7e 48 7f 00',
        clip_init_sse2='66 41 0f 6e e0 66 41 0f 6e d1 f2 0f 70 d2 00 66 0f 70 d2 00 66 0f ef c9',
        clip_body_sse2='f3 41 0f 6f 03 66 0f e1 c4 66 0f ee c1 66 0f ea c2 66 0f 67 c1 66 0f d6 00',
        clip_init_avx='c4 c1 79 6e e0 c4 c1 79 6e d1 c5 fb 70 d2 00 c5 f9 70 d2 00 c5 f1 ef c9',
        clip_body_avx='c4 c1 7a 6f 03 c5 f9 e1 c4 c5 f9 ee c1 c5 f9 ea c2 c5 f9 67 c1 c5 f9 d6 00',
        clip_init_avx2='c4 c1 79 6e e0 c4 c1 79 6e d1 c4 e2 7d 79 d2 c5 f5 ef c9',
        clip_body_avx2='c4 c1 7e 6f 03 c5 fd e1 c4 c5 fd ee c1 c5 fd ea c2 c5 fd 67 c0 c4 e3 fd 00 c0 d8 c5 fa 7f 00',
        clip_init_avx512bw='c4 c1 79 6e e0 c4 c1 79 6e d1 62 f2 7d 48 79 d2 62 f1 75 48 ef c9',
        clip_body_avx512bw='62 d1 ff 48 6f 03 62 f1 7d 48 e1 c4 62 f1 7d 48 ee c1 62 f1 7d 48 ea c2 62 f2 7e 48 10 00',
        clip_tail='45 0f bf 13 41 d3 fa 45 31 c0 45 85 d2 45 0f 4c d0 45 39 ca 45 0f 4f d1 44 88 10',
      }
      for _,a in ipairs(e[3]) do generate(a);push() end
      local bad,loop,tail,scalar,done,exit=label(),label(),label(),label(),label(),label()
      if mix then

        hex(snippets.mix_args);hex('4d 85 d2');condition_branch(bad,0,0x88)
        hex(snippets['mix_init_'..profile])
        local width=profile=='avx512' and 16 or (profile=='avx2' and 8 or 4)
        mark(loop);hex('49 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c)
        hex(snippets['mix_body_'..profile])
        for _,prefix in ipairs({'48 83 c0','48 83 c1','48 83 c2','49 83 c0','49 83 c1'}) do hex(prefix);bytes(string.char(width*4)) end
        hex('49 83 ea');bytes(string.char(width));jump(loop)
        mark(tail);if profile~='sse2' then hex('c5 f8 77') end
        hex('4c 89 54 24 40')
        mark(scalar);hex('48 83 7c 24 40 00');condition_branch(done,0,0x8e)
        hex(snippets.mix_tail)
        hex('48 83 c0 04 48 83 c1 04 48 83 c2 04 49 83 c0 04 49 83 c1 04 48 ff 4c 24 40');jump(scalar)
      else
        pop(9);pop(8);pop(2);pop(1);pop(0)
        hex('48 85 d2');condition_branch(bad,0,0x88)
        hex('49 83 f8 0f');condition_branch(bad,0,0x87)
        hex('49 81 f9 ff 00 00 00');condition_branch(bad,0,0x87)
        hex(snippets['clip_init_'..profile]);hex('49 89 cb 4c 89 c1')
        local width=profile=='avx512bw' and 32 or (profile=='avx2' and 16 or 8)
        mark(loop);hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c)
        hex(snippets['clip_body_'..profile])
        hex('48 83 c0');bytes(string.char(width));hex('49 83 c3');bytes(string.char(width*2));hex('48 83 ea');bytes(string.char(width));jump(loop)
        mark(tail);if profile~='sse2' then hex('c5 f8 77') end
        mark(scalar);hex('48 85 d2');condition_branch(done,0,0x8e)
        hex(snippets.clip_tail);hex('48 ff c0 49 83 c3 02 48 ff ca');jump(scalar)
      end
      mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit)
      if mix then hex('48 81 c4 a0 00 00 00') end
      return
    end

    if special=='kırp_çift_i32_u8' then

      if instruction=='auto' then
        local done=label()
        local choices=Y.avx512_auto and {{15,'avx512'},{7,'avx2'},{3,'avx'}} or {{7,'avx2'},{3,'avx'}}
        for _,choice in ipairs(choices) do
          local next_label=label()
          generate({'==',{'&',{'var','__t_cpu_cache',global=globals.__t_cpu_cache,type='u64'},{'num',choice[1],type='u64'},type='u64',operand='u64'},{'num',choice[1],type='u64'},type='i64',operand='u64'})
          jump(next_label,true);instruction=choice[2];generate(e);instruction='auto';jump(done);mark(next_label)
        end
        instruction='sse2';generate(e);instruction='auto';mark(done);return
      end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local bad,loop,tail,scalar,done,exit=label(),label(),label(),label(),label(),label()
      local profile=instruction=='avx512bw' and 'avx512' or instruction
      local width=profile=='avx512' and 16 or (profile=='avx2' and 8 or 4)
      local snippets={
        init_neon='e5 03 03 4b a4 0c 04 4e 02 04 00 4f e3 07 07 4f e6 1f 80 52',
        body_neon='20 00 c0 3d 00 44 a4 4e 00 64 a2 4e 00 6c a3 4e 00 28 61 0e 01 28 21 0e 01 00 00 bd 00 9c 60 0e 00 84 08 0f 80 00 00 bd',
        scalar_neon='25 00 40 b9 a5 28 c3 1a bf 00 00 71 a5 c0 9f 1a e6 1f 80 52 bf 00 06 6b a5 d0 86 1a 05 00 00 39 a5 7c 05 1b a5 7c 08 53 85 00 00 39',
        init_sse2='66 0f ef d2 66 0f 75 db 66 0f 71 d3 08 66 41 0f 6e e0',
        body_sse2='f3 41 0f 6f 02 66 0f e2 c4 66 0f 6f c8 66 0f 66 ca 66 0f db c1 66 0f 6b c0 66 0f ea c3 66 0f 6f c8 66 0f 67 c9 66 0f 7e 08 66 0f d5 c0 66 0f 71 d0 08 66 0f 67 c0 66 41 0f 7e 01',
        init_avx='c5 e9 ef d2 c5 e1 75 db c5 e1 71 d3 08 c4 c1 79 6e e0',
        body_avx='c4 c1 7a 6f 02 c5 f9 e2 c4 c5 f9 66 ca c5 f9 db c1 c5 f9 6b c0 c5 f9 ea c3 c5 f9 67 c8 c5 f9 7e 08 c5 f9 d5 c0 c5 f9 71 d0 08 c5 f9 67 c0 c4 c1 79 7e 01',
        init_avx2='c5 ed ef d2 41 bb ff 00 00 00 c4 c1 79 6e db c4 e2 7d 58 db c4 c1 79 6e e0',
        body_avx2='c4 c1 7e 6f 02 c5 fd e2 c4 c4 e2 7d 3d c2 c4 e2 7d 39 c3 c5 fd 6b c0 c4 e3 fd 00 c0 d8 c5 f9 67 c8 c5 f9 d6 08 c5 f9 d5 c0 c5 f9 71 d0 08 c5 f9 67 c0 c4 c1 79 d6 01',
        init_avx512='62 f1 6d 48 ef d2 41 bb ff 00 00 00 62 d2 7d 48 7c db c4 c1 79 6e e0',
        body_avx512='62 d1 7e 48 6f 02 62 f1 7d 48 e2 c4 62 f2 7d 48 3d c2 62 f2 7d 48 39 c3 62 f2 7e 48 33 c0 c5 fd 67 c8 c4 e3 fd 00 c9 d8 c5 fa 7f 08 c5 fd d5 c0 c5 fd 71 d0 08 c5 fd 67 c0 c4 e3 fd 00 c0 d8 c4 c1 7a 7f 01',
        scalar_x64='45 8b 1a 41 d3 fb 45 31 c0 45 85 db 45 0f 4c d8 41 b8 ff 00 00 00 45 39 c3 45 0f 4f d8 44 88 18 45 0f af db 41 c1 eb 08 45 88 19',
      }
      if arm then
        u32(0xf100005f);condition_branch(bad,11,0)
        u32(0xf1007c7f);condition_branch(bad,8,0)
        u32(0x8b020004)
      else
        hex('48 85 d2');condition_branch(bad,0,0x88)
        hex('49 83 f8 1f');condition_branch(bad,0,0x87)
        hex('4c 8d 0c 10 49 89 ca')
      end
      if profile~='scalar' then hex(assert(snippets['init_'..profile])) end
      if not arm then hex('4c 89 c1') end
      if profile~='scalar' then
        mark(loop)
        if arm then u32(0xf100005f | (width<<10));condition_branch(tail,11,0)
        else hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c) end
        hex(assert(snippets['body_'..profile]))
        if arm then
          u32(0x91000000 | (width<<10));u32(0x91000084 | (width<<10));u32(0x91000021 | ((width*4)<<10));u32(0xd1000042 | (width<<10))
        else
          hex('48 83 c0');bytes(string.char(width));hex('49 83 c1');bytes(string.char(width));hex('49 83 c2');bytes(string.char(width*4));hex('48 83 ea');bytes(string.char(width))
        end
        jump(loop);mark(tail);if not arm and profile~='sse2' then hex('c5 f8 77') end
      end
      mark(scalar)
      if arm then u32(0xf100005f);condition_branch(done,13,0)
      else hex('48 85 d2');condition_branch(done,0,0x8e) end
      hex(snippets['scalar_'..(arm and 'neon' or 'x64')])
      if arm then u32(0x91000400);u32(0x91000484);u32(0x91001021);u32(0xd1000442)
      else hex('48 ff c0 49 ff c1 49 83 c2 04 48 ff ca') end
      jump(scalar);mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if special=='çarp_kırp_i16_u8' then
      if instruction=='auto' then
        local done=label()
        local choices=Y.avx512_auto and {{31,'avx512bw'},{7,'avx2'},{3,'avx'}} or {{7,'avx2'},{3,'avx'}}
        for _,choice in ipairs(choices) do
          local next_label=label()
          generate({'==',{'&',{'var','__t_cpu_cache',global=globals.__t_cpu_cache,type='u64'},{'num',choice[1],type='u64'},type='u64',operand='u64'},{'num',choice[1],type='u64'},type='i64',operand='u64'})
          jump(next_label,true);instruction=choice[2];generate(e);instruction='auto';jump(done);mark(next_label)
        end
        instruction='sse2';generate(e);instruction='auto';mark(done);return
      end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local bad,loop,tail,scalar,done,exit=label(),label(),label(),label(),label(),label()
      local profile=instruction=='avx512' and 'avx2' or instruction
      local width=profile=='avx512bw' and 32 or (profile=='avx2' and 16 or 8)
      local snippets={
        init_sse2='66 0f ef d2 66 0f 75 db 66 0f 71 d3 08',
        body_sse2='f3 0f 6f 01 f3 0f 6f 0a 66 0f ee c2 66 0f ee ca 66 0f ea c3 66 0f ea cb 66 0f d5 c1 66 0f 71 d0 08 66 0f 67 c0 66 0f d6 00',
        init_avx='c5 e9 ef d2 c5 e1 75 db c5 e1 71 d3 08',
        body_avx='c5 fa 6f 01 c5 fa 6f 0a c5 f9 ee c2 c5 f1 ee ca c5 f9 ea c3 c5 f1 ea cb c5 f9 d5 c1 c5 f9 71 d0 08 c5 f9 67 c0 c5 f9 d6 00',
        init_avx2='c5 ed ef d2 c5 e5 75 db c5 e5 71 d3 08',
        body_avx2='c5 fe 6f 01 c5 fe 6f 0a c5 fd ee c2 c5 f5 ee ca c5 fd ea c3 c5 f5 ea cb c5 fd d5 c1 c5 fd 71 d0 08 c5 fd 67 c0 c4 e3 fd 00 c0 d8 c5 fa 7f 00',
        init_avx512bw='62 f1 6d 48 ef d2 41 b9 ff 00 00 00 62 d2 7d 48 7b d9',
        body_avx512bw='62 f1 ff 48 6f 01 62 f1 ff 48 6f 0a 62 f1 7d 48 ee c2 62 f1 75 48 ee ca 62 f1 7d 48 ea c3 62 f1 75 48 ea cb 62 f1 7d 48 d5 c1 62 f1 7d 48 71 d0 08 62 f2 7e 48 10 00',
        init_neon='02 84 00 4f e3 87 07 4f',
        body_neon='20 00 c0 3d 41 00 c0 3d 00 64 62 4e 21 64 62 4e 00 6c 63 4e 21 6c 63 4e 00 9c 61 4e 00 84 08 0f 00 00 00 fd',
        scalar_x64='44 0f bf 09 44 0f bf 12 45 31 db 45 85 c9 45 0f 4c cb 45 85 d2 45 0f 4c d3 41 bb ff 00 00 00 45 39 d9 45 0f 4f cb 45 39 da 45 0f 4f d3 45 0f af ca 41 c1 e9 08 44 88 08',
        scalar_neon='24 00 c0 79 45 00 c0 79 9f 00 00 71 84 c0 9f 1a bf 00 00 71 a5 c0 9f 1a e6 1f 80 52 9f 00 06 6b 84 d0 86 1a bf 00 06 6b a5 d0 86 1a 84 7c 05 1b 84 7c 08 53 04 00 00 39',
      }
      if arm then u32(0xf100007f);condition_branch(bad,11,0)
      else hex('4d 85 c0');condition_branch(bad,0,0x88) end
      if profile~='scalar' then
        hex(assert(snippets['init_'..profile]));mark(loop)
        if arm then u32(0xf100007f | (width<<10));condition_branch(tail,11,0)
        else hex('49 83 f8');bytes(string.char(width));condition_branch(tail,0,0x8c) end
        hex(assert(snippets['body_'..profile]))
        if arm then
          u32(0x91000000 | (width<<10));u32(0x91000021 | ((width*2)<<10));u32(0x91000042 | ((width*2)<<10));u32(0xd1000063 | (width<<10))
        else
          hex('48 83 c0');bytes(string.char(width));hex('48 83 c1');bytes(string.char(width*2));hex('48 83 c2');bytes(string.char(width*2));hex('49 83 e8');bytes(string.char(width))
        end
        jump(loop);mark(tail);if not arm and profile~='sse2' then hex('c5 f8 77') end
      end
      mark(scalar)
      if arm then u32(0xf100007f);condition_branch(done,13,0)
      else hex('4d 85 c0');condition_branch(done,0,0x8e) end
      hex(snippets['scalar_'..(arm and 'neon' or 'x64')])
      if arm then u32(0x91000400);u32(0x91000821);u32(0x91000842);u32(0xd1000463)
      else hex('48 ff c0 48 83 c1 02 48 83 c2 02 49 ff c8') end
      jump(scalar);mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if special=='kırp_i32_u8' or special=='kare_kırp_i16_u8' then
      local square=special=='kare_kırp_i16_u8';local kind=square and 'square' or 'clip'
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 4 or 9);pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local bad,loop,tail,scalar,done,exit=label(),label(),label(),label(),label(),label()
      if arm then
        u32(0xf100005f);condition_branch(bad,11,0)
        u32(0xf1007c7f);condition_branch(bad,8,0);u32(0xf103fc9f);condition_branch(bad,8,0)
      else
        hex('48 85 d2');condition_branch(bad,0,0x88)
        hex('49 83 f8 1f');condition_branch(bad,0,0x87);hex('49 81 f9 ff 00 00 00');condition_branch(bad,0,0x87)
      end
      local profile=instruction
      if square and profile=='avx512' then profile='avx2' elseif not square and profile=='avx512bw' then profile='avx512' end
      local width=(profile=='avx512' or profile=='avx512bw') and 16 or (profile=='avx2' and 8 or 4)
      local snippets={        clip_init_sse2='66 41 0f 6e e0 66 41 0f 6e e9 66 0f 70 ed 00',
        square_init_sse2='66 41 0f 6e e0 66 41 0f 6e d9 f2 0f 70 db 00 66 0f 70 db 00 41 ba ff 00 00 00 66 41 0f 6e ea 66 0f 70 ed 00',
        clip_sse2='f3 41 0f 6f 03 66 0f e2 c4 66 0f ef d2 66 0f 6f c8 66 0f 66 ca 66 0f db c1 66 0f 6f c8 66 0f 66 cd 66 0f 6f d1 66 0f db cd 66 0f df d0 66 0f eb d1 66 0f 6b d2 66 0f 67 d2 66 0f 7e 10',
        square_sse2='f3 41 0f 7e 03 66 0f ef d2 66 0f ee c2 66 0f ea c3 66 0f d5 c0 66 0f 61 c2 66 0f e2 c4 66 0f 6f c8 66 0f 66 cd 66 0f 6f d1 66 0f db cd 66 0f df d0 66 0f eb d1 66 0f 6b d2 66 0f 67 d2 66 0f 7e 10',
        clip_init_avx2='c4 c1 79 6e e0 c4 c1 79 6e e9 c4 e2 7d 58 ed',
        square_init_avx2='c4 c1 79 6e e0 c4 c1 79 6e d9 c4 e2 79 79 db 41 ba ff 00 00 00 c4 c1 79 6e ea c4 e2 7d 58 ed',
        clip_avx2='c4 c1 7e 6f 03 c5 fd e2 c4 c5 ed ef d2 c4 e2 7d 3d c2 c4 e2 7d 39 c5 c5 fd 6b c0 c4 e3 fd 00 c0 d8 c5 f9 67 c0 c5 f9 d6 00',
        square_avx2='c4 c1 7a 6f 03 c5 e9 ef d2 c5 f9 ee c2 c5 f9 ea c3 c5 f9 d5 c0 c4 e2 7d 33 c0 c5 fd e2 c4 c4 e2 7d 39 c5 c5 fd 6b c0 c4 e3 fd 00 c0 d8 c5 f9 67 c0 c5 f9 d6 00',
        clip_init_avx512='c4 c1 79 6e e0 c4 c1 79 6e e9 62 f2 7d 48 58 ed',
        square_init_avx512bw='c4 c1 79 6e e0 c4 c1 79 6e d9 c4 e2 7d 79 db 41 ba ff 00 00 00 c4 c1 79 6e ea 62 f2 7d 48 58 ed',
        clip_avx512='62 d1 7e 48 6f 03 62 f1 7d 48 e2 c4 62 f1 6d 48 ef d2 62 f2 7d 48 3d c2 62 f2 7d 48 39 c5 62 f2 7e 48 11 00',
        square_avx512bw='c4 c1 7e 6f 03 c5 ed ef d2 c5 fd ee c2 c5 fd ea c3 c5 fd d5 c0 62 f2 7d 48 33 c0 62 f1 7d 48 e2 c4 62 f2 7d 48 39 c5 62 f2 7e 48 11 00',
        clip_init_neon='e5 03 03 4b a4 0c 04 4e 85 0c 04 4e 02 04 00 4f',
        square_init_neon='e5 03 03 4b a4 0c 04 4e 83 0c 02 0e 02 04 00 4f e5 1f 80 52 a5 0c 04 4e',
        clip_neon='20 00 c0 3d 00 44 a4 4e 00 64 a2 4e 00 6c a5 4e 00 48 61 0e 00 28 21 2e 00 00 00 bd',
        square_neon='20 00 40 fd 00 64 62 0e 00 6c 63 0e 00 9c 60 0e 00 a4 10 2f 00 44 a4 4e 00 6c a5 4e 00 48 61 0e 00 28 21 2e 00 00 00 bd',
        clip_tail_neon='25 00 40 b9 a5 28 c3 1a bf 00 00 71 a5 a0 9f 1a bf 00 04 6b a5 d0 84 1a 05 00 00 39',
        square_tail_neon='25 00 c0 79 bf 00 00 71 a5 a0 9f 1a bf 00 04 6b a5 d0 84 1a a5 7c 05 1b a5 24 c3 1a e6 1f 80 52 bf 00 06 6b a5 d0 86 1a 05 00 00 39',
        clip_tail_x64='45 8b 13 41 d3 fa 45 31 c0 45 85 d2 45 0f 4c d0 45 39 ca 45 0f 4f d1 44 88 10',
        square_tail_x64='45 0f bf 13 45 31 c0 45 85 d2 45 0f 4c d0 45 39 ca 45 0f 4f d1 45 0f af d2 41 d3 ea 41 b8 ff 00 00 00 45 39 c2 45 0f 4f d0 44 88 10',
        clip_avx='c4 c1 7a 6f 03 c5 f9 e2 c4 c5 e9 ef d2 c5 f9 6f c8 c5 f1 66 ca c5 f9 db c1 c5 f9 6f c8 c5 f1 66 cd c5 f9 6f d1 c5 f1 db cd c5 e9 df d0 c5 e9 eb d1 c5 e9 6b d2 c5 e9 67 d2 c5 f9 7e 10',
        square_avx='c4 c1 7a 7e 03 c5 e9 ef d2 c5 f9 ee c2 c5 f9 ea c3 c5 f9 d5 c0 c5 f9 61 c2 c5 f9 e2 c4 c5 f9 6f c8 c5 f1 66 cd c5 f9 6f d1 c5 f1 db cd c5 e9 df d0 c5 e9 eb d1 c5 e9 6b d2 c5 e9 67 d2 c5 f9 7e 10',
        clip_init_avx='c4 c1 79 6e e0 c4 c1 79 6e e9 c5 f9 70 ed 00',
        square_init_avx='c4 c1 79 6e e0 c4 c1 79 6e d9 c5 fb 70 db 00 c5 f9 70 db 00 41 ba ff 00 00 00 c4 c1 79 6e ea c5 f9 70 ed 00'}
      if profile~='scalar' then hex(assert(snippets[kind..'_init_'..profile])) end
      if not arm then hex('49 89 cb 4c 89 c1') end
      if profile~='scalar' then
        mark(loop)
        if arm then u32(0xf100005f | (width<<10));condition_branch(tail,11,0)
        else hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c) end
        hex(assert(snippets[kind..'_'..profile]))
        if arm then u32(0x91000000 | (width<<10));u32(0x91000021 | ((width*(square and 2 or 4))<<10));u32(0xd1000042 | (width<<10))
        else hex('48 83 c0');bytes(string.char(width));hex('49 83 c3');bytes(string.char(width*(square and 2 or 4)));hex('48 83 ea');bytes(string.char(width)) end
        jump(loop);mark(tail);if not arm and profile~='sse2' then hex('c5 f8 77') end
      end
      mark(scalar)
      if arm then u32(0xf100005f);condition_branch(done,13,0)
      else hex('48 85 d2');condition_branch(done,0,0x8e) end
      hex(snippets[kind..'_tail_'..(arm and 'neon' or 'x64')])
      if arm then u32(0x91000400);u32(0x91000021 | ((square and 2 or 4)<<10));u32(0xd1000442)
      else hex('48 ff c0 49 83 c3');bytes(string.char(square and 2 or 4));hex('48 ff ca') end
      jump(scalar);mark(done);generate({'num',0});jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if special=='nokta_u8_i8' or special=='katla_u8_i8_i32' then
      local dot=special=='nokta_u8_i8'
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        if not dot then pop(arm and 3 or 8) end;pop(2);pop(1);pop(0)
      end

      local loop,tail,scalar,done,bad,exit=label(),label(),label(),label(),label(),label()
      if arm then
        if dot then u32(0xd2800003) end
        u32(0xf100005f);condition_branch(dot and done or bad,11,0)
        if not dot then u32(0xf103fc7f);condition_branch(bad,8,0) end
      else
        if dot then hex('49 89 c2 49 89 cb 45 31 c0') end
        hex('48 85 d2');condition_branch(dot and done or bad,0,0x88)
        if not dot then hex('49 81 f8 ff 00 00 00');condition_branch(bad,0,0x87) end
      end
      local profile=instruction
      if profile=='avx512bw' and not dot then profile='avx512' end
      if profile=='avx512' and dot then profile='avx2' end
      local width=dot and (profile=='avx512bw' and 32 or 16) or (profile=='avx512' and 16 or 8)
      if profile~='scalar' then
        local init={          sse2='66 41 0f 6e e0 f2 0f 70 e4 00 66 0f 70 e4 00',
          avx2='c4 c1 79 6e e0 c4 e2 7d 58 e4',
          avx512='c4 c1 79 6e e0 62 f2 7d 48 58 e4',
          neon='64 0c 02 4e',
          avx='c4 c1 79 6e e0 c5 fb 70 e4 00 c5 f9 70 e4 00'}
        if not dot then hex(assert(init[profile])) end
        mark(loop)
        if arm then u32(0xf100005f | (width<<10));condition_branch(tail,11,0)
        else hex('48 83 fa');bytes(string.char(width));condition_branch(tail,0,0x8c) end
        local body={          dot_sse2='f3 41 0f 6f 02 f3 41 0f 6f 0b 66 0f ef d2 66 0f 6f da 66 0f 64 d9 66 0f 6f e0 66 0f 60 c2 66 0f 68 e2 66 0f 6f e9 66 0f 60 cb 66 0f 68 eb 66 0f f5 c1 66 0f f5 e5 66 0f fe c4 66 0f 6f c8 66 0f 73 d9 08 66 0f fe c1 66 0f 6f c8 66 0f 73 d9 04 66 0f fe c1 66 0f 7e c0 48 98 49 01 c0',
          dot_avx2='c4 c2 7d 30 02 c4 c2 7d 20 0b c5 fd f5 c1 c4 e3 7d 39 c1 01 c5 f9 fe c1 c5 f1 73 d8 08 c5 f9 fe c1 c5 f1 73 d8 04 c5 f9 fe c1 c5 f9 7e c0 48 98 49 01 c0',
          dot_avx512bw='62 d2 7d 48 30 02 62 d2 7d 48 20 0b 62 f1 7d 48 f5 c1 62 f3 fd 48 3b c1 01 c5 fd fe c1 c4 e3 7d 39 c1 01 c5 f9 fe c1 c5 f1 73 d8 08 c5 f9 fe c1 c5 f1 73 d8 04 c5 f9 fe c1 c5 f9 7e c0 48 98 49 01 c0',
          dot_neon='00 00 c0 3d 21 00 c0 3d 02 a4 08 2f 03 a4 08 6f 24 a4 08 0f 25 a4 08 4f 40 c0 64 0e 40 80 64 4e 60 80 65 0e 60 80 65 4e 00 b8 b1 4e 04 2c 04 4e 63 00 04 8b',
          column_sse2='f3 0f 7e 01 66 0f ef d2 66 0f 64 d0 66 0f 60 c2 66 0f d5 c4 66 0f 6f d0 66 0f 71 e2 0f 66 0f 6f c8 66 0f 61 c2 66 0f 69 ca f3 0f 6f 10 f3 0f 6f 58 10 66 0f fe c2 66 0f fe cb f3 0f 7f 00 f3 0f 7f 48 10',
          column_avx2='c4 e2 7d 21 01 c4 e2 7d 40 c4 c5 fd fe 00 c5 fe 7f 00',
          column_avx512='62 f2 7d 48 21 01 62 f2 7d 48 40 c4 62 f1 7d 48 fe 00 62 f1 7e 48 7f 00',
          column_neon='20 00 40 fd 00 a4 08 0f 00 9c 64 4e 01 a4 10 0f 02 a4 10 4f 03 00 c0 3d 05 04 c0 3d 21 84 a3 4e 42 84 a5 4e 01 00 80 3d 02 04 80 3d',
          dot_avx='c4 c1 7a 6f 02 c4 c1 7a 6f 0b c5 e9 ef d2 c5 f9 6f da c5 e1 64 d9 c5 f9 6f e0 c5 f9 60 c2 c5 d9 68 e2 c5 f9 6f e9 c5 f1 60 cb c5 d1 68 eb c5 f9 f5 c1 c5 d9 f5 e5 c5 f9 fe c4 c5 f9 6f c8 c5 f1 73 d9 08 c5 f9 fe c1 c5 f9 6f c8 c5 f1 73 d9 04 c5 f9 fe c1 c5 f9 7e c0 48 98 49 01 c0',
          column_avx='c5 fa 7e 01 c5 e9 ef d2 c5 e9 64 d0 c5 f9 60 c2 c5 f9 d5 c4 c5 f9 6f d0 c5 e9 71 e2 0f c5 f9 6f c8 c5 f9 61 c2 c5 f1 69 ca c5 fa 6f 10 c5 fa 6f 58 10 c5 f9 fe c2 c5 f1 fe cb c5 fa 7f 00 c5 fa 7f 48 10'};hex(assert(body[(dot and 'dot_' or 'column_')..profile]))
        if arm then
          u32(0x91000000 | ((width*(dot and 1 or 4))<<10));u32(0x91000021 | (width<<10));u32(0xd1000042 | (width<<10))
        elseif dot then hex('49 83 c2');bytes(string.char(width));hex('49 83 c3');bytes(string.char(width));hex('48 83 ea');bytes(string.char(width))
        else hex('48 83 c0');bytes(string.char(width*4));hex('48 83 c1');bytes(string.char(width));hex('48 83 ea');bytes(string.char(width)) end
        jump(loop);mark(tail)
        if not arm and profile~='sse2' then hex('c5 f8 77') end
      end
      mark(scalar)
      if arm then
        u32(0xf100005f);condition_branch(done,13,0)
        if dot then u32(0x39400004);u32(0x39800025);u32(0x9b050c83)
        else u32(0x39c00024);u32(0x1b037c84);u32(0xb9400005);u32(0x0b0400a5);u32(0xb9000005) end
        u32(0x91000000 | ((dot and 1 or 4)<<10));u32(0x91000421);u32(0xd1000442)
      else
        hex('48 85 d2');condition_branch(done,0,0x8e)
        if dot then hex('49 0f b6 02 49 0f be 0b 48 0f af c1 49 01 c0 49 ff c2 49 ff c3')
        else hex('44 0f be 09 45 0f af c8 44 01 08 48 83 c0 04 48 ff c1') end
        hex('48 ff ca')
      end
      jump(scalar);mark(done)
      if dot then if arm then u32(0xaa0303e0) else hex('4c 89 c0') end
      else generate({'num',0}) end
      jump(exit);mark(bad);generate({'num',-1});mark(exit);return
    end
    if special=='bit_gör' then generate(e[3][2]);normalize(e.type);return end
    if special=='gör' or special=='dizi_gör' then generate(e[3][2]);return end
    if special=='boyut' then generate({'num',e.size});return end
    if special=='adres' or special=='adres_bitleri' then generate(e[3][1]);return end
    if special=='sil' then generate({'call','bellek_bırak',{e[3][1]}});return end
    if special=='yerel' then generate({'call','dizi',{{'num',e.size}}});return end
    if special=='yeni' then generate({'call','bellek_ayır',{{'num',e.size}}});return end
    if special=='yerel_dizi' then generate({'call','dizi',{{'num',e.size*e.count}}});return end
    if special=='yeni_dizi' then generate({'call','__t_array_alloc',{e[3][2],{'num',e.size}}});return end
    if numeric[special] then
      local from=e[3][1].type;local sf=(numeric[from] or {}).float;local df=numeric[special].float
      generate(e[3][1])
      if sf and df then
        if from~=special then
          fp_in(from,0,0)
          if arm then u32(special=='f32' and 0x1e624000 or 0x1e22c000)
          else hex(special=='f32' and 'f2 0f 5a c0' or 'f3 0f 5a c0') end
          fp_out(special)
        end
      elseif df then
        local unsigned=from=='u64'
        if arm then u32((special=='f32' and 0x9e220000 or 0x9e620000) | (unsigned and 0x10000 or 0))
        else
          local regular,done=label(),label()
          if unsigned then
            hex('48 85 c0');condition_branch(regular,0,0x89)
            hex('48 89 c1 48 83 e1 01 48 d1 e8 48 09 c8')
            hex(special=='f32' and 'f3 48 0f 2a c0 f3 0f 58 c0' or 'f2 48 0f 2a c0 f2 0f 58 c0');jump(done);mark(regular)
          end
          hex(special=='f32' and 'f3 48 0f 2a c0' or 'f2 48 0f 2a c0');mark(done)
        end
        fp_out(special)
      elseif sf then
        local unsigned=special=='u64';local invalid,done=label(),label()
        fp_in(from,0,0)
        generate({'real',unsigned and 18446744073709551616.0 or 9223372036854775808.0,type=from});fp_in(from,1,0);fp_compare(from)
        condition_branch(invalid,2,0x83)
        if not arm then condition_branch(invalid,0,0x8a) end
        generate({'real',unsigned and 0.0 or -9223372036854775808.0,type=from});fp_in(from,1,0);fp_compare(from)
        condition_branch(invalid,4,0x82)
        if arm then u32((from=='f32' and 0x9e380000 or 0x9e780000) | (unsigned and 0x10000 or 0))
        else
          local regular,converted=label(),label()
          if unsigned then
            generate({'real',9223372036854775808.0,type=from});fp_in(from,1,0);fp_compare(from);condition_branch(regular,0,0x82)
            hex(from=='f32' and 'f3 0f 5c c1 f3 48 0f 2c c0' or 'f2 0f 5c c1 f2 48 0f 2c c0')
            hex('48 0f ba f8 3f');jump(converted);mark(regular)
          end
          hex(from=='f32' and 'f3 48 0f 2c c0' or 'f2 48 0f 2c c0');mark(converted)
        end
        jump(done);mark(invalid);if arm then u32(0xd4200000) else hex('0f 0b') end;mark(done)
      end
      normalize(special);return
    end
    if special=='karekök' then
      generate(e[3][1]);fp_in(e.type,0,0)
      if arm then u32(e.type=='f32' and 0x1e21c000 or 0x1e61c000) else hex(e.type=='f32' and 'f3 0f 51 c0' or 'f2 0f 51 c0') end
      fp_out(e.type);return
    end
    if special=='işlev_adresi' then address(entries[e[3][1][2]]);return end
    if special=='adres_ekle' then
      if arm and optimization>0 then
        local c=H.leaf_constant(e[3][2])
        if c and c>-4096 and c<16777216 then
          local rb=H.leaf_register(e[3][1]);if not rb then generate(e[3][1]);rb=0 end
          if c==0 then move_register(0,rb)
          elseif c<0 then u32(0xd1000000 | ((-c)<<10) | (rb<<5))
          elseif c<4096 then u32(0x91000000 | (c<<10) | (rb<<5))
          else u32(0x91400000 | ((c>>12)<<10) | (rb<<5));if c%4096~=0 then u32(0x91000000 | ((c%4096)<<10)) end end
          return
        end
        H.emit_arm_binary({'+',e[3][1],e[3][2],type='i64',operand='i64'},0);return
      end
      memory_arguments(e[3],false)
      if arm then u32(0x8b010000) else hex('48 01 c8') end;return
    end
    if special=='işlemci_özellikleri' then
      if arm then generate({'call','__t_arm_features',{},type='u64'})
      else
        local done,no_bw=label(),label()
        hex('53 45 31 d2 31 c0 0f a2 41 89 c0 83 f8 01');condition_branch(done,0,0x82)
        hex('b8 01 00 00 00 0f a2 f7 c2 00 00 00 04');condition_branch(done,0,0x84)
        hex('41 ba 01 00 00 00 81 e1 00 00 00 1c 81 f9 00 00 00 1c');condition_branch(done,0,0x85)
        hex('31 c9 0f 01 d0 41 89 c3 83 e0 06 83 f8 06');condition_branch(done,0,0x85)
        hex('41 83 ca 02 41 83 f8 07');condition_branch(done,0,0x82)
        hex('b8 07 00 00 00 31 c9 0f a2 f7 c3 20 00 00 00');condition_branch(done,0,0x84)
        hex('41 83 ca 04 41 81 e3 e6 00 00 00 41 81 fb e6 00 00 00');condition_branch(done,0,0x85)
        hex('f7 c3 00 00 01 00');condition_branch(done,0,0x84)
        hex('41 83 ca 08 f7 c3 00 00 00 40');condition_branch(no_bw,0,0x84)
        hex('41 83 ca 10');mark(no_bw)
        hex('f7 c1 00 08 00 00');condition_branch(done,0,0x84)
        hex('41 81 ca 80 00 00 00');mark(done);hex('4c 89 d0 5b')
      end
      return
    end
    if special=='işlemci_bekle' then
      if arm then u32(0xd503203f);u32(0xd2800000) else hex('f3 90 31 c0') end;return
    end
    if special=='öngetir' then
      generate(e[3][1]);if arm then u32(0xf9800000);u32(0xd2800000) else hex('0f 18 08 31 c0') end;return
    end
    if special=='bayt_ters' or special=='son_bit' or special=='bit_ters' then
      generate(e[3][1])
      if special=='bit_ters' then
        if arm then u32(0xdac00000)
        else
          for _,v in ipairs({{1,0x5555555555555555},{2,0x3333333333333333},{4,0x0f0f0f0f0f0f0f0f}}) do
            hex('48 89 c1 48 c1 e9');bytes(string.char(v[1]));hex('48 ba');bytes(string.pack('<i8',v[2]))
            hex('48 21 d1 48 21 d0 48 c1 e0');bytes(string.char(v[1]));hex('48 09 c8')
          end
          hex('48 0f c8')
        end
      elseif special=='bayt_ters' then if arm then u32(0xdac00c00) else hex('48 0f c8') end
      elseif arm then
        u32(0xdac01000);u32(0xd28007e1);u32(0xcb000020)
      else hex('48 0f bd c8 48 c7 c0 ff ff ff ff 48 0f 45 c1') end
      return
    end
    if special=='atomik_oku' or special=='atomik_yaz' or special=='atomik_ekle' or special=='atomik_kıyas_değiştir' then
      for _,a in ipairs(e[3]) do generate(a);push() end
      if #e[3]==3 then pop(2) end
      if #e[3]>=2 then pop(1) end;pop(0)
      if arm then
        if special=='atomik_oku' then u32(0xc8dffc00)
        elseif special=='atomik_yaz' then u32(0xc89ffc01);u32(0xaa0103e0)
        elseif special=='atomik_ekle' then
          for _,v in ipairs({0xc85ffc02,0x8b010043,0xc804fc03,0x35ffffa4,0xaa0203e0}) do u32(v) end
        else
          for _,v in ipairs({0xc85ffc03,0xeb01007f,0x54000061,0xc804fc02,0x35ffff84,0xd5033f5f,0xaa0303e0}) do u32(v) end
        end
      else
        if special=='atomik_oku' then hex('48 8b 00')
        elseif special=='atomik_yaz' then hex('48 89 08 48 89 c8')
        elseif special=='atomik_ekle' then hex('f0 48 0f c1 08 48 89 c8')
        else hex('49 89 c0 48 89 c8 f0 49 0f b1 10') end
      end
      return
    end
    if special=='çarp_yüksek_u64' then
      generate(e[3][1]);push();generate(e[3][2]);pop(1)
      if arm then u32(0x9bc17c00) else hex('48 f7 e1 48 89 d0') end;return
    end
    if special=='kırp_i16_u8' then
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local fail_label,done,scalar,loop=label(),label(),label(),label()

      if arm then
        u32(0xf103fc7f);patches[#patches+1]={#code,fail_label,'cond8'};u32(0x54000008)
      else
        hex('49 81 f8 ff 00 00 00 0f 87');patches[#patches+1]={#code,fail_label,'rel32'};u32(0)
      end
      local enc={arm_init='62 0c 02 4e 01 84 00 4f',arm_body='20 00 c0 3d 00 64 61 4e 00 6c 62 4e 00 28 21 2e 00 00 00 fd',arm_tail='24 00 c0 79 9f 00 00 71 84 a0 9f 1a 9f 00 03 6b 84 d0 83 1a 04 00 00 39',x64_init='66 41 0f 6e d0 f2 0f 70 d2 00 66 0f 70 d2 00 66 0f ef c9',x64_body='f3 0f 6f 01 66 0f ee c1 66 0f ea c2 66 0f 67 c1 66 0f d6 00',x64_tail='44 0f bf 09 45 31 d2 45 85 c9 45 0f 4c ca 45 39 c1 45 0f 4f c8 44 88 08'}
      local function less(n,l)
        if arm then u32(0xf100005f | (n<<10));patches[#patches+1]={#code,l,'cond11'};u32(0x5400000b)
        else hex('48 83 fa');bytes(string.char(n));hex('0f 8c');patches[#patches+1]={#code,l,'rel32'};u32(0) end
      end
      local function advance(n)
        if arm then u32(0x91000000 | (n<<10));u32(0x91000021 | ((n*2)<<10));u32(0xd1000042 | (n<<10))
        else
          hex('48 83 c0');bytes(string.char(n));hex('48 83 c1');bytes(string.char(n*2));hex('48 83 ea');bytes(string.char(n))
        end
      end
      if instruction~='scalar' then
        hex(enc[arm and 'arm_init' or 'x64_init'])
        mark(loop);less(8,scalar);hex(enc[arm and 'arm_body' or 'x64_body']);advance(8);jump(loop)
      end
      mark(scalar);less(1,done);hex(enc[arm and 'arm_tail' or 'x64_tail']);advance(1);jump(scalar)
      mark(fail_label);generate({'num',-1});local exit_label=label();jump(exit_label)
      mark(done);generate({'num',0});mark(exit_label);return
    end
    if special=='vektör_topla_i32' or special=='vektör_topla_i16' or special=='vektör_çıkar_i16' or special=='vektör_enbüyük_i16' then
      local word=special~='vektör_topla_i32';local subtract=special=='vektör_çıkar_i16';local maxop=special=='vektör_enbüyük_i16';local element=word and 2 or 4
      local profile=(word and instruction=='avx512') and 'avx2' or instruction
      if not word and profile=='avx512bw' then profile='avx512' end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local scalar,loop,done=label(),label(),label()
      local width=profile=='scalar' and 1 or ((profile=='avx512' or profile=='avx512bw') and 64//element or (profile=='avx2' and 32//element or 16//element))
      local function less_than(n,l)
        if arm then
          u32(0xf100007f | (n<<10));patches[#patches+1]={#code,l,'cond11'};u32(0x5400000b)
        else
          hex('49 83 f8');bytes(string.char(n));hex('0f 8c');patches[#patches+1]={#code,l,'rel32'};u32(0)
        end
      end
      local function advance(n)
        if arm then
          for r=0,2 do u32(0x91000000 | ((n*element)<<10) | (r<<5) | r) end
          u32(0xd1000063 | (n<<10))
        else
          for _,h in ipairs({'48 83 c0','48 83 c1','48 83 c2'}) do hex(h);bytes(string.char(n*element)) end
          hex('49 83 e8');bytes(string.char(n))
        end
      end
      local n4=e[3][4];local sabit=n4[1]=='num' and n4[2] or (n4[1]=='var' and constants[n4[2]] and resolve_constant(n4[2]).value) or nil
      if arm and width>1 and sabit and sabit>0 and sabit%width==0 and sabit//width<=8 then

        local op=word and (maxop and 0x4e616400 or subtract and 0x6e618400 or 0x4e618400) or 0x4ea18400
        for i=0,sabit//width-1 do
          u32(0x3dc00020 | (i<<10));u32(0x3dc00041 | (i<<10));u32(op);u32(0x3d800000 | (i<<10))
        end
        u32(0xd2800000);return
      end
      if width>1 then
        if arm then

          local big=label();mark(big);less_than(width*4,loop)
          hex(word and (maxop and '20 20 40 4c 44 20 40 4c 00 64 64 4e 21 64 65 4e 42 64 66 4e 63 64 67 4e 00 20 00 4c' or subtract and '20 20 40 4c 44 20 40 4c 00 84 64 6e 21 84 65 6e 42 84 66 6e 63 84 67 6e 00 20 00 4c' or '20 20 40 4c 44 20 40 4c 00 84 64 4e 21 84 65 4e 42 84 66 4e 63 84 67 4e 00 20 00 4c') or '20 20 40 4c 44 20 40 4c 00 84 a4 4e 21 84 a5 4e 42 84 a6 4e 63 84 a7 4e 00 20 00 4c');advance(width*4);jump(big)
        end
        mark(loop);less_than(width,scalar)
        if arm then
          local op=word and (maxop and 0x4e616400 or subtract and 0x6e618400 or 0x4e618400) or 0x4ea18400
          for _,v in ipairs({0x3dc00020,0x3dc00041,op,0x3d800000}) do u32(v) end
        else
          local enc={
            sse2='f3 0f 6f 01 f3 0f 6f 0a 66 0f fe c1 f3 0f 7f 00',
            avx='c5 fa 6f 01 c5 fa 6f 0a c5 f9 fe c1 c5 fa 7f 00',
            avx2='c5 fe 6f 01 c5 fe 6f 0a c5 fd fe c1 c5 fe 7f 00',
            avx512='62 f1 7e 48 6f 01 62 f1 7e 48 6f 0a 62 f1 7d 48 fe c1 62 f1 7e 48 7f 00',
          }
          local words={
            add_sse2='f3 0f 6f 01 f3 0f 6f 0a 66 0f fd c1 f3 0f 7f 00',
            add_avx='c5 fa 6f 01 c5 fa 6f 0a c5 f9 fd c1 c5 fa 7f 00',
            add_avx2='c5 fe 6f 01 c5 fe 6f 0a c5 fd fd c1 c5 fe 7f 00',
            add_avx512bw='62 f1 ff 48 6f 01 62 f1 ff 48 6f 0a 62 f1 7d 48 fd c1 62 f1 ff 48 7f 00',
            sub_sse2='f3 0f 6f 01 f3 0f 6f 0a 66 0f f9 c1 f3 0f 7f 00',
            sub_avx='c5 fa 6f 01 c5 fa 6f 0a c5 f9 f9 c1 c5 fa 7f 00',
            sub_avx2='c5 fe 6f 01 c5 fe 6f 0a c5 fd f9 c1 c5 fe 7f 00',
            sub_avx512bw='62 f1 ff 48 6f 01 62 f1 ff 48 6f 0a 62 f1 7d 48 f9 c1 62 f1 ff 48 7f 00',
            max_sse2='f3 0f 6f 01 f3 0f 6f 0a 66 0f ee c1 f3 0f 7f 00',
            max_avx='c5 fa 6f 01 c5 fa 6f 0a c5 f9 ee c1 c5 fa 7f 00',
            max_avx2='c5 fe 6f 01 c5 fe 6f 0a c5 fd ee c1 c5 fe 7f 00',
            max_avx512bw='62 f1 ff 48 6f 01 62 f1 ff 48 6f 0a 62 f1 7d 48 ee c1 62 f1 ff 48 7f 00',
          };hex(assert(word and words[(maxop and 'max_' or subtract and 'sub_' or 'add_')..profile] or enc[profile]))
        end
        advance(width);jump(loop)
        if not arm and width>8//element then

          local ara,ara_bitti=label(),label();local w2=16//element
          mark(ara);less_than(w2,ara_bitti)
          local v=levels[profile]>=2
          if word then
            hex(v and 'c5 fa 6f 01 c5 fa 6f 0a' or 'f3 0f 6f 01 f3 0f 6f 0a')
            hex(v and (maxop and 'c5 f9 ee c1' or subtract and 'c5 f9 f9 c1' or 'c5 f9 fd c1') or (maxop and '66 0f ee c1' or subtract and '66 0f f9 c1' or '66 0f fd c1'))
            hex(v and 'c5 fa 7f 00' or 'f3 0f 7f 00')
          else
            hex(v and 'c5 fa 6f 01 c5 fa 6f 0a c5 f9 fe c1 c5 fa 7f 00' or 'f3 0f 6f 01 f3 0f 6f 0a 66 0f fe c1 f3 0f 7f 00')
          end
          advance(w2);jump(ara);mark(ara_bitti)
        end
      end
      mark(scalar);less_than(1,done)
      if arm and maxop then

        u32(0x79c00024);u32(0x79c00045);u32(0x6b05009f);u32(0x1a85c084);u32(0x79000004)
      elseif arm then
        u32(word and 0x79400024 or 0xb9400024);u32(word and 0x79400045 or 0xb9400045)
        u32(subtract and 0x4b050084 or 0x0b050084);u32(word and 0x79000004 or 0xb9000004)
      elseif maxop then
        hex('44 0f bf 09 44 0f bf 12 45 39 d1 45 0f 4c ca 66 44 89 08')
      elseif word then
        hex('44 0f b7 09 44 0f b7 12');hex(subtract and '45 29 d1' or '45 01 d1');hex('66 44 89 08')
      else hex('44 8b 09 44 03 0a 44 89 08') end
      advance(1);jump(scalar);mark(done)
      if not arm and levels[instruction]>=2 then hex('c5 f8 77') end
      if arm then u32(0xd2800000) else hex('31 c0') end;return
    end
    if special=='taşlar_havuz_i16' then

      local hizli=arm and instruction=='neon' or (not arm and (instruction=='avx2' or instruction=='avx512' or instruction=='avx512bw'))
      if not hizli then generate({'call','__t_taşlar_havuz_i16_düz',e[3],type='i64'});return end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 4 or 9);pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local tas,satir,relu,bitti=label(),label(),label(),label()
      if arm then

        for r=16,28 do u32(0x6e201c00 + r*0x10021) end
        mark(tas);u32(0xf100005f);patches[#patches+1]={#code,bitti,'cond0'};u32(0x54000000)
        for _,v in ipairs({0x38401429,0xf8408406,0x4c4024c0,0xf1000529}) do u32(v) end
        mark(satir);u32(0xf100013f);patches[#patches+1]={#code,relu,'cond0'};u32(0x54000000)
        for _,v in ipairs({0xf8408406,0x4c4024c4,0x4e648400,0x4e658421,0x4e668442,0x4e678463,0xf1000529}) do u32(v) end
        jump(satir);mark(relu)
        for _,v in ipairs({0x4e7c6400,0x4e7c6421,0x4e7c6442,0x4e7c6463,
                           0x0e601210,0x4e601231,0x0e611252,0x4e611273,0x0e621294,0x4e6212b5,0x0e6312d6,0x4e6312f7,
                           0x4e606718,0x4e616739,0x4e62675a,0x4e63677b,0xf1000442}) do u32(v) end
        jump(tas);mark(bitti)
        for _,v in ipairs({0x4c9f2870,0x4c002874,0x4c002498,0xd2800000}) do u32(v) end;return
      end

      if windows then
        hex('48 83 ec 60 c5 fa 7f 34 24 c5 fa 7f 7c 24 10 c5 7a 7f 44 24 20 c5 7a 7f 4c 24 30 c5 7a 7f 54 24 40 c5 7a 7f 5c 24 50')
      end
      hex('49 89 c2')
      hex('c5 e5 ef db c5 cd ef f6 c5 c5 ef ff c4 41 3d ef c0 c4 41 35 ef c9 c4 41 2d ef d2 c4 41 25 ef db')
      mark(tas);hex('48 85 d2');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
      hex('44 0f b6 19 48 ff c1')
      hex('49 8b 02 49 83 c2 08 c5 fe 6f 00 c5 fe 6f 48 20 49 ff cb')
      mark(satir);hex('4d 85 db');hex('0f 84');patches[#patches+1]={#code,relu,'rel32'};u32(0)
      hex('49 8b 02 49 83 c2 08 c5 fd fd 00 c5 f5 fd 48 20 49 ff cb');jump(satir)
      mark(relu);hex('c5 fd ee c3 c5 f5 ee cb')
      hex('c4 e2 7d 23 d0 c5 cd fe f2 c4 e3 7d 39 c2 01 c4 e2 7d 23 d2 c5 c5 fe fa')
      hex('c4 e2 7d 23 d1 c4 61 3d fe c2 c4 e3 7d 39 ca 01 c4 e2 7d 23 d2 c4 61 35 fe ca')
      hex('c4 61 2d ee d0 c4 61 25 ee d9 48 ff ca');jump(tas)
      mark(bitti);hex('c4 c1 7e 7f 30 c4 c1 7e 7f 78 20 c4 41 7e 7f 40 40 c4 41 7e 7f 48 60 c4 41 7e 7f 11 c4 41 7e 7f 59 20')
      hex('c5 f8 77')
      if windows then
        hex('c5 fa 6f 34 24 c5 fa 6f 7c 24 10 c5 7a 6f 44 24 20 c5 7a 6f 4c 24 30 c5 7a 6f 54 24 40 c5 7a 6f 5c 24 50 48 83 c4 60')
      end
      hex('31 c0');return
    end
    if special=='taş_havuz_i16' then

      if instruction=='scalar' then generate({'call','__t_taş_havuz_i16_düz',e[3],type='i64'});return end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local dongu,bitti=label(),label()
      if arm then

        for _,v in ipairs({0x6e3c1f9c,0x4cdf2850,0x4c402854,0x4c402478,0xf8408404,0x4c402480,0xd1000421}) do u32(v) end
        mark(dongu);u32(0xf100003f);patches[#patches+1]={#code,bitti,'cond0'};u32(0x54000000)
        for _,v in ipairs({0xf8408404,0x4c402484,0x4e648400,0x4e658421,0x4e668442,0x4e678463,0xd1000421}) do u32(v) end
        jump(dongu);mark(bitti)
        for _,v in ipairs({0x4e7c6400,0x4e7c6421,0x4e7c6442,0x4e7c6463,
                           0x0e601210,0x4e601231,0x0e611252,0x4e611273,0x0e621294,0x4e6212b5,0x0e6312d6,0x4e6312f7,
                           0x4e606718,0x4e616739,0x4e62675a,0x4e63677b,
                           0x4c002854,0xd1010042,0x4c002850,0x4c002478,0xd2800000}) do u32(v) end
        return
      end

      if instruction=='avx512bw' then

        hex('4c 8b 10 48 83 c0 08 62 d1 fe 48 6f 02 48 ff c9')
        mark(dongu);hex('48 85 c9');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
        hex('4c 8b 10 48 83 c0 08 62 d1 7d 48 fd 02 48 ff c9');jump(dongu);mark(bitti)
        hex('62 f1 f5 48 ef c9 62 f1 7d 48 ee c1')
        hex('62 f2 7d 48 23 c8 62 f1 75 48 fe 0a 62 f1 7e 48 7f 0a')
        hex('62 f3 fd 48 3b c1 01 62 f2 7d 48 23 c9 62 f1 75 48 fe 4a 01 62 f1 7e 48 7f 4a 01')
        hex('62 d1 7d 48 ee 00 62 d1 fe 48 7f 00 c5 f8 77 31 c0');return
      end
      if instruction=='avx2' or instruction=='avx512' then

        hex('4c 8b 10 48 83 c0 08 c4 c1 7e 6f 02 c4 c1 7e 6f 4a 20 48 ff c9')
        mark(dongu);hex('48 85 c9');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
        hex('4c 8b 10 48 83 c0 08 c4 c1 7d fd 02 c4 c1 75 fd 4a 20 48 ff c9');jump(dongu);mark(bitti)
        hex('c5 ed ef d2 c5 fd ee c2 c5 f5 ee ca')
        hex('c4 e2 7d 23 d0 c5 ed fe 12 c5 fe 7f 12 c4 e3 7d 39 c2 01 c4 e2 7d 23 d2 c5 ed fe 52 20 c5 fe 7f 52 20')
        hex('c4 e2 7d 23 d1 c5 ed fe 52 40 c5 fe 7f 52 40 c4 e3 7d 39 ca 01 c4 e2 7d 23 d2 c5 ed fe 52 60 c5 fe 7f 52 60')
        hex('c4 c1 7d ee 00 c4 c1 7e 7f 00 c4 c1 75 ee 48 20 c4 c1 7e 7f 48 20 c5 f8 77 31 c0');return
      end

      local vex=levels[instruction]>=2
      hex('4c 8b 10 48 83 c0 08')
      hex(vex and 'c4 c1 7a 6f 02 c4 c1 7a 6f 4a 10 c4 c1 7a 6f 52 20 c4 c1 7a 6f 5a 30' or 'f3 41 0f 6f 02 f3 41 0f 6f 4a 10 f3 41 0f 6f 52 20 f3 41 0f 6f 5a 30')
      hex('48 ff c9');mark(dongu);hex('48 85 c9');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
      hex('4c 8b 10 48 83 c0 08')
      hex(vex and 'c4 c1 79 fd 02 c4 c1 71 fd 4a 10 c4 c1 69 fd 52 20 c4 c1 61 fd 5a 30' or '66 41 0f fd 02 66 41 0f fd 4a 10 66 41 0f fd 52 20 66 41 0f fd 5a 30')
      hex('48 ff c9');jump(dongu);mark(bitti)
      hex(vex and 'c5 d1 ef ed c5 f9 ee c5 c5 f1 ee cd c5 e9 ee d5 c5 e1 ee dd' or '66 0f ef ed 66 0f ee c5 66 0f ee cd 66 0f ee d5 66 0f ee dd')
      for k=0,3 do
        local d0,d1,dm=string.format('%02x',32*k),string.format('%02x',32*k+16),string.format('%02x',16*k)
        if vex then
          hex('c4 e2 79 23 '..string.format('%02x',0xe0+k)..' c5 fa 6f 6a '..d0..' c5 d9 fe e5 c5 fa 7f 62 '..d0)
          hex('c5 f9 70 '..string.format('%02x',0xe0+k)..' ee c4 e2 79 23 e4 c5 fa 6f 6a '..d1..' c5 d9 fe e5 c5 fa 7f 62 '..d1)
          hex('c4 c1 7a 6f 60 '..dm..' c5 d9 ee '..string.format('%02x',0xe0+k)..' c4 c1 7a 7f 60 '..dm)
        else
          hex('66 0f 6f '..string.format('%02x',0xe0+k)..' 66 0f 61 e4 66 0f 72 e4 10 f3 0f 6f 6a '..d0..' 66 0f fe e5 f3 0f 7f 62 '..d0)
          hex('66 0f 6f '..string.format('%02x',0xe0+k)..' 66 0f 69 e4 66 0f 72 e4 10 f3 0f 6f 6a '..d1..' 66 0f fe e5 f3 0f 7f 62 '..d1)
          hex('f3 41 0f 6f 60 '..dm..' 66 0f ee '..string.format('%02x',0xe0+k)..' f3 41 0f 7f 60 '..dm)
        end
      end
      hex('31 c0');return
    end
    if special=='havuz_i16' then

      if instruction=='scalar' then generate({'call','__t_havuz_i16_düz',e[3],type='i64'});return end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local dongu,bitti=label(),label()
      if arm then
        u32(0x6e231c63)
        mark(dongu);u32(0xf100207f);patches[#patches+1]={#code,bitti,'cond11'};u32(0x5400000b)
        for _,v in ipairs({0x3dc00000,0x4e636400,0x3d800000,
                           0x3dc00021,0x3dc00422,0x0e601021,0x4e601042,0x3d800021,0x3d800422,
                           0x3dc00044,0x4e606484,0x3d800044,
                           0x91004000,0x91008021,0x91004042,0xf1002063}) do u32(v) end
        jump(dongu);mark(bitti);u32(0xd2800000);return
      end
      local vex=levels[instruction]>=2
      hex(vex and 'c5 e1 ef db' or '66 0f ef db')
      mark(dongu);hex('49 83 f8 08');hex('0f 8c');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
      if vex then
        hex('c5 fa 6f 00 c5 f9 ee c3 c5 fa 7f 00 c5 fa 6f 09 c5 fa 6f 51 10 c4 e2 79 23 e0 c5 f1 fe cc c5 f9 70 e0 ee c4 e2 79 23 e4 c5 e9 fe d4 c5 fa 7f 09 c5 fa 7f 51 10 c5 fa 6f 22 c5 d9 ee e0 c5 fa 7f 22')
      else
        hex('f3 0f 6f 00 66 0f ee c3 f3 0f 7f 00 f3 0f 6f 09 f3 0f 6f 51 10 66 0f 6f e0 66 0f 61 e4 66 0f 72 e4 10 66 0f fe cc 66 0f 6f e0 66 0f 69 e4 66 0f 72 e4 10 66 0f fe d4 f3 0f 7f 09 f3 0f 7f 51 10 f3 0f 6f 22 66 0f ee e0 f3 0f 7f 22')
      end
      hex('48 83 c0 10 48 83 c1 20 48 83 c2 10 49 83 e8 08');jump(dongu)
      mark(bitti);hex('31 c0');return
    end
    if special=='ekle_relu512_i32_i16' then

      if instruction=='scalar' then generate({'call','__t_ekle_relu512_i32_i16_düz',e[3],type='i64'});return end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local dongu,bitti=label(),label()
      if arm then
        u32(0x4f000404)
        mark(dongu);u32(0xf100207f);patches[#patches+1]={#code,bitti,'cond11'};u32(0x5400000b)
        for _,v in ipairs({0x4cdfa820,0x4cdfa842,0x4ea28400,0x4ea38421,
          0x4ea46400,0x4ea46421,0x4f370400,0x4f370421,0x0e612802,
          0x4e612822,0x3c810402,0xd1002063}) do u32(v) end
        jump(dongu);mark(bitti);u32(0xd2800000);return
      end
      if levels[instruction]>=3 then
        hex('c5 d9 ef e4');mark(dongu);hex('49 83 f8 08');hex('0f 8c');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
        hex('c5 fe 6f 01 c5 fd fe 02 c4 e2 7d 3d c4 c5 fd 72 e0 09 c4 e3 7d 39 c1 01 c5 f9 72 f0 10 c5 f9 72 e0 10 c5 f1 72 f1 10 c5 f1 72 e1 10 c5 f9 6b c1 c5 fa 7f 00 48 83 c1 20 48 83 c2 20 48 83 c0 10 49 83 e8 08')
        jump(dongu);mark(bitti);hex('c5 f8 77 31 c0');return
      end
      hex('66 0f ef e4');mark(dongu);hex('49 83 f8 08');hex('0f 8c');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
      hex('f3 0f 6f 01 f3 0f 6f 49 10 66 0f fe 02 66 0f fe 4a 10 66 0f 6f d0 66 0f 6f d9 66 0f 72 e2 1f 66 0f 72 e3 1f 66 0f df d0 66 0f df d9 66 0f 72 e2 09 66 0f 72 e3 09 66 0f 72 f2 10 66 0f 72 f3 10 66 0f 72 e2 10 66 0f 72 e3 10 66 0f 6b d3 f3 0f 7f 10 48 83 c1 20 48 83 c2 20 48 83 c0 10 49 83 e8 08')
      jump(dongu);mark(bitti);hex('31 c0');return
    end
    if special=='yoğun_i16' then

      if instruction=='scalar' then generate({'call','__t_yoğun_i16_düz',e[3],type='i64'});return end
      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 4 or 9);pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local satir,ic,bitti=label(),label(),label()
      if arm then
        mark(satir);u32(0xf100009f);patches[#patches+1]={#code,bitti,'cond0'};u32(0x54000000)

        for _,v in ipairs({0x6e221c42,0x6e231c63,0x6e241c84,0x6e251ca5,0xaa0103e5,0xaa0303e6}) do u32(v) end
        local kuyruk,son=label(),label()
        mark(ic);u32(0xf10040df);patches[#patches+1]={#code,kuyruk,'cond11'};u32(0x5400000b)
        for _,v in ipairs({0x3cc104a0,0x3cc10441,0x3cc104a6,0x3cc10447,0x0e618002,0x4e618003,0x0e6780c4,0x4e6780c5,0xd10040c6}) do u32(v) end
        jump(ic)
        mark(kuyruk);u32(0xf10020df);patches[#patches+1]={#code,son,'cond11'};u32(0x5400000b)
        for _,v in ipairs({0x3cc104a0,0x3cc10441,0x0e618002,0x4e618003,0xd10020c6}) do u32(v) end
        jump(kuyruk)
        mark(son);for _,v in ipairs({0x4ea38442,0x4ea58484,0x4ea48442,0x4eb1b842,0xbc004402,0xd1000484}) do u32(v) end
        jump(satir)
        mark(bitti);u32(0xd2800000);return
      end
      local vex=levels[instruction]>=2
      mark(satir);hex('4d 85 c9');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
      if instruction=='avx512bw' or instruction=='avx2' or instruction=='avx512' then
        local z=instruction=='avx512bw'

        local k32,k16,k8,son=label(),label(),label(),label()
        mark(satir);hex('4d 85 c9');hex('0f 84');patches[#patches+1]={#code,bitti,'rel32'};u32(0)
        hex(z and '62 f1 ed 48 ef d2 62 f1 e5 48 ef db' or 'c5 ed ef d2 c5 e5 ef db');hex('c5 dd ef e4 c5 d1 ef ed 49 89 ca 4d 89 c3')
        if z then
          mark(k32);hex('49 83 fb 40');hex('0f 8c');patches[#patches+1]={#code,k16,'rel32'};u32(0)
          hex('62 d1 fe 48 6f 02 62 f1 7d 48 f5 02 62 f1 6d 48 fe d0 62 d1 fe 48 6f 4a 01 62 f1 75 48 f5 4a 01 62 f1 65 48 fe d9')
          hex('49 81 c2 80 00 00 00 48 81 c2 80 00 00 00 49 83 eb 40');jump(k32)
          mark(k16);hex('49 83 fb 20');hex('0f 8c');patches[#patches+1]={#code,k8,'rel32'};u32(0)
          hex('62 d1 fe 48 6f 02 62 f1 7d 48 f5 02 62 f1 6d 48 fe d0 49 83 c2 40 48 83 c2 40 49 83 eb 20');jump(k16)
        else
          mark(k32);hex('49 83 fb 20');hex('0f 8c');patches[#patches+1]={#code,k16,'rel32'};u32(0)
          hex('c4 c1 7e 6f 02 c5 fd f5 02 c5 ed fe d0 c4 c1 7e 6f 4a 20 c5 f5 f5 4a 20 c5 e5 fe d9 49 83 c2 40 48 83 c2 40 49 83 eb 20');jump(k32)
          mark(k16);hex('49 83 fb 10');hex('0f 8c');patches[#patches+1]={#code,k8,'rel32'};u32(0)
          hex('c4 c1 7e 6f 02 c5 fd f5 02 c5 ed fe d0 49 83 c2 20 48 83 c2 20 49 83 eb 10');jump(k16)
        end

        if z then
          mark(k8);hex('49 83 fb 10');hex('0f 8c');patches[#patches+1]={#code,son,'rel32'};u32(0)
          hex('c4 c1 7e 6f 02 c5 fd f5 02 c5 dd fe e0 49 83 c2 20 48 83 c2 20 49 83 eb 10');jump(k8)
          mark(son);local s8,fin=label(),label()
          mark(s8);hex('49 83 fb 08');hex('0f 8c');patches[#patches+1]={#code,fin,'rel32'};u32(0)
          hex('c4 c1 7a 6f 02 c5 f9 f5 02 c5 d1 fe e8 49 83 c2 10 48 83 c2 10 49 83 eb 08');jump(s8)
          mark(fin);hex('62 f1 6d 48 fe d3 62 f1 6d 48 fe d4 62 f1 6d 48 fe d5 62 f3 fd 48 3b d0 01 c5 ed fe d0')
        else
          mark(k8);hex('49 83 fb 08');hex('0f 8c');patches[#patches+1]={#code,son,'rel32'};u32(0)
          hex('c4 c1 7a 6f 02 c5 f9 f5 02 c5 d9 fe e0 49 83 c2 10 48 83 c2 10 49 83 eb 08');jump(k8)
          mark(son);hex('c5 ed fe d3 c5 ed fe d4')
        end
        hex('c4 e3 7d 39 d0 01 c5 e9 fe d0 c5 f9 70 c2 4e c5 e9 fe d0 c5 f9 70 c2 b1 c5 e9 fe d0 c5 f9 7e 10 48 83 c0 04 49 ff c9');jump(satir)
        mark(bitti);hex('c5 f8 77 31 c0');return
      end

      hex(vex and 'c5 e9 ef d2 c5 e1 ef db' or '66 0f ef d2 66 0f ef db');hex('49 89 ca 4d 89 c3')
      local kuyruk,son=label(),label()
      mark(ic);hex('49 83 fb 10');hex('0f 8c');patches[#patches+1]={#code,kuyruk,'rel32'};u32(0)
      hex(vex and 'c4 c1 7a 6f 02 c5 fa 6f 0a c5 f9 f5 c1 c5 e9 fe d0 c4 c1 7a 6f 42 10 c5 fa 6f 4a 10 c5 f9 f5 c1 c5 e1 fe d8' or 'f3 41 0f 6f 02 f3 0f 6f 0a 66 0f f5 c1 66 0f fe d0 f3 41 0f 6f 42 10 f3 0f 6f 4a 10 66 0f f5 c1 66 0f fe d8')
      hex('49 83 c2 20 48 83 c2 20 49 83 eb 10');jump(ic)
      mark(kuyruk);hex('49 83 fb 08');hex('0f 8c');patches[#patches+1]={#code,son,'rel32'};u32(0)
      hex(vex and 'c4 c1 7a 6f 02 c5 fa 6f 0a c5 f9 f5 c1 c5 e9 fe d0' or 'f3 41 0f 6f 02 f3 0f 6f 0a 66 0f f5 c1 66 0f fe d0')
      hex('49 83 c2 10 48 83 c2 10 49 83 eb 08');jump(kuyruk)
      mark(son);hex(vex and 'c5 e9 fe d3 c5 f9 70 c2 4e c5 e9 fe d0 c5 f9 70 c2 b1 c5 e9 fe d0 c5 f9 7e 10' or '66 0f fe d3 66 0f 70 c2 4e 66 0f fe d0 66 0f 70 c2 b1 66 0f fe d0 66 0f 7e 10')
      hex('48 83 c0 04 49 ff c9');jump(satir)
      mark(bitti);hex('31 c0');return
    end
    if special=='vektör_topla_i8_i16' or special=='vektör_çıkar_i8_i16' then

      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local sub=special=='vektör_çıkar_i8_i16'
      local profile=(instruction=='avx512' or instruction=='avx512bw') and 'avx2' or instruction
      local scalar,loop,done,bad,exit=label(),label(),label(),label(),label()
      local width=profile=='scalar' and 1 or (profile=='avx2' and 16 or 8)
      local function less(n,l)
        if arm then u32(0xf100007f | (n<<10));condition_branch(l,11,0)
        else hex('49 83 f8');bytes(string.char(n));condition_branch(l,0,0x8c) end
      end
      local function advance(n)
        if arm then
          u32(0x91000000 | ((n*2)<<10));u32(0x91000021 | ((n*2)<<10))
          u32(0x91000042 | (n<<10));u32(0xd1000063 | (n<<10))
        else
          hex('48 83 c0');bytes(string.char(n*2));hex('48 83 c1');bytes(string.char(n*2))
          hex('48 83 c2');bytes(string.char(n));hex('49 83 e8');bytes(string.char(n))
        end
      end
      less(0,bad)
      if width>1 then
        if arm then
          local big=label();mark(big);less(32,loop)
          hex('20 20 40 4c')
          u32(0x3dc00044);u32(0x3dc00445)
          for _,v in ipairs({0x0e241000,0x4e241021,0x0e251042,0x4e251063}) do u32(v | (sub and 0x2000 or 0)) end
          hex('00 20 00 4c');advance(32);jump(big)
        end
        mark(loop);less(width,scalar)
        if arm then
          u32(0x3dc00020);u32(0xfd400041);u32(sub and 0x0e213000 or 0x0e211000);u32(0x3d800000)
        else
          local op=sub and 'f9' or 'fd'
          local enc={
            sse2='f3 0f 6f 01 f3 0f 7e 0a 66 0f 60 c9 66 0f 71 e1 08 66 0f '..op..' c1 f3 0f 7f 00',
            avx='c5 fa 6f 01 c4 e2 79 20 0a c5 f9 '..op..' c1 c5 fa 7f 00',
            avx2='c5 fe 6f 01 c4 e2 7d 20 0a c5 fd '..op..' c1 c5 fe 7f 00'}
          hex(assert(enc[profile]))
        end
        advance(width);jump(loop)
      end
      mark(scalar);less(1,done)
      if arm then
        u32(0x79c00024);u32(0x39c00045);u32(sub and 0x4b050084 or 0x0b050084);u32(0x79000004)
      else hex('44 0f bf 09 44 0f be 12');hex(sub and '45 29 d1' or '45 01 d1');hex('66 44 89 08') end
      advance(1);jump(scalar)
      mark(done);if arm then u32(0xd2800000) else hex('31 c0') end;jump(exit)
      mark(bad);if arm then u32(0x92800000) else hex('48 c7 c0 ff ff ff ff') end
      mark(exit);if not arm and levels[instruction]>=2 then hex('c5 f8 77') end;return
    end
    if special=='vektör_topla_i16_i32' then

      if not e.yb_hazir then
        for _,a in ipairs(e[3]) do generate(a);push() end
        pop(arm and 3 or 8);pop(2);pop(1);pop(0)
      end
      local profile=instruction
      if not arm and (profile=='avx512' or profile=='avx512bw') then profile='avx2' end
      local scalar,loop,done=label(),label(),label()
      local width=profile=='scalar' and 1 or (profile=='avx2' and 8 or 4)
      local function less_than(n,l)
        if arm then u32(0xf100007f | (n<<10));patches[#patches+1]={#code,l,'cond11'};u32(0x5400000b)
        else hex('49 83 f8');bytes(string.char(n));hex('0f 8c');patches[#patches+1]={#code,l,'rel32'};u32(0) end
      end
      local function advance(n)
        if arm then u32(0x91000000 | ((n*4)<<10));u32(0x91000021 | ((n*4)<<10));u32(0x91000042 | ((n*2)<<10));u32(0xd1000063 | (n<<10))
        else hex('48 83 c0');bytes(string.char(n*4));hex('48 83 c1');bytes(string.char(n*4));hex('48 83 c2');bytes(string.char(n*2));hex('49 83 e8');bytes(string.char(n)) end
      end
      if width>1 then
        mark(loop);less_than(width,scalar)
        if arm then

          for _,v in ipairs({0x3dc00020,0xfd400041,0x0e611000,0x3d800000}) do u32(v) end
        else
          local enc={sse2='f3 0f 6f 01 f3 0f 7e 0a 66 0f 61 c9 66 0f 72 e1 10 66 0f fe c1 f3 0f 7f 00',
            avx='c5 fa 6f 01 c5 fa 7e 0a c4 e2 79 23 c9 c5 f9 fe c1 c5 fa 7f 00',
            avx2='c5 fe 6f 01 c4 e2 7d 23 0a c5 fd fe c1 c5 fe 7f 00'}
          hex(assert(enc[profile]))
        end
        advance(width);jump(loop)
      end
      mark(scalar);less_than(1,done)
      if arm then u32(0xb9400024);u32(0x79c00045);u32(0x0b050084);u32(0xb9000004)
      else hex('44 8b 09 44 0f bf 12 45 01 d1 44 89 08') end
      advance(1);jump(scalar);mark(done)
      if not arm and levels[instruction]>=2 then hex('c5 f8 77') end
      if arm then u32(0xd2800000) else hex('31 c0') end;return
    end
    if special=='bit_say' or special=='ilk_bit' then
      if #e[3]~=1 then fail('bit işlemi tek parametre ister') end
      generate(e[3][1])
      if special=='ilk_bit' then
        if arm then u32(0xdac00000);u32(0xdac01000)
        else

          hex('48 0f bc c8 48 c7 c0 40 00 00 00 48 0f 45 c1')
        end
      elseif arm and instruction~='scalar' then
        u32(0x9e670000);u32(0x0e205800);u32(0x0e31b800);u32(0x0e013c00)
      elseif arm then
        u32(0xaa0003e1);u32(0xd2800000);local loop,done=label(),label()
        u32(0xf100003f);patches[#patches+1]={#code,done,'cond0'};u32(0x54000000)
        mark(loop);u32(0xd1000422);u32(0x8a020021);u32(0x91000400);u32(0xf100003f)
        patches[#patches+1]={#code,loop,'cond1'};u32(0x54000001);mark(done)
      else

        hex('48 89 c1 48 d1 e9 48 ba');bytes(string.pack('<i8',0x5555555555555555))
        hex('48 21 d1 48 29 c8 48 89 c1 48 c1 e9 02 48 ba');bytes(string.pack('<i8',0x3333333333333333))
        hex('48 21 d0 48 21 d1 48 01 c8 48 89 c1 48 c1 e9 04 48 01 c8 48 ba');bytes(string.pack('<i8',0x0f0f0f0f0f0f0f0f))
        hex('48 21 d0 48 ba');bytes(string.pack('<i8',0x0101010101010101))
        hex('48 0f af c2 48 c1 e8 38')
      end
      return
    end
    if special=='nokta8_i16' then
      if #e[3]~=2 then fail('nokta8_i16 iki adres ister') end
      generate(e[3][1]);push();generate(e[3][2])
      if arm and instruction=='scalar' then
        u32(0xaa0003e1);pop(0);u32(0xaa0003e2);u32(0xd2800000)
        for i=0,7 do
          u32(0x79800043 | (i<<10));u32(0x79800024 | (i<<10));u32(0x9b047c63);u32(0x8b030000)
        end
      elseif arm then
        u32(0xaa0003e1);pop(0)
        for _,v in ipairs({0x3dc00000,0x3dc00021,0x0e61c002,0x4e61c003,0x4ea02842,0x4ea06862,0x5ef1b840,0x9e660000}) do u32(v) end
      elseif instruction~='scalar' then
        hex('48 89 c1');pop(0)
        local dot={
          sse2='f3 0f 6f 00 f3 0f 6f 09 66 0f 6f d0 66 0f d5 c1 66 0f e5 d1 66 0f 6f c8 66 0f 61 c2 66 0f 69 ca 66 0f 6f d0 66 0f 72 e2 1f 66 0f 6f d8 66 0f 62 c2 66 0f 6a da 66 0f d4 c3 66 0f 6f d1 66 0f 72 e2 1f 66 0f 6f d9 66 0f 62 ca 66 0f 6a da 66 0f d4 cb 66 0f d4 c1 66 0f 6f c8 66 0f 73 d9 08 66 0f d4 c1 66 48 0f 7e c0',
          avx='c5 fa 6f 00 c5 fa 6f 09 c5 f9 6f d0 c5 f9 d5 c1 c5 e9 e5 d1 c5 f9 6f c8 c5 f9 61 c2 c5 f1 69 ca c5 f9 6f d0 c5 e9 72 e2 1f c5 f9 6f d8 c5 f9 62 c2 c5 e1 6a da c5 f9 d4 c3 c5 f9 6f d1 c5 e9 72 e2 1f c5 f9 6f d9 c5 f1 62 ca c5 e1 6a da c5 f1 d4 cb c5 f9 d4 c1 c5 f9 6f c8 c5 f1 73 d9 08 c5 f9 d4 c1 c4 e1 f9 7e c0 c5 f8 77',
          avx2='c4 e2 7d 23 00 c4 e2 7d 23 09 c4 e2 7d 40 c1 c4 e3 7d 39 c1 01 c4 e2 7d 25 d0 c4 e2 7d 25 d9 c5 ed d4 d3 c4 e3 7d 39 d3 01 c5 e9 d4 d3 c5 e1 73 da 08 c5 e9 d4 d3 c4 e1 f9 7e d0 c5 f8 77',
        };hex(dot[(instruction=='avx512' or instruction=='avx512bw') and 'avx2' or instruction])
      else
        hex('48 89 c1');pop(0);hex('49 89 c2 45 31 c0')
        for i=0,7 do
          hex('49 0f bf 42');bytes(string.char(i*2));hex('48 0f bf 51');bytes(string.char(i*2))
          hex('48 0f af c2 49 01 c0')
        end
        hex('4c 89 c0')
      end
      return
    end
    if special=='dizi' then
      local count=e.count or (e[3][1] and (e[3][1].constant or (e[3][1][1]=='num' and e[3][1][2])))
      if #e[3]~=1 or not count or count<=0 or count>16777216 then fail('dizi 1..16777216 arasında sabit bayt boyutu ister') end
      local size=(count+7)//8;local base=slots;slots=slots+size
      if slots>2097152 then fail('16 MiB yığın çerçevesi sınırı') end
      if arm then frame_address(base*8) else hex('48 8d 85');u32(windows and base*8 or -slots*8) end
      return
    end
    local memtype,memop=special:match('^([iuf]%d+)_(%a+)$')
    if special=='adres_oku' or special=='adres_yaz' then memtype='adres';memop=special:sub(7) end
    if (numeric[memtype] or memtype=='adres') and (memop=='oku' or memop=='yaz') then
      local write=memop=='yaz'
      if arm and optimization>0 and (H.arm_memory_access(e[3],write,memtype) or H.arm_indexed_access(e[3],write,memtype)) then return end
      H.discard=false;memory_arguments(e[3],write)
      local width=memtype=='adres' and 64 or numeric[memtype][1]
      if arm then
        local stores={[8]=0x38216802,[16]=0x78217802,[32]=0xb8217802,[64]=0xf8217802}
        u32(write and stores[width] or (H.arm_load_reg[memtype] | (1<<16)))
        if write then u32(0xaa0203e0) end;return
      else
        local loads={[8]='48 0f b6 04 08',[16]='48 0f b7 04 48',[32]='8b 04 88',[64]='48 8b 04 c8'}
        local stores={[8]='88 14 08',[16]='66 89 14 48',[32]='89 14 88',[64]='48 89 14 c8'}
        hex(write and stores[width] or loads[width])
      end
      if write then if arm then u32(0xaa0203e0) else hex('48 89 d0') end end
      normalize(memtype);return
    end
    local memory={bayt_oku={2,false,false},bayt_yaz={3,true,false},['sayı_oku']={2,false,true},['sayı_yaz']={3,true,true}}
    if memory[special] then
      local m=memory[special];if #e[3]~=m[1] then fail('bellek işlemi parametre sayısı') end
      if arm and optimization>0 and (H.arm_memory_access(e[3],m[2],m[3] and 'i64' or 'u8') or H.arm_indexed_access(e[3],m[2],m[3] and 'i64' or 'u8')) then return end
      H.discard=false
      memory_arguments(e[3],m[2])
      if arm then
        local instruction=m[3] and (m[2] and 0xf8217802 or 0xf8617800) or (m[2] and 0x38216802 or 0x38616800)
        u32(instruction)
      else
        if m[3] then hex(m[2] and '48 89 14 c8' or '48 8b 04 c8')
        else hex(m[2] and '88 14 08' or '48 0f b6 04 08') end
      end
      if m[2] then if arm then u32(0xaa0203e0) else hex('48 89 d0') end end
      return
    end
    local indirect=e[2]=='çağır'
    local intrinsic=builtins[e[2]];local count=indirect and (#e[3]-1) or (intrinsic and intrinsic[2] or signatures[e[2]])
    if count==nil then fail('tanımsız işlev: '..e[2]) end
    if indirect then generate(e[3][1]);push() end
    local args={};for i=indirect and 2 or 1,#e[3] do args[#args+1]=e[3][i] end
    if not arm and optimization>0 and not indirect and count==#args and not (intrinsic and intrinsic[5]=='float64') then
      local regs=windows and {1,2,8,9} or {7,6,2,1,8,9}

      local last=0;for i,a in ipairs(args) do if not simple(a) then last=i end end
      if count<=#regs and last<count then
        for i=1,last do generate(args[i]);push() end
        for i=last,1,-1 do pop(regs[i]) end
        for i=last+1,count do generate_leaf(args[i],regs[i]) end
        if windows then hex('48 83 ec 20') end
        if intrinsic then
          external(intrinsic[1])
          if intrinsic[5]=='int' then hex('48 98') elseif intrinsic[5]=='void' then hex('31 c0') end
          normalize(intrinsic[4])
        else jump(entries[e[2]],false,true) end
        if windows then hex('48 83 c4 20') end
        return
      end
    end
    if arm and optimization>0 and not indirect and count==#args and count<=6 and not (intrinsic and intrinsic[5]=='float64') then

      local last=0;for i,a in ipairs(args) do if not H.pure(a) then last=i end end
      if last<count then
        local holds={}
        for i=1,last do generate(args[i]);push() end
        for i=last+1,count do
          local a=args[i]
          if simple(a) then holds[i]=false else generate(a);move_register(2+i,0);holds[i]=2+i end
        end
        for i=last,1,-1 do pop(i-1) end
        for i=last+1,count do if holds[i] then move_register(i-1,holds[i]) end end
        for i=last+1,count do if holds[i]==false then generate_leaf(args[i],i-1) end end
        if intrinsic then
          external(intrinsic[1])
          if intrinsic[5]=='int' then u32(0x93407c00) elseif intrinsic[5]=='void' then u32(0xd2800000) end
          normalize(intrinsic[4])
        else jump(entries[e[2]],false,true) end
        return
      end
    end
    for _,a in ipairs(args) do generate(a);push() end
    local xregs=windows and {1,2,8,9} or {7,6,2,1,8,9}
    local register_count=arm and 8 or #xregs
    local extra=math.max(0,count-register_count)
    local shadow=((windows and 32 or 0)+extra*8+15)//16*16

    if arm then if shadow>0 then u32(0xd10003ff | (shadow<<10)) end
    elseif shadow>0 then hex('48 81 ec');u32(shadow) end
    for i=1,count do
      local offset=shadow+(count-i)*16
      if i<=register_count then
        local reg=arm and (i-1) or xregs[i]
        if arm then u32(0xf94003e0 | ((offset//8)<<10) | reg)
        else bytes(string.char(0x48 | (reg>=8 and 4 or 0),0x8b,0x84 | ((reg&7)<<3),0x24));u32(offset) end
      else
        local dest=(windows and 32 or 0)+(i-register_count-1)*8
        if arm then u32(0xf94003e9 | ((offset//8)<<10));u32(0xf90003e9 | ((dest//8)<<10))
        else hex('4c 8b 94 24');u32(offset);hex('4c 89 94 24');u32(dest) end
      end
    end
    if indirect then
      local offset=shadow+count*16
      if arm then u32(0xf94003f0 | ((offset//8)<<10)) else hex('4c 8b 9c 24');u32(offset) end
    end
    if intrinsic then
      if intrinsic[5]=='float64' then for i=1,count do fp_in('f64',i-1,arm and i-1 or xregs[i]) end end
      external(intrinsic[1])
      if intrinsic[5]=='float64' then fp_out('f64') end
      if intrinsic[5]=='int' then
        if arm then u32(0x93407c00) else hex('48 98') end
      elseif intrinsic[5]=='void' then
        if arm then u32(0xd2800000) else hex('31 c0') end
      end
      normalize(intrinsic[4])
    elseif indirect then if arm then u32(0xd63f0200) else hex('41 ff d3') end
    else jump(entries[e[2]],false,true) end
    local release=shadow+(count+(indirect and 1 or 0))*16
    if release>0 then if arm then u32(0x910003ff | (release<<10)) else hex('48 81 c4');u32(release) end end
  elseif (op=='&&' or op=='||') and arm and optimization>0 then
    local f,done=label(),label();H.branch_false(e,f)
    generate({'num',1});jump(done);mark(f);generate({'num',0});mark(done);return
  elseif op=='&&' or op=='||' then
    local alternate,done=label(),label()
    generate(e[2]);jump(alternate,true)
    if op=='||' then generate({'num',1}) else generate({'!=',e[3],{'num',0}}) end
    jump(done);mark(alternate)
    if op=='&&' then generate({'num',0}) else generate({'!=',e[3],{'num',0}}) end
    mark(done)
  else

    if optimization>0 and (op=='/' or op=='%') and not (numeric[e.operand] or {}).float and pure_constant(e[3]) then
      local ok,d=pcall(constant_eval,e[3]);local shift
      local signed=not e.operand or numeric[e.operand][2]
      if ok and d~=0 and (not signed or d>0) and (d & (d-1))==0 then
        for i=0,63 do if d==(1<<i) then shift=i;break end end
      end

      if arm and signed and shift and shift>0 then shift=nil end
      if shift then
        generate(e[2])
        if shift==0 then if op=='%' then generate({'num',0}) end
        elseif not signed then
          if arm then
            u32(op=='/' and (0xd340fc00 | (shift<<16)) or (0xd3400000 | ((shift-1)<<10)))
          elseif op=='/' then hex('48 c1 e8');bytes(string.char(shift))
          else immediate((1<<shift)-1,1);hex('48 21 c8') end
        elseif arm then
          if op=='%' then move_register(2,0) end
          u32(0x937ffc01);u32(0xd340fc21 | ((64-shift)<<16));u32(0x8b010000)
          u32(0x9340fc00 | (shift<<16))
          if op=='%' then u32(0xcb000040 | (shift<<10)) end
        else
          if op=='%' then move_register(1,0) end
          hex('48 89 c2 48 c1 fa 3f 48 c1 ea');bytes(string.char(64-shift));hex('48 01 d0 48 c1 f8');bytes(string.char(shift))
          if op=='%' then hex('48 c1 e0');bytes(string.char(shift));hex('48 29 c1 48 89 c8') end
        end
        normalize(e.type);return
      end
    end
    if arm and optimization>0 and (H.arm_ops[op] or H.signed_cond[op]) and not H.is_float(e) then H.emit_arm_binary(e,0);return end
    generate(e[2])
    if optimization>0 and simple(e[3]) then
      if arm then move_register(1,0);generate_leaf(e[3],0) else generate_leaf(e[3],1) end
    elseif optimization>0 and temp_depth<#temp_registers and scratch_safe(e[3]) then
      temp_depth=temp_depth+1;local r=temp_registers[temp_depth];move_register(r,0);generate(e[3])
      if arm then move_register(1,r) else move_register(1,0);move_register(0,r) end
      temp_depth=temp_depth-1
    else
      push();generate(e[3]);if arm then pop(1) else move_register(1,0);pop(0) end
    end
    if (numeric[e.operand] or {}).float then
      local t=e.operand;fp_in(t,0,arm and 1 or 0);fp_in(t,1,arm and 0 or 1)
      local arithmetic={['+']=0x28,['-']=0x38,['*']=0x08,['/']=0x18}
      if arithmetic[op] then
        if arm then u32((t=='f32' and 0x1e210000 or 0x1e610000) | (arithmetic[op]<<8))
        else hex(t=='f32' and 'f3 0f' or 'f2 0f');bytes(string.char(({['+']=0x58,['-']=0x5c,['*']=0x59,['/']=0x5e})[op],0xc1)) end
        fp_out(t)
      else
        fp_compare(t)
        if arm then
          local cond=({['==']=0,['!=']=1,['<']=4,['<=']=9,['>']=12,['>=']=10})[op]
          u32(0x9a9f07e0 | ((cond~1)<<12))
        else
          hex('0f');bytes(string.char(({['==']=0x94,['!=']=0x95,['<']=0x92,['<=']=0x96,['>']=0x97,['>=']=0x93})[op],0xc0))
          if op=='!=' then hex('0f 9a c2 08 d0')
          elseif op=='==' or op=='<' or op=='<=' then hex('0f 9b c2 20 d0') end
          hex('48 0f b6 c0')
        end
      end
      return
    end
    if op=='>>' and e.operand and numeric[e.operand] and numeric[e.operand][1]<64 then
      local bits=numeric[e.operand][1]
      if arm then u32(0xd3400021 | ((bits-1)<<10)) else normalize('u'..bits) end
    end
    if op=='/' or op=='%' then
      local signed=not e.operand or numeric[e.operand][2]
      if arm then
        local c=H.leaf_constant(e[3])
        if not (c and c~=0) then
          local valid=label();u32(0xf100001f);patches[#patches+1]={#code,valid,'cond1'};u32(0x54000001)
          u32(0xd4200000);mark(valid)
        end
        u32(signed and 0x9ac00c22 or 0x9ac00822)
        if op=='/' then u32(0xaa0203e0) else u32(0x9b008440) end
      else
        local regular,done=label(),label()
        if signed then
          hex('48 83 f9 ff 0f 85');patches[#patches+1]={#code,regular,'rel32'};u32(0)
          hex(op=='/' and '48 f7 d8' or '31 c0');jump(done);mark(regular)
          hex('48 99 48 f7 f9')
        else hex('31 d2 48 f7 f1') end
        if op=='%' then hex('48 89 d0') end;mark(done)
      end
      normalize(e.type);return
    end
    if arm then
      local ops={['+']=0x8b000020,['-']=0xcb000020,['*']=0x9b007c20,['&']=0x8a000020,['|']=0xaa000020,['^']=0xca000020,['<<']=0x9ac02020,['>>']=0x9ac02420}
      if ops[op] then u32(ops[op]) else
        u32(0xeb00003f)
        local inverse={['==']=1,['!=']=0,['<']=10,['>=']=11,['>']=13,['<=']=12}
        if e.operand and numeric[e.operand] and not numeric[e.operand][2] then
          inverse={['==']=1,['!=']=0,['<']=2,['>=']=3,['>']=9,['<=']=8}
        end
        u32(0x9a9f07e0 | (assert(inverse[op])<<12))
      end
    else
      local ops={['+']='48 01 c8',['-']='48 29 c8',['*']='48 0f af c1',['&']='48 21 c8',['|']='48 09 c8',['^']='48 31 c8',['<<']='48 d3 e0',['>>']='48 d3 e8'}
      if ops[op] then hex(ops[op]) else
        local conditions={['==']=0x94,['!=']=0x95,['<']=0x9c,['>=']=0x9d,['>']=0x9f,['<=']=0x9e}
        if e.operand and numeric[e.operand] and not numeric[e.operand][2] then conditions={['==']=0x94,['!=']=0x95,['<']=0x92,['>=']=0x93,['>']=0x97,['<=']=0x96} end
        hex('48 39 c8 0f');bytes(string.char(assert(conditions[op])));hex('c0 48 0f b6 c0')
      end
    end
  end
  normalize(e.type)
end
local finish;local loops={};local peak_slots=0;local cleanups={}
local emit_block
local function emit_cleanups(first)
  for i=#cleanups,first,-1 do
    local list=cleanups[i]
    for j=#list,1,-1 do emit_block(list[j]) end
  end
end
emit_block=function(b)
  scopes[#scopes+1]={};cleanups[#cleanups+1]={}
  for _,n in ipairs(b) do
    local k=n[1]
    if k=='scope' then emit_block(n[2])
    elseif k=='defer' then local list=cleanups[#cleanups];list[#list+1]=n[2]
    elseif k=='update' then
      local lhs,t=n[2],n.type
      if lhs[1]=='var' and not lhs.global then
        local b=lhs.binding
        if arm and optimization>0 and b and b.reg and H.arm_ops[n[4]] and not numeric[t].float then H.emit_arm_binary({n[4],lhs,n[3],type=t,operand=t},b.reg)
        else generate({n[4],lhs,n[3],type=t,operand=t});local_save(b) end
      else
        local base=slots;local p={slot=slots+1};local old={slot=slots+2};local value={slot=slots+3};slots=slots+3
        if slots>2097152 then fail('16 MiB yığın çerçevesi aşıldı') end
        local addr
        if lhs.global then addr={'global_address',lhs.global}
        elseif lhs[1]=='field' then addr=field_address(lhs)
        else addr={'call','adres_ekle',{lhs[2],{'*',lhs[3],{'num',numeric[t][1]//8}}}} end
        local function v(b,ty) return {'var','',binding=b,type=ty} end
        local arithmetic={['+']=0x8b020021,['-']=0xcb020021,['&']=0x8a020021,['|']=0xaa020021,['^']=0xca020021}
        if arm and optimization>0 and H.arm_ops[n[4]] and numeric[t] and not numeric[t].float and H.arm_update(addr,n[3],n[4],t) then
        elseif optimization>0 and arithmetic[n[4]] and simple(n[3]) and numeric[t] and not numeric[t].float then

          generate(addr);local bits=numeric[t][1]
          if arm then
            u32(({[8]=0x39400001,[16]=0x79400001,[32]=0xb9400001,[64]=0xf9400001})[bits])
            generate_leaf(n[3],2);u32(arithmetic[n[4]])
            u32(({[8]=0x39000001,[16]=0x79000001,[32]=0xb9000001,[64]=0xf9000001})[bits])
          else
            generate_leaf(n[3],1)
            if bits==16 then hex('66') elseif bits==64 then hex('48') end
            bytes(string.char(({['+']=0x01,['-']=0x29,['&']=0x21,['|']=0x09,['^']=0x31})[n[4]]-(bits==8 and 1 or 0),0x08))
          end
        else
          generate(addr);local_save(p)
          generate({'call',t..'_oku',{v(p,'adres'),{'num',0}},type=t});local_save(old)
          generate({n[4],v(old,t),n[3],type=t,operand=t});local_save(value)
          generate({'call',t..'_yaz',{v(p,'adres'),{'num',0},v(value,t)},type=t})
        end
        peak_slots=math.max(peak_slots,slots);if slots==base+3 then slots=base end
      end
    elseif k=='kır' then local loop=loops[#loops];emit_cleanups(loop[3]+1);jump(loop[2])
    elseif k=='sürdür' then local loop=loops[#loops];emit_cleanups(loop[3]+1);jump(loop[1])
    elseif k=='store' then H.discard=arm and optimization>0;generate(memory_node(n[2],n[3]));H.discard=false
    elseif k==':=' then
      if scopes[#scopes][n[2]] then fail('yinelenen değişken: '..n[2]) end
      local b=n.binding
      if arm and optimization>0 and b.reg and (H.arm_ops[n[3][1]] or H.signed_cond[n[3][1]]) and not H.is_float(n[3]) then H.emit_arm_binary(n[3],b.reg);n.direct=true
      elseif arm and optimization>0 and b.reg and H.leaf_register(n[3]) then move_register(b.reg,H.leaf_register(n[3]));n.direct=true
      elseif arm and optimization>0 and b.reg and H.load_into(n[3],b.reg) then n.direct=true
      else generate(n[3]) end
      if not b.reg then slots=slots+1;b.slot=slots end
      if slots>2097152 then fail('16 MiB yığın çerçevesi aşıldı') end
      scopes[#scopes][n[2]]=b;if not n.direct then local_save(b) end
    elseif k=='=' then
      if n.global then generate({'call',(numeric[n.global.type] and n.global.type or 'adres')..'_yaz',{{'global_address',n.global},{'num',0},n[3]},type=n.global.type})
      else
        local s=n.binding or lookup(n[2])
        if arm and optimization>0 and type(s)=='table' and s.reg and (H.arm_ops[n[3][1]] or H.signed_cond[n[3][1]]) and not H.is_float(n[3]) then H.emit_arm_binary(n[3],s.reg)
        elseif arm and optimization>0 and type(s)=='table' and s.reg and H.leaf_register(n[3]) then move_register(s.reg,H.leaf_register(n[3]))
        elseif arm and optimization>0 and type(s)=='table' and s.reg and H.load_into(n[3],s.reg) then
        else generate(n[3]);local_save(s) end
      end
    elseif k=='eval' then generate(n[2])
    elseif k=='return' then
      generate(n[2]);local active=false;for _,list in ipairs(cleanups) do if #list>0 then active=true end end
      if active then
        local base=slots;slots=slots+1;if slots>2097152 then fail('16 MiB yığın çerçevesi aşıldı') end
        local saved={slot=slots};local_save(saved);emit_cleanups(1);local_load(saved)
        peak_slots=math.max(peak_slots,slots);if slots==base+1 then slots=base end
      end
      jump(finish)
    elseif k=='if' then
      local no,done=label(),label();H.branch_false(n[2],no);emit_block(n[3]);jump(done);mark(no)
      if n[4] then emit_block(n[4]) end;mark(done)
    elseif k=='while' then
      local start,step,done=label(),label(),label();loops[#loops+1]={step,done,#cleanups}
      if optimization>0 then

        local body,cond=label(),label();jump(cond);mark(body);emit_block(n[3]);mark(step);if n.step then emit_block(n.step) end
        mark(cond);H.branch_true(n[2],body);mark(done)
      else
        mark(start);H.branch_false(n[2],done);emit_block(n[3]);mark(step);if n.step then emit_block(n.step) end;jump(start);mark(done)
      end
      loops[#loops]=nil
    end
  end
  emit_cleanups(#cleanups);cleanups[#cleanups]=nil;scopes[#scopes]=nil
end
local unwind={}
if arka=='yeni' then
  local HD=arm and Y.arm_hedef() or Y.x64_hedef(windows)
  local E={
    u32=u32,hex=hex,bytes=bytes,label=label,mark=mark,jump=jump,
    immediate=immediate,normalize=normalize,external=external,
    entries=entries,data=data,builtins=builtins,
    global_relocations=global_relocations,
    unwind=unwind,
    kod_boy=function() return #code end,

    hiza=function(n,ust)
      if arm then
        local d=(-#code)%n
        if d<=ust then for _=1,d//4 do u32(0xd503201f) end end
      else
        Y.hizalar[#Y.hizalar+1]={#code,n,ust}
      end
    end,
    cbnz=function(r,l) patches[#patches+1]={#code,l,'cbnz'};u32(0xb5000000|r) end,
    kosul_dal=function(l,c) condition_branch(l,c,0) end,
    kosul_dal64=function(l,c) condition_branch(l,0,0x80|c) end,
    mantik_anlik=H.encode_logical,
    generate=function(e) return generate(e) end,
    opt=optimization,hata=fail}
  for _,fn in ipairs(functions) do
    location=fn.line or location
    fn.ir.giris_etiketi=entries[fn[1]]
    Y.derle(fn,E,HD)
  end
else
for _,fn in ipairs(functions) do
  local planned_frame=0
  local checkpoint={#code,#patches,#data,#relocations,#global_relocations,serial}
  for pass=1,2 do
  local function_start=#code
  mark(entries[fn[1]]);slots=#fn.saved;peak_slots=0;scopes={{}};finish=label()
  local frame_at,allocation_end,frame_end;local stack_parameters={}
  fn.bare=arm and fn.leaf and optimization>0 and planned_frame==0 and #fn.saved==0
  if fn.bare then

  elseif arm then
    u32(0xa9bf7bfd)
    if planned_frame>4096 then

      u32(0x910003f0);u32(0xd2800011 | ((planned_frame//4096)<<5))
      local probe=label();mark(probe);u32(0xd1400610);u32(0x3940021f);u32(0xf1000631);condition_branch(probe,1,0)
      if planned_frame%4096~=0 then u32(0xd1000210 | ((planned_frame%4096)<<10));u32(0x3940021f) end

      u32(0x910003f1)
      u32(0xd14003ff | ((planned_frame//4096)<<10));u32(0xd10003ff | ((planned_frame%4096)<<10))
      u32(0x910003fd)
    else frame_at=#code;u32(0);u32(0x910003fd) end
  else
    hex('55');if not windows then hex('48 89 e5') end
    if planned_frame>4096 then
      hex('49 89 e3 b8');u32(planned_frame)
      local probe,last=label(),label();mark(probe)
      hex('48 3d 00 10 00 00');condition_branch(last,0,0x82)
      hex('49 81 eb 00 10 00 00 41 f6 03 00 48 2d 00 10 00 00');jump(probe)
      mark(last);hex('49 29 c3 41 f6 03 00')
    end
    hex('48 81 ec');frame_at=#code;u32(0);allocation_end=#code-function_start
    if windows then hex('48 89 e5');frame_end=#code-function_start end
  end
  local saved_offsets={}
  for i,r in ipairs(fn.saved) do
    if arm and i%2==1 and fn.saved[i+1] then u32(0xa90003a0 | ((i-1)<<15) | (fn.saved[i+1]<<10) | r)
    elseif arm and i%2==1 then u32(0xf90003a0 | ((i-1)<<10) | r)
    elseif not arm then bytes(string.char(0x48 | (r>=8 and 4 or 0),0x89,0x85 | ((r&7)<<3)));u32(windows and (i-1)*8 or -i*8) end
    saved_offsets[#saved_offsets+1]={r,(i-1)*8,#code-function_start}
  end
  local prologue_size=#code-function_start
  for i,param in ipairs(fn[2]) do
    if scopes[1][param] then fail('yinelenen parametre: '..param) end
    local b=fn.params[i];if not b.reg then slots=slots+1;b.slot=slots end;scopes[1][param]=b
    if arm and i<=8 then
      if b.reg then move_register(b.reg,i-1) else move_register(0,i-1);local_save(b) end
    elseif arm then
      if planned_frame>4096 then u32(0xf9400220 | (((16+(i-9)*8)//8)<<10))
      else stack_parameters[#stack_parameters+1]={#code,16+(i-9)*8};u32(0) end
      local_save(b)
    else
      local regs=windows and {1,2,8,9} or {7,6,2,1,8,9};local r=regs[i]
      if r then bytes(string.char(r>=8 and 0x4c or 0x48,0x89,0xc0 | ((r&7)<<3)))
      else hex('48 8b 85');stack_parameters[#stack_parameters+1]={#code,windows and (48+(i-5)*8) or (16+(i-7)*8)};u32(0) end
      local_save(b)
    end
  end
  emit_block(fn[3]);assert(temp_depth==0);generate({'num',0});mark(finish)
  local frame=(math.max(slots,peak_slots)*8+15)//16*16
  if frame>16773120 then fail('yığın çerçevesi en fazla 16 MiB - 4 KiB olabilir') end
  if pass==1 then
    planned_frame=frame
    for j,t in ipairs({code,patches,data,relocations,global_relocations}) do for i=#t,checkpoint[j]+1,-1 do t[i]=nil end end
    for i=checkpoint[6]+1,serial do labels[i]=nil end;serial=checkpoint[6]
  else
  assert(frame==planned_frame,'yığın boyutlandırma geçişleri uyuşmuyor')
  local immediate=frame==4096 and 0x400400 or (frame<<10)
  local reserve=arm and (0xd10003ff | immediate) or frame
  local encoded=string.pack('<I4',reserve)
  if frame_at then for i=1,4 do code[frame_at+i]=encoded:byte(i) end end
  for _,p in ipairs(stack_parameters) do
    local off=(arm or windows) and frame+p[2] or p[2]
    local value=string.pack('<I4',arm and (0xf94003a0 | ((off//8)<<10)) or off);for i=1,4 do code[p[1]+i]=value:byte(i) end
  end
  for i,r in ipairs(fn.saved) do
    if arm and i%2==1 and fn.saved[i+1] then u32(0xa94003a0 | ((i-1)<<15) | (fn.saved[i+1]<<10) | r)
    elseif arm and i%2==1 then u32(0xf94003a0 | ((i-1)<<10) | r)
    elseif not arm then bytes(string.char(0x48 | (r>=8 and 4 or 0),0x8b,0x85 | ((r&7)<<3)));u32(windows and (i-1)*8 or -i*8) end
  end
  if fn.bare then assert(frame==0);u32(0xd65f03c0)
  elseif arm then
    if frame>4096 then u32(0x914003ff | ((frame//4096)<<10));u32(0x910003ff | ((frame%4096)<<10))
    else u32(0x910003ff | immediate) end;u32(0xa8c17bfd);u32(0xd65f03c0)
  elseif windows then hex('48 8d a5');u32(frame);hex('5d c3')
  else hex('c9 c3') end
  unwind[#unwind+1]={function_start,#code,frame,saved_offsets,prologue_size,allocation_end,frame_end}
end
  end
end
end
local process_entry
if linux then
  process_entry=#code
  if arm then
    u32(0xd280001d);u32(0xd280001e);u32(0xaa0003e5)
    u32(0xf94003e1);u32(0x910023e2);u32(0x910003e6)
    address(entries[main_entry]);u32(0xd2800003);u32(0xd2800004)
  else
    hex('31 ed 49 89 d1 5e 48 89 e2 48 83 e4 f0 50 54 45 31 c0 31 c9')
    address(entries[main_entry]);hex('48 89 c7')
  end
  external(builtins.__t_libc_start[1])
  if arm then u32(0xd4200000) else hex('0f 0b') end
end
for _,d in ipairs(data) do mark(d[1]);bytes(d[2]) end

Y.yeni_konum=function(x) return x end
function Y.kisalt()
  if arm or os.getenv('YB_KISALT_YOK') then return end
  local ogeler={}
  for _,p in ipairs(patches) do
    if p[4]=='jmp' then
      ogeler[#ogeler+1]={anahtar=(p[1]-1)*2+1,tur='d',bas=p[1]-1,uzun=5,kisa=2,
                         op=0xeb,p=p,kisa_mi=false}
    elseif p[4]=='jcc' then
      ogeler[#ogeler+1]={anahtar=(p[1]-2)*2+1,tur='d',bas=p[1]-2,uzun=6,kisa=2,
                         op=0x70|(code[p[1]]&0x0f),p=p,kisa_mi=false}
    end
  end
  for _,h in ipairs(Y.hizalar) do
    ogeler[#ogeler+1]={anahtar=h[1]*2-1,tur='h',at=h[1],n=h[2],ust=h[3],dolgu=0}
  end
  if #ogeler==0 then return end
  table.sort(ogeler,function(a,b) return a.anahtar<b.anahtar end)

  local kum={}
  local function kumule()
    local t=0
    for k,o in ipairs(ogeler) do
      if o.tur=='d' then t=t+(o.kisa_mi and (o.kisa-o.uzun) or 0)
      else t=t+o.dolgu end
      kum[k]=t
    end
  end
  local function kaydir(anahtar)
    local lo,hi,r=1,#ogeler,0
    while lo<=hi do
      local m=(lo+hi)//2
      if ogeler[m].anahtar<anahtar then r=m; lo=m+1 else hi=m-1 end
    end
    return r>0 and kum[r] or 0
  end
  local function hiza_payi(a,b)
    if a>b then a,b=b,a end
    local n=0
    for _,o in ipairs(ogeler) do
      if o.tur=='h' and o.at>a and o.at<b then n=n+o.n-1 end
    end
    return n
  end
  local function hizalari_hesapla()
    kumule()
    for _,o in ipairs(ogeler) do
      if o.tur=='h' then
        local y=o.at+kaydir(o.anahtar)
        local d=(-y)%o.n
        o.dolgu=(d<=o.ust) and d or 0
        kumule()
      end
    end
  end

  hizalari_hesapla()
  local tur=0
  repeat
    local degisti=false
    tur=tur+1
    kumule()
    for _,o in ipairs(ogeler) do
      if o.tur=='d' and not o.kisa_mi then
        local hedef=assert(labels[o.p[2]])
        local yb=o.bas+kaydir(o.anahtar)
        local yh=hedef+kaydir(hedef*2)
        local uz=yh-(yb+o.kisa)
        local pay=hiza_payi(o.bas,hedef)
        if uz-pay>=-128 and uz+pay<=127 then
          o.kisa_mi=true; degisti=true; kumule()
        end
      end
    end
  until not degisti or tur>20
  hizalari_hesapla()

  local nop={[1]={0x90},[2]={0x66,0x90},[3]={0x0f,0x1f,0x00},
             [4]={0x0f,0x1f,0x40,0x00},[5]={0x0f,0x1f,0x44,0x00,0x00},
             [6]={0x66,0x0f,0x1f,0x44,0x00,0x00},
             [7]={0x0f,0x1f,0x80,0x00,0x00,0x00,0x00},
             [8]={0x0f,0x1f,0x84,0x00,0x00,0x00,0x00,0x00},
             [9]={0x66,0x0f,0x1f,0x84,0x00,0x00,0x00,0x00,0x00}}
  local yeni={}
  local i=1
  local kisaltilan=0
  for _,o in ipairs(ogeler) do
    local son=(o.tur=='d') and o.bas or o.at
    while i<=son do yeni[#yeni+1]=code[i]; i=i+1 end
    if o.tur=='h' then
      local kaldi=o.dolgu
      while kaldi>0 do
        local k=kaldi>9 and 9 or kaldi
        for _,v in ipairs(nop[k]) do yeni[#yeni+1]=v end
        kaldi=kaldi-k
      end
    elseif o.kisa_mi then
      yeni[#yeni+1]=o.op; yeni[#yeni+1]=0
      o.yeni_at=#yeni-1
      kisaltilan=kisaltilan+1
      i=o.bas+o.uzun+1
    else
      for j=1,o.uzun do yeni[#yeni+1]=code[o.bas+j] end
      o.yeni_at=#yeni-4
      i=o.bas+o.uzun+1
    end
  end
  while i<=#code do yeni[#yeni+1]=code[i]; i=i+1 end

  for _,p in ipairs(patches) do
    if p[4]~='jmp' and p[4]~='jcc' then p[1]=p[1]+kaydir(p[1]*2) end
  end
  for _,o in ipairs(ogeler) do
    if o.tur=='d' then o.p[1]=o.yeni_at; if o.kisa_mi then o.p[3]='rel8' end end
  end
  for l,v in pairs(labels) do labels[l]=v+kaydir(v*2) end
  for _,r in ipairs(relocations) do r[1]=r[1]+kaydir(r[1]*2) end
  for _,r in ipairs(global_relocations) do r[1]=r[1]+kaydir(r[1]*2) end
  code=yeni

  Y.yeni_konum=function(x) return x+kaydir(x*2) end
  if os.getenv('YB_SAY') then
    io.stderr:write(string.format('kisaltilan dal %d/%d, kod %d bayt\n',
      kisaltilan,#ogeler,#code))
  end
end
Y.kisalt()

if process_entry then process_entry=Y.yeni_konum(process_entry) end
for _,u in ipairs(unwind) do
  local bas=Y.yeni_konum(u[1])

  for _,so in ipairs(u[4]) do so[3]=Y.yeni_konum(u[1]+so[3])-bas end
  u[5]=Y.yeni_konum(u[1]+u[5])-bas
  if u[6] then u[6]=Y.yeni_konum(u[1]+u[6])-bas end
  if u[7] then u[7]=Y.yeni_konum(u[1]+u[7])-bas end
  u[2]=Y.yeni_konum(u[2]); u[1]=bas
end
for _,p in ipairs(patches) do
  local at,dest,kind=p[1],assert(labels[p[2]]),p[3];local v
  if kind=='rel8' then
    local d=dest-at-1
    assert(d>=-128 and d<=127,'kisa dal menzili asildi')
    code[at+1]=d&0xff
    goto sonraki
  elseif kind=='rel32' then v=(dest-at-4)&0xffffffff
  elseif kind:sub(1,4)=='cond' then
    local d=(dest-at)//4;assert(d>=-262144 and d<262144,'dal uzaklığı aşıldı')
    v=0x54000000 | ((d&0x7ffff)<<5) | tonumber(kind:sub(5))
  elseif kind=='adr' then
    local d=dest-at;assert(d>=-1048576 and d<1048576,'metin uzaklığı aşıldı')
    v=0x10000000 | ((d&3)<<29) | (((d>>2)&0x7ffff)<<5)
  else
    local delta=dest-at;assert(delta%4==0);local d=delta//4
    local compare=kind=='cbz' or kind=='cbnz'
    local bits=compare and 19 or 26
    assert(d>=-(1<<(bits-1)) and d<(1<<(bits-1)),'dal uzaklığı aşıldı')
    v=compare and ((kind=='cbz' and 0xb4000000 or 0xb5000000) | (code[at+1]&0x1f) | ((d&0x7ffff)<<5)) or ((kind=='bl' and 0x94000000 or 0x14000000) | (d&0x3ffffff))
  end
  local s=string.pack('<I4',v);for i=1,4 do code[at+i]=s:byte(i) end
  ::sonraki::
end
if symbol_map then

  local f=assert(io.open(symbol_map,'w'))
  for _,fn in ipairs(functions) do f:write(string.format('%x %s\n',labels[entries[fn[1]]],fn[1])) end
  f:close()
end
local used={};for _,r in ipairs(relocations) do used[r[2]]=true end
local names,remap={},{}
for i,n in ipairs(externs) do if used[i] then names[#names+1]=n;remap[i]=#names end end
for _,r in ipairs(relocations) do r[2]=remap[r[2]] end
externs=names
local parts={};for _,v in ipairs(code) do parts[#parts+1]=string.char(v) end
local machine=table.concat(parts)
local function patch_global_addresses(text_base,global_base)
  local function patch(at,v) machine=machine:sub(1,at)..string.pack('<I4',v&0xffffffff)..machine:sub(at+5) end
  for _,r in ipairs(global_relocations) do
    local dest=r[2].text_label and (text_base+assert(labels[r[2].text_label])) or (global_base+r[2].offset)
    if arm then
      dest=dest+(r.extra or 0)
      local d=dest//4096-(text_base+r[1])//4096
      if d< -1048576 or d>=1048576 then fail('statik veri ADRP uzaklığı aşıldı') end
      local rd=string.unpack('<I4',machine,r[1]+1)&0x1f
      patch(r[1],0x90000000 | ((d&3)<<29) | (((d>>2)&0x7ffff)<<5) | rd)
      if r.opcode then
        if dest%r.width~=0 then fail('genel değişken hizası: '..tostring(r[2].name)) end
        patch(r[1]+4,r.opcode | (((dest%4096)//r.width)<<10))
      else patch(r[1]+4,0x91000000 | ((dest%4096)<<10) | (rd<<5) | rd) end
    else
      local d=dest-(text_base+r[1]+4+(r.bias or 0));if d< -2147483648 or d>2147483647 then fail('statik veri uzaklığı aşıldı') end
      patch(r[1],d)
    end
  end
end

local function p32(...) local a={...};for i,v in ipairs(a) do a[i]=string.pack('<I4',v) end;return table.concat(a) end
local function p64(n) return string.pack('<I8',n) end
local function name(s) return s..string.rep('\0',16-#s) end
if linux then

  local function align(n,a) return (n+a-1)//a*a end
  local function p16(n) return string.pack('<I2',n) end
  local page=arm and 65536 or 4096
  local interpreter=arm and '/lib/ld-linux-aarch64.so.1' or '/lib64/ld-linux-x86-64.so.2'
  local phnum=8;local meta=string.rep('\0',64+phnum*56)
  local function append(s,a)
    meta=meta..string.rep('\0',align(#meta,a or 1)-#meta)
    local at=#meta;meta=meta..s;return at
  end
  local interp_at=append(interpreter..'\0')
  local needs_math=false;for _,n in ipairs(externs) do if math_symbols[n] then needs_math=true end end
  local strings='\0libc.so.6\0';local math_string=#strings;if needs_math then strings=strings..'libm.so.6\0' end;local symbols={string.rep('\0',24)}
  for _,n in ipairs(externs) do
    symbols[#symbols+1]=p32(#strings)..string.char(0x12,0)..p16(0)..p64(0)..p64(0)
    strings=strings..n..'\0'
  end
  local str_at=append(strings);local sym_at=append(table.concat(symbols),8)
  local chain={p32(1,#symbols,1,0)}
  for i=1,#externs do chain[#chain+1]=p32(i<#externs and i+1 or 0) end
  local hash_at=append(table.concat(chain),8)
  local text_at=align(#meta,page);local rw_at=align(text_at+#machine,page)
  local got_at=rw_at;local rela_at=align(got_at+#externs*8,8)
  local relas={}
  for i=1,#externs do
    relas[#relas+1]=p64(got_at+(i-1)*8)..p64((i<<32) | (arm and 1025 or 6))..p64(0)
  end
  local rela=table.concat(relas);local dynamic_at=rela_at+#rela
  local tags={{1,1},{5,str_at},{10,#strings},{6,sym_at},{11,24},{4,hash_at},{7,rela_at},{8,#rela},{9,24},{21,0},{30,8},{0x6ffffffb,0x08000001},{0,0}}
  if needs_math then table.insert(tags,2,{1,math_string}) end
  local dynamic={};for _,v in ipairs(tags) do dynamic[#dynamic+1]=p64(v[1])..p64(v[2]) end
  dynamic=table.concat(dynamic)
  local rw=string.rep('\0',rela_at-rw_at)..rela..dynamic
  rw=rw..string.rep('\0',align(#rw,page)-#rw)
  local function patch(at,value) machine=machine:sub(1,at)..p32(value&0xffffffff)..machine:sub(at+5) end
  for _,r in ipairs(relocations) do
    local got=got_at+(r[2]-1)*8
    if arm then
      local d=(got//4096)-((text_at+r[1])//4096)
      assert(d>=-1048576 and d<1048576,'GOT ADRP uzaklığı aşıldı')
      patch(r[1],0x90000010 | ((d&3)<<29) | (((d>>2)&0x7ffff)<<5))
      patch(r[1]+4,0xf9400210 | (((got%4096)//8)<<10))
    else patch(r[1],got-(text_at+r[1]+4)) end
  end
  local relro_size=#rw+readonly_size;local global_at=rw_at+#rw
  Y.rw_mem=#rw+#global_bytes
  patch_global_addresses(text_at,global_at);rw=rw..global_bytes:sub(1,Y.file_globals)
  local function ph(t,flags,at,size,alignment,memsize)
    return p32(t,flags)..p64(at)..p64(at)..p64(at)..p64(size)..p64(memsize or size)..p64(alignment)
  end
  local phdr=ph(6,4,64,phnum*56,8)..ph(3,4,interp_at,#interpreter+1,1)
    ..ph(1,4,0,#meta,page)..ph(1,5,text_at,#machine,page)..ph(1,6,rw_at,#rw,page,Y.rw_mem)
    ..ph(2,6,dynamic_at,#dynamic,8)..ph(0x6474e551,6,0,0,16)..ph(0x6474e552,4,rw_at,relro_size,1)
  local header='\127ELF'..string.char(2,1,1,0)..string.rep('\0',8)..p16(3)..p16(arm and 183 or 62)..p32(1)
    ..p64(text_at+process_entry)..p64(64)..p64(0)..p32(0)..p16(64)..p16(56)..p16(phnum)..p16(0)..p16(0)..p16(0)
  assert(#header==64 and #phdr==phnum*56)
  meta=header..phdr..meta:sub(64+phnum*56+1)
  local executable=meta..string.rep('\0',text_at-#meta)..machine..string.rep('\0',rw_at-text_at-#machine)..rw
  local out=assert(io.open(output,'wb'));out:write(executable);out:close()
  if package.config:sub(1,1)=='/' then
    local quoted="'"..output:gsub("'", "'\\''").."'"
    if not os.execute('chmod +x '..quoted) then fail('ELF çalıştırma izni ayarlanamadı') end
  end
  print(string.format('%s: Linux ELF64 PIE %s / %s, %d bayt makine kodu',output,target,instruction,#machine))
  return
end
if windows then

  local function align(n,a) return (n+a-1)//a*a end
  local function p16(n) return string.pack('<I2',n) end
  local text_rva=0x1000
  local import_rva=align(text_rva+#machine,4096)
  local groups={}
  for i,n in ipairs(externs) do
    local dll=kernel32[n] and 'KERNEL32.dll' or 'msvcrt.dll'
    if not groups[dll] then groups[dll]={} end
    groups[dll][#groups[dll]+1]={i,n}
  end
  local dlls={};for n in pairs(groups) do dlls[#dlls+1]=n end;table.sort(dlls)
  local imports=string.rep('\0',20*(#dlls+1));local descriptors={};local iat={}
  local function append(s,a)
    imports=imports..string.rep('\0',align(#imports,a or 1)-#imports)
    local off=#imports;imports=imports..s;return off
  end
  local function replace32(s,at,v) return s:sub(1,at)..p32(v)..s:sub(at+5) end
  for _,dll in ipairs(dlls) do
    local names={};for _,entry in ipairs(groups[dll]) do names[#names+1]=import_rva+append(p16(0)..entry[2]..'\0',2) end
    local thunk={};for _,rva in ipairs(names) do thunk[#thunk+1]=p64(rva) end;thunk[#thunk+1]=p64(0)
    local ilt=append(table.concat(thunk),8);local table_at=append(table.concat(thunk),8)
    local dll_at=append(dll..'\0')
    for j,entry in ipairs(groups[dll]) do iat[entry[1]]=import_rva+table_at+(j-1)*8 end
    descriptors[#descriptors+1]=p32(import_rva+ilt,0,0,import_rva+dll_at,import_rva+table_at)
  end
  local desc=table.concat(descriptors);imports=desc..imports:sub(#desc+1)
  for _,r in ipairs(relocations) do
    local d=iat[r[2]]-(text_rva+r[1]+4)
    machine=replace32(machine,r[1],d&0xffffffff)
  end
  local pdata_rva=align(import_rva+#imports,4096)
  local pdata,unwind_bytes={},''
  for _,fn in ipairs(unwind) do
    local frame=fn[3]
    local codes=''

    for i=#fn[4],1,-1 do
      local r=fn[4][i]
      if r[2]<=524280 then codes=codes..string.char(r[3],(r[1]<<4)|4)..p16(r[2]//8)
      else codes=codes..string.char(r[3],(r[1]<<4)|5)..p32(r[2]) end
    end

    if not fn.rsp then codes=codes..string.char(fn[7],3) end
    if frame>0 then codes=codes..(frame<=524280 and (string.char(fn[6],1)..p16(frame//8)) or (string.char(fn[6],0x11)..p32(frame))) end
    if not fn.rsp then codes=codes..string.char(1,0x50) end
    local info=string.char(1,fn[5],#codes//2,fn.rsp and 0 or 5)..codes
    info=info..string.rep('\0',align(#info,4)-#info)
    pdata[#pdata+1]=p32(text_rva+fn[1],text_rva+fn[2],pdata_rva+#unwind*12+#unwind_bytes)
    unwind_bytes=unwind_bytes..info
  end
  local pdata_bytes=table.concat(pdata)..unwind_bytes

  local reloc_rva=align(pdata_rva+math.max(#pdata_bytes,1),4096)

  local reloc=p32(0,12)..p16(0)..p16(0)
  local sections={{'.text',text_rva,machine,0x60000020},{'.idata',import_rva,imports,0xc0000040},
    {'.pdata',pdata_rva,pdata_bytes,0x40000040},{'.reloc',reloc_rva,reloc,0x42000040}}
  local global_rva=align(reloc_rva+#reloc,4096)
  if readonly_size>0 then sections[#sections+1]={'.rdata',global_rva,global_bytes:sub(1,readonly_size),0x40000040} end

  if #global_bytes>readonly_size then sections[#sections+1]={'.data',global_rva+readonly_size,global_bytes:sub(readonly_size+1,Y.file_globals),0xc0000040,#global_bytes-readonly_size} end
  patch_global_addresses(text_rva,global_rva);sections[1][3]=machine
  local headers_size=align(128+4+20+240+#sections*40,512)
  local directories={};for i=1,16 do directories[i]=p32(0,0) end
  directories[2]=p32(import_rva,20*(#dlls+1))
  directories[4]=p32(pdata_rva,#unwind*12)
  directories[6]=p32(reloc_rva,#reloc)
  local optional=p16(0x20b)..string.char(0,1)..p32(align(#machine,512),align(#imports,512)+align(#pdata_bytes,512)+512+align(#global_bytes,512),0,
    text_rva+labels[entries['__t_giriş']],text_rva)..p64(0x140000000)..p32(4096,512)..p16(6)..p16(0)..p16(0)..p16(0)..p16(6)..p16(0)
    ..p32(0,#global_bytes>0 and align(global_rva+#global_bytes,4096) or align(reloc_rva+#reloc,4096),headers_size,0)..p16(3)..p16(0x160)
    ..p64(8*1024*1024)..p64(16384)..p64(1024*1024)..p64(4096)..p32(0,16)..table.concat(directories)
  assert(#optional==240)
  local dos='MZ'..string.rep('\0',58)..p32(128)..string.rep('\0',64)
  local header=dos..'PE\0\0'..p16(0x8664)..p16(#sections)..p32(0,0,0)..p16(240)..p16(0x22)..optional
  local raw_offset=headers_size;local contents={}
  for _,section in ipairs(sections) do
    local raw_size=align(#section[3],512)
    header=header..section[1]..string.rep('\0',8-#section[1])..p32(section[5] or #section[3],section[2],raw_size,raw_size>0 and raw_offset or 0,0,0)..p16(0)..p16(0)..p32(section[4])
    contents[#contents+1]=section[3]..string.rep('\0',raw_size-#section[3]);raw_offset=raw_offset+raw_size
  end
  local out=assert(io.open(output,'wb'));out:write(header..string.rep('\0',headers_size-#header)..table.concat(contents));out:close()
  print(string.format('%s: Windows PE32+ x86_64 / %s, %d bayt makine kodu',output,instruction,#machine))
  return
end
if emit=='exe' then
  local function write_macho()

  local function align(n,a) return (n+a-1)//a*a end
  local function zeros(n) return string.rep('\0',n) end
  local function be32(...) local a={...};for i,v in ipairs(a) do a[i]=string.pack('>I4',v) end;return table.concat(a) end
  local function sha256(s)
    local k={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
      0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
      0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
      0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
      0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
      0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
      0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
      0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
    local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local function r(x,n) return ((x>>n)|(x<<(32-n)))&0xffffffff end
    local bytes=#s;s=s..'\128'..zeros((55-bytes)%64)..string.pack('>I8',bytes*8)
    for at=1,#s,64 do
      local w={};for i=0,15 do w[i]=string.unpack('>I4',s,at+i*4) end
      for i=16,63 do
        local x,y=w[i-15],w[i-2]
        w[i]=(w[i-16]+(r(x,7)~r(x,18)~(x>>3))+w[i-7]+(r(y,17)~r(y,19)~(y>>10)))&0xffffffff
      end
      local a,b,c,d,e,f,g,j=table.unpack(h)
      for i=0,63 do
        local t=(j+(r(e,6)~r(e,11)~r(e,25))+((e&f)~((~e)&g))+k[i+1]+w[i])&0xffffffff
        local u=((r(a,2)~r(a,13)~r(a,22))+((a&b)~(a&c)~(b&c)))&0xffffffff
        j,g,f,e,d,c,b,a=g,f,e,(d+t)&0xffffffff,c,b,a,(t+u)&0xffffffff
      end
      for i,v in ipairs({a,b,c,d,e,f,g,j}) do h[i]=(h[i]+v)&0xffffffff end
    end
    return be32(table.unpack(h))
  end
  local function uleb(n)
    local s={};repeat local v=n&127;n=n>>7;s[#s+1]=string.char(v|(n>0 and 128 or 0)) until n==0;return table.concat(s)
  end
  local function path_command(cmd,head,path)
    local s=head..path..'\0';return p32(cmd,align(8+#s,8))..s..zeros(align(8+#s,8)-8-#s)
  end
  local dylinker=path_command(0xe,p32(12),'/usr/lib/dyld')
  local dylib=path_command(0xc,p32(24,0,0x10000,0x10000),'/usr/lib/libSystem.B.dylib')
  local page,base=arm and 16384 or 4096,0x100000000
  local count=#externs;local writable=#global_bytes-readonly_size
  local data_file=Y.file_globals-readonly_size;local bss=writable-data_file
  local const_size=align(count*8,page)+align(readonly_size,page)
  local nsegments=3+(const_size>0 and 1 or 0)+(writable>0 and 1 or 0)
  local nsections=1+(count>0 and 2 or 0)+(readonly_size>0 and 1 or 0)+(data_file>0 and 1 or 0)+(bss>0 and 1 or 0)
  local header_size=32+nsegments*72+nsections*80+48+#dylinker+#dylib+24+24+24+24+80+16
  local text_at=align(header_size,16);local stub_size=arm and 12 or 6
  local stub_at=align(text_at+#machine,4);local text_size=align(stub_at+count*stub_size,page)
  local global_at=text_size+align(count*8,page)+align(readonly_size,page)-readonly_size
  local data_at=text_size+const_size;local link_at=data_at+align(data_file,page);local link_vm=data_at+align(writable,page)
  patch_global_addresses(base+text_at,base+global_at)
  local function patch(at,v) machine=machine:sub(1,at)..p32(v&0xffffffff)..machine:sub(at+5) end
  for _,r in ipairs(relocations) do
    local dest=stub_at+(r[2]-1)*stub_size
    if arm then
      local d=(dest-text_at-r[1])//4;assert(d>=-33554432 and d<33554432,'Mach-O BL uzaklığı aşıldı')
      patch(r[1],0x94000000|(d&0x3ffffff))
    else
      local d=dest-text_at-r[1]-4;assert(d>=-2147483648 and d<=2147483647,'Mach-O CALL uzaklığı aşıldı');patch(r[1],d)
    end
  end
  local stubs,bind,indirect={},{string.char(0x11,0x51)},{}
  for i,n in ipairs(externs) do
    local slot=text_size+(i-1)*8;local pc=stub_at+(i-1)*stub_size
    if arm then
      local d=slot//4096-pc//4096;assert(d>=-1048576 and d<1048576,'Mach-O GOT uzaklığı aşıldı')
      stubs[#stubs+1]=p32(0x90000010|((d&3)<<29)|(((d>>2)&0x7ffff)<<5),0xf9400210|(((slot%4096)//8)<<10),0xd61f0200)
    else stubs[#stubs+1]='\255\37'..p32((slot-pc-6)&0xffffffff) end

    bind[#bind+1]=string.char(0x40)..'_'..n..'\0'..string.char(0x72)..uleb((i-1)*8)..string.char(0x90)
    indirect[#indirect+1]=p32(i)
  end
  stubs=table.concat(stubs);bind=table.concat(bind)..'\0';indirect=table.concat(indirect);indirect=indirect..indirect
  local entry=text_at+labels[entries[main_entry]]
  local strings='\0_main\0';local symbols={p32(1)..string.char(0xf,1)..string.pack('<I2',0)..p64(base+entry)}
  for _,n in ipairs(externs) do
    symbols[#symbols+1]=p32(#strings)..string.char(1,0)..string.pack('<I2',0x100)..p64(0);strings=strings..'_'..n..'\0'
  end
  symbols=table.concat(symbols)
  local link='';local function append(s,a)
    link=link..zeros(align(#link,a or 1)-#link);local at=link_at+#link;link=link..s;return at
  end
  local bind_at=append(bind);local sym_at=append(symbols,8);local str_at=append(strings);local indirect_at=append(indirect,4)
  local sig_at=append('',16);local id='T.program\0';local slots=(sig_at+4095)//4096
  local sig_size=20+88+#id+slots*32;local link_size=#link+sig_size
  local function section(n,seg,at,size,alignment,flags,r1,r2)
    return name(n)..name(seg)..p64(base+at)..p64(size)..p32(at,alignment,0,0,flags or 0,r1 or 0,r2 or 0,0)
  end
  local function segment(n,at,size,prot,sections,flags,filesize,vmat)
    local zero=n=='__PAGEZERO';sections=sections or ''
    return p32(0x19,72+#sections)..name(n)..p64(zero and 0 or base+(vmat or at))..p64(zero and base or align(size,page))
      ..p64(at)..p64(zero and 0 or (filesize or size))..p32(prot,prot,#sections//80,flags or 0)..sections
  end
  local sections=section('__text','__TEXT',text_at,#machine,4,0x80000400)
  if count>0 then sections=sections..section('__stubs','__TEXT',stub_at,#stubs,2,0x80000408,0,stub_size) end
  local commands={segment('__PAGEZERO',0,0,0),segment('__TEXT',0,text_size,5,sections)}
  if const_size>0 then
    sections=count>0 and section('__got','__DATA_CONST',text_size,count*8,3,6,count) or ''
    if readonly_size>0 then sections=sections..section('__const','__DATA_CONST',global_at,readonly_size,6) end
    commands[#commands+1]=segment('__DATA_CONST',text_size,const_size,3,sections,0x10)
  end
  if writable>0 then
    local ds=data_file>0 and section('__data','__DATA',data_at,data_file,6) or ''

    if bss>0 then ds=ds..name('__bss')..name('__DATA')..p64(base+data_at+data_file)..p64(bss)..p32(0,6,0,0,1,0,0,0) end
    commands[#commands+1]=segment('__DATA',data_at,writable,3,ds,nil,align(data_file,page))
  end
  commands[#commands+1]=segment('__LINKEDIT',link_at,link_size,1,nil,nil,nil,link_vm)
  commands[#commands+1]=p32(0x80000022,48,0,0,bind_at,#bind,0,0,0,0,0,0)
  commands[#commands+1]=dylinker;commands[#commands+1]=dylib
  commands[#commands+1]=p32(0x80000028,24)..p64(entry)..p64(0)
  commands[#commands+1]=p32(0x32,24,1,0x000b0000,0,0)
  commands[#commands+1]=p32(0x1b,24)..sha256(machine..global_bytes:sub(1,Y.file_globals)):sub(1,16)
  commands[#commands+1]=p32(2,24,sym_at,count+1,str_at,#strings)
  commands[#commands+1]=p32(0xb,80,0,0,0,1,1,count,0,0,0,0,0,0,indirect_at,count*2,0,0,0,0)
  commands[#commands+1]=p32(0x1d,16,sig_at,sig_size)
  local header=p32(0xfeedfacf,arm and 0x100000c or 0x1000007,arm and 0 or 3,2,#commands,header_size-32,0x200085,0)..table.concat(commands)
  assert(#header==header_size)
  local executable=header..zeros(text_at-#header)..machine..zeros(stub_at-text_at-#machine)..stubs
  executable=executable..zeros(global_at-#executable)..global_bytes:sub(1,Y.file_globals)
  executable=executable..zeros(link_at-#executable)..link;assert(#executable==sig_at)
  local directory=be32(0xfade0c02,sig_size-20,0x20400,0x20002,88+#id,88,0,slots,sig_at)
    ..string.char(32,2,0,12)..be32(0,0,0,0)..string.pack('>I8I8I8I8',0,0,text_size,1)..id
  local hashes={};for at=1,sig_at,4096 do hashes[#hashes+1]=sha256(executable:sub(at,math.min(at+4095,sig_at))) end
  local signature=be32(0xfade0cc0,sig_size,1,0,20)..directory..table.concat(hashes);assert(#signature==sig_size)

  local temp=os.tmpname();local pending=output..'.'..temp:match('[^/\\]+$')..'.tmp';os.remove(temp)
  local out,err=io.open(pending,'wb');if not out then fail(err) end
  local ok,message=out:write(executable,signature);local closed,close_error=out:close()
  if not ok or not closed then os.remove(pending);fail(message or close_error) end
  if package.config:sub(1,1)=='/' then
    local quoted="'"..pending:gsub("'", "'\\''").."'"
    if not os.execute('/bin/chmod +x '..quoted) then os.remove(pending);fail('Mach-O çalıştırma izni ayarlanamadı') end
  end
  local renamed,reason=os.rename(pending,output);if not renamed then os.remove(pending);fail(reason) end
  print(string.format('%s: macOS Mach-O PIE %s / %s, %d bayt makine kodu (Lua bağlayıcı/imza)',output,target,instruction,#machine))
  end
  write_macho()
  return
end
local has_data=#global_bytes>0
local has_readonly=readonly_size>0;local has_writable=#global_bytes>readonly_size
local section_count=1+(has_readonly and 1 or 0)+(has_writable and 1 or 0)
local segment_size=72+section_count*80
local offset=32+segment_size+24+24
local data_vm=(#machine+63)//64*64
local data_at=(offset+#machine+63)//64*64
local payload=machine
if has_data then payload=payload..string.rep('\0',data_at-offset-#machine)..global_bytes end
local reloff=(offset+#payload+7)//8*8
local rel={}
for _,r in ipairs(relocations) do rel[#rel+1]={r[1],0x2d000000 | r[2]} end
local strings='\0_main\0'
local symbols={p32(1)..string.char(0x0f,1)..string.pack('<I2',0)..p64(labels[entries[main_entry]])}
for _,n in ipairs(externs) do
  symbols[#symbols+1]=p32(#strings)..string.char(1,0)..string.pack('<I2',0)..p64(0);strings=strings..'_'..n..'\0'
end
local global_symbols={}
for _,g in ipairs(global_order) do
  global_symbols[g.name]=#symbols
  symbols[#symbols+1]=p32(#strings)..string.char(0x0e,g.readonly and 2 or (has_readonly and 3 or 2))..string.pack('<I2',0)..p64(data_vm+g.offset)
  strings=strings..'T_global_'..g.name..'\0'
end
for _,r in ipairs(global_relocations) do
  local key=r[2].text_label
  if key and not global_symbols[key] then
    global_symbols[key]=#symbols;symbols[#symbols+1]=p32(#strings)..string.char(0x0e,1)..string.pack('<I2',0)..p64(assert(labels[key]))
    strings=strings..'T_text_'..key..'\0'
  end
  local index=global_symbols[key or r[2].name]
  if arm then rel[#rel+1]={r[1],0x3d000000|index};rel[#rel+1]={r[1]+4,0x4c000000|index}
  else rel[#rel+1]={r[1],0x1d000000|index} end
end
table.sort(rel,function(a,b) return a[1]>b[1] end)
local encoded={};for _,r in ipairs(rel) do encoded[#encoded+1]=p32(r[1],r[2]) end
local relbytes=table.concat(encoded);local symoff=reloff+#relbytes
local header=p32(0xfeedfacf,arm and 0x100000c or 0x1000007,arm and 0 or 3,1,3,segment_size+48,0,0)
local segment=p32(0x19,segment_size)..name('')..p64(0)..p64(has_data and data_vm+#global_bytes or #machine)..p64(offset)..p64(#payload)..p32(7,7,section_count,0)
local section=name('__text')..name('__TEXT')..p64(0)..p64(#machine)..p32(offset,arm and 2 or 0,reloff,#rel,0x80000400,0,0,0)
if has_readonly then section=section..name('__const')..name('__TEXT')..p64(data_vm)..p64(readonly_size)..p32(data_at,6,0,0,0,0,0,0) end
if has_writable then section=section..name('__data')..name('__DATA')..p64(data_vm+readonly_size)..p64(#global_bytes-readonly_size)..p32(data_at+readonly_size,6,0,0,0,0,0,0) end
local symtab=p32(2,24,symoff,#symbols,symoff+16*#symbols,#strings)
local platform=p32(0x32,24,1,0x000b0000,0,0)
local obj=header..segment..section..symtab..platform..payload..string.rep('\0',reloff-offset-#payload)..relbytes..table.concat(symbols)..strings
local out=assert(io.open(output,'wb'));out:write(obj);out:close()
print(string.format('%s: macOS %s / %s, %d bayt makine kodu',output,target,instruction,#machine))

end
local ok,message=pcall(main)
if not ok then io.stderr:write(tostring(message),"\n");os.exit(1) end
