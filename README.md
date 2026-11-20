# SAB Pass Farmer

One job: take an account (a brand-new one is fine) to the last rank of the event pass in **Stack A Butter Squishy**, on its own, so the last reward can be claimed by hand.

## Loader (Delta)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FlamingClaw/sab-pass/main/SAB_Pass.lua?t=" .. tick()))()
```

Put the same line in Delta's **autoexecute** folder so it starts by itself after every rejoin.

## What it does

- **Tutorial** on a new account: pulls the lever, buys the butter, waxes it, waits, steps on the collector.
- **Pulls the lever itself** (no Auto Roll pass needed), about one pull every 2 seconds.
- **Buys what helps**: anything a "wax a Rare / Epic / Legendary" quest needs, anything while a "buy" or "wax" quest is open, otherwise butters that earn more as it gets richer. Waxes them, and buys the next wax station once it costs under a third of its cash.
- **Collects** the cash on its plot (every 6 s while a collect quest is open).
- **Helps other players' waxes** for the help quests: it stands inside their butter so the help counts.
- **Claims** finished quests, the daily bonus, and pass ranks **1 to 19 on the free side**.
- **Never** claims the last rank (the 90%-of-best butter), never uses Claim All, never buys anything with Robux.
- **Stays in**: anti-idle, rejoins when disconnected (to a pinned server if you set one), and restarts itself after a teleport.

## The pass (Thanksgiving, measured Nov 20 2026)

- 20 ranks, 4,300 acorns in total.
- 5 quests a day (one collect, one wax, one help, two of pull / buy / rare / epic / legendary), plus +100 after 4 of them.
- A full day is about 520–730 acorns, so about **7–8 full days** reach rank 20.
- Quests reset at 00:00 UTC. The event ends Dec 1 00:00 UTC; rewards can be claimed until 08:00 UTC that day.

## Window

RUN / STOPPED, HELP on/off, LOW GFX (3D rendering off and a 20 fps cap, for running many accounts). The `_` button shrinks it. It shows the rank, acorns, today's quests and the last thing it did.

## Tips for alts

- Put the alts **in the same server as your main**. Your long waxes are always there for their help quests, and every alt help takes 10% off your wax.
- To make an alt rejoin that same server after a disconnect, run this once on it: `getgenv().SABP.pin()`.
