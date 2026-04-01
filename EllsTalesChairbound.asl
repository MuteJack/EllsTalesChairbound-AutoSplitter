// LiveSplit Auto Splitter for Ell's Tales: Chairbound
// Engine: Unreal Engine 4.27 | Steam App ID: 3281410
//
// SETUP:
//   1. Add Scriptable Auto Splitter -> select this file
//   2. Timer 1: set to Game Time (bomb elapsed time, PB comparison)
//   3. Timer 2 (optional): set to Real Time (wall clock)
//   4. (Optional) Add Text components, set to Custom Variable:
//      - "BombRemain" for bomb remaining time
//      - "BombElapsed" for bomb elapsed time (text)
//   5. Add 1 split segment (e.g. "Clear")
//
// TIMING:
//   Game Time = bomb elapsed time (reflects item effects, matches leaderboard)
//   Real Time = wall clock time (cannot be paused by ASL)

state("EllsTalesChairbound-Win64-Shipping")
{
    int mapNameId : "EllsTalesChairbound-Win64-Shipping.exe", 0x049D9530, 0x18;
    long worldPtr : "EllsTalesChairbound-Win64-Shipping.exe", 0x049D9530;
    byte isPaused : "EllsTalesChairbound-Win64-Shipping.exe", 0x049D9530, 0x118, 0x2B8;
}

startup
{
    settings.Add("split_lever", true, "Split on clear (both levers pulled)");
    settings.Add("pause_on_esc", true, "Pause timer on ESC menu");
    settings.Add("bomb_as_gametime", false, "Game Time = bomb elapsed (leaderboard timing)");
    settings.Add("show_bomb_remain", true, "Show bomb remaining time (Custom Variable: BombRemain)");
    settings.Add("show_bomb_elapsed", true, "Show bomb elapsed time (Custom Variable: BombElapsed)");
    settings.Add("debug_log", true, "Enable debug log (chairbound_log_{yyyyMMdd_HHmmss}.txt in game folder)");
}

init
{
    vars.MAP_GAME = 504;
    vars.MAP_MENU = -1;
    if (current.mapNameId != 0 && current.mapNameId != vars.MAP_GAME)
        vars.MAP_MENU = current.mapNameId;

    vars.logPath = "";
    vars.debugTimer = 0;

    // Log helper: creates log dir on first use
    vars.Log = (Action<string>)((msg) => {
        try
        {
            if (String.IsNullOrEmpty(vars.logPath))
            {
                string lsDir = Environment.CurrentDirectory;
                string logDir = System.IO.Path.Combine(lsDir, "logs");
                if (!System.IO.Directory.Exists(logDir))
                    System.IO.Directory.CreateDirectory(logDir);
                string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                vars.logPath = System.IO.Path.Combine(logDir, "Ells Tales Chairbound_asl_log_" + timestamp + ".txt");
            }
            var sw = new System.IO.StreamWriter(vars.logPath, true);
            sw.WriteLine("[" + DateTime.Now + "] " + msg);
            sw.Close();
        }
        catch { }
    });
    vars.inGame = (current.mapNameId == vars.MAP_GAME);
    vars.fnamePoolRVA = 0x04855940;

    vars.mechanismAddr = (long)0;
    vars.leftMechAddr = (long)0;
    vars.rightMechAddr = (long)0;
    vars.heroAddr = (long)0;
    vars.stateIsOnOffset = (int)0;
    vars.checkTimerOffset = (int)0;
    vars.remainedSecondsOffset = (int)0;

    vars.lever1State = false;
    vars.lever2State = false;
    vars.bothPulled = false;
    vars.oldLever1 = false;
    vars.oldLever2 = false;
    vars.oldBothPulled = false;
    vars.cleared = false;
    vars.oldCleared = false;
    vars.scanned = false;
    vars.bombRemaining = (int)600;

    // Memory read helpers
    vars.RL = (Func<long, long>)((addr) => {
        byte[] b = game.ReadBytes(new IntPtr(addr), 8);
        return b != null ? BitConverter.ToInt64(b, 0) : 0;
    });
    vars.RI = (Func<long, int>)((addr) => {
        byte[] b = game.ReadBytes(new IntPtr(addr), 4);
        return b != null ? BitConverter.ToInt32(b, 0) : 0;
    });
    vars.RS = (Func<long, short>)((addr) => {
        byte[] b = game.ReadBytes(new IntPtr(addr), 2);
        return b != null ? BitConverter.ToInt16(b, 0) : (short)0;
    });
    vars.RB = (Func<long, byte>)((addr) => {
        byte[] b = game.ReadBytes(new IntPtr(addr), 1);
        return b != null ? b[0] : (byte)0;
    });
    vars.FN = (Func<long, int, string>)((fnPool, idx) => {
        if (idx <= 0) return null;
        int blk = idx >> 16;
        int pos = (idx & 0xFFFF) << 1;
        long bp = vars.RL(fnPool + 0x10 + blk * 8);
        if (bp == 0) return null;
        short hdr = vars.RS(bp + pos);
        int sl = ((int)hdr & 0xFFFF) >> 6;
        if (sl <= 0 || sl > 120) return null;
        byte[] nb = game.ReadBytes(new IntPtr(bp + pos + 2), sl);
        if (nb == null) return null;
        return System.Text.Encoding.ASCII.GetString(nb);
    });
    vars.WalkFF = (Func<long, long, System.Collections.Generic.Dictionary<string, int>>)((fnPool, classAddr) => {
        var result = new System.Collections.Generic.Dictionary<string, int>();
        long cur = vars.RL(classAddr + 0x50);
        int cnt = 0;
        while (cur != 0 && cnt < 100)
        {
            int fn = vars.RI(cur + 0x28);
            int off = vars.RI(cur + 0x4C);
            string nm = vars.FN(fnPool, fn);
            if (nm != null && off > 0) result[nm] = off;
            cur = vars.RL(cur + 0x20);
            cnt++;
        }
        return result;
    });

    if (settings["debug_log"]) vars.Log("ASL Attached map=" + current.mapNameId);
}

