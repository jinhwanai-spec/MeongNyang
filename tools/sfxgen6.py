# v0.49 효과음: 새 날갯짓 / 쥐덫 탁! / 기름통 폭발 / 연막 치익
import numpy as np, sys, os
sys.path.insert(0, os.path.dirname(__file__))
exec(open(os.path.join(os.path.dirname(__file__), 'sfxgen2.py'), encoding='utf-8').read().split('# weapons')[0])
rng6 = np.random.default_rng(66)
def nz6(d): return rng6.uniform(-1,1,int(SR*d))
def envx(n, a, d):
    t_ = np.arange(n)/SR
    return np.minimum(1.0, t_/max(a,1e-4)) * np.exp(-t_/d)
# 날갯짓: 18Hz로 떨리는 잡음, 점점 멀어짐
d=0.9; n=int(SR*d); t_=np.arange(n)/SR
flap = bp(nz6(d),0.05,0.35) if 'bp' in dir() else lp(hp(nz6(d),0.08),0.4)
flap = flap*(0.5+0.5*np.sign(np.sin(2*np.pi*17*t_)))*np.exp(-t_/0.45)
save('flap', flap, 0.6)
# 쥐덫: 금속성 딱 + 짧은 울림
d=0.35; n=int(SR*d)
snap = hp(nz6(0.02),0.6)*envx(int(SR*0.02),0.0002,0.004)
snap = np.concatenate([snap, np.zeros(n-len(snap))])
ring = (np.sin(2*np.pi*2300*np.arange(n)/SR)+0.5*np.sin(2*np.pi*3700*np.arange(n)/SR))*envx(n,0.0005,0.06)*0.35
thud_ = sweep(220,90,d)*envx(n,0.001,0.03)*0.6
save('trap_snap', snap+ring+thud_, 0.85)
# 폭발: 저역 쿵 + 잡음 꼬리
d=1.6; n=int(SR*d)
boom = lp(nz6(d),0.04)*envx(n,0.002,0.45)*2.5 + sweep(90,35,d)*envx(n,0.002,0.35) + hp(nz6(d),0.3)*envx(n,0.001,0.08)*0.5
save('explosion', boom, 0.95)
# 연막: 치이익
d=1.4; n=int(SR*d)
hiss = hp(nz6(d),0.5)*envx(n,0.05,0.7)*0.7
save('smoke_hiss', hiss, 0.6)
print('sfx6 ok')
