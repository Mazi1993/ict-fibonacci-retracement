# MT5 validation checklist

Not yet executed in MetaTrader/MetaEditor.

1. Compile with F7 in MetaEditor; resolve any errors before attaching.
2. Attach to a liquid symbol with sufficient history. Check the Experts/Journal
   tabs for errors; change timeframe and inputs and confirm clean initialization.
3. Find a bullish example: confirm a low sweep, a later bullish displacement close
   above the opposing pivot, and levels measured from sweep low to MSS high.
   Repeat with reversed rules for a bearish example.
4. Check the arithmetic: for a bullish 100→110 impulse, levels must be
   103.8, 102.95 and 102.1. For a bearish 110→100 impulse, levels must be
   106.2, 107.05 and 107.9.
5. Use visual replay to confirm a pivot becomes usable only after its right-hand
   candles close. No signal may appear on the forming candle or MSS candle.
6. Confirm at most one touch arrow per setup, pending sweep expiry/invalidation,
   setup expiry, and stop/target retirement. Check an OHLC bar crossing both the
   zone and stop/target: it must produce no arrow.
7. Enable FVG filtering: every new setup's MSS candle must form a strict gap with
   the candle two bars back, and the gap must overlap its retracement zone.
8. Enable popup alerts on a demo chart. Historical attachment must be silent;
   a newly closed touch candle must alert once despite repeated ticks. Configure
   terminal notifications separately before testing push alerts.
9. Compare pairs with different digits and a metal/index: padding is expressed
   in each symbol's points. Check prices visually using the Data Window.
10. Reload and compare within identical history. Increase the replay window to
    inspect boundary sensitivity; the bounded replay is documented in README.
