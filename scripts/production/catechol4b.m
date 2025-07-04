%DIT KOPI�REN!!!!
%     p=3:0.05:20;
%   y=15e-1*p.^-2.74+12e0*p.^-4.54;
%   figure(22); plot(p,y,'co'); hold on;
%   for p=2:0.5:20
%     PfO2(1:800)=p;
%     for ico=4:800;
%     catechol3
%     end
%     figure(22); hold on; plot(p,NEa(800),'rx')
%     end

qfet0=18.25e-6;
if ico==3
    CAum(1:2)=0.89e-3;
    CAf(1:2)=1.0e-3;
    CAmix(1:2)=0.97e-3;
    CAmix2(1:2)=0.97e-3;

    facgm3ngml=10^3;
    qfet0=mfqmc+mfqbr;
    qum0=mfqummc;
    qut0=mqutven;
end

P0=0.5*85e-9*3/60; %[ng/s] gedeeld door 2 vanwege verrekening Ef met P
facEum=0.45;%1/6; %fraction of clearance flow from umbilical flow% 
facEf=0;%1/29; %fraction of clearance flow from systemic flow% 
qfet=mfqmc+mfqbr;%2.42e-5; %mean(fqsav(sfa,jmin:jmax)); % umbilical flow [m^3/s]
qum=mfqummc;%2.42e-5; %mean(fqsav(sumv,jmin:jmax)); % umbilical flow [m^3/s]
qut=mqutven;
qCO=qfet+qum;
CLum0=3*48e-6/60;
CLum=facEum*qum; 
CLf0=3*48e-6/60;
CLf=facEf*qCO;
ka=1;

%Volumes
mVf1= 300e-6;%mVv;
mVum1= 30e-6;%mVa;
mVf= 300e-6;%if umbilical==1; mVv=(fV(num)); else  mVv=sum(fV([numa,numv])); end% fetal venous volume
mVum= 30e-6;%sum(fV)-mVv; % fetal venous volume

dfVumdto =(mVum1-mVum)/tso; %fetal venous volume change
dfVfdto =(mVf1-mVf)/tso; %fetal venous volume change

%Elimination and production rates [g/s]
Eum(ico)=CLum*CAmix(ico-1)*(qut/qut0); %totale afbraaksnelheid
Ef(ico)=CLf*CAmix(ico-1); %totale afbraaksnelheid
pOCA(ico)=PfO2(ico-1)-3;
if pOCA(ico)<12
    P(ico)=1e-6*qfet*3.0873e+05*exp(-pOCA(ico)/1.5977); %gefit op data van Cohen: netto-verschil tussen aanmaak/afbraak in foetale en mix compartiment
else
    P(ico)=P0;
end


%CA concentrations [g/m3]
CAmix(ico)=(qfet/qCO)*CAf(ico-1)+(qum/qCO)*CAum(ico-1);

dCAfdt(ico)=-(CAf(ico-1)/mVf)*dfVfdto+(qfet/mVf)*(CAmix(ico-1)-CAf(ico-1))+(P(ico)/mVf);
CAf(ico)=CAf(ico-1)+dCAfdt(ico)*tso;

dCAumdt(ico)=-(CAum(ico-1)/mVum)*dfVumdto+(qum/mVum)*(CAmix(ico-1)-CAum(ico-1))-(Eum(ico)/mVum);
CAum(ico)=CAum(ico-1)+dCAumdt(ico)*tso;

%CAf(ico)=(CAf(ico-1)+(qfet*CAmix(ico)+P(ico)-0)*tso/mVf)/(1+tso/mVf*(qfet+dfVfdto));
%CAum(ico)=max(0,(CAum(ico-1)+(qum*CAmix(ico)+E(ico))*tso/mVum)/(1+tso/mVum*(qum+dfVumdto)));
