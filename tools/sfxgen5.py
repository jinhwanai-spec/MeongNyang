# v0.37 발소리: 풀 / 딱딱한 바닥 / 진흙 (조용한 한 걸음, 각 3가지 변주)
import numpy as np, sys, os
sys.path.insert(0, os.path.dirname(__file__))
exec(open(os.path.join(os.path.dirname(__file__), 'sfxgen2.py'), encoding='utf-8').read().split('# weapons')[0])
rng5 = np.random.default_rng(77)
def nz5(d): return rng5.uniform(-1,1,int(SR*d))
def envx(n, a, d):
    t_ = np.arange(n)/SR
    e = np.minimum(1.0, t_/max(a,1e-4)) * np.exp(-t_/d)
    return e
# 풀: 사각사각 (고역 잡음 두 번)
d=0.16; n=int(SR*d)
g = hp(nz5(d),0.45)*envx(n,0.004,0.035)
g2 = np.zeros(n); i=int(SR*0.05); g2[i:] = (hp(nz5(d),0.5)*envx(n,0.003,0.03))[:n-i]*0.7
save('step_grass', g+g2, 0.5)
# 딱딱한 바닥: 톡 (짧은 저역 + 클릭)
d=0.09; n=int(SR*d)
h = lp(nz5(d),0.25)*envx(n,0.001,0.012) + sweep(240,120,d)*envx(n,0.001,0.015)*0.6
save('step_hard', h, 0.55)
# 진흙: 철퍽 (저역 잡음 + 느린 감쇠)
d=0.2; n=int(SR*d)
m = lp(nz5(d),0.08)*envx(n,0.008,0.05) + sweep(180,90,d)*envx(n,0.004,0.04)*0.4
save('step_mud', m, 0.55)
print('steps ok')
