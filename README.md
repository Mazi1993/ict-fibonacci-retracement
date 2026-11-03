# ICT-inspired Fibonacci retracement for MetaTrader 5

An MQL5 **custom indicator**, not an automated trading robot. It plots Fibonacci
optimal trade entry (OTE) levels after a liquidity sweep and a displacement-backed
market structure shift (MSS). Optional fair value gap (FVG) confluence is available.
No orders are submitted.

## Install

1. Download `MQL5/Indicators/ICTFibonacciRetracement.mq5`.
2. In MT5, choose **File → Open Data Folder** and copy the file into `MQL5/Indicators`.
3. Open it in MetaEditor and press **F7** to compile.
4. Refresh the Navigator's Indicators list and attach the indicator to a chart.
5. Enable popup alerts in its Inputs if wanted. Push alerts also require MT5's
   **Tools → Options → Notifications** configuration.

## Exact rules

- A pivot must be strictly higher/lower than `SwingDepth` bars on both sides.
  Equal highs/lows are not pivots. A pivot is available only after its right-side
  bars close; it is not treated as known on the original pivot candle.
- A bullish sweep trades below the latest confirmed swing low, then closes back
  above it and below the confirmed swing high. Bearish rules are reversed.
  Bars sweeping both sides are ignored. The opposing pivot level is frozen at
  the sweep; a new qualifying sweep replaces the pending sweep.
- On a **later closed bar**, price must close through that frozen opposing pivot
  with a directional candle body of at least `DisplacementATR × Wilder ATR`.
  A breach of the sweep extreme or expiry cancels a pending sweep.
- The impulse runs from the sweep extreme to the **MSS candle's high/low**.
  Its anchors remain fixed; later highs/lows do not move them.
- Bullish retracements are `high − range × ratio`; bearish retracements are
  `low + range × ratio`. Ratios are **0.62, 0.705 and 0.79**.
- Optional FVG: the MSS candle must form a three-candle gap
  (`low[i] > high[i−2]` bullish, reversed bearish), and that gap must intersect
  the 62–79% zone. This strict filter is off by default.
- Invalidation is the sweep extreme plus an outward padding in **symbol points**,
  not pips. The displayed target is the impulse tip. These are reference levels.
- An arrow marks the first later closed candle whose range overlaps the OTE zone.
  This is a zone touch, not confirmation of a profitable trade. Each setup signals
  once. Touches on the MSS candle are excluded.
- A stop touch, target touch, timeout, or replacement MSS retires the setup. If a
  candle hits both a reference exit and the zone, the exit takes priority and no
  arrow is emitted, because OHLC data cannot determine the intrabar sequence.

## Inputs and buffers

Defaults: swing depth 3; ATR 14; displacement 1× ATR; sweep expiry 12 bars;
setup expiry 50 bars; padding 10 points; replay window 5,000 bars; alerts off.

| Buffer | Value |
| --- | --- |
| 0 | 62% retracement |
| 1 | 70.5% retracement |
| 2 | 79% retracement |
| 3 | Invalidation reference |
| 4 | Impulse target reference |
| 5 | Bullish zone-touch arrow price |
| 6 | Bearish zone-touch arrow price |

For `iCustom` consumers, absent values are `EMPTY_VALUE`. Read signal buffers
on shift 1 (the last closed candle), never shift 0.

## Timing and limitations

Signals use closed candles and confirmed pivots. The indicator recalculates on a
new bar or history reset; levels extend onto the forming candle for display only.
Initial attachment does not alert for historical signals. A new-bar alert refers
to the candle that just closed, not its intrabar touch time.

The most recent `HistoryBars` candles are replayed from empty state, with ATR
calculated from available history. As this bounded window advances, early setups
can disappear or change if their preceding context leaves the window. Broker
history corrections and additional loaded data can also change results. Replacing
a setup blanks the preceding level segment to avoid connecting different zones.
This is not a promise of immutable historical plotting.

These are explicit approximations of discretionary ICT concepts, not an official
ICT implementation or a complete trading model. There are no session/kill-zone,
higher-timeframe bias, order block, spread, commission, or execution filters.
No win rate or profitability is claimed. Validate on demo data before using it
in trading decisions.

## Validation status

Source review and local static checks are available; MetaEditor and an MT5 terminal
are not installed in the authoring environment. **Compilation and chart behavior
must still be verified in MT5.** See [the validation checklist](docs/VALIDATION.md).
