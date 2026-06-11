# V0.8.1 REPAIR SPRINT — Final Report

## 1. Root Cause V0.8 Invalid

**Problem:** Semua test V0.8 Profit Sprint hasil identik (SL=100, TP=150) karena profile .set tidak terbaca.

**Root cause:** File .set dikorupsi encoding — tidak ada BOM (`fffe`) UTF-16LE dan CRLF line endings tidak sesuai format MT5.

**Fix:** Profile dibuat ulang via bash + iconv (bukan Python), dengan BOM + CRLF + comment header.

---

## 2. Profile Loading Verification ✅

Config log dari OnInit Print membuktikan SL/TP sesuai profile:

| Test | SL | TP | AutoTrade | AllowTester |
|------|----|----|-----------|-------------|
| S1 | 80 | 100 | true | true |
| S2 | 100 | 150 | true | true |
| S3 | 150 | 225 | true | true |
| S4 | 150 | 300 | true | true |

**Status: ✅ VALID — profile loading berfungsi.**

---

## 3. CTradeManager Execution ✅

**Perubahan:**
- Raw `OrderSend()` di V0.8 dihapus
- Semua eksekusi via `CTradeManager.ExecuteTrade()`
- TradeManager diubah: SL/TP dihitung dari `plan.sl_points`/`plan.tp_points` terhadap execution price (bukan stale price)
- `type_filling` dihapus (default MT5)
- `plan.sl_price`/`tp_price` tidak dipakai — hanya `sl_points`/`tp_points`

**Status: ✅ Execution lewat CTradeManager.**

---

## 4. Attempts/Success/Fail Counter ✅

Counter berfungsi normal. Bar gap filter (InpMinBarsBetweenTrades=6) membatasi attempt dari 92.844 ke ~10.912 per test.

**Status: ✅ Counter bekerja.**

---

## 5. S1-S4 Results

| # | Test | SL | TP | RR | Attempts | Success | Fail | Final Bal | Net P&L |
|---|------|----|----|----|----------|---------|------|-----------|---------|
| 1 | S1 | 80 | 100 | 1.25 | 10,918 | 256 | 10,662 | 19.57 | -80.43 |
| 2 | S2 | 100 | 150 | 1.50 | 10,918 | 174 | 10,744 | 19.51 | -80.49 |
| 3 | S3 | 150 | 225 | 1.50 | 10,915 | 178 | 10,737 | 19.88 | -80.12 |
| 4 | S4 | 150 | 300 | 2.00 | 10,912 | 167 | 10,745 | 18.35 | -81.65 |

**Catatan:** 98.5% order gagal dengan `retcode=10019 err=4756` (margin tidak cukup). Hanya 167-256 trade pertama yang terisi sebelum balance drop di bawah margin requirement XAUUSD 0.01 lot (~$33 margin per posisi).

---

## 6. Ranking Net Profit

| Rank | Test | Net P&L |
|------|------|---------|
| 1 | S3 | -80.12 |
| 2 | S1 | -80.43 |
| 3 | S2 | -80.49 |
| 4 | S4 | -81.65 |

Semua test loss ~$80. Perbedaan antar test tidak signifikan (±$1.5).

---

## 7. Ranking Profit Factor

Profit factor tidak bisa dihitung akurat karena dari 10.912 attempt hanya 167-256 yang terisi. Data tidak cukup untuk PF yang bermakna.

---

## 8. Ranking Max Drawdown

Drawdown ~80% untuk semua test (dari $100 ke ~$19). Tidak ada perbedaan signifikan antar SL/TP.

---

## 9. Apakah M1 Execution Lebih Baik dari V0.7A.1?

**Data pembanding:**

| Metric | V0.7A.1 Test D | V0.8.1 S4 |
|--------|---------------|-----------|
| Deposit | $100 | $100 |
| SL/TP | 150/300 | 150/300 |
| Trades | 240 | 167 |
| Win Rate | 29.6% | 27.5% (est) |
| Net P&L | -38.68 | -81.65 |

**Kesimpulan: V0.8.1 S4 LEBIH BURUK dari V0.7A.1 Test D.**

Loss lebih besar (-81.65 vs -38.68) dari deposit sama. M1 entry concept tidak memberikan perbaikan signifikan. Order rejection 98.5% juga membuat data tidak reliable.

---

## 10. Final Decision

**DECISION: M1 EXECUTION FAILS**

M1 entry concept menghasilkan trade execution, tapi:
- 98.5% order reject karena margin tidak cukup
- Win rate dan P&L tidak bisa divalidasi dengan benar
- Hasil lebih buruk dari benchmark V0.7A.1

---

## 11. Audit Checklist

| Item | Status |
|------|--------|
| Compile 0 errors, 0 warnings | ✅ 32KB, 0 err 0 warn |
| No encoding corruption | ✅ Profile via bash+iconv |
| EA tidak crash | ✅ Stable running |
| ConfigLog created | ✅ XAUUSD_SMC_V081_ConfigLog.csv |
| ExecutionLog via Logger | ✅ CSV dan Print |
| P&L dari DEAL_PROFIT | ✅ Final balance verified |
| V0.4 live untouched | ✅ Separate build |
| No martingale/grid/averaging | ✅ |
| Max 1 posisi aktif | ✅ |
| Not pushed to GitHub | ✅ |

---

## 12. Rekomendasi

**Jangan lanjutkan V0.8 M1 sprint dengan deposit $100.** Margin XAUUSD terlalu besar untuk 0.01 lot.

Opsi ke depan:
1. **Kembali ke V0.6/V0.7A.1** yang terbukti bisa running
2. **Tambahkan session filter + overextension filter** di V0.7A.1 untuk improve win rate
3. **Deposit lebih besar** (min $500) jika tetap mau M1 execution
4. **Model 1 minute OHLC** bukan Every tick untuk mengurangi order reject

---

## Output Files

| File | Path |
|------|------|
| EA source | `mq5/Experts/...V081_REPAIR/XAUUSD_SMC_Scalper_MTF_V081_REPAIR.mq5` |
| TradeManager | `mq5/Include/SMC_V081_REPAIR/TradeManager.mqh` |
| Profiles | `Profiles/Tester/V081_REPAIR_S[1-4].set` |
| Backup profiles | `Profiles/Tester/_backup_all_210956/` |
| Config CSV | `MQL5/Files/XAUUSD_SMC_V081_ConfigLog.csv` |
| Report | `docs/V081_REPAIR_SPRINT_REPORT.md` |
