import numpy as np, wave, os
SR=22050
OUT='/home/claude/game/assets/sfx'
rng=np.random.default_rng(7)
def t(d): return np.arange(int(SR*d))/SR
def env(n,a=0.005,d=None,curve=4.0):
    x=np.arange(n)/SR; dur=n/SR
    e=np.minimum(1,x/max(a,1e-4))
    e*=np.exp(-curve*x/dur) if d is None else np.exp(-x/d)
    return e
def noise(d): return rng.uniform(-1,1,int(SR*d))
def lp(x,k):  # one-pole lowpass, k in (0,1)
    y=np.zeros_like(x); s=0.0
    for i,v in enumerate(x): s+=k*(v-s); y[i]=s
    return y
def hp(x,k): return x-lp(x,k)
def sweep(f0,f1,d,shape='sin'):
    tt=t(d); f=f0*(f1/f0)**(tt/d) if f0>0 and f1>0 else np.linspace(f0,f1,len(tt))
    ph=2*np.pi*np.cumsum(f)/SR
    if shape=='sq': return np.sign(np.sin(ph))*0.6
    if shape=='tri': return 2/np.pi*np.arcsin(np.sin(ph))
    return np.sin(ph)
def tone(f,d,shape='sin'): return sweep(f,f,d,shape)
def mix(*xs):
    n=max(len(x) for x in xs); o=np.zeros(n)
    for x in xs: o[:len(x)]+=x
    return o
def cat(*xs): return np.concatenate(xs)
def pad(x,d): return cat(x,np.zeros(int(SR*d)))
def save(name,x,gain=0.9):
    x=np.asarray(x,dtype=float); m=np.max(np.abs(x))+1e-9; x=x/m*gain
    fade=min(200,len(x)); x[-fade:]*=np.linspace(1,0,fade)
    d=(x*32767).astype(np.int16)
    with wave.open(os.path.join(OUT,name+'.wav'),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def note(n): return 440*2**((n-69)/12)
def pluck(f,d,bright=0.5):
    x=tone(f,d,'tri')*0.7+tone(f*2,d)*0.2*bright
    return x*env(len(x),0.003,None,6)

# weapons
# ── v0.13 새 무기·타격 소리 (층을 쌓아 묵직하게) ──
rng2=np.random.default_rng(11)
def nz(d): return rng2.uniform(-1,1,int(SR*d))
def tail(d,k=0.12,dec=0.12):  # 짧은 잔향 꼬리
    n=lp(nz(d),k); return n*env(len(n),0.003,dec)
def crack(d=0.03,k=0.6): return hp(nz(d),k)*env(int(SR*d),0.0003,d*0.25)
def boom(f0,f1,d,dec): return sweep(f0,f1,d)*env(int(SR*d),0.001,dec)
def shot(crack_g, boom_f0, boom_f1, boom_d, boom_dec, body_k, body_d, body_dec, tail_d, tail_g):
    return mix(crack(0.03)*crack_g, boom(boom_f0,boom_f1,boom_d,boom_dec), lp(nz(body_d),body_k)*env(int(SR*body_d),0.0008,body_dec),
               pad(np.zeros(int(SR*0.02)),0)[:0] if False else np.zeros(1), cat(np.zeros(int(SR*0.02)), tail(tail_d)*tail_g))
save('shot_rifle', shot(0.9, 180, 55, 0.22, 0.06, 0.4, 0.18, 0.035, 0.35, 0.35))
save('shot_sniper', shot(1.0, 140, 38, 0.5, 0.12, 0.3, 0.3, 0.06, 0.9, 0.55))
save('shot_smg', shot(0.7, 220, 80, 0.12, 0.03, 0.5, 0.1, 0.02, 0.16, 0.2), 0.8)
save('shot_revolver', shot(0.9, 150, 45, 0.3, 0.08, 0.35, 0.22, 0.05, 0.45, 0.4))
# 총알이 몸에 박히는 소리 (퍽!)
save('impact_flesh', mix(boom(220,70,0.12,0.035), lp(nz(0.08),0.35)*env(int(SR*.08),0.0005,0.018)*0.9, crack(0.015,0.4)*0.4))
# 벽/바닥에 맞는 소리 (탁·칭)
save('impact_hard', mix(crack(0.02,0.5)*0.8, tone(2800,0.09)*env(int(SR*.09),0.0005,0.02)*0.25, lp(nz(0.06),0.5)*env(int(SR*.06),0.0005,0.012)*0.6), 0.7)
# 처치 확인 (짧고 경쾌한 딩)
save('kill', mix(tone(note(88),0.25)*env(int(SR*.25),0.001,0.06)*0.6, tone(note(95),0.25)*env(int(SR*.25),0.001,0.05)*0.35, boom(300,90,0.1,0.03)*0.5), 0.6)
# 묵직한 근접 타격
save('melee_heavy', mix(boom(160,40,0.3,0.08), lp(nz(0.12),0.3)*env(int(SR*.12),0.0005,0.03), crack(0.02,0.5)*0.5))
save('slash', mix(hp(nz(0.16),0.25)*np.sin(np.pi*np.arange(int(SR*.16))/int(SR*.16))*0.6, crack(0.02,0.6)*0.4), 0.7)
# 탄피 떨어지는 소리
save('shell_drop', cat(tone(4200,0.03)*env(int(SR*.03),0.0005,0.008), np.zeros(int(SR*.07)), tone(3700,0.03)*env(int(SR*.03),0.0005,0.006)*0.6), 0.35)
# 총알이 귀 옆을 스치는 소리
save('whiz', hp(nz(0.18),0.2)*np.sin(np.pi*np.arange(int(SR*.18))/int(SR*.18))**2*0.5, 0.5)
