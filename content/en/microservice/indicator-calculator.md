+++
title = "indicator-calculator"
weight = 71
+++

1. **FGI and Support/Resistance**

   * **FGI (Fear & Greed Index)** is not a purely technical indicator, but a "meta-assessment" of sentiment. In a simplified version, it can be calculated as a function of volatility, volumes, and distance to levels:

     $$
     FGI = w_1 \cdot RSI + w_2 \cdot \frac{\text{Volume}}{\text{MA(Volume)}} + w_3 \cdot \frac{|Price - SR\_Level|}{Price}
     $$

     where $w_i$ are weights (e.g., 0.4, 0.3, 0.3). The result is normalized to the range \[0,100].

     > **FGI < 30** → fear (market is oversold), **FGI > 70** → greed (overbought).

   * **Support / Resistance**
     Algorithm:

     1. Calculate local extrema (using `argrelextrema` or through level clusters).
     2. Aggregate level clusters with `tol` = 0.1–0.5%.
     3. Signals:

        * **Breakout upwards**: price crosses the nearest resistance with increasing volume → buy signal.
        * **Rebound downwards**: price bounces off support (candle reversal + RSI < 30) → buy.
        * Similarly for a short on a downward breakout or a rebound from resistance.

2. **Additional Indicators**

   * **VWAP (Volume Weighted Average Price)**:

     $$
     VWAP = \frac{\sum (Price_i \cdot Volume_i)}{\sum Volume_i}
     $$

     Works well in backfill: you can store intraday VWAP and check if the current price is higher/lower.

   * **OBV (On Balance Volume)**:

     $$
     OBV_t = OBV_{t-1} + \begin{cases} 
     Volume_t, & Price_t > Price_{t-1} \\ 
     -Volume_t, & Price_t < Price_{t-1} \\
     0, & \text{otherwise} 
     \end{cases}
     $$

     Price growth with OBV growth confirms the trend.

   * **SuperTrend** (trend filter):
     Based on ATR:

     $$
     \text{UpperBand} = \frac{High+Low}{2} + m \cdot ATR
     $$

     $$
     \text{LowerBand} = \frac{High+Low}{2} - m \cdot ATR
     $$

     where $m$ is a multiplier (e.g., 3). The SuperTrend line switches depending on the candle breakout.

3. **Backfill via Kafka**
   Everything is logical:

   * create a consumer with `group.id = f"backfill-{time.time()}"`,
   * `auto_offset_reset="earliest"`,
   * process all messages from the beginning of the `orderbook/trades` topics,
   * aggregate into candles + indicators,
   * publish only to the **final topic** (interactive is disabled),
   * terminate the consumer upon reaching the end of the log.