update
{
    vars.debugTimer++;

    if (vars.MAP_MENU == -1 && current.mapNameId != 0 && current.mapNameId != vars.MAP_GAME)
        vars.MAP_MENU = current.mapNameId;

    vars.inGame = (current.mapNameId == vars.MAP_GAME);

    // === SCAN ===
    if (vars.inGame && !vars.scanned)
    {
        try
        {
            long gw = (long)current.worldPtr;
            if (gw == 0) goto skipScan;

            long moduleBase = (long)modules.First().BaseAddress;
            long fnPool = moduleBase + vars.fnamePoolRVA;

            long level = vars.RL(gw + 0x30);
            long aPtr = vars.RL(level + 0x98);
            int aCount = vars.RI(level + 0xA0);
            if (aCount <= 0 || aCount > 5000 || aPtr == 0) goto skipScan;

            bool fMech = false;
            bool fHero = false;

            for (int i = 0; i < Math.Min(aCount, 2500); i++)
            {
                if (fMech && fHero) break;

                long aa = vars.RL(aPtr + i * 8);
                if (aa == 0) continue;

                long ca = vars.RL(aa + 0x10);
                if (ca == 0) continue;

                int cf = vars.RI(ca + 0x18);
                if (cf <= 0) continue;

                string cn = vars.FN(fnPool, cf);
                if (cn == null) continue;

                if (!fMech && cn == "BP_FinalMechanism_C")
                {
                    vars.mechanismAddr = aa;
                    var props = vars.WalkFF(fnPool, ca);
                    if (props.ContainsKey("LeftMechanism")) vars.leftMechAddr = vars.RL(aa + props["LeftMechanism"]);
                    if (props.ContainsKey("RightMechanism")) vars.rightMechAddr = vars.RL(aa + props["RightMechanism"]);
                    if (props.ContainsKey("CheckTimer")) vars.checkTimerOffset = props["CheckTimer"];

                    if (vars.leftMechAddr != 0)
                    {
                        long ic = vars.RL(vars.leftMechAddr + 0x10);
                        if (ic != 0)
                        {
                            var iprops = vars.WalkFF(fnPool, ic);
                            if (iprops.ContainsKey("StateIsOn")) vars.stateIsOnOffset = iprops["StateIsOn"];
                        }
                    }

                    fMech = (vars.leftMechAddr != 0 && vars.rightMechAddr != 0 && vars.stateIsOnOffset != 0);
                }

                if (!fHero && cn == "BP_Hero_C")
                {
                    vars.heroAddr = aa;
                    var props = vars.WalkFF(fnPool, ca);
                    if (props.ContainsKey("RemainedSeconds")) vars.remainedSecondsOffset = props["RemainedSeconds"];
                    fHero = (vars.remainedSecondsOffset != 0);
                }
            }

            vars.scanned = fMech && fHero;

            if (settings["debug_log"]) vars.Log("SCAN: mech=" + fMech + " hero=" + fHero
                + " stateIsOn=0x" + ((int)vars.stateIsOnOffset).ToString("X")
                + " checkTimer=0x" + ((int)vars.checkTimerOffset).ToString("X")
                + " remained=0x" + ((int)vars.remainedSecondsOffset).ToString("X"));
        }
        catch (Exception ex)
        {
            if (settings["debug_log"]) vars.Log("SCAN ERR: " + ex.Message);
        }
        skipScan:;
    }

    // Reset on map change
    if (old.mapNameId != current.mapNameId)
    {
        vars.scanned = false;
        vars.mechanismAddr = (long)0;
        vars.leftMechAddr = (long)0;
        vars.rightMechAddr = (long)0;
        vars.heroAddr = (long)0;
        vars.stateIsOnOffset = (int)0;
        vars.checkTimerOffset = (int)0;
        vars.remainedSecondsOffset = (int)0;
        vars.lever1State = false;
        vars.lever2State = false;
        vars.bothPulled = false;
        vars.oldLever1 = false;
        vars.oldLever2 = false;
        vars.oldBothPulled = false;
        vars.cleared = false;
        vars.oldCleared = false;
        vars.bombRemaining = (int)600;
    }

    // === Read states ===
    vars.oldLever1 = (bool)vars.lever1State;
    vars.oldLever2 = (bool)vars.lever2State;
    vars.oldBothPulled = (bool)vars.bothPulled;
    vars.oldCleared = (bool)vars.cleared;

    if (vars.inGame && vars.scanned)
    {
        try
        {
            if (vars.leftMechAddr != 0 && vars.rightMechAddr != 0 && vars.stateIsOnOffset != 0)
            {
                byte ls = vars.RB(vars.leftMechAddr + vars.stateIsOnOffset);
                byte rs = vars.RB(vars.rightMechAddr + vars.stateIsOnOffset);
                vars.lever1State = (rs == 1);
                vars.lever2State = (ls == 1);
                vars.bothPulled = ((bool)vars.lever1State && (bool)vars.lever2State);
            }

            if ((bool)vars.bothPulled && vars.mechanismAddr != 0 && vars.checkTimerOffset != 0)
            {
                long tv = vars.RL(vars.mechanismAddr + vars.checkTimerOffset);
                vars.cleared = (tv == 0);
            }

            if (vars.heroAddr != 0 && vars.remainedSecondsOffset != 0)
            {
                vars.bombRemaining = vars.RI(vars.heroAddr + vars.remainedSecondsOffset);
            }
        }
        catch { }
    }

    // === Bomb Custom Variables ===
    try
    {
        var cv = timer.Run.Metadata.CustomVariables;
        if (vars.inGame && vars.scanned && vars.remainedSecondsOffset != 0)
        {
            int rem = (int)vars.bombRemaining;
            if (rem < 0) rem = 0;
            int elapsed = 600 - rem;
            if (elapsed < 0) elapsed = 0;

            if (settings["show_bomb_remain"] && cv.ContainsKey("BombRemain"))
                cv["BombRemain"].Value = (rem / 60).ToString() + ":" + (rem % 60).ToString("D2");
            if (settings["show_bomb_elapsed"] && cv.ContainsKey("BombElapsed"))
                cv["BombElapsed"].Value = (elapsed / 60).ToString() + ":" + (elapsed % 60).ToString("D2");
        }
        else if (timer.CurrentPhase == TimerPhase.NotRunning)
        {
            if (cv.ContainsKey("BombRemain")) cv["BombRemain"].Value = "10:00";
            if (cv.ContainsKey("BombElapsed")) cv["BombElapsed"].Value = "0:00";
        }
    }
    catch { }

    // === Log ===
    bool mc = (old.mapNameId != current.mapNameId);
    bool lc = ((bool)vars.lever1State != (bool)vars.oldLever1 || (bool)vars.lever2State != (bool)vars.oldLever2);
    bool cc = ((bool)vars.cleared && !(bool)vars.oldCleared);
    bool pc = (old.isPaused != current.isPaused);
    bool sl = (vars.debugTimer % 300 == 0);

    if (settings["debug_log"])
    {
        if (mc) vars.Log("MAP: " + old.mapNameId + " -> " + current.mapNameId);
        if (lc) vars.Log("LEVER: L1=" + vars.lever1State + " L2=" + vars.lever2State);
        if (cc) vars.Log("CLEAR!");
        if (pc) vars.Log("PAUSE: " + old.isPaused + " -> " + current.isPaused);
        if (sl && !mc && !lc && !cc && !pc) vars.Log("POLL map=" + current.mapNameId + " bomb=" + vars.bombRemaining + " scanned=" + vars.scanned);
    }
}

start { return current.mapNameId == vars.MAP_GAME && old.mapNameId != vars.MAP_GAME; }

split
{
    if (!vars.inGame || !settings["split_lever"]) return false;
    if ((bool)vars.cleared && !(bool)vars.oldCleared) return true;
    return false;
}

reset { return current.mapNameId == vars.MAP_GAME && old.mapNameId != vars.MAP_GAME; }

isLoading
{
    if (settings["bomb_as_gametime"])
        return true; // gameTime block controls Game Time
    else
        return current.mapNameId == 0 || (settings["pause_on_esc"] && (bool)vars.inGame && current.isPaused == 1);
}

gameTime
{
    if (!settings["bomb_as_gametime"])
        return null; // Let isLoading handle Game Time normally

    // Game Time = bomb elapsed time (600 - RemainedSeconds)
    if (vars.inGame && vars.scanned && vars.remainedSecondsOffset != 0)
    {
        int rem = (int)vars.bombRemaining;
        if (rem < 0) rem = 0;
        int elapsed = 600 - rem;
        if (elapsed < 0) elapsed = 0;
        return TimeSpan.FromSeconds(elapsed);
    }
    return TimeSpan.Zero;
}
