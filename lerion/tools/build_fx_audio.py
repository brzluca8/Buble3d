"""Original short cues for Etapa 4.2, rendered offline with the same synth as build_board_audio.py.

Every cue is short (<= 1.1 s), soft at the attack and pitched in the key of the music (D major)
so it never fights the theme after dozens of rolls. The game randomises pitch slightly at run time.

    python3 tools/build_fx_audio.py
"""
from build_board_audio import render, OUT

hz = lambda midi: 440 * 2 ** ((midi - 69) / 12)


def arp(start, midis, step, decay, volume, noise=.01):
    return [(start + i * step, hz(m), decay, volume, noise) for i, m in enumerate(midis)]


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True, parents=True)
    render("fx_wheel_tick", [(0, 1500, .006, .2, .55), (.004, 2400, .005, .1, .2)])
    render("fx_wheel_stop", [(0, 220, .05, .35, .4)] + arp(.05, [86, 90, 93], .06, .12, .16))
    render("fx_win_energy", arp(0, [74, 78, 81, 86, 90], .045, .09, .2, .02) + [(.22, hz(93), .2, .14, .01)])
    render("fx_win_chest", arp(0, [69, 76, 81], .07, .16, .2) + [(.21, hz(88), .3, .12, .02)])
    render("fx_win_gold", arp(0, [62, 66, 69, 74, 78, 81, 86], .055, .14, .2) +
           [(.38, hz(74), .45, .18, .005), (.38, hz(78), .45, .14, .005), (.38, hz(81), .45, .14, .005), (.38, hz(86), .5, .12, .005)])
    render("fx_chest_beat", [(0, hz(81), .09, .26, .01), (.002, hz(93), .05, .1, .01)])
    render("fx_chest_open", [(0, 140, .06, .3, .7), (.05, 260, .05, .2, .8)] + arp(.12, [81, 85, 88, 93], .04, .12, .14))
    render("fx_card_flip", [(0, 2200, .012, .16, .95), (.03, 1700, .01, .1, .95)])
    render("fx_card_rare", arp(0, [86, 90, 93, 98], .05, .2, .14) + [(.2, hz(102), .3, .08, .01)])
    render("fx_crystal_pulse", [(0, hz(93), .07, .12, .01), (.03, hz(100), .05, .06, .01)])
    render("fx_crystal_ready", arp(0, [74, 81, 86, 90, 93, 98], .07, .25, .12))
    render("fx_crystal_activate", [(i * .035, 300 + i * 120, .03, .05 + i * .006, .6) for i in range(14)] +
           [(.5, hz(86), .3, .16, .01), (.5, hz(93), .3, .12, .01)])
    render("fx_dice_settle", [(0, 820, .012, .2, .4), (.07, 980, .012, .16, .4)])
    render("fx_hammer", [(0, 1250, .02, .26, .25), (.004, 3100, .012, .12, .1)])
    render("fx_hammer_big", [(0, 170, .07, .45, .5), (.02, 1100, .03, .22, .3), (.12, hz(74), .05, .12, .01), (.2, hz(71), .07, .1, .01)])
    render("fx_cheer", arp(0, [74, 78, 81, 86], .06, .08, .2))
    render("fx_sneeze", [(i * .02, 900 - i * 20, .03, .06, .9) for i in range(6)] +
           [(.2 + i * .012, 1800 - i * 90, .02, .12, .95) for i in range(8)] + arp(.32, [93, 97, 100], .04, .1, .1))
    render("fx_landing", [(0, 160, .045, .34, .4), (.03, hz(86), .07, .08, .01)])
    render("fx_hud_pop", [(0, 700, .018, .16, .05), (.012, 1050, .02, .1, .02)])
    render("fx_awaken", arp(0, [62, 66, 69, 74, 78, 81, 86, 90, 93], .06, .35, .12, .005))
