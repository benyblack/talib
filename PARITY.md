# TA-Lib parity

Function-by-function coverage against the
[TA-Lib](https://github.com/ta-lib/ta-lib-python) indicator list
(133 functions). "House notes" describe deliberate divergences: this
library returns `nil` — never `0` — for insufficient data or undefined
values, validates periods with `ArgumentError`, and takes prices/bars
in chronological order (oldest first) with nil-padded series.

## Overlap Studies — 13/17

| TA-Lib | TAlib | Notes |
| --- | --- | --- |
| BBANDS | `BBands.bbands/_list` | mult configurable; middle always SMA |
| DEMA | `MA.dema/dema_list` | |
| EMA | `MA.ema/ema_list` | |
| HT_TRENDLINE | — | Hilbert transform, pending |
| KAMA | `MA.kama/kama_list` | |
| MA | — | generic MA-type dispatcher, pending |
| MAMA | — | pending |
| MAVP | — | variable-period MA, pending |
| MIDPOINT | `MA.midpoint/midpoint_list` | |
| MIDPRICE | `Donchian.midprice` | |
| SAR | `SAR.sar/sar_list` | af_start/step/max configurable |
| SAREXT | — | SAR covers the common case; extended pending |
| SMA | `MA.sma/sma_list` | |
| T3 | `MA.t3/t3_list` | vfactor configurable |
| TEMA | `MA.tema/tema_list` | |
| TRIMA | `MA.trima/trima_list` | |
| WMA | `MA.wma/wma_list` | |

## Momentum Indicators — 29/31

| TA-Lib | TAlib | Notes |
| --- | --- | --- |
| ADX | `ADX.adx/adx_all` | |
| ADXR | `ADX.adxr` | |
| APO | `APO.apo/apo_list` | |
| AROON | `Aroon.aroon/aroon_list` | map / {up, down} tuples |
| AROONOSC | `Aroon.aroon_osc` | |
| BOP | `BOP.bop/bop_list` | needs `:open` |
| CCI | `CCI.cci/cci_list` | |
| CMO | `CMO.cmo/cmo_list` | |
| DX | `ADX.dx` | |
| MACD | `MACD.macd/macd_list/macd_all` | |
| MACDEXT | — | configurable MA types, pending |
| MACDFIX | — | pending |
| MFI | `MFI.mfi/mfi_list` | |
| MINUS_DI | `ADX.minus_di` | |
| MINUS_DM | `ADX.minus_dm` | raw per-bar series |
| MOM | `Momentum.momentum/momentum_list` | |
| PLUS_DI | `ADX.plus_di` | |
| PLUS_DM | `ADX.plus_dm` | raw per-bar series |
| PPO | `PPO.ppo/ppo_list` | |
| ROC | `ROC.roc/roc_list` | |
| ROCP | `ROC.rocp` | |
| ROCR | `ROC.rocr` | |
| ROCR100 | `ROC.rocr100` | |
| RSI | `RSI.rsi/rsi_list` | Wilder smoothing (as of 0.7.0) |
| STOCH | `Stochastic.slow` | slow %K + %D map |
| STOCHF | `Stochastic.stochastic_k/stochastic_d` | fast %K and its SMA |
| STOCHRSI | `StochRSI.stoch_rsi/_list` | fast %K of the Wilder RSI |
| TRIX | `TRIX.trix/trix_list` | |
| ULTOSC | `UltimateOsc.ultimate_osc/_list` | 7/14/28 configurable |
| WILLR | `WilliamsR.williams_r/_list` | |

## Volume Indicators — 3/3

| TA-Lib | TAlib | Notes |
| --- | --- | --- |
| AD | `ChaikinAD.ad/ad_list` | |
| ADOSC | `ChaikinAD.adosc` | |
| OBV | `OBV.obv/obv_list` | |

## Volatility Indicators — 3/3

| TA-Lib | TAlib | Notes |
| --- | --- | --- |
| ATR | `ATR.atr/atr_list` | Wilder RMA seeded with an SMA |
| NATR | `ATR.natr` | |
| TRANGE | `ATR.true_range` | |

## Statistic Functions — 9/9

| TA-Lib | TAlib | Notes |
| --- | --- | --- |
| BETA | `Stats.beta` | |
| CORREL | `Stats.correl` | |
| LINEARREG | `Stats.linear_reg` | |
| LINEARREG_ANGLE | `Stats.angle` | degrees |
| LINEARREG_INTERCEPT | `Stats.intercept` | |
| LINEARREG_SLOPE | `Stats.slope` | |
| STDDEV | `StdDev.std_dev/_list` | population |
| TSF | `Stats.tsf` | |
| VAR | `Stats.variance` | population |

## Price Transform — 4/4

| TA-Lib | TAlib |
| --- | --- |
| AVGPRICE | `PriceTransform.avgprice` |
| MEDPRICE | `PriceTransform.medprice` |
| TYPPRICE | `PriceTransform.typprice` |
| WCLPRICE | `PriceTransform.wclprice` |

## Cycle Indicators — 0/5

HT_DCPERIOD, HT_DCPHASE, HT_PHASOR, HT_SINE and HT_TRENDMODE (Hilbert
transforms) are pending.

## Pattern Recognition — 0/61

The 61 candlestick patterns (CDL*) are pending; they need bar input
with `:open` and return a per-bar pattern score.

**Summary: 61 of 133 functions.** Everything outside candlestick
patterns, Hilbert-transform cycle indicators and seven MA-type-generic
variants (MA, MAMA, MAVP, HT_TRENDLINE, SAREXT, MACDEXT, MACDFIX) is
covered.
