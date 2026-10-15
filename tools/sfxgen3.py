# v0.16 새 효과음: 제작소·물약·갑옷·부품·가방·탈출 연출
import numpy as np, sys, os
sys.path.insert(0, os.path.dirname(__file__))
exec(open(os.path.join(os.path.dirname(__file__), 'sfxgen2.py'), encoding='utf-8').read().split('# weapons')[0])
rng3 = np.random.default_rng(23)
def nz(d): return rng3.uniform(-1,1,int(SR*d))
def at(x, sec): return cat(np.zeros(int(SR*sec)), x)
def ping(f, d, dec, g=1.0): return (tone(f,d)*0.7 + tone(f*2.76,d)*0.25 + tone(f*5.4,d)*0.1)*env(int(SR*d),0.0005,dec)*g
def thud(f0,f1,d,dec,g=1.0): return sweep(f0,f1,d)*env(int(SR*d),0.001,dec)*g
def crack(d=0.03,k=0.6): return hp(nz(d),k)*env(int(SR*d),0.0003,d*0.25)
def click(g=1.0): return hp(nz(0.012),0.5)*env(int(SR*.012),0.0002,0.003)*g
# 무기 제작: 망치 두 번 + 래칫
save('craft_weapon', mix(at(mix(ping(1250,0.4,0.09),thud(180,70,0.12,0.03)),0.0), at(mix(ping(1180,0.4,0.1,0.8),thud(170,70,0.12,0.03,0.8)),0.22),
    at(cat(*[cat(click(0.6),np.zeros(int(SR*0.035))) for _ in range(5)]),0.5)), 0.8)
# 물약 제작: 보글보글 + 병 뚜껑 퐁
def bubble(f, d=0.06): return sweep(f, f*2.2, d)*env(int(SR*d),0.002,d*0.4)
b = np.zeros(int(SR*0.9))
for i in range(9):
    s0 = int(SR*(0.05+i*0.085+rng3.uniform(0,0.03)))
    x = bubble(rng3.uniform(300,700))*0.5
    b[s0:s0+len(x)] += x[:len(b)-s0]
save('craft_potion', mix(b, at(mix(sweep(900,500,0.08)*env(int(SR*.08),0.001,0.02), click(0.5)),0.82)), 0.75)
# 갑옷 제작: 모루 두드림 3번 (쨍)
save('craft_armor', mix(at(ping(1650,0.6,0.16),0), at(ping(1600,0.6,0.15,0.8),0.28), at(ping(1700,0.8,0.22,0.9),0.56),
    at(thud(120,60,0.1,0.03,0.6),0), at(thud(120,60,0.1,0.03,0.5),0.28), at(lp(nz(0.5),0.05)*env(int(SR*.5),0.05,0.2)*0.3,0.6)), 0.8)
# 물약 마시기: 꿀꺽 꿀꺽
def gulp(): return mix(sweep(260,140,0.09)*env(int(SR*.09),0.005,0.03), lp(nz(0.09),0.2)*env(int(SR*.09),0.002,0.02)*0.4)
save('drink', cat(gulp(), np.zeros(int(SR*0.12)), gulp()*0.9, np.zeros(int(SR*0.1)), sweep(1200,1800,0.12)*env(int(SR*.12),0.002,0.04)*0.25), 0.7)
# 갑옷이 막음: 금속 팅
save('armor_hit', mix(ping(2100,0.25,0.05), crack(0.015,0.5)*0.6, thud(300,120,0.06,0.02,0.4)), 0.6)
# 갑옷 부서짐
save('armor_break', mix(ping(1500,0.3,0.06), at(ping(900,0.3,0.05,0.7),0.05), lp(nz(0.3),0.4)*env(int(SR*.3),0.001,0.06)*0.8, thud(200,60,0.2,0.05)), 0.8)
# 갑옷 입기: 천 바스락 + 버클 딸깍
save('equip_armor', mix(hp(lp(nz(0.35),0.3),0.05)*env(int(SR*.35),0.05,0.12)*0.6, at(click(1.0),0.3), at(click(0.8),0.36)), 0.7)
# 부품 끼우기: 철컥
save('attach', mix(click(1.0), at(mix(click(1.0), ping(3000,0.08,0.015,0.5), thud(400,200,0.05,0.015,0.5)),0.08)), 0.7)
# 내 가방 찾음: 반짝 차임 3음
save('bag_found', mix(at(pluck(note(76),0.5),0), at(pluck(note(80),0.5),0.09), at(pluck(note(83),0.7),0.18), at(pluck(note(88),0.8),0.27)), 0.6)
# 맨홀 뚜껑 열기: 덜컹
save('manhole', mix(thud(140,60,0.3,0.08), ping(700,0.4,0.08,0.6), at(ping(650,0.3,0.06,0.5),0.12), lp(nz(0.25),0.2)*env(int(SR*.25),0.001,0.05)*0.5), 0.8)
# 트럭 출발: 부릉
tt = t(1.6)
f = 40 + 35*np.clip(tt/1.2,0,1)
eng = np.sin(2*np.pi*np.cumsum(f)/SR)*0.6 + np.sign(np.sin(2*np.pi*np.cumsum(f*2)/SR))*0.15 + lp(nz(1.6),0.1)*0.3
save('truck', eng*env(len(eng),0.15,None,1.2), 0.8)
print('ok')
