# v0.25 지역 환경음: 공원(새·바람·잎) / 마트 뒷골목(냉장고 웅웅·먼 차 소리)
import numpy as np, sys, os
sys.path.insert(0, os.path.dirname(__file__))
exec(open(os.path.join(os.path.dirname(__file__), 'sfxgen2.py'), encoding='utf-8').read().split('# weapons')[0])
rng4 = np.random.default_rng(41)
def nz4(d): return rng4.uniform(-1,1,int(SR*d))
dur = 10.0
n = int(SR*dur)
x = np.arange(n)/SR
def place(o, s_, at_s):
    i = int(SR*at_s); m = min(len(s_), n-i); o[i:i+m] += s_[:m]
# 공원: 부드러운 바람 + 나뭇잎 + 새소리
wind = lp(lp(nz4(dur),0.02),0.05)*2.2*(0.6+0.4*np.sin(2*np.pi*x/5.0)**2)
leaves = hp(nz4(dur),0.6)*0.025*(0.5+0.5*np.sin(2*np.pi*x/3.3)**4)
park = wind + leaves
def chirp(f0, f1, d, g):
    tt = t(d); f = np.linspace(f0, f1, len(tt))
    return np.sin(2*np.pi*np.cumsum(f)/SR)*env(len(tt),0.004,None,2)*g
def trill(at_s, base, k, g):
    for j in range(k):
        place(park, chirp(base, base*1.35, 0.06, g), at_s + j*0.09)
trill(0.8, 3200, 4, 0.10); place(park, chirp(4200, 2800, 0.18, 0.08), 2.1)
trill(4.0, 2700, 3, 0.08); place(park, chirp(2600, 3900, 0.12, 0.07), 6.2); place(park, chirp(3900, 3000, 0.12, 0.06), 6.4)
trill(8.1, 3500, 5, 0.07)
f_=int(SR*0.3); park[:f_]*=np.linspace(0.6,1,f_); park[-f_:]*=np.linspace(1,0.6,f_)
save('amb_park', park, 0.45)
# 마트 뒷골목: 냉장고 웅웅 + 형광등 지직 + 먼 차 소리
hum = (np.sin(2*np.pi*60*x)*0.5 + np.sin(2*np.pi*120*x)*0.25 + np.sin(2*np.pi*180*x)*0.1)*0.18
traffic = lp(lp(nz4(dur),0.015),0.03)*2.5*(0.4+0.6*np.exp(-((x-3.5)/1.6)**2) + 0.5*np.exp(-((x-8.0)/1.2)**2))
mart = hum + traffic
for s_at in [1.3, 1.36, 5.7]:
    place(mart, hp(nz4(0.05),0.7)*env(int(SR*0.05),0.001,0.02)*0.08, s_at)
f_=int(SR*0.3); mart[:f_]*=np.linspace(0.6,1,f_); mart[-f_:]*=np.linspace(1,0.6,f_)
save('amb_mart', mart, 0.4)
print('amb4 ok')
