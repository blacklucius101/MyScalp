# MyScalp
MT5 Expert Advisor and its related Indicators

## TradeAssistant.mq5 Retracement Lines

The `TradeAssistant.mq5` expert advisor implements retracement lines based on signals from the `Single_Level_ZZ_Semafor` custom indicator.

### Implementation Details

1.  **Signal Trigger**: The drawing of retracement lines is triggered by the `Single_Level_ZZ_Semafor` indicator. The expert advisor looks for new high (bearish) or low (bullish) signals on the most recently closed candle.

2.  **Calculation**:
    *   **Bearish Retracement**: When a high semafor (bearish signal) appears on the previous candle, a retracement level is calculated. The formula is:
        ```
        ThresholdPrice = CandleHigh - ((Input_Signal_Threshold / 100.0) * CandleRange)
        ```
        Where `CandleHigh` and `CandleRange` are from the signal candle. `Input_Signal_Threshold` is a user-configurable percentage.

    *   **Bullish Retracement**: When a low semafor (bullish signal) appears on the previous candle, the retracement level is calculated with the formula:
        ```
        ThresholdPrice = CandleLow + ((Input_Signal_Threshold / 100.0) * CandleRange)
        ```
        Where `CandleLow` and `CandleRange` are from the signal candle.

3.  **Drawing**: The calculated `ThresholdPrice` is then used to draw a horizontal line (`OBJ_TREND`) on the chart, starting from the signal candle.

4.  **Dynamic Retracement Labels**: The `OnTick` function continuously calculates the current price's retracement percentage relative to the most recent high and low semafor points. 
    *   It uses the `FindLatestSemaforTA` function to identify the latest semafor signals.
    *   It then calculates the percentage of retracement from the semafor price to the current bid/ask price.
    *   This percentage is displayed on the chart using labels, providing a real-time view of the market's retracement.
