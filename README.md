# SAB Pass Farmer

One job: take an account (a brand-new one is fine) to the last rank of the event pass in **Stack A Butter Squishy**, on its own, so the last reward can be claimed by hand.

## Loader (Delta)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FlamingClaw/sab-pass/main/SAB_Pass.lua?t=" .. tick()))()
```

It only starts when you run it, or when Delta's **autoexecute** runs it (put the same line in the autoexecute folder for that). It never queues itself for the next server. Each account keeps its own settings (`SAB/SAB_Pass_<userId>.txt`).

## What it does

- **Tutorial** on a new account: pulls the lever, buys the butter, waxes it, waits, steps on the collector.
- **Pulls the lever itself** (no Auto Roll pass needed), about one pull every 2 seconds.
- **Buys what helps**: anything a "wax a Rare / Epic / Legendary" quest needs, anything while a "buy" or "wax" quest is open, otherwise butters that earn more as it gets richer. Waxes them, and buys the next wax station once it costs under a third of its cash.
- **Collects** the cash on its plot (every 6 s while a collect quest is open).
- **Helps other players' waxes** for the help quests: it stands inside their butter so the help counts.
- **Claims** finished quests, the daily bonus, and pass ranks **1 to 19 on the free side**.
- **Never** claims the last rank (the 90%-of-best butter), never uses Claim All, never buys anything with Robux.
- **Stays in**: anti-idle, and rejoins when disconnected (to a pinned server if you set one). After a rejoin it starts again only if autoexecute is on.

## The pass (Thanksgiving, measured Nov 20 2026)

- 20 ranks, 4,300 acorns in total.
- 5 quests a day (one collect, one wax, one help, two of pull / buy / rare / epic / legendary), plus +100 after 4 of them.
- A full day is about 520–730 acorns, so about **7–8 full days** reach rank 20.
- Quests reset at 00:00 UTC. The event ends Dec 1 00:00 UTC; rewards can be claimed until 08:00 UTC that day.

## Window

RUN / STOPPED, HELP on/off, and the **GFX** switch for running many accounts (tap to cycle, the screen always stays normal):

- **GFX: NORMAL**: everything drawn.
- **GFX: LOW**: other players' bases, stacks and butters aren't drawn (they're still there, so helping works); sparkles, shadows and post effects off; 20 fps cap.
- **GFX: LOWEST**: the same, plus your own base and stack tower aren't drawn either. Buying, waxing and collecting still work.

The `_` button shrinks the window. It shows the rank, acorns, today's quests and the last thing it did.

## Tips for alts

- Put the alts **in the same server as your main**. Your long waxes are always there for their help quests, and every alt help takes 10% off your wax.
- To make an alt rejoin that same server after a disconnect, run this once on it: `getgenv().SABP.pin()`.